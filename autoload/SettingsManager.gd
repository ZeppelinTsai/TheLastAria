extends Node

signal settings_changed(settings: Dictionary)

const SETTINGS_PATH := "user://settings.json"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
]
const CONTROL_SCHEMES: Array[String] = [
	"keyboard_mouse",
	"controller",
]
const DEFAULT_SETTINGS := {
	"version": 1,
	"locale": "zh_TW",
	"resolution_index": 0,
	"control_scheme": "keyboard_mouse",
}

var settings := DEFAULT_SETTINGS.duplicate(true)
var applying := false

func _ready() -> void:
	load_settings()
	apply_settings(false)

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		settings = DEFAULT_SETTINGS.duplicate(true)
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not read settings file: %s" % SETTINGS_PATH)
		settings = DEFAULT_SETTINGS.duplicate(true)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Settings file data is invalid.")
		settings = DEFAULT_SETTINGS.duplicate(true)
		return

	settings = DEFAULT_SETTINGS.duplicate(true)
	settings.merge(parsed, true)
	_normalize_settings()

func save_settings() -> bool:
	_normalize_settings()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Could not write settings file: %s" % SETTINGS_PATH)
		return false

	file.store_string(JSON.stringify(settings, "\t"))
	return true

func get_settings_snapshot() -> Dictionary:
	_normalize_settings()
	return settings.duplicate(true)

func apply_settings_from_snapshot(snapshot: Dictionary, persist := true) -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	settings.merge(snapshot, true)
	_normalize_settings()
	apply_settings(persist)

func reset_to_defaults() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	apply_settings(true)

func set_locale(locale_id: String) -> void:
	settings["locale"] = locale_id
	apply_settings(true)

func set_resolution_index(index: int) -> void:
	settings["resolution_index"] = clampi(index, 0, RESOLUTIONS.size() - 1)
	apply_settings(true)

func set_control_scheme(control_scheme: String) -> void:
	if not CONTROL_SCHEMES.has(control_scheme):
		control_scheme = str(DEFAULT_SETTINGS["control_scheme"])
	settings["control_scheme"] = control_scheme
	apply_settings(true)

func get_locale() -> String:
	return str(settings.get("locale", DEFAULT_SETTINGS["locale"]))

func get_resolution_index() -> int:
	return int(settings.get("resolution_index", DEFAULT_SETTINGS["resolution_index"]))

func get_control_scheme() -> String:
	return str(settings.get("control_scheme", DEFAULT_SETTINGS["control_scheme"]))

func get_resolution_label(index: int) -> String:
	var resolution := RESOLUTIONS[clampi(index, 0, RESOLUTIONS.size() - 1)]
	return "%d x %d" % [resolution.x, resolution.y]

func get_control_scheme_label_key(control_scheme: String) -> String:
	return "options.controls.%s" % control_scheme

func apply_settings(persist := true) -> void:
	if applying:
		return

	applying = true
	_normalize_settings()
	_apply_resolution()
	_apply_locale()
	if persist:
		save_settings()
	applying = false
	settings_changed.emit(get_settings_snapshot())

func _apply_resolution() -> void:
	var resolution := RESOLUTIONS[get_resolution_index()]
	DisplayServer.window_set_size(resolution)
	var screen_id := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen_id)
	var centered_position := screen_rect.position + ((screen_rect.size - resolution) / 2)
	DisplayServer.window_set_position(centered_position)

func _apply_locale() -> void:
	if has_node("/root/LocalizationManager"):
		LocalizationManager.set_locale(get_locale())

func _normalize_settings() -> void:
	settings["version"] = int(settings.get("version", DEFAULT_SETTINGS["version"]))
	settings["locale"] = str(settings.get("locale", DEFAULT_SETTINGS["locale"]))
	settings["resolution_index"] = clampi(int(settings.get("resolution_index", DEFAULT_SETTINGS["resolution_index"])), 0, RESOLUTIONS.size() - 1)
	var control_scheme := str(settings.get("control_scheme", DEFAULT_SETTINGS["control_scheme"]))
	if not CONTROL_SCHEMES.has(control_scheme):
		control_scheme = str(DEFAULT_SETTINGS["control_scheme"])
	settings["control_scheme"] = control_scheme
