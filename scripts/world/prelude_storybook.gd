extends Node2D

const TARGET_SCENE := "res://scenes/world/sunken_city_lyra_room.tscn"
const PAGE_DATA_PATH := "res://data/dialogues/prelude_storybook.json"
const PAGE_SOUND_PITCH := 1.0
const QUAKE_SOUND_PITCH := 0.55
const PAGE_SOUND_MAX_DURATION := 0.12
const QUAKE_SOUND_MAX_DURATION := 0.7
const PAGE_FADE_DURATION := 0.85
const TEXT_FADE_DURATION := 0.28
const IMAGE_REVEAL_DELAY := 0.35
const TYPEWRITER_SPEED := 0.035
const NEXT_INDICATOR_FLOAT_DISTANCE := 4.0
const NEXT_INDICATOR_BREATH_DURATION := 0.55
const NEXT_INDICATOR_DIM_ALPHA := 0.45
const NEXT_INDICATOR_TEXT_OFFSET := Vector2(16, 18)

@onready var story_image: TextureRect = $UI/StoryImage
@onready var fade_overlay: ColorRect = $UI/FadeOverlay
@onready var text_panel: PanelContainer = $UI/TextPanel
@onready var speaker_label: Label = $UI/TextPanel/Margin/VBox/SpeakerLabel
@onready var page_text: Label = $UI/TextPanel/Margin/VBox/PageText
@onready var next_indicator: Control = $UI/NextIndicator
@onready var next_indicator_arrow: Node2D = $UI/NextIndicator/Arrow
@onready var page_sound: AudioStreamPlayer = $PageSound
@onready var quake_sound: AudioStreamPlayer = $QuakeSound

var pages: Array[Dictionary] = []
var page_index := 0
var can_advance := false
var is_finishing := false
var is_typing := false
var is_transitioning := false
var full_text := ""
var typing_run_id := 0
var page_sound_run_id := 0
var quake_sound_run_id := 0
var root_base_position := Vector2.ZERO
var next_indicator_arrow_base_position := Vector2.ZERO
var next_indicator_tween: Tween

func _ready() -> void:
	MusicManager.play_context("storybook")
	_load_pages()
	root_base_position = position
	next_indicator_arrow_base_position = next_indicator_arrow.position
	fade_overlay.color = Color(0, 0, 0, 1)
	text_panel.modulate.a = 0.0
	hide_next_indicator()

	if pages.is_empty():
		push_warning("Storybook has no pages.")
		await _finish_storybook()
		return

	_show_page(0)
	await _fade_overlay_to(0.0, 0.9)
	await get_tree().create_timer(IMAGE_REVEAL_DELAY).timeout
	await _fade_text_panel_to(1.0, TEXT_FADE_DURATION)
	await _typewrite(full_text)

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
	if is_finishing or is_transitioning:
		return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		_handle_advance()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_advance()

func _handle_advance() -> void:
	if is_typing:
		_complete_typewriter()
		return

	if not can_advance:
		return

	if page_index >= pages.size() - 1:
		_finish_storybook()
	else:
		_advance_to_next_page()

func _advance_to_next_page() -> void:
	is_transitioning = true
	can_advance = false
	hide_next_indicator()
	_play_page_sound()
	await _fade_text_panel_to(0.0, TEXT_FADE_DURATION)
	await _fade_overlay_to(1.0, PAGE_FADE_DURATION)
	page_index += 1
	_show_page(page_index)
	await _fade_overlay_to(0.0, PAGE_FADE_DURATION)
	await get_tree().create_timer(IMAGE_REVEAL_DELAY).timeout
	await _fade_text_panel_to(1.0, TEXT_FADE_DURATION)
	is_transitioning = false
	await _typewrite(full_text)

func _show_page(index: int) -> void:
	var page := pages[index]
	var image_path := str(page.get("image_path", page.get("right_image", "")))
	var speaker := str(page.get("speaker", ""))
	full_text = str(page.get("text", page.get("left_text", "")))

	if image_path != "" and ResourceLoader.exists(image_path):
		story_image.texture = load(image_path)
	else:
		story_image.texture = null
		push_warning("Storybook image missing: %s" % image_path)

	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	page_text.text = ""

func _typewrite(text: String) -> void:
	typing_run_id += 1
	var run_id := typing_run_id
	is_typing = true
	can_advance = false
	hide_next_indicator()
	page_text.text = ""

	for i in range(text.length()):
		if run_id != typing_run_id:
			return
		page_text.text = text.substr(0, i + 1)
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout

	is_typing = false
	page_text.text = text
	can_advance = true
	show_next_indicator()

func _complete_typewriter() -> void:
	typing_run_id += 1
	is_typing = false
	page_text.text = full_text
	can_advance = true
	show_next_indicator()

func _fade_overlay_to(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", target_alpha, duration)
	await tween.finished

func _fade_text_panel_to(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(text_panel, "modulate:a", target_alpha, duration)
	await tween.finished

func _finish_storybook() -> void:
	if is_finishing:
		return
	is_finishing = true
	can_advance = false
	typing_run_id += 1
	is_typing = false
	hide_next_indicator()
	await _fade_text_panel_to(0.0, TEXT_FADE_DURATION)
	await _quake()
	await _fade_overlay_to(1.0, 0.7)
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
		Vector2(5, -3),
		Vector2(-4, 5),
		Vector2.ZERO
	]
	for offset in offsets:
		position = root_base_position + offset
		await get_tree().create_timer(0.055).timeout
	position = root_base_position

func _play_page_sound() -> void:
	page_sound_run_id += 1
	var run_id := page_sound_run_id
	page_sound.pitch_scale = PAGE_SOUND_PITCH
	page_sound.stop()
	page_sound.play()
	_stop_page_sound_after(PAGE_SOUND_MAX_DURATION, run_id)

func _play_quake_sound() -> void:
	quake_sound_run_id += 1
	var run_id := quake_sound_run_id
	quake_sound.pitch_scale = QUAKE_SOUND_PITCH
	quake_sound.stop()
	quake_sound.play()
	_stop_quake_sound_after(QUAKE_SOUND_MAX_DURATION, run_id)

func _stop_page_sound_after(delay: float, run_id: int) -> void:
	await get_tree().create_timer(delay).timeout
	if run_id == page_sound_run_id:
		page_sound.stop()

func _stop_quake_sound_after(delay: float, run_id: int) -> void:
	await get_tree().create_timer(delay).timeout
	if run_id == quake_sound_run_id:
		quake_sound.stop()

func show_next_indicator() -> void:
	if next_indicator_tween:
		next_indicator_tween.kill()
	_place_next_indicator_after_text()
	next_indicator.visible = true
	next_indicator_arrow.position = next_indicator_arrow_base_position
	next_indicator_arrow.modulate.a = NEXT_INDICATOR_DIM_ALPHA
	next_indicator_tween = create_tween()
	next_indicator_tween.set_loops()
	next_indicator_tween.set_trans(Tween.TRANS_SINE)
	next_indicator_tween.set_ease(Tween.EASE_IN_OUT)
	next_indicator_tween.tween_property(next_indicator_arrow, "position", next_indicator_arrow_base_position + Vector2(0, -NEXT_INDICATOR_FLOAT_DISTANCE), NEXT_INDICATOR_BREATH_DURATION)
	next_indicator_tween.parallel().tween_property(next_indicator_arrow, "modulate:a", 1.0, NEXT_INDICATOR_BREATH_DURATION)
	next_indicator_tween.tween_property(next_indicator_arrow, "position", next_indicator_arrow_base_position, NEXT_INDICATOR_BREATH_DURATION)
	next_indicator_tween.parallel().tween_property(next_indicator_arrow, "modulate:a", NEXT_INDICATOR_DIM_ALPHA, NEXT_INDICATOR_BREATH_DURATION)

func hide_next_indicator() -> void:
	if next_indicator_tween:
		next_indicator_tween.kill()
		next_indicator_tween = null
	next_indicator.visible = false
	next_indicator_arrow.position = next_indicator_arrow_base_position
	next_indicator_arrow.modulate.a = 1.0

func _place_next_indicator_after_text() -> void:
	var font := page_text.get_theme_font("font")
	var font_size := page_text.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	var wrapped_lines := _wrap_text_for_label(full_text, font, font_size, page_text.size.x)
	var last_line := ""
	var last_line_index := 0
	for i in range(wrapped_lines.size() - 1, -1, -1):
		if not str(wrapped_lines[i]).strip_edges().is_empty():
			last_line = str(wrapped_lines[i])
			last_line_index = i
			break

	var last_line_width := font.get_string_size(last_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x_offset := 0.0
	if page_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x_offset = maxf((page_text.size.x - last_line_width) * 0.5, 0.0)
	elif page_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x_offset = maxf(page_text.size.x - last_line_width, 0.0)

	var text_origin := page_text.global_position
	var block_height := wrapped_lines.size() * line_height
	var y_offset := 0.0
	if page_text.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y_offset = maxf((page_text.size.y - block_height) * 0.5, 0.0)
	elif page_text.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y_offset = maxf(page_text.size.y - block_height, 0.0)

	var indicator_position := text_origin + Vector2(x_offset + last_line_width, y_offset + line_height * last_line_index) + NEXT_INDICATOR_TEXT_OFFSET
	next_indicator.global_position = indicator_position

func _wrap_text_for_label(text: String, font: Font, font_size: int, max_width: float) -> Array[String]:
	var wrapped_lines: Array[String] = []
	var source_lines := text.split("\n", true)
	for source_line in source_lines:
		if source_line == "":
			wrapped_lines.append("")
			continue

		var current_line := ""
		for i in range(source_line.length()):
			var next_line := current_line + source_line[i]
			var next_width := font.get_string_size(next_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if current_line != "" and next_width > max_width:
				wrapped_lines.append(current_line)
				current_line = source_line[i]
			else:
				current_line = next_line
		wrapped_lines.append(current_line)

	if wrapped_lines.is_empty():
		wrapped_lines.append("")
	return wrapped_lines
