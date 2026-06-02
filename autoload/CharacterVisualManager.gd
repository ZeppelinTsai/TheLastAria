extends Node

const CHARACTER_CONFIG_PATH = "res://data/characters.json"
const DEFAULT_EXPRESSION = "default"

var characters := {}
var texture_cache := {}

func _ready() -> void:
	load_character_config()

func load_character_config() -> void:
	var file = FileAccess.open(CHARACTER_CONFIG_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not load character config: %s" % CHARACTER_CONFIG_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Character config data is invalid: %s" % CHARACTER_CONFIG_PATH)
		return

	characters = parsed

func get_display_name(character_id: String) -> String:
	var character_data: Dictionary = characters.get(character_id, {})
	return str(character_data.get("display_name", character_id))

func get_dialog_standee_layout(character_id: String, overrides := {}) -> Dictionary:
	var character_data: Dictionary = characters.get(character_id, {})
	var layout: Dictionary = character_data.get("dialog_standee", {}).duplicate(true)
	if typeof(overrides) == TYPE_DICTIONARY:
		for key in overrides:
			layout[key] = overrides[key]

	return {
		"x": float(layout.get("x", 92.0)),
		"bottom": float(layout.get("bottom", 46.0)),
		"position": str(layout.get("position", "")),
		"x_ratio": float(layout.get("x_ratio", -1.0)),
		"x_anchor": float(layout.get("x_anchor", -1.0)),
		"x_offset": float(layout.get("x_offset", 0.0)),
		"x_offset_ratio": float(layout.get("x_offset_ratio", 0.0)),
		"bottom_ratio": float(layout.get("bottom_ratio", 999.0)),
		"height_ratio": float(layout.get("height_ratio", 0.94)),
		"scale": float(layout.get("scale", 1.0)),
		"z_offset": int(layout.get("z_offset", 0)),
		"visible": bool(layout.get("visible", true))
	}

func get_portrait(character_id: String, expression := DEFAULT_EXPRESSION) -> Texture2D:
	return get_visual_texture(character_id, "portraits", expression)

func get_bust(character_id: String, expression := DEFAULT_EXPRESSION) -> Texture2D:
	return get_visual_texture(character_id, "busts", expression)

func get_dialog_standee(character_id: String, expression := DEFAULT_EXPRESSION) -> Texture2D:
	var bust := get_bust(character_id, expression)
	if bust:
		return bust

	return get_portrait(character_id, expression)

func get_visual_texture(character_id: String, visual_group: String, expression := DEFAULT_EXPRESSION) -> Texture2D:
	var path = get_visual_path(character_id, visual_group, expression)
	if path == "":
		return null

	if texture_cache.has(path):
		return texture_cache[path]

	var texture = load(path)
	if not texture:
		push_warning("Could not load character visual: %s" % path)
		return null

	texture_cache[path] = texture
	return texture

func get_visual_path(character_id: String, visual_group: String, expression := DEFAULT_EXPRESSION) -> String:
	var character_data: Dictionary = characters.get(character_id, {})
	if character_data.is_empty():
		return ""

	var visual_data: Dictionary = character_data.get(visual_group, {})
	if visual_data.is_empty():
		return ""

	var path = str(visual_data.get(expression, ""))
	if path != "":
		return path

	return str(visual_data.get(DEFAULT_EXPRESSION, ""))
