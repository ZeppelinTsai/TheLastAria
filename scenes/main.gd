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
const POINTER_ADVANCE_DEBOUNCE_MS = 180
const DIALOG_STANDEE_DEFAULT_ASPECT = 2.0 / 3.0
const DIALOG_TEXT_MIN_FONT_SIZE = 28
const DIALOG_TEXT_MAX_FONT_SIZE = 38
const DIALOG_NAME_MIN_FONT_SIZE = 22
const DIALOG_NAME_MAX_FONT_SIZE = 30
const DIALOG_DEBUG_SMALL_WINDOW_SIZE = Vector2i(640, 360)
var dialogue_sets = {}
var active_dialogue_id = ""
var current_index = 0
var dialog_active = false
var is_typing = false
var full_text = ""
var typing_run_id = 0

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
var last_pointer_advance_msec := 0
var dialog_debug_visible := false
var dialog_debug_layer: CanvasLayer
var dialog_debug_label: Label
var dialog_debug_frame: ColorRect
var dialog_debug_speaker_id := ""
var dialog_debug_expression := ""
var dialog_debug_small_preview := false
var dialog_standee_nodes := {}

func _ready():
	pass

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
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
			toggle_dialog_debug_overlay()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB and dialog_debug_visible:
			toggle_dialog_debug_window_size()
			get_viewport().set_input_as_handled()
			return

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

	if _is_dialog_advance_event(event):
		if not dialog_active:
			if event.is_action_pressed("ui_accept") and not event.is_echo() and can_talk_to_lumi:
				start_dialog("lumi_intro")
			return

		get_viewport().set_input_as_handled()
		_advance_active_dialog()

func _unhandled_input(event: InputEvent) -> void:
	if not dialog_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_advance_active_dialog()

func _is_dialog_advance_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		return true

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return false

		var now := Time.get_ticks_msec()
		if now - last_pointer_advance_msec < POINTER_ADVANCE_DEBOUNCE_MS:
			return false

		last_pointer_advance_msec = now
		return true

	return false

func _advance_active_dialog() -> void:
	if is_typing:
		typing_run_id += 1
		is_typing = false
		dialog_text.text = full_text
		if type_sound:
			type_sound.stop()
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
	var expression = get_dialog_expression(d, "default")
	dialog_debug_speaker_id = speaker_id
	dialog_debug_expression = expression
	update_prelude_scene(str(d.get("scene", "")))
	if str(d.get("effect", "")) == "shake":
		shake_scene()
	configure_dialog_text_style()
	speaker_name.text = CharacterVisualManager.get_display_name(speaker_id)
	full_text = LocalizationManager.get_entry_text(d)
	dialog_text.text = ""
	show_dialog_standees(d, speaker_id, expression)
	is_typing = true
	typing_run_id += 1
	var run_id = typing_run_id
	type_text(full_text, run_id)
	hide_next_indicator()

func type_text(text: String, run_id: int):
	for i in range(text.length()):
		if not is_typing or run_id != typing_run_id:
			break

		dialog_text.text = text.substr(0, i + 1)

		if text[i] != " ":
			if type_sound:
				type_sound.stop()
				type_sound.play()

		await get_tree().create_timer(0.05).timeout

	if run_id != typing_run_id:
		return
	is_typing = false
	dialog_text.text = text
	if type_sound:
		type_sound.stop()
	show_next_indicator()

func end_dialog():
	typing_run_id += 1
	is_typing = false
	if type_sound:
		type_sound.stop()
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
		hide_dialog_standees()
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
	hide_dialog_standees()
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

func show_dialog_standees(entry: Dictionary, speaker_id: String, expression: String) -> void:
	hide_dialog_standees()

	var standee_entries: Array = []
	if entry.has("standees") and typeof(entry["standees"]) == TYPE_ARRAY:
		standee_entries = entry["standees"]

	var speaker_in_stage := false
	for item in standee_entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_character := str(item.get("character", item.get("speaker", "")))
		if item_character == speaker_id:
			speaker_in_stage = true
			break

	if standee_entries.is_empty() and speaker_id != "":
		standee_entries.append({
			"character": speaker_id,
			"expression": expression,
			"layout": entry.get("standee", {})
		})
	elif not speaker_in_stage and speaker_id != "":
		standee_entries.append({
			"character": speaker_id,
			"expression": expression,
			"layout": entry.get("standee", {})
		})

	for item in standee_entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_character := str(item.get("character", item.get("speaker", "")))
		if item_character == "":
			continue
		var item_expression := get_dialog_expression(item, expression)
		var overrides := {}
		if item.has("layout") and typeof(item["layout"]) == TYPE_DICTIONARY:
			overrides = item["layout"]
		else:
			overrides = item.duplicate(true)
		var node := get_dialog_standee_node(item_character)
		var texture := CharacterVisualManager.get_dialog_standee(item_character, item_expression)
		node.texture = texture
		node.visible = texture != null
		var layout := CharacterVisualManager.get_dialog_standee_layout(item_character, overrides)
		configure_dialog_standee_node(node, layout, item_character == speaker_id)
		if item_character == speaker_id:
			speaker_avatar = node
			update_dialog_debug_overlay(item_character, layout)

func get_dialog_standee_node(character_id: String) -> TextureRect:
	if dialog_standee_nodes.has(character_id):
		return dialog_standee_nodes[character_id]

	var node: TextureRect
	if dialog_standee_nodes.is_empty() and speaker_avatar:
		node = speaker_avatar
	else:
		node = TextureRect.new()
		node.name = "Standee_%s" % character_id
		dialog_box.add_child(node)

	dialog_standee_nodes[character_id] = node
	return node

func hide_dialog_standees() -> void:
	for node in dialog_standee_nodes.values():
		if node:
			node.visible = false

func get_dialog_expression(source: Dictionary, fallback := "default") -> String:
	var expression := str(source.get("expression", "")).strip_edges()
	if expression != "":
		return expression
	var tachie := str(source.get("tachie", "")).strip_edges()
	if tachie != "":
		return tachie
	return fallback

func configure_dialog_standee_node(standee_node: TextureRect, layout: Dictionary, is_speaking: bool) -> void:
	if not standee_node or not dialog_box:
		return

	var viewport_size := get_dialog_debug_layout_size()
	var dialog_height: float = dialog_box.size.y
	if dialog_height <= 0.0:
		dialog_height = 262.0
	var texture: Texture2D = standee_node.texture
	var aspect: float = DIALOG_STANDEE_DEFAULT_ASPECT
	if texture and texture.get_height() > 0:
		aspect = float(texture.get_width()) / float(texture.get_height())

	var target_height: float = viewport_size.y * float(layout["height_ratio"]) * float(layout["scale"])
	var target_width: float = target_height * aspect
	var layout_position := str(layout["position"])
	var x_ratio: float = float(layout["x_ratio"])
	var x_anchor: float = float(layout["x_anchor"])
	var bottom_ratio: float = float(layout["bottom_ratio"])
	var left: float = float(layout["x"])
	var bottom_offset: float = float(layout["bottom"])
	if layout_position != "":
		match layout_position:
			"left":
				x_ratio = 0.0
				x_anchor = 0.0
			"center":
				x_ratio = 0.5
				x_anchor = 0.5
			"right":
				x_ratio = 1.0
				x_anchor = 1.0
			_:
				push_warning("Unknown dialog standee position: %s" % layout_position)
	if x_ratio >= 0.0:
		if x_anchor < 0.0:
			x_anchor = 0.0
		left = (viewport_size.x * x_ratio) - (target_width * x_anchor)
	left += float(layout["x_offset"]) + viewport_size.x * float(layout["x_offset_ratio"])
	if bottom_ratio != 999.0:
		bottom_offset = viewport_size.y * bottom_ratio
	var bottom: float = dialog_height - bottom_offset

	standee_node.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	standee_node.offset_left = left
	standee_node.offset_top = bottom - target_height
	standee_node.offset_right = left + target_width
	standee_node.offset_bottom = bottom
	standee_node.grow_horizontal = Control.GROW_DIRECTION_END
	standee_node.grow_vertical = Control.GROW_DIRECTION_END
	standee_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	standee_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	standee_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standee_node.focus_mode = Control.FOCUS_NONE
	standee_node.z_index = (-1 if is_speaking else -3) + int(layout.get("z_offset", 0))
	dialog_box.move_child(standee_node, 0)

func configure_dialog_text_style() -> void:
	if not dialog_box:
		return

	var viewport_size := get_dialog_debug_layout_size()
	var dialog_height: float = dialog_box.size.y
	if dialog_height <= 0.0:
		dialog_height = 262.0

	var text_font_size := int(round(clampf(viewport_size.y * 0.048, DIALOG_TEXT_MIN_FONT_SIZE, DIALOG_TEXT_MAX_FONT_SIZE)))
	var name_font_size := int(round(clampf(viewport_size.y * 0.037, DIALOG_NAME_MIN_FONT_SIZE, DIALOG_NAME_MAX_FONT_SIZE)))
	var content_left: float = clampf(viewport_size.x * 0.055, 28.0, 72.0)
	var content_right: float = 46.0
	var name_top: float = maxf(16.0, dialog_height * 0.08)
	var text_top: float = maxf(62.0, dialog_height * 0.25)
	var text_bottom: float = 34.0

	if speaker_name:
		speaker_name.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		speaker_name.offset_left = content_left
		speaker_name.offset_top = name_top
		speaker_name.offset_right = viewport_size.x - content_right
		speaker_name.offset_bottom = name_top + float(name_font_size + 12)
		speaker_name.add_theme_font_size_override("font_size", name_font_size)
		speaker_name.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
		speaker_name.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		speaker_name.add_theme_constant_override("shadow_offset_x", 2)
		speaker_name.add_theme_constant_override("shadow_offset_y", 2)
		speaker_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if dialog_text:
		dialog_text.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		dialog_text.offset_left = content_left
		dialog_text.offset_top = text_top
		dialog_text.offset_right = viewport_size.x - content_right
		dialog_text.offset_bottom = dialog_height - text_bottom
		dialog_text.add_theme_font_size_override("font_size", text_font_size)
		dialog_text.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
		dialog_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		dialog_text.add_theme_constant_override("shadow_offset_x", 2)
		dialog_text.add_theme_constant_override("shadow_offset_y", 2)
		dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func toggle_dialog_debug_overlay() -> void:
	dialog_debug_visible = not dialog_debug_visible
	ensure_dialog_debug_overlay()
	if dialog_debug_layer:
		dialog_debug_layer.visible = dialog_debug_visible
	update_dialog_debug_overlay(dialog_debug_speaker_id, CharacterVisualManager.get_dialog_standee_layout(dialog_debug_speaker_id))

func toggle_dialog_debug_window_size() -> void:
	dialog_debug_small_preview = not dialog_debug_small_preview
	update_dialog_debug_preview_frame()
	configure_dialog_text_style()
	if dialog_debug_speaker_id != "":
		var layout := CharacterVisualManager.get_dialog_standee_layout(dialog_debug_speaker_id)
		configure_dialog_standee_node(speaker_avatar, layout, true)
		update_dialog_debug_overlay(dialog_debug_speaker_id, layout)

func get_dialog_debug_layout_size() -> Vector2:
	if dialog_debug_visible and dialog_debug_small_preview:
		return Vector2(DIALOG_DEBUG_SMALL_WINDOW_SIZE)
	return get_viewport_rect().size

func ensure_dialog_debug_overlay() -> void:
	if dialog_debug_layer:
		return

	dialog_debug_layer = CanvasLayer.new()
	dialog_debug_layer.name = "DialogDebugLayer"
	dialog_debug_layer.layer = 100
	add_child(dialog_debug_layer)

	dialog_debug_frame = ColorRect.new()
	dialog_debug_frame.name = "SmallPreviewFrame"
	dialog_debug_frame.color = Color(0.2, 0.75, 1.0, 0.16)
	dialog_debug_frame.visible = false
	dialog_debug_layer.add_child(dialog_debug_frame)

	var panel := PanelContainer.new()
	panel.name = "DialogDebugPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = 430.0
	panel.offset_bottom = 210.0
	dialog_debug_layer.add_child(panel)

	dialog_debug_label = Label.new()
	dialog_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_debug_label.add_theme_font_size_override("font_size", 13)
	dialog_debug_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	panel.add_child(dialog_debug_label)
	dialog_debug_layer.visible = dialog_debug_visible
	update_dialog_debug_preview_frame()

func update_dialog_debug_preview_frame() -> void:
	if not dialog_debug_frame:
		return
	dialog_debug_frame.visible = dialog_debug_visible and dialog_debug_small_preview
	if not dialog_debug_frame.visible:
		return
	var preview_size := Vector2(DIALOG_DEBUG_SMALL_WINDOW_SIZE)
	dialog_debug_frame.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	dialog_debug_frame.offset_left = 0.0
	dialog_debug_frame.offset_top = 0.0
	dialog_debug_frame.offset_right = preview_size.x
	dialog_debug_frame.offset_bottom = preview_size.y

func update_dialog_debug_overlay(speaker_id: String, layout: Dictionary) -> void:
	if not dialog_debug_visible:
		return
	ensure_dialog_debug_overlay()
	if not dialog_debug_label:
		return

	var texture: Texture2D = null
	var texture_path := ""
	var texture_size := Vector2i.ZERO
	var avatar_rect := Rect2()
	var avatar_parent := ""
	var avatar_z := 0
	var avatar_child_index := -1
	var avatar_visible := false
	if speaker_avatar:
		texture = speaker_avatar.texture
		avatar_rect = speaker_avatar.get_global_rect()
		avatar_z = speaker_avatar.z_index
		avatar_child_index = speaker_avatar.get_index()
		avatar_visible = speaker_avatar.visible
		if speaker_avatar.get_parent():
			avatar_parent = speaker_avatar.get_parent().name
	if texture:
		texture_path = texture.resource_path
		texture_size = Vector2i(texture.get_width(), texture.get_height())

	var preview_label := "window"
	if dialog_debug_small_preview:
		preview_label = "640x360"
	var debug_lines := PackedStringArray([
		"Dialog Standee Debug (F3)  Tab=%s" % preview_label,
		"speaker=%s expression=%s active=%s" % [speaker_id, dialog_debug_expression, str(dialog_active)],
		"texture=%s" % texture_path,
		"texture_size=%s visible=%s" % [str(texture_size), str(avatar_visible)],
		"rect pos=%s size=%s" % [str(avatar_rect.position), str(avatar_rect.size)],
		"parent=%s z_index=%d child_index=%d" % [avatar_parent, avatar_z, avatar_child_index],
		"layout position=%s x=%.1f x_ratio=%.3f x_anchor=%.2f" % [
			str(layout.get("position", "")),
			float(layout.get("x", 0.0)),
			float(layout.get("x_ratio", -1.0)),
			float(layout.get("x_anchor", -1.0)),
		],
		"layout x_offset=%.1f x_offset_ratio=%.3f bottom=%.1f bottom_ratio=%.3f" % [
			float(layout.get("x_offset", 0.0)),
			float(layout.get("x_offset_ratio", 0.0)),
			float(layout.get("bottom", 0.0)),
			float(layout.get("bottom_ratio", 999.0)),
		],
		"layout height_ratio=%.2f scale=%.2f" % [
			float(layout.get("height_ratio", 0.0)),
			float(layout.get("scale", 0.0)),
		],
	])
	dialog_debug_label.text = "\n".join(debug_lines)

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
