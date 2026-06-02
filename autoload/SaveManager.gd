extends Node

const LEGACY_SAVE_PATH = "user://savegame.json"
const SAVE_PATH_TEMPLATE = "user://save_slot_%d.json"
const SLOT_COUNT = 9
const AUTOSAVE_INTERVAL = 15.0
const POSITION_SAVE_DISTANCE = 12.0
const DEFAULT_GAME_SCENE = "res://scenes/main.tscn"

var default_save_data := {
	"version": 1,
	"scene": DEFAULT_GAME_SCENE,
	"player_position": {"x": 0.0, "y": 0.0},
	"flags": {},
	"story": {},
	"settings": {},
	"saved_at_unix": 0,
	"location": "亞特蘭提斯",
}

var player: Node2D
var save_data := default_save_data.duplicate(true)
var active_slot := 1
var dirty := false
var last_saved_player_position := Vector2.INF

func _ready() -> void:
	load_game(active_slot)
	var timer = Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = AUTOSAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(autosave)
	add_child(timer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave(true)

func register_player(node: Node2D) -> void:
	player = node
	apply_player_position()
	last_saved_player_position = player.global_position

func unregister_player(node: Node2D) -> void:
	if player == node:
		player = null
		last_saved_player_position = Vector2.INF

func get_save_path(slot := -1) -> String:
	var resolved_slot = get_valid_slot(slot)
	return SAVE_PATH_TEMPLATE % resolved_slot

func get_valid_slot(slot: int) -> int:
	if slot < 1 or slot > SLOT_COUNT:
		return active_slot

	return slot

func set_active_slot(slot: int) -> void:
	active_slot = get_valid_slot(slot)

func has_save_file(slot := -1) -> bool:
	var resolved_slot = get_valid_slot(slot)
	return FileAccess.file_exists(get_save_path(resolved_slot)) or (resolved_slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH))

func start_new_game(slot := -1) -> void:
	set_active_slot(get_valid_slot(slot))
	reset_save_data()
	delete_save_file(active_slot)
	if active_slot == 1:
		delete_legacy_save_file()
	set_location("亞特蘭提斯")

func reset_save_data() -> void:
	save_data = default_save_data.duplicate(true)
	dirty = false
	last_saved_player_position = Vector2.INF

func track_player_position(position: Vector2) -> void:
	if last_saved_player_position == Vector2.INF:
		last_saved_player_position = position

	if position.distance_to(last_saved_player_position) < POSITION_SAVE_DISTANCE:
		return

	set_player_position(position)

func set_player_position(position: Vector2) -> void:
	save_data["player_position"] = {"x": position.x, "y": position.y}
	last_saved_player_position = position
	dirty = true

func set_flag(flag_name: String, value := true) -> void:
	if save_data["flags"].get(flag_name) == value:
		return

	save_data["flags"][flag_name] = value
	dirty = true

func has_flag(flag_name: String) -> bool:
	return bool(save_data["flags"].get(flag_name, false))

func set_story_value(key: String, value: Variant) -> void:
	if save_data["story"].get(key) == value:
		return

	save_data["story"][key] = value
	dirty = true

func get_story_value(key: String, default_value: Variant = null) -> Variant:
	return save_data["story"].get(key, default_value)

func set_location(location: String) -> void:
	if save_data.get("location", "") == location:
		return

	save_data["location"] = location
	dirty = true

func autosave(force := false) -> void:
	if player:
		if force:
			set_player_position(player.global_position)
		else:
			track_player_position(player.global_position)

	if not dirty:
		return

	save_game()

func save_game(slot := -1) -> bool:
	if slot != -1:
		set_active_slot(slot)

	save_data["scene"] = get_current_scene_path()
	if has_node("/root/SettingsManager"):
		save_data["settings"] = SettingsManager.get_settings_snapshot()
	save_data["saved_at_unix"] = Time.get_unix_time_from_system()

	var file = FileAccess.open(get_save_path(active_slot), FileAccess.WRITE)
	if not file:
		push_warning("Could not open save file: %s" % get_save_path(active_slot))
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	dirty = false
	return true

func load_game(slot := -1) -> bool:
	if slot != -1:
		set_active_slot(slot)

	var save_path = get_save_path(active_slot)
	if not FileAccess.file_exists(save_path):
		if active_slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH):
			save_path = LEGACY_SAVE_PATH
		else:
			return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_warning("Could not read save file: %s" % save_path)
		return false


	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file data is invalid.")
		return false

	save_data = default_save_data.duplicate(true)
	save_data.merge(parsed, true)
	apply_loaded_settings()
	dirty = false
	return true

func apply_loaded_settings() -> void:
	if not has_node("/root/SettingsManager"):
		return
	var loaded_settings = save_data.get("settings", {})
	if typeof(loaded_settings) == TYPE_DICTIONARY and not loaded_settings.is_empty():
		SettingsManager.apply_settings_from_snapshot(loaded_settings, true)

func delete_save_file(slot := -1) -> void:
	var save_path = get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return

	var absolute_path = ProjectSettings.globalize_path(save_path)
	var error = DirAccess.remove_absolute(absolute_path)
	if error != OK:
		push_warning("Could not delete save file: %s" % save_path)

func delete_legacy_save_file() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return

	var absolute_path = ProjectSettings.globalize_path(LEGACY_SAVE_PATH)
	var error = DirAccess.remove_absolute(absolute_path)
	if error != OK:
		push_warning("Could not delete save file: %s" % LEGACY_SAVE_PATH)

func get_saved_scene_path() -> String:
	var scene_path = str(save_data.get("scene", ""))
	if scene_path == "":
		return DEFAULT_GAME_SCENE

	return scene_path

func get_scene_path_from_data(source_data: Dictionary) -> String:
	var scene_path = str(source_data.get("scene", ""))
	if scene_path == "":
		return DEFAULT_GAME_SCENE

	return scene_path

func get_save_summary(slot := -1) -> Dictionary:
	var source_data = save_data
	var has_data = true
	var summary_slot = get_valid_slot(slot)
	if slot != -1:
		source_data = read_save_data(summary_slot)
		has_data = not source_data.is_empty()

	if not has_data:
		return {
			"slot": summary_slot,
			"exists": false,
			"scene": "",
			"saved_at_unix": 0,
			"location": "",
			"player_position": Vector2.ZERO,
		}

	var position_data: Dictionary = source_data.get("player_position", {})
	return {
		"slot": summary_slot,
		"exists": true,
		"scene": get_scene_path_from_data(source_data),
		"saved_at_unix": int(source_data.get("saved_at_unix", 0)),
		"location": str(source_data.get("location", "")),
		"player_position": Vector2(
			float(position_data.get("x", 0.0)),
			float(position_data.get("y", 0.0))
		),
	}

func read_save_data(slot: int) -> Dictionary:
	var save_path = get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		if slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH):
			save_path = LEGACY_SAVE_PATH
		else:
			return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var merged = default_save_data.duplicate(true)
	merged.merge(parsed, true)
	return merged

func get_all_save_summaries() -> Array:
	var summaries = []
	for slot in range(1, SLOT_COUNT + 1):
		summaries.append(get_save_summary(slot))

	return summaries

func get_latest_save_slot(default_slot := 1) -> int:
	var latest_slot = get_valid_slot(default_slot)
	var latest_saved_at = -1
	for slot in range(1, SLOT_COUNT + 1):
		var summary = get_save_summary(slot)
		if not bool(summary["exists"]):
			continue

		var saved_at = int(summary.get("saved_at_unix", 0))
		if saved_at > latest_saved_at:
			latest_saved_at = saved_at
			latest_slot = slot

	return latest_slot

func apply_player_position() -> void:
	if not player:
		return

	var position_data: Dictionary = save_data.get("player_position", {})
	if not position_data.has("x") or not position_data.has("y"):
		return

	var saved_position = Vector2(float(position_data["x"]), float(position_data["y"]))
	if saved_position == Vector2.ZERO:
		return

	player.global_position = saved_position

func get_current_scene_path() -> String:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.scene_file_path != "":
		return current_scene.scene_file_path

	return get_saved_scene_path()
