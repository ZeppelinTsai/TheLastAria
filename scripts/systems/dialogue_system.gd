extends Node
class_name DialogueSystem

var host: Node

func init(owner_node: Node) -> void:
    host = owner_node
var active_dialogs: Array = []
var active_dialogue_id: String = ""
var current_index: int = 0
var dialog_active: bool = false
var is_typing: bool = false
var full_text: String = ""
var typing_run_id: int = 0

func load_dialogue_sets(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        push_warning("Could not load dialogue file: %s" % path)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Dialogue file data is invalid: %s" % path)
        return
    host.dialogue_sets = parsed

func start_dialog(dialogue_id: String) -> void:
    if not host.dialogue_sets.has(dialogue_id):
        push_warning("Dialogue id not found: %s" % dialogue_id)
        return

    dialog_active = true
    if host.dialog_box:
        host.dialog_box.visible = true
    active_dialogue_id = dialogue_id
    active_dialogs = host.dialogue_sets[dialogue_id]
    current_index = 0

    var p = host.get_player() if host and host.has_method("get_player") else null
    if p:
        p.can_move = false

    show_dialog(current_index)

func next_dialog() -> void:
    current_index += 1
    if current_index >= active_dialogs.size():
        end_dialog()
    else:
        show_dialog(current_index)

func show_dialog(index: int) -> void:
    var d = active_dialogs[index]
    var speaker_id = str(d.get("speaker", ""))
    var expression = host.get_dialog_expression(d, "default") if host.has_method("get_dialog_expression") else str(d.get("expression", ""))
    host.dialog_debug_speaker_id = speaker_id
    host.dialog_debug_expression = expression
    host.update_prelude_scene(str(d.get("scene", ""))) if host.has_method("update_prelude_scene") else null
    if str(d.get("effect", "")) == "shake":
        if host.has_method("shake_scene"): host.shake_scene()
    if host.has_method("configure_dialog_text_style"): host.configure_dialog_text_style()
    if host.speaker_name and host.has_method("CharacterVisualManager"):
        host.speaker_name.text = CharacterVisualManager.get_display_name(speaker_id)
    full_text = LocalizationManager.get_entry_text(d)
    if host.dialog_text:
        host.dialog_text.text = ""
    if host.has_method("show_dialog_standees"):
        host.show_dialog_standees(d, speaker_id, expression)
    is_typing = true
    typing_run_id += 1
    var run_id = typing_run_id
    type_text(full_text, run_id)
    if host.has_method("hide_next_indicator"): host.hide_next_indicator()

func type_text(text: String, run_id: int) -> void:
    for i in range(text.length()):
        if not is_typing or run_id != typing_run_id:
            break

        if host.dialog_text:
            host.dialog_text.text = text.substr(0, i + 1)

        if text[i] != " ":
            if host.type_sound:
                host.type_sound.stop()
                host.type_sound.play()

        await host.get_tree().create_timer(0.05).timeout

    if run_id != typing_run_id:
        return
    is_typing = false
    if host.dialog_text:
        host.dialog_text.text = text
    if host.type_sound:
        host.type_sound.stop()
    if host.has_method("show_next_indicator"): host.show_next_indicator()

func end_dialog() -> void:
    typing_run_id += 1
    is_typing = false
    if host.type_sound:
        host.type_sound.stop()
    if active_dialogue_id == "prelude_opening":
        SaveManager.set_flag("prelude_opening_complete")
        SaveManager.set_location("亞特蘭提斯")
        SaveManager.autosave(true)
        if host.has_method("clear_prelude_overlay"): host.clear_prelude_overlay()
        start_dialog("tutorial")
        return
    elif active_dialogue_id == "tutorial":
        SaveManager.set_flag("tutorial_complete")
    elif active_dialogue_id == "lumi_intro":
        SaveManager.set_flag("talked_to_lumi")
        if host.has_method("enable_lumi_follow"):
            host.lumi_follow_enabled = true
    elif active_dialogue_id == "orion_first_seen":
        SaveManager.set_flag("orion_discovered")
        SaveManager.set_location("墜落地點")
        SaveManager.autosave(true)
        dialog_active = false
        if host.dialog_box: host.dialog_box.visible = false
        # delegate to systems if available, otherwise no-op
        if host.has_method("hide_dialog_standees"): host.hide_dialog_standees()
        if host.has_method("hide_next_indicator"): host.hide_next_indicator()
        active_dialogue_id = ""
        if host.has_method("show_orion_choice"): host.show_orion_choice()
        return
    elif active_dialogue_id == "orion_rescue":
        SaveManager.set_flag("prelude_complete")
        SaveManager.set_location("小島")
        if host.has_method("clear_prelude_overlay"): host.clear_prelude_overlay()
        MusicManager.play_context("overworld")

    dialog_active = false
    if host.dialog_box: host.dialog_box.visible = false
    if host.has_method("hide_dialog_standees"): host.hide_dialog_standees()
    if host.has_method("hide_next_indicator"): host.hide_next_indicator()
    active_dialogue_id = ""

    var p = host.get_player() if host and host.has_method("get_player") else null
    if p:
        p.can_move = true
    SaveManager.autosave(true)

# Dialogue helpers and debug overlay (migrated from scene):
const DIALOG_STANDEE_DEFAULT_ASPECT := 2.0 / 3.0
const DIALOG_DEBUG_SMALL_WINDOW_SIZE := Vector2i(640, 360)
const DIALOG_TEXT_MIN_FONT_SIZE := 28
const DIALOG_TEXT_MAX_FONT_SIZE := 38
const DIALOG_NAME_MIN_FONT_SIZE := 22
const DIALOG_NAME_MAX_FONT_SIZE := 30

var dialog_debug_visible: bool = false
var dialog_debug_layer: CanvasLayer
var dialog_debug_label: Label
var dialog_debug_frame: ColorRect
var dialog_debug_speaker_id: String = ""
var dialog_debug_expression: String = ""
var dialog_debug_small_preview: bool = false
var dialog_standee_nodes := {}

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
            if host.speaker_avatar != null:
                host.speaker_avatar = node
            dialog_debug_speaker_id = item_character
            update_dialog_debug_overlay(item_character, layout)

func get_dialog_standee_node(character_id: String) -> TextureRect:
    if dialog_standee_nodes.has(character_id):
        return dialog_standee_nodes[character_id]

    var node: TextureRect
    if dialog_standee_nodes.is_empty() and host.speaker_avatar:
        node = host.speaker_avatar
    else:
        node = TextureRect.new()
        node.name = "Standee_%s" % character_id
        host.dialog_box.add_child(node)

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
    if not standee_node or not host.dialog_box:
        return

    var viewport_size := get_dialog_debug_layout_size()
    var dialog_height: float = host.dialog_box.size.y
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
    host.dialog_box.move_child(standee_node, 0)

func configure_dialog_text_style() -> void:
    if not host.dialog_box:
        return

    var viewport_size := get_dialog_debug_layout_size()
    var dialog_height: float = host.dialog_box.size.y
    if dialog_height <= 0.0:
        dialog_height = 262.0

    var text_font_size := int(round(clampf(viewport_size.y * 0.048, DIALOG_TEXT_MIN_FONT_SIZE, DIALOG_TEXT_MAX_FONT_SIZE)))
    var name_font_size := int(round(clampf(viewport_size.y * 0.037, DIALOG_NAME_MIN_FONT_SIZE, DIALOG_NAME_MAX_FONT_SIZE)))
    var content_left: float = clampf(viewport_size.x * 0.055, 28.0, 72.0)
    var content_right: float = 46.0
    var name_top: float = maxf(16.0, dialog_height * 0.08)
    var text_top: float = maxf(62.0, dialog_height * 0.25)
    var text_bottom: float = 34.0

    if host.speaker_name:
        host.speaker_name.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
        host.speaker_name.offset_left = content_left
        host.speaker_name.offset_top = name_top
        host.speaker_name.offset_right = viewport_size.x - content_right
        host.speaker_name.offset_bottom = name_top + float(name_font_size + 12)
        host.speaker_name.add_theme_font_size_override("font_size", name_font_size)
        host.speaker_name.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
        host.speaker_name.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
        host.speaker_name.add_theme_constant_override("shadow_offset_x", 2)
        host.speaker_name.add_theme_constant_override("shadow_offset_y", 2)
        host.speaker_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    if host.dialog_text:
        host.dialog_text.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
        host.dialog_text.offset_left = content_left
        host.dialog_text.offset_top = text_top
        host.dialog_text.offset_right = viewport_size.x - content_right
        host.dialog_text.offset_bottom = dialog_height - text_bottom
        host.dialog_text.add_theme_font_size_override("font_size", text_font_size)
        host.dialog_text.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
        host.dialog_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
        host.dialog_text.add_theme_constant_override("shadow_offset_x", 2)
        host.dialog_text.add_theme_constant_override("shadow_offset_y", 2)
        host.dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        host.dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP

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
        configure_dialog_standee_node(host.speaker_avatar, layout, true)
        update_dialog_debug_overlay(dialog_debug_speaker_id, layout)

func get_dialog_debug_layout_size() -> Vector2:
    if dialog_debug_visible and dialog_debug_small_preview:
        return Vector2(DIALOG_DEBUG_SMALL_WINDOW_SIZE)
    return host.get_viewport_rect().size

func ensure_dialog_debug_overlay() -> void:
    if dialog_debug_layer:
        return

    dialog_debug_layer = CanvasLayer.new()
    dialog_debug_layer.name = "DialogDebugLayer"
    dialog_debug_layer.layer = 100
    host.add_child(dialog_debug_layer)

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
    if host.speaker_avatar:
        texture = host.speaker_avatar.texture
        avatar_rect = host.speaker_avatar.get_global_rect()
        avatar_z = host.speaker_avatar.z_index
        avatar_child_index = host.speaker_avatar.get_index()
        avatar_visible = host.speaker_avatar.visible
        if host.speaker_avatar.get_parent():
            avatar_parent = host.speaker_avatar.get_parent().name
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
