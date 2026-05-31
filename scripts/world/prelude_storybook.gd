extends Node2D

const TARGET_SCENE := "res://scenes/world/sunken_city.tscn"
const PAGE_DATA_PATH := "res://data/dialogues/prelude_storybook.json"
const PAGE_SOUND_PITCH := 1.0
const QUAKE_SOUND_PITCH := 0.55

@onready var overlay: ColorRect = $UI/Overlay
@onready var book_container: Control = $UI/BookContainer
@onready var left_page_text: Label = $UI/BookContainer/Book/Pages/LeftPage/PageText
@onready var right_page_text: Label = $UI/BookContainer/Book/Pages/RightPage/PageText
@onready var speaker_label: Label = $UI/BookContainer/Book/SpeakerLabel
@onready var page_sound: AudioStreamPlayer = $PageSound
@onready var quake_sound: AudioStreamPlayer = $QuakeSound

var pages: Array[Dictionary] = []

var page_index := -1
var can_advance := false
var is_finishing := false
var book_base_position := Vector2.ZERO
var root_base_position := Vector2.ZERO

func _ready() -> void:
	MusicManager.play_context("overworld")
	_load_pages()
	book_base_position = book_container.position
	root_base_position = position
	overlay.color = Color(0, 0, 0, 1)
	book_container.modulate.a = 0.0
	_set_page_text("", "")
	await _fade_in_opening()
	_show_next_page()

func _load_pages() -> void:
	pages = []
	var file := FileAccess.open(PAGE_DATA_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not load storybook pages: %s" % PAGE_DATA_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Storybook page data is invalid: %s" % PAGE_DATA_PATH)
		return

	var page_data = parsed.get("storybook_intro", [])
	if typeof(page_data) != TYPE_ARRAY:
		push_warning("Storybook intro must be an Array: %s" % PAGE_DATA_PATH)
		return

	for entry in page_data:
		if typeof(entry) == TYPE_DICTIONARY:
			pages.append(entry)

func _input(event: InputEvent) -> void:
	if not can_advance or is_finishing:
		return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		_show_next_page()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_show_next_page()

func _fade_in_opening() -> void:
	_play_page_sound()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.0, 0.9)
	tween.tween_property(book_container, "modulate:a", 1.0, 0.9)
	await tween.finished

func _show_next_page() -> void:
	can_advance = false
	page_index += 1
	if page_index >= pages.size():
		_finish_storybook()
		return

	_play_page_sound()
	var page: Dictionary = pages[page_index]
	_set_page_text(str(page.get("speaker", "")), str(page.get("text", "")))

	if page_index == pages.size() - 1:
		_finish_storybook_after_pause()
	else:
		can_advance = true

func _set_page_text(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	left_page_text.text = text
	right_page_text.text = ""

func _finish_storybook_after_pause() -> void:
	is_finishing = true
	await get_tree().create_timer(2.0).timeout
	await _quake()
	await SceneTransition.go(TARGET_SCENE)

func _finish_storybook() -> void:
	if is_finishing:
		return
	is_finishing = true
	await _quake()
	await SceneTransition.go(TARGET_SCENE)

func _quake() -> void:
	_play_quake_sound()
	var offsets: Array[Vector2] = [
		Vector2(10, -7),
		Vector2(-12, 6),
		Vector2(8, 9),
		Vector2(-7, -10),
		Vector2(11, 5),
		Vector2(-8, 4),
		Vector2.ZERO
	]
	for offset: Vector2 in offsets:
		position = root_base_position + offset
		book_container.position = book_base_position - offset * 0.7
		await get_tree().create_timer(0.055).timeout
	position = root_base_position
	book_container.position = book_base_position

func _play_page_sound() -> void:
	page_sound.pitch_scale = PAGE_SOUND_PITCH
	page_sound.stop()
	page_sound.play()

func _play_quake_sound() -> void:
	quake_sound.pitch_scale = QUAKE_SOUND_PITCH
	quake_sound.stop()
	quake_sound.play()
