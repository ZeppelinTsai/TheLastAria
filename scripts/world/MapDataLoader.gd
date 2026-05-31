class_name MapDataLoader
extends RefCounted

static func load_map_data(path: String) -> Dictionary:
	var clean_path := path.strip_edges()
	if clean_path == "":
		push_warning("Map data path is empty.")
		return {}

	if not FileAccess.file_exists(clean_path):
		push_warning("Map data file does not exist: %s" % clean_path)
		return {}

	var file := FileAccess.open(clean_path, FileAccess.READ)
	if not file:
		push_warning("Could not open map data file: %s" % clean_path)
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_warning(
			"Map data JSON parse error in %s at line %d: %s"
			% [clean_path, json.get_error_line(), json.get_error_message()]
		)
		return {}

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Map data root must be a Dictionary: %s" % clean_path)
		return {}

	return data
