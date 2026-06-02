extends Node

signal locale_changed(locale: String)

const TEXT_PATH := "res://data/localization/ui_text.json"
const EXTRA_TEXT_DIRS := [
	"res://data/localization/dialogues",
	"res://data/localization/scripts"
]
const DEFAULT_LOCALE := "en"
const EMPTY_LOCALE_NAMES := {
	"zh_TW": "繁體中文",
	"zh_CN": "简体中文",
	"ko": "한국어",
	"fr": "Français",
	"de": "Deutsch",
	"es": "Español"
}

var locale := DEFAULT_LOCALE
var texts := {}

func _ready() -> void:
	load_texts()

func load_texts() -> void:
	var file := FileAccess.open(TEXT_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not load localization file: %s" % TEXT_PATH)
		texts = {}
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Localization file data is invalid: %s" % TEXT_PATH)
		texts = {}
		return

	texts = parsed
	for directory_path in EXTRA_TEXT_DIRS:
		load_text_directory(directory_path)

func load_text_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if not directory:
		return

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".json"):
			merge_text_file("%s/%s" % [directory_path, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()

func merge_text_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Could not load localization file: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Localization file data is invalid: %s" % path)
		return

	for locale_id in parsed.keys():
		var locale_texts = parsed[locale_id]
		if typeof(locale_texts) != TYPE_DICTIONARY:
			continue
		if not texts.has(locale_id) or typeof(texts[locale_id]) != TYPE_DICTIONARY:
			texts[locale_id] = {}
		for key in locale_texts.keys():
			var value := str(locale_texts[key])
			if value != "":
				texts[locale_id][key] = value

func set_locale(next_locale: String) -> void:
	if not texts.has(next_locale):
		return
	if locale == next_locale:
		return
	locale = next_locale
	locale_changed.emit(locale)

func get_supported_locales() -> Array[String]:
	var locales: Array[String] = []
	for key in texts.keys():
		locales.append(str(key))
	locales.sort()
	return locales

func get_locale_name(locale_id: String) -> String:
	var locale_texts := get_locale_texts(locale_id)
	var name := str(locale_texts.get("language_name", ""))
	if name != "":
		return name
	return str(EMPTY_LOCALE_NAMES.get(locale_id, locale_id))

func tr_text(key: String) -> String:
	var current := get_locale_texts(locale)
	var value := str(current.get(key, ""))
	if value != "":
		return value

	var fallback := get_locale_texts(DEFAULT_LOCALE)
	value = str(fallback.get(key, ""))
	if value != "":
		return value

	return key

func format_text(key: String, values: Array) -> String:
	return tr_text(key) % values

func get_locale_texts(locale_id: String) -> Dictionary:
	var locale_texts = texts.get(locale_id, {})
	if typeof(locale_texts) == TYPE_DICTIONARY:
		return locale_texts
	return {}
