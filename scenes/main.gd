extends Node2D

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
var next_indicator_arrow_base_position = Vector2.ZERO
var next_indicator_tween: Tween
const NEXT_INDICATOR_FLOAT_DISTANCE = 4.0
const NEXT_INDICATOR_BREATH_DURATION = 0.55
const NEXT_INDICATOR_DIM_ALPHA = 0.45
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
var was_player_movable_before_menu = true

func _ready():
	dialog_box.visible = false
	SaveManager.register_player(player)
	load_dialogue_sets()
	setup_pause_menu()
	next_indicator.visible = true
	await get_tree().process_frame
	next_indicator_arrow_base_position = next_indicator_arrow.position
	hide_next_indicator()
	play_lumi_idle()
	MusicManager.play_context("overworld")
	pulse_orion_light()
	if not SaveManager.has_flag("tutorial_complete"):
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

		toggle_pause_menu()
		return

	if pause_menu and pause_menu.visible:
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
	speaker_name.text = CharacterVisualManager.get_display_name(speaker_id)
	full_text = d["text"]
	dialog_text.text = ""
	speaker_avatar.texture = CharacterVisualManager.get_portrait(speaker_id, expression)
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
	if active_dialogue_id == "tutorial":
		SaveManager.set_flag("tutorial_complete")
	elif active_dialogue_id == "lumi_intro":
		SaveManager.set_flag("talked_to_lumi")
	elif active_dialogue_id == "orion_first_seen":
		SaveManager.set_flag("orion_discovered")

	dialog_active = false
	dialog_box.visible = false
	hide_next_indicator()
	active_dialogue_id = ""

	player.can_move = true

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
	pause_menu.visible = false
	player.can_move = was_player_movable_before_menu

func save_from_pause_menu() -> void:
	SaveManager.set_player_position(player.global_position)
	if SaveManager.save_game():
		pause_status_label.text = "Saved"
	else:
		pause_status_label.text = "Save failed"

func load_from_pause_menu() -> void:
	if not SaveManager.load_game():
		pause_status_label.text = "No save data"
		return

	var saved_scene = SaveManager.get_saved_scene_path()
	if saved_scene != get_tree().current_scene.scene_file_path:
		get_tree().change_scene_to_file(saved_scene)
		return

	SaveManager.apply_player_position()
	pause_status_label.text = "Loaded"
	close_pause_menu()

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
