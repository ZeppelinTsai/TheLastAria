extends Node2D

@onready var dialog_box = $UI/DialogBox
@onready var dialog_text = $UI/DialogBox/DialogText
@onready var speaker_name = $UI/DialogBox/SpeakerName
@onready var speaker_avatar = $UI/DialogBox/SpeakerAvatar
@onready var type_sound = $TypeSound
@onready var next_indicator = $UI/DialogBox/NextIndicator
@onready var player = $Player
var avatars = {}

var dialogs = [
	{"speaker": "Lumi", "text": "Hey! Wake up!"},
	{"speaker": "Lyra", "text": "..."},
	{"speaker": "Lumi", "text": "There's someone in the water!"},
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
	next_indicator.visible = false

func _input(event):
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if not dialog_active:
			if can_talk_to_lumi:
				start_dialog()
		elif is_typing:
			is_typing = false
			dialog_text.text = full_text
			next_indicator.visible = true
		else:
			next_dialog()

func start_dialog():
	dialog_active = true
	dialog_box.visible = true
	current_index = 0

	player.can_move = false

	show_dialog(current_index)

func next_dialog():
	current_index += 1
	if current_index >= dialogs.size():
		end_dialog()
	else:
		show_dialog(current_index)

func show_dialog(index):
	var d = dialogs[index]
	speaker_name.text = d["speaker"]
	full_text = d["text"]
	dialog_text.text = ""
	if avatars.has(d["speaker"]):
		speaker_avatar.texture = avatars[d["speaker"]]
	is_typing = true
	type_text()
	next_indicator.visible = false

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
	next_indicator.visible = true

func end_dialog():
	dialog_active = false
	dialog_box.visible = false
	next_indicator.visible = false

	player.can_move = true


func _on_lumi_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		can_talk_to_lumi = true
		print("Press Enter to talk to Lumi")


func _on_lumi_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		can_talk_to_lumi = false
