extends Node2D

@onready var dialog_box = $UI/DialogBox
@onready var dialog_text = $UI/DialogBox/DialogText
@onready var speaker_name = $UI/DialogBox/SpeakerName
@onready var speaker_avatar = $UI/DialogBox/SpeakerAvatar
@onready var type_sound = $TypeSound
@onready var background_music = $BackgroundMusic
@onready var next_indicator = $UI/DialogBox/NextIndicator
@onready var next_indicator_arrow = $UI/DialogBox/NextIndicator/Arrow
@onready var player = $Player
@onready var lumi = $Lumi
@onready var orion_glow = $OrionTrigger/GlowSprite
@onready var orion_light = $OrionTrigger/PointLight2D
var avatars = {}
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
var tutorial_dialogs = [
	{"speaker": "System", "text": "Use arrow keys to move."},
	{"speaker": "System", "text": "Press Enter to investigate or talk."},
	{"speaker": "System", "text": "Press Esc to open the menu."},
	{"speaker": "System", "text": "Talk to Lumi first. She may know something."},
]
var dialogs = [
	{"speaker": "Lumi", "text": "Hey! Wake up!"},
	{"speaker": "Lyra", "text": "...Lumi? Why are you shaking?"},
	{"speaker": "Lumi", "text": "I saw something strange."},
	{"speaker": "Lyra", "text": "Strange?"},
	{"speaker": "Lumi", "text": "Near the upper-right ruins... something is glowing."},
]
var orion_dialogs = [
	{"speaker": "Lumi", "text": "Lyra, over here!"},
	{"speaker": "Lyra", "text": "That shape... is that a person?"},
	{"speaker": "Lumi", "text": "He has legs!"},
	{"speaker": "Lyra", "text": "A human...?"},
]
var current_index = 0
var dialog_active = false
var is_typing = false
var full_text = ""

var can_talk_to_lumi = false
func _ready():
	dialog_box.visible = false
	avatars["Lumi"] = preload("res://img/lumi.png")
	avatars["Lyra"] = preload("res://img/lyra.png")
	next_indicator.visible = true
	await get_tree().process_frame
	next_indicator_arrow_base_position = next_indicator_arrow.position
	hide_next_indicator()
	play_lumi_idle()
	setup_background_music()
	pulse_orion_light()
	start_dialog(tutorial_dialogs)
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
func _input(event):
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if not dialog_active:
			if can_talk_to_lumi:
				start_dialog()
		elif is_typing:
			is_typing = false
			dialog_text.text = full_text
			show_next_indicator()
		else:
			next_dialog()

func start_dialog(dialog_lines = dialogs):
	dialog_active = true
	dialog_box.visible = true
	active_dialogs = dialog_lines
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
	speaker_name.text = d["speaker"]
	full_text = d["text"]
	dialog_text.text = ""
	if avatars.has(d["speaker"]):
		speaker_avatar.texture = avatars[d["speaker"]]
	else:
		speaker_avatar.texture = null
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
	dialog_active = false
	dialog_box.visible = false
	hide_next_indicator()

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

func setup_background_music():
	if background_music.stream is AudioStreamMP3:
		background_music.stream.loop = true

	if not background_music.playing:
		background_music.play()


func _on_lumi_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		can_talk_to_lumi = true
		print("Press Enter to talk to Lumi")


func _on_lumi_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		can_talk_to_lumi = false


func _on_orion_trigger_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not dialog_active:
		start_dialog(orion_dialogs)
