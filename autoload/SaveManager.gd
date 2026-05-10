extends Node

const SAVE_PATH = "user://savegame.json"
const AUTOSAVE_INTERVAL = 15.0
const POSITION_SAVE_DISTANCE = 12.0
const DEFAULT_GAME_SCENE = "res://scenes/main.tscn"

var default_save_data := {
	"version": 1,
	"scene": DEFAULT_GAME_SCENE,
	"player_position": {"x": 0.0, "y": 0.0},
	"flags": {},
	"story": {},
	"saved_at_unix": 0,
}

var player: Node2D
var save_data := default_save_data.duplicate(true)
var dirty := false
var last_saved_player_position := Vector2.INF

func _ready() -> void:
	load_game()
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

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func start_new_game() -> void:
	reset_save_data()
	delete_save_file()

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

func autosave(force := false) -> void:
	if player:
		if force:
			set_player_position(player.global_position)
		else:
			track_player_position(player.global_position)

	if not dirty:
		return

	save_game()

func save_game() -> bool:
	save_data["scene"] = get_current_scene_path()
	save_data["saved_at_unix"] = Time.get_unix_time_from_system()

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Could not open save file: %s" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	dirty = false
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not read save file: %s" % SAVE_PATH)
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file data is invalid.")
		return false

	save_data = default_save_data.duplicate(true)
	save_data.merge(parsed, true)
	dirty = false
	return true

func delete_save_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var absolute_path = ProjectSettings.globalize_path(SAVE_PATH)
	var error = DirAccess.remove_absolute(absolute_path)
	if error != OK:
		push_warning("Could not delete save file: %s" % SAVE_PATH)

func get_saved_scene_path() -> String:
	var scene_path = str(save_data.get("scene", ""))
	if scene_path == "":
		return DEFAULT_GAME_SCENE

	return scene_path

func get_save_summary() -> Dictionary:
	var position_data: Dictionary = save_data.get("player_position", {})
	return {
		"scene": get_saved_scene_path(),
		"saved_at_unix": int(save_data.get("saved_at_unix", 0)),
		"player_position": Vector2(
			float(position_data.get("x", 0.0)),
			float(position_data.get("y", 0.0))
		),
	}

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
