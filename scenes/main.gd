extends Node2D

enum PauseSlotMode { NONE, SAVE, LOAD }

@onready var dialog_box = $UI/DialogBox
@onready var dialog_text = $UI/DialogBox/DialogText
@onready var speaker_name = $UI/DialogBox/SpeakerName
@onready var speaker_avatar = $UI/DialogBox/SpeakerAvatar
@onready var type_sound = $TypeSound
@onready var next_indicator = $UI/DialogBox/NextIndicator
@onready var next_indicator_arrow = $UI/DialogBox/NextIndicator/Arrow
@onready var player = $Player
@onready var lumi = $Lumi
@onready var lumi_follow_pivot = $Lumi/CollisionShape2D
@onready var orion_glow = $OrionTrigger/GlowSprite
@onready var orion_light = $OrionTrigger/PointLight2D
var active_dialogs = []
var prelude_layer: CanvasLayer
var prelude_shade: ColorRect
var prelude_visual_label: Label
var choice_layer: CanvasLayer
var choice_panel: PanelContainer
var choice_default_button: Button
var next_indicator_arrow_base_position = Vector2.ZERO
var next_indicator_tween: Tween
var scene_shake_tween: Tween
const NEXT_INDICATOR_FLOAT_DISTANCE = 4.0
const NEXT_INDICATOR_BREATH_DURATION = 0.55
const NEXT_INDICATOR_DIM_ALPHA = 0.45
const SLOT_DOUBLE_PRESS_MS = 450
const ORION_GLOW_BASE_SCALE = Vector2(1.0, 1.0)
const ORION_GLOW_PEAK_SCALE = Vector2(1.22, 1.22)
const ORION_GLOW_DIM_ALPHA = 0.62
const ORION_GLOW_PEAK_ALPHA = 1.0
const LUMI_FOLLOW_OFFSET = Vector2(-42, -34)
const LUMI_FOLLOW_SPEED = 165.0
const LUMI_FOLLOW_STOP_DISTANCE = 18.0
const LUMI_FOLLOW_DRIFT_DISTANCE = 7.0
const LUMI_FOLLOW_DRIFT_SPEED = 2.2
const PROLOGUE_DIALOGUE_PATH = "res://data/dialogues/prologue.json"
var dialogue_sets = {}
var active_dialogue_id = ""
var current_index = 0
var dialog_active = false
var is_typing = false
var full_text = ""

var can_talk_to_lumi = false
var lumi_follow_enabled = false
var lumi_follow_time = 0.0
var pause_menu: Control
var pause_status_label: Label
var pause_slot_modal: Control
var pause_slot_title_label: Label
var pause_slot_status_label: Label
var pause_slot_action_button: Button
var pause_slot_buttons: Array[Button] = []
var pause_selected_slot := 1
var pause_slot_mode := PauseSlotMode.NONE
var pause_overwrite_confirm_slot := -1
var pause_last_slot_press_slot := -1
var pause_last_slot_press_msec := 0
var was_player_movable_before_menu = true

func _ready():
	dialog_box.visible = false
	SaveManager.register_player(player)
	load_dialogue_sets()
	build_prelude_overlay()
	build_choice_overlay()
	setup_pause_menu()
	next_indicator.visible = true
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	await get_tree().process_frame
	next_indicator_arrow_base_position = next_indicator_arrow.position
	hide_next_indicator()
	play_lumi_idle()
	MusicManager.play_context("overworld")
	pulse_orion_light()
	if SaveManager.has_flag("prelude_complete"):
		SaveManager.set_location("小島")
	else:
		SaveManager.set_location("亞特蘭提斯")
	if not SaveManager.has_flag("prelude_opening_complete"):
		start_dialog("prelude_opening")
	elif not SaveManager.has_flag("tutorial_complete"):
		start_dialog("tutorial")

func _physics_process(delta):
	update_lumi_follow(delta)
	SaveManager.track_player_position(player.global_position)

func _exit_tree() -> void:
	SaveManager.unregister_player(player)

func pulse_orion_light():
	orion_light.energy = 2.0
	orion_glow.scale = ORION_GLOW_BASE_SCALE
	orion_glow.modulate.a = ORION_GLOW_DIM_ALPHA

	var tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(orion_light, "energy", 3.4, 0.9)
	tween.parallel().tween_property(orion_glow, "scale", ORION_GLOW_PEAK_SCALE, 0.9)
	tween.parallel().tween_property(orion_glow, "modulate:a", ORION_GLOW_PEAK_ALPHA, 0.9)
	tween.tween_property(orion_light, "energy", 1.35, 0.9)
	tween.parallel().tween_property(orion_glow, "scale", ORION_GLOW_BASE_SCALE, 0.9)
	tween.parallel().tween_property(orion_glow, "modulate:a", ORION_GLOW_DIM_ALPHA, 0.9)

func update_lumi_follow(delta):
	if not lumi_follow_enabled:
		return

	lumi_follow_time += delta
	var drift = Vector2(
		sin(lumi_follow_time * LUMI_FOLLOW_DRIFT_SPEED),
		cos(lumi_follow_time * LUMI_FOLLOW_DRIFT_SPEED * 0.8)
	) * LUMI_FOLLOW_DRIFT_DISTANCE
	var target_position = player.global_position + LUMI_FOLLOW_OFFSET + drift
	var current_position = lumi_follow_pivot.global_position
	var distance = current_position.distance_to(target_position)

	if distance <= LUMI_FOLLOW_STOP_DISTANCE:
		return

	var next_position = current_position.move_toward(target_position, LUMI_FOLLOW_SPEED * delta)
	lumi.global_position += next_position - current_position

func _input(event):
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if dialog_active:
			return

		if pause_slot_modal and pause_slot_modal.visible:
			close_pause_slot_modal()
			return

		toggle_pause_menu()
		return

	if pause_menu and pause_menu.visible:
		return

	if pause_slot_modal and pause_slot_modal.visible:
		return

	if choice_layer and choice_layer.visible:
		return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if not dialog_active:
			if can_talk_to_lumi:
				start_dialog("lumi_intro")
		elif is_typing:
			is_typing = false
			dialog_text.text = full_text
			show_next_indicator()
		else:
			next_dialog()

func load_dialogue_sets():
	var file = FileAccess.open(PROLOGUE_DIALOGUE_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not load dialogue file: %s" % PROLOGUE_DIALOGUE_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Dialogue file data is invalid: %s" % PROLOGUE_DIALOGUE_PATH)
		return

	dialogue_sets = parsed

func start_dialog(dialogue_id: String):
	if not dialogue_sets.has(dialogue_id):
		push_warning("Dialogue id not found: %s" % dialogue_id)
		return

	dialog_active = true
	dialog_box.visible = true
	active_dialogue_id = dialogue_id
	active_dialogs = dialogue_sets[dialogue_id]
	current_index = 0

	player.can_move = false

	show_dialog(current_index)

func next_dialog():
	current_index += 1
	if current_index >= active_dialogs.size():
		end_dialog()
	else:
		show_dialog(current_index)

func show_dialog(index):
	var d = active_dialogs[index]
	var speaker_id = str(d.get("speaker", ""))
	var expression = str(d.get("expression", "default"))
	update_prelude_scene(str(d.get("scene", "")))
	if str(d.get("effect", "")) == "shake":
		shake_scene()
	speaker_name.text = CharacterVisualManager.get_display_name(speaker_id)
	full_text = d["text"]
	dialog_text.text = ""
	var portrait = CharacterVisualManager.get_portrait(speaker_id, expression)
	speaker_avatar.texture = portrait
	speaker_avatar.visible = portrait != null
	is_typing = true
	type_text()
	hide_next_indicator()

func type_text():
	for i in range(full_text.length()):
		if not is_typing:
			break

		dialog_text.text = full_text.substr(0, i + 1)

		if full_text[i] != " ":
			if type_sound:
				type_sound.stop()
				type_sound.play()

		await get_tree().create_timer(0.05).timeout

	is_typing = false
	if type_sound:
		type_sound.stop()
	show_next_indicator()

func end_dialog():
	if active_dialogue_id == "prelude_opening":
		SaveManager.set_flag("prelude_opening_complete")
		SaveManager.set_location("亞特蘭提斯")
		SaveManager.autosave(true)
		clear_prelude_overlay()
		start_dialog("tutorial")
		return
	elif active_dialogue_id == "tutorial":
		SaveManager.set_flag("tutorial_complete")
	elif active_dialogue_id == "lumi_intro":
		SaveManager.set_flag("talked_to_lumi")
		lumi_follow_enabled = true
	elif active_dialogue_id == "orion_first_seen":
		SaveManager.set_flag("orion_discovered")
		SaveManager.set_location("墜落地點")
		SaveManager.autosave(true)
		dialog_active = false
		dialog_box.visible = false
		hide_next_indicator()
		active_dialogue_id = ""
		show_orion_choice()
		return
	elif active_dialogue_id == "orion_rescue":
		SaveManager.set_flag("prelude_complete")
		SaveManager.set_location("小島")
		clear_prelude_overlay()
		MusicManager.play_context("overworld")

	dialog_active = false
	dialog_box.visible = false
	hide_next_indicator()
	active_dialogue_id = ""

	player.can_move = true
	SaveManager.autosave(true)

func build_prelude_overlay() -> void:
	prelude_layer = CanvasLayer.new()
	prelude_layer.name = "PreludeLayer"
	prelude_layer.layer = 0
	add_child(prelude_layer)

	prelude_shade = ColorRect.new()
	prelude_shade.color = Color(0.0, 0.0, 0.0, 0.0)
	prelude_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	prelude_layer.add_child(prelude_shade)

	prelude_visual_label = Label.new()
	prelude_visual_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	prelude_visual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prelude_visual_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prelude_visual_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prelude_visual_label.add_theme_font_size_override("font_size", 30)
	prelude_visual_label.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0, 0.92))
	prelude_visual_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	prelude_visual_label.add_theme_constant_override("shadow_offset_x", 2)
	prelude_visual_label.add_theme_constant_override("shadow_offset_y", 2)
	prelude_visual_label.offset_left = 72
	prelude_visual_label.offset_right = -72
	prelude_layer.add_child(prelude_visual_label)

	prelude_layer.visible = false

func build_choice_overlay() -> void:
	choice_layer = CanvasLayer.new()
	choice_layer.name = "ChoiceLayer"
	choice_layer.layer = 20
	add_child(choice_layer)

	var shade = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.add_child(shade)

	choice_panel = PanelContainer.new()
	choice_panel.custom_minimum_size = Vector2(360, 170)
	choice_panel.anchor_left = 0.5
	choice_panel.anchor_top = 0.5
	choice_panel.anchor_right = 0.5
	choice_panel.anchor_bottom = 0.5
	choice_panel.offset_left = -180
	choice_panel.offset_top = -85
	choice_panel.offset_right = 180
	choice_panel.offset_bottom = 85
	choice_layer.add_child(choice_panel)

	var menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	choice_panel.add_child(menu)

	var prompt = Label.new()
	prompt.text = "怎麼辦……？"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.custom_minimum_size = Vector2(320, 34)
	menu.add_child(prompt)

	var rescue_button = Button.new()
	rescue_button.text = "救他"
	rescue_button.custom_minimum_size = Vector2(320, 42)
	rescue_button.pressed.connect(Callable(self, "_on_orion_choice_selected").bind("rescue"))
	menu.add_child(rescue_button)
	choice_default_button = rescue_button

	var report_button = Button.new()
	report_button.text = "交給監督型"
	report_button.custom_minimum_size = Vector2(320, 42)
	report_button.pressed.connect(Callable(self, "_on_orion_choice_selected").bind("report"))
	menu.add_child(report_button)

	choice_layer.visible = false

func update_prelude_scene(scene_id: String) -> void:
	if scene_id == "":
		return

	prelude_layer.visible = true
	var scene_data = get_prelude_scene_data(scene_id)
	prelude_shade.color = scene_data["color"]
	prelude_visual_label.text = scene_data["label"]

func get_prelude_scene_data(scene_id: String) -> Dictionary:
	var scenes = {
		"black": {"label": "", "color": Color(0.0, 0.0, 0.0, 0.94)},
		"book": {"label": "古老童話書", "color": Color(0.08, 0.05, 0.03, 0.72)},
		"fairytale": {"label": "水彩般的海面與人魚公主", "color": Color(0.06, 0.14, 0.2, 0.55)},
		"storm": {"label": "暴風雨", "color": Color(0.02, 0.03, 0.07, 0.68)},
		"dawn": {"label": "黎明", "color": Color(0.18, 0.16, 0.12, 0.44)},
		"atlantis": {"label": "亞特蘭提斯", "color": Color(0.0, 0.08, 0.14, 0.36)},
		"quake": {"label": "海底都市震動", "color": Color(0.08, 0.02, 0.02, 0.5)},
		"impact": {"label": "燃燒的光墜入深海", "color": Color(0.12, 0.06, 0.0, 0.48)},
		"wreck": {"label": "墜落地點", "color": Color(0.06, 0.07, 0.08, 0.38)},
		"escort": {"label": "拖行", "color": Color(0.0, 0.04, 0.08, 0.46)},
		"island": {"label": "暴雨後的小島", "color": Color(0.05, 0.07, 0.09, 0.52)},
		"observatory": {"label": "深海觀測室", "color": Color(0.03, 0.0, 0.08, 0.5)},
		"portal": {"label": "傳送門", "color": Color(0.0, 0.1, 0.12, 0.48)},
		"farewell": {"label": "離別", "color": Color(0.0, 0.06, 0.12, 0.42)},
		"lighthouse": {"label": "廢棄燈塔", "color": Color(0.12, 0.12, 0.1, 0.44)}
	}
	return scenes.get(scene_id, {"label": "", "color": Color(0.0, 0.0, 0.0, 0.0)})

func clear_prelude_overlay() -> void:
	prelude_layer.visible = false
	prelude_visual_label.text = ""
	prelude_shade.color = Color(0.0, 0.0, 0.0, 0.0)

func shake_scene() -> void:
	if scene_shake_tween:
		scene_shake_tween.kill()

	position = Vector2.ZERO
	scene_shake_tween = create_tween()
	scene_shake_tween.tween_property(self, "position", Vector2(9, -5), 0.04)
	scene_shake_tween.tween_property(self, "position", Vector2(-8, 6), 0.04)
	scene_shake_tween.tween_property(self, "position", Vector2(6, 4), 0.04)
	scene_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.06)

func show_orion_choice() -> void:
	player.can_move = false
	choice_layer.visible = true
	choice_default_button.grab_focus()

func _on_orion_choice_selected(_choice_id: String) -> void:
	choice_layer.visible = false
	start_dialog("orion_rescue")

func show_next_indicator():

	if next_indicator_tween:
		next_indicator_tween.kill()

	next_indicator.visible = true

	next_indicator_arrow.position = next_indicator_arrow_base_position
	next_indicator_arrow.modulate.a = NEXT_INDICATOR_DIM_ALPHA

	next_indicator_tween = create_tween()
	next_indicator_tween.set_loops()

	next_indicator_tween.set_trans(Tween.TRANS_SINE)
	next_indicator_tween.set_ease(Tween.EASE_IN_OUT)

	next_indicator_tween.tween_property(
		next_indicator_arrow,
		"position",
		next_indicator_arrow_base_position + Vector2(0, -NEXT_INDICATOR_FLOAT_DISTANCE),
		NEXT_INDICATOR_BREATH_DURATION
	)

	next_indicator_tween.parallel().tween_property(
		next_indicator_arrow,
		"modulate:a",
		1.0,
		NEXT_INDICATOR_BREATH_DURATION
	)

	next_indicator_tween.tween_property(
		next_indicator_arrow,
		"position",
		next_indicator_arrow_base_position,
		NEXT_INDICATOR_BREATH_DURATION
	)

	next_indicator_tween.parallel().tween_property(
		next_indicator_arrow,
		"modulate:a",
		NEXT_INDICATOR_DIM_ALPHA,
		NEXT_INDICATOR_BREATH_DURATION
	)
func hide_next_indicator():
	if next_indicator_tween:
		next_indicator_tween.kill()
		next_indicator_tween = null
	next_indicator.visible = false
	next_indicator_arrow.position = next_indicator_arrow_base_position
	next_indicator_arrow.modulate.a = 1.0

func play_lumi_idle():
	for lumi_sprite in lumi.find_children("*", "AnimatedSprite2D", true, false):
		if not lumi_sprite or not lumi_sprite.sprite_frames:
			continue

		var idle_animation = lumi_sprite.animation
		if not lumi_sprite.sprite_frames.has_animation(idle_animation):
			if lumi_sprite.sprite_frames.has_animation("idle_down"):
				idle_animation = "idle_down"
			elif lumi_sprite.sprite_frames.has_animation("default"):
				idle_animation = "default"
			else:
				continue

		lumi_sprite.play(idle_animation)

func setup_pause_menu() -> void:
	var layer = CanvasLayer.new()
	layer.name = "PauseMenuLayer"
	add_child(layer)

	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pause_menu)

	var shade = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(shade)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 260)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -140
	panel.offset_top = -130
	panel.offset_right = 140
	panel.offset_bottom = 130
	pause_menu.add_child(panel)

	var menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	panel.add_child(menu)

	var title = Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	menu.add_child(title)

	pause_status_label = Label.new()
	pause_status_label.text = ""
	pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_status_label.custom_minimum_size = Vector2(240, 30)
	menu.add_child(pause_status_label)

	var resume_button = create_pause_button("Resume")
	resume_button.pressed.connect(close_pause_menu)
	menu.add_child(resume_button)

	var save_button = create_pause_button("Save")
	save_button.pressed.connect(save_from_pause_menu)
	menu.add_child(save_button)

	var load_button = create_pause_button("Load")
	load_button.pressed.connect(load_from_pause_menu)
	menu.add_child(load_button)

	var title_button = create_pause_button("Title")
	title_button.pressed.connect(return_to_title)
	menu.add_child(title_button)

	build_pause_slot_modal(layer)

func build_pause_slot_modal(layer: CanvasLayer) -> void:
	pause_slot_modal = Control.new()
	pause_slot_modal.name = "PauseSlotModal"
	pause_slot_modal.visible = false
	pause_slot_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pause_slot_modal)

	var shade = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_slot_modal.add_child(shade)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 540)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_top = -270
	panel.offset_right = 230
	panel.offset_bottom = 270
	pause_slot_modal.add_child(panel)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	pause_slot_title_label = Label.new()
	pause_slot_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_slot_title_label.add_theme_font_size_override("font_size", 24)
	pause_slot_title_label.custom_minimum_size = Vector2(360, 38)
	content.add_child(pause_slot_title_label)

	var slot_scroll = ScrollContainer.new()
	slot_scroll.custom_minimum_size = Vector2(360, 310)
	content.add_child(slot_scroll)

	var slot_list = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 8)
	slot_scroll.add_child(slot_list)

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var slot_button = create_pause_button("")
		slot_button.custom_minimum_size = Vector2(360, 38)
		slot_button.toggle_mode = true
		slot_button.pressed.connect(select_pause_slot.bind(slot))
		pause_slot_buttons.append(slot_button)
		slot_list.add_child(slot_button)

	pause_slot_status_label = Label.new()
	pause_slot_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_slot_status_label.custom_minimum_size = Vector2(360, 30)
	pause_slot_status_label.modulate = Color(0.78, 0.9, 1.0, 1.0)
	content.add_child(pause_slot_status_label)

	pause_slot_action_button = create_pause_button("")
	pause_slot_action_button.custom_minimum_size = Vector2(360, 38)
	pause_slot_action_button.pressed.connect(confirm_pause_slot_action)
	content.add_child(pause_slot_action_button)

	var back_button = create_pause_button("Back")
	back_button.custom_minimum_size = Vector2(360, 38)
	back_button.pressed.connect(close_pause_slot_modal)
	content.add_child(back_button)

func create_pause_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 38)
	return button

func toggle_pause_menu() -> void:
	if pause_menu.visible:
		close_pause_menu()
	else:
		open_pause_menu()

func open_pause_menu() -> void:
	was_player_movable_before_menu = player.can_move
	player.can_move = false
	pause_status_label.text = ""
	pause_menu.visible = true

func close_pause_menu() -> void:
	close_pause_slot_modal()
	pause_menu.visible = false
	player.can_move = was_player_movable_before_menu

func save_from_pause_menu() -> void:
	open_pause_slot_modal(PauseSlotMode.SAVE)

func load_from_pause_menu() -> void:
	if not has_any_pause_save():
		pause_status_label.text = "No save data"
		return

	open_pause_slot_modal(PauseSlotMode.LOAD)

func open_pause_slot_modal(mode: int) -> void:
	pause_slot_mode = mode
	pause_overwrite_confirm_slot = -1
	pause_last_slot_press_slot = -1
	if pause_slot_mode == PauseSlotMode.SAVE:
		pause_selected_slot = SaveManager.active_slot
		pause_slot_title_label.text = "Save"
		pause_slot_action_button.text = "Save"
	else:
		pause_selected_slot = SaveManager.get_latest_save_slot(SaveManager.active_slot)
		pause_slot_title_label.text = "Load"
		pause_slot_action_button.text = "Load"

	pause_slot_modal.visible = true
	refresh_pause_slots()
	pause_slot_buttons[pause_selected_slot - 1].grab_focus()

func close_pause_slot_modal() -> void:
	if not pause_slot_modal:
		return

	pause_slot_mode = PauseSlotMode.NONE
	pause_overwrite_confirm_slot = -1
	pause_last_slot_press_slot = -1
	pause_slot_modal.visible = false

func select_pause_slot(slot: int) -> void:
	var now = Time.get_ticks_msec()
	var is_double_press = slot == pause_selected_slot and slot == pause_last_slot_press_slot and now - pause_last_slot_press_msec <= SLOT_DOUBLE_PRESS_MS
	pause_selected_slot = slot
	if not is_double_press:
		pause_overwrite_confirm_slot = -1
	refresh_pause_slots()
	pause_last_slot_press_slot = slot
	pause_last_slot_press_msec = now
	if is_double_press:
		quick_confirm_pause_slot_action()

func refresh_pause_slots() -> void:
	for index in range(pause_slot_buttons.size()):
		var slot = index + 1
		var summary = SaveManager.get_save_summary(slot)
		var button = pause_slot_buttons[index]
		button.button_pressed = slot == pause_selected_slot
		button.disabled = pause_slot_mode == PauseSlotMode.LOAD and not bool(summary["exists"])
		button.text = format_pause_slot_summary(summary)

	var selected_summary = SaveManager.get_save_summary(pause_selected_slot)
	if pause_slot_mode == PauseSlotMode.LOAD:
		pause_slot_action_button.text = "Load"
		pause_slot_action_button.disabled = not bool(selected_summary["exists"])
		pause_slot_status_label.text = ""
	else:
		pause_slot_action_button.disabled = false
		if selected_summary["exists"]:
			if pause_overwrite_confirm_slot == pause_selected_slot:
				pause_slot_action_button.text = "Confirm Overwrite"
				pause_slot_status_label.text = "Press again to overwrite Slot %d." % pause_selected_slot
			else:
				pause_slot_action_button.text = "Save"
				pause_slot_status_label.text = "This will overwrite existing save data."
		else:
			pause_slot_action_button.text = "Save"
			pause_slot_status_label.text = ""

func confirm_pause_slot_action() -> void:
	if pause_slot_mode == PauseSlotMode.SAVE:
		var selected_summary = SaveManager.get_save_summary(pause_selected_slot)
		if bool(selected_summary["exists"]) and pause_overwrite_confirm_slot != pause_selected_slot:
			pause_overwrite_confirm_slot = pause_selected_slot
			refresh_pause_slots()
			return

		SaveManager.set_player_position(player.global_position)
		if SaveManager.save_game(pause_selected_slot):
			pause_status_label.text = "Saved Slot %d" % pause_selected_slot
			close_pause_slot_modal()
		else:
			pause_slot_status_label.text = "Save failed"
	elif pause_slot_mode == PauseSlotMode.LOAD:
		load_pause_slot()

func quick_confirm_pause_slot_action() -> void:
	if pause_slot_mode == PauseSlotMode.SAVE:
		SaveManager.set_player_position(player.global_position)
		if SaveManager.save_game(pause_selected_slot):
			pause_status_label.text = "Saved Slot %d" % pause_selected_slot
			close_pause_slot_modal()
		else:
			pause_slot_status_label.text = "Save failed"
	elif pause_slot_mode == PauseSlotMode.LOAD:
		if bool(SaveManager.get_save_summary(pause_selected_slot)["exists"]):
			load_pause_slot()

func load_pause_slot() -> void:
	if not SaveManager.load_game(pause_selected_slot):
		pause_slot_status_label.text = "No save data"
		refresh_pause_slots()
		return

	var saved_scene = SaveManager.get_saved_scene_path()
	if saved_scene != get_tree().current_scene.scene_file_path:
		get_tree().change_scene_to_file(saved_scene)
		return

	SaveManager.apply_player_position()
	pause_status_label.text = "Loaded Slot %d" % pause_selected_slot
	close_pause_slot_modal()
	close_pause_menu()

func has_any_pause_save() -> bool:
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if bool(SaveManager.get_save_summary(slot)["exists"]):
			return true

	return false

func format_pause_slot_summary(summary: Dictionary) -> String:
	var slot = int(summary["slot"])
	if not bool(summary["exists"]):
		return "Slot %d - Empty" % slot

	var location = str(summary.get("location", ""))
	if location == "":
		location = "Unknown"

	var saved_at = int(summary.get("saved_at_unix", 0))
	var time_text = "No time"
	if saved_at > 0:
		var time_data = Time.get_datetime_dict_from_unix_time(saved_at)
		time_text = "%04d-%02d-%02d %02d:%02d" % [
			int(time_data["year"]),
			int(time_data["month"]),
			int(time_data["day"]),
			int(time_data["hour"]),
			int(time_data["minute"]),
		]

	return "Slot %d - %s  %s" % [slot, location, time_text]

func return_to_title() -> void:
	SaveManager.autosave(true)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_lumi_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		can_talk_to_lumi = true
		print("Press Enter to talk to Lumi")


func _on_lumi_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		can_talk_to_lumi = false


func _on_orion_trigger_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not dialog_active and not SaveManager.has_flag("orion_discovered"):
		MusicManager.play_context("mystery")
		start_dialog("orion_first_seen")


func _on_dungeon_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		SaveManager.set_flag("entered_dungeon_area")
		MusicManager.play_context("dungeon")
		lumi_follow_enabled = true


func _on_dungeon_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		MusicManager.play_context("overworld")
		lumi_follow_enabled = false
