extends Node2D

enum PauseSlotMode { NONE, SAVE, LOAD }

const NEXT_INDICATOR_FLOAT_DISTANCE = 4.0
const NEXT_INDICATOR_BREATH_DURATION = 0.55
const NEXT_INDICATOR_DIM_ALPHA = 0.45
const SLOT_DOUBLE_PRESS_MS = 450
const TYPE_DELAY = 0.05
const POINTER_ADVANCE_DEBOUNCE_MS = 180
const DIALOG_STANDEE_DEFAULT_ASPECT = 2.0 / 3.0
const DIALOG_TEXT_MIN_FONT_SIZE = 28
const DIALOG_TEXT_MAX_FONT_SIZE = 38
const DIALOG_NAME_MIN_FONT_SIZE = 22
const DIALOG_NAME_MAX_FONT_SIZE = 30
const DIALOG_DEBUG_SMALL_WINDOW_SIZE = Vector2i(640, 360)

@export var dialogue_path: String = ""

@onready var dialog_box: Control = get_node_or_null("UI/DialogBox")
@onready var dialog_text: Label = get_node_or_null("UI/DialogBox/DialogText")
@onready var speaker_name: Label = get_node_or_null("UI/DialogBox/SpeakerName")
@onready var speaker_avatar: TextureRect = get_node_or_null("UI/DialogBox/SpeakerAvatar")
@onready var type_sound: AudioStreamPlayer = get_node_or_null("TypeSound")
@onready var next_indicator: Control = get_node_or_null("UI/DialogBox/NextIndicator")
@onready var next_indicator_arrow: Node2D = get_node_or_null("UI/DialogBox/NextIndicator/Arrow")
@onready var player: Node2D = get_node_or_null("Player")

var dialogue_sets := {}
var active_dialogs: Array = []
var active_dialogue_id := ""
var current_index := 0
var dialog_active := false
var is_typing := false
var full_text := ""
var typing_run_id := 0

var next_indicator_arrow_base_position := Vector2.ZERO
var next_indicator_tween: Tween
var scene_shake_tween: Tween

var pause_menu: Control
var pause_status_label: Label
var pause_slot_modal: Control
var pause_slot_title_label: Label
var pause_slot_status_label: Label
var pause_slot_action_button: Button
var pause_slot_buttons: Array[Button] = []
var pause_selected_slot := 1
var pause_slot_mode: int = PauseSlotMode.NONE
var pause_overwrite_confirm_slot := -1
var pause_last_slot_press_slot := -1
var pause_last_slot_press_msec := 0
var was_player_movable_before_menu := true
var last_pointer_advance_msec := 0
var dialog_debug_visible := false
var dialog_debug_layer: CanvasLayer
var dialog_debug_label: Label
var dialog_debug_frame: ColorRect
var dialog_debug_speaker_id := ""
var dialog_debug_expression := ""
var dialog_debug_small_preview := false

func _ready() -> void:
	_validate_world_nodes()
	if dialog_box:
		dialog_box.visible = false
	configure_dialog_text_style()
	if next_indicator_arrow:
		next_indicator_arrow_base_position = next_indicator_arrow.position
	hide_next_indicator()
	load_dialogue_sets()
	setup_pause_menu()
	if player:
		SaveManager.register_player(player)
	on_world_ready()

func _physics_process(delta: float) -> void:
	if player:
		SaveManager.track_player_position(player.global_position)
	on_world_physics_process(delta)

func _exit_tree() -> void:
	if player:
		SaveManager.unregister_player(player)

func _input(event: InputEvent) -> void:
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

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if not dialog_active:
			return
		_advance_active_dialog()

func _unhandled_input(event: InputEvent) -> void:
	if not dialog_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_advance_active_dialog()

func _advance_active_dialog() -> void:
	if is_typing:
		typing_run_id += 1
		is_typing = false
		if dialog_text:
			dialog_text.text = full_text
		if type_sound:
			type_sound.stop()
		show_next_indicator()
	else:
		next_dialog()

func _validate_world_nodes() -> void:
	if not player:
		push_warning("WorldBase expected a Player node.")
	if not dialog_box:
		push_warning("WorldBase expected UI/DialogBox.")
	if not dialog_text:
		push_warning("WorldBase expected UI/DialogBox/DialogText.")
	if not speaker_name:
		push_warning("WorldBase expected UI/DialogBox/SpeakerName.")
	if not speaker_avatar:
		push_warning("WorldBase expected UI/DialogBox/SpeakerAvatar.")
	if not next_indicator:
		push_warning("WorldBase expected UI/DialogBox/NextIndicator.")
	if not next_indicator_arrow:
		push_warning("WorldBase expected UI/DialogBox/NextIndicator/Arrow.")

func load_dialogue_sets() -> void:
	dialogue_sets = {}
	if dialogue_path.strip_edges() == "":
		push_warning("dialogue_path is empty for this world.")
		return

	var file = FileAccess.open(dialogue_path, FileAccess.READ)
	if not file:
		push_warning("Could not load dialogue file: %s" % dialogue_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Dialogue file data is invalid: %s" % dialogue_path)
		return

	dialogue_sets = parsed

func apply_background_from_map_data(data: Dictionary) -> void:
	var background_path: String = str(data.get("background", "")).strip_edges()
	if background_path == "":
		push_warning("Map data missing background.")
		return

	var background_node: Node = get_node_or_null("Background")
	if not background_node:
		push_warning("World has no Background node for map background: %s" % background_path)
		return
	if not (background_node is Sprite2D) and not (background_node is TextureRect):
		push_warning("Background node must be Sprite2D or TextureRect: %s" % background_path)
		return

	var texture_resource: Resource = load(background_path)
	if texture_resource == null or not (texture_resource is Texture2D):
		push_warning("Could not load map background texture: %s" % background_path)
		return

	var texture: Texture2D = texture_resource as Texture2D
	if background_node is Sprite2D:
		var sprite_background: Sprite2D = background_node as Sprite2D
		sprite_background.texture = texture
	elif background_node is TextureRect:
		var texture_background: TextureRect = background_node as TextureRect
		texture_background.texture = texture

func start_dialog(dialogue_id: String) -> void:
	if not dialogue_sets.has(dialogue_id):
		push_warning("Dialogue id not found: %s" % dialogue_id)
		return
	if not dialog_box or not dialog_text:
		push_warning("Cannot start dialog without DialogBox and DialogText nodes.")
		return

	dialog_active = true
	dialog_box.visible = true
	active_dialogue_id = dialogue_id
	active_dialogs = dialogue_sets[dialogue_id]
	current_index = 0
	set_player_can_move(false)
	show_dialog(current_index)

func show_dialog(index: int) -> void:
	if index < 0 or index >= active_dialogs.size():
		end_dialog()
		return

	var entry = active_dialogs[index]
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("Dialogue entry is not a Dictionary in %s." % active_dialogue_id)
		next_dialog()
		return

	var speaker_id = str(entry.get("speaker", ""))
	var expression = str(entry.get("expression", "default"))
	dialog_debug_speaker_id = speaker_id
	dialog_debug_expression = expression
	if str(entry.get("effect", "")) == "shake":
		shake_scene()
	configure_dialog_text_style()
	if speaker_name:
		speaker_name.text = CharacterVisualManager.get_display_name(speaker_id)

	full_text = str(entry.get("text", ""))
	if dialog_text:
		dialog_text.text = ""
	if speaker_avatar:
		var standee = CharacterVisualManager.get_dialog_standee(speaker_id, expression)
		speaker_avatar.texture = standee
		speaker_avatar.visible = standee != null
		configure_dialog_standee(speaker_id)

	is_typing = true
	typing_run_id += 1
	var run_id := typing_run_id
	hide_next_indicator()
	type_text(full_text, run_id)

func configure_dialog_standee(speaker_id: String) -> void:
	if not speaker_avatar or not dialog_box:
		return

	var layout := CharacterVisualManager.get_dialog_standee_layout(speaker_id)
	var viewport_size := get_dialog_debug_layout_size()
	var dialog_height: float = dialog_box.size.y
	if dialog_height <= 0.0:
		dialog_height = 262.0
	var texture: Texture2D = speaker_avatar.texture
	var aspect: float = DIALOG_STANDEE_DEFAULT_ASPECT
	if texture and texture.get_height() > 0:
		aspect = float(texture.get_width()) / float(texture.get_height())

	var target_height: float = viewport_size.y * float(layout["height_ratio"]) * float(layout["scale"])
	var target_width: float = target_height * aspect
	var position := str(layout["position"])
	var x_ratio: float = float(layout["x_ratio"])
	var x_anchor: float = float(layout["x_anchor"])
	var bottom_ratio: float = float(layout["bottom_ratio"])
	var left: float = float(layout["x"])
	var bottom_offset: float = float(layout["bottom"])
	if position != "":
		match position:
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
				push_warning("Unknown dialog standee position: %s" % position)
	if x_ratio >= 0.0:
		if x_anchor < 0.0:
			x_anchor = 0.0
		left = (viewport_size.x * x_ratio) - (target_width * x_anchor)
	left += float(layout["x_offset"]) + viewport_size.x * float(layout["x_offset_ratio"])
	if bottom_ratio != 999.0:
		bottom_offset = viewport_size.y * bottom_ratio
	var bottom: float = dialog_height - bottom_offset

	speaker_avatar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, false)
	speaker_avatar.offset_left = left
	speaker_avatar.offset_top = bottom - target_height
	speaker_avatar.offset_right = left + target_width
	speaker_avatar.offset_bottom = bottom
	speaker_avatar.grow_horizontal = Control.GROW_DIRECTION_END
	speaker_avatar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speaker_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	speaker_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	speaker_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_avatar.focus_mode = Control.FOCUS_NONE
	speaker_avatar.z_index = -1
	dialog_box.move_child(speaker_avatar, 0)
	update_dialog_debug_overlay(speaker_id, layout)

func configure_dialog_text_style() -> void:
	if not dialog_box:
		return

	var viewport_size := get_dialog_debug_layout_size()
	var dialog_height: float = dialog_box.size.y
	if dialog_height <= 0.0:
		dialog_height = 262.0

	var text_font_size := int(round(clampf(viewport_size.y * 0.048, DIALOG_TEXT_MIN_FONT_SIZE, DIALOG_TEXT_MAX_FONT_SIZE)))
	var name_font_size := int(round(clampf(viewport_size.y * 0.037, DIALOG_NAME_MIN_FONT_SIZE, DIALOG_NAME_MAX_FONT_SIZE)))
	var content_left: float = maxf(300.0, viewport_size.x * 0.30)
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
		configure_dialog_standee(dialog_debug_speaker_id)

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

func type_text(text: String, run_id: int) -> void:
	for i in range(text.length()):
		if not is_typing or run_id != typing_run_id:
			break
		if dialog_text:
			dialog_text.text = text.substr(0, i + 1)
		if text[i] != " " and type_sound:
			type_sound.stop()
			type_sound.play()
		await get_tree().create_timer(TYPE_DELAY).timeout

	if run_id != typing_run_id:
		return
	is_typing = false
	if dialog_text:
		dialog_text.text = text
	if type_sound:
		type_sound.stop()
	show_next_indicator()

func next_dialog() -> void:
	current_index += 1
	if current_index >= active_dialogs.size():
		end_dialog()
	else:
		show_dialog(current_index)

func end_dialog() -> void:
	var finished_dialogue_id = active_dialogue_id
	typing_run_id += 1
	is_typing = false
	if type_sound:
		type_sound.stop()
	on_dialog_finished(finished_dialogue_id)
	dialog_active = false
	if dialog_box:
		dialog_box.visible = false
	if speaker_avatar:
		speaker_avatar.visible = false
	hide_next_indicator()
	active_dialogue_id = ""
	active_dialogs = []
	current_index = 0
	set_player_can_move(true)
	SaveManager.autosave(true)

func show_next_indicator() -> void:
	if not next_indicator or not next_indicator_arrow:
		return
	if next_indicator_tween:
		next_indicator_tween.kill()
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
	if next_indicator:
		next_indicator.visible = false
	if next_indicator_arrow:
		next_indicator_arrow.position = next_indicator_arrow_base_position
		next_indicator_arrow.modulate.a = 1.0

func shake_scene() -> void:
	if scene_shake_tween:
		scene_shake_tween.kill()
	position = Vector2.ZERO
	scene_shake_tween = create_tween()
	scene_shake_tween.tween_property(self, "position", Vector2(9, -5), 0.04)
	scene_shake_tween.tween_property(self, "position", Vector2(-8, 6), 0.04)
	scene_shake_tween.tween_property(self, "position", Vector2(6, 4), 0.04)
	scene_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.06)

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
	if pause_menu and pause_menu.visible:
		close_pause_menu()
	else:
		open_pause_menu()

func open_pause_menu() -> void:
	was_player_movable_before_menu = get_player_can_move()
	set_player_can_move(false)
	if pause_status_label:
		pause_status_label.text = ""
	if pause_menu:
		pause_menu.visible = true

func close_pause_menu() -> void:
	close_pause_slot_modal()
	if pause_menu:
		pause_menu.visible = false
	set_player_can_move(was_player_movable_before_menu)

func save_from_pause_menu() -> void:
	open_pause_slot_modal(PauseSlotMode.SAVE)

func load_from_pause_menu() -> void:
	if not has_any_pause_save():
		if pause_status_label:
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
		_save_pause_slot()
	elif pause_slot_mode == PauseSlotMode.LOAD:
		load_pause_slot()

func quick_confirm_pause_slot_action() -> void:
	if pause_slot_mode == PauseSlotMode.SAVE:
		_save_pause_slot()
	elif pause_slot_mode == PauseSlotMode.LOAD and bool(SaveManager.get_save_summary(pause_selected_slot)["exists"]):
		load_pause_slot()

func _save_pause_slot() -> void:
	if player:
		SaveManager.set_player_position(player.global_position)
	if SaveManager.save_game(pause_selected_slot):
		if pause_status_label:
			pause_status_label.text = "Saved Slot %d" % pause_selected_slot
		close_pause_slot_modal()
	elif pause_slot_status_label:
		pause_slot_status_label.text = "Save failed"

func load_pause_slot() -> void:
	if not SaveManager.load_game(pause_selected_slot):
		if pause_slot_status_label:
			pause_slot_status_label.text = "No save data"
		refresh_pause_slots()
		return
	var current_scene = get_tree().current_scene
	var current_scene_path = ""
	if current_scene:
		current_scene_path = current_scene.scene_file_path
	var saved_scene = SaveManager.get_saved_scene_path()
	if saved_scene != current_scene_path:
		get_tree().change_scene_to_file(saved_scene)
		return
	SaveManager.apply_player_position()
	if pause_status_label:
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

func set_player_can_move(value: bool) -> void:
	if player:
		player.set("can_move", value)

func get_player_can_move() -> bool:
	if not player:
		return true
	return bool(player.get("can_move"))

func on_world_ready() -> void:
	pass

func on_dialog_finished(_dialogue_id: String) -> void:
	pass

func on_world_physics_process(_delta: float) -> void:
	pass
