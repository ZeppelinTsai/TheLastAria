extends Node

const TRACK_CONFIG_PATH = "res://data/music_tracks.json"
const DEFAULT_CONTEXT = "overworld"
const DEFAULT_FADE_DURATION = 1.0
const SILENT_VOLUME_DB = -80.0

var tracks := {}
var current_context := ""
var current_track_path := ""
var player: AudioStreamPlayer
var fade_tween: Tween

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.volume_db = SILENT_VOLUME_DB
	add_child(player)
	load_track_config()

func load_track_config() -> void:
	var file = FileAccess.open(TRACK_CONFIG_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not load music config: %s" % TRACK_CONFIG_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Music config data is invalid: %s" % TRACK_CONFIG_PATH)
		return

	tracks = parsed

func play_context(context: String, fade_duration := DEFAULT_FADE_DURATION) -> void:
	var track_data: Dictionary = tracks.get(context, {})
	if track_data.is_empty():
		push_warning("Music context not found: %s" % context)
		track_data = tracks.get(DEFAULT_CONTEXT, {})
		context = DEFAULT_CONTEXT

	var path = str(track_data.get("path", ""))
	if path == "":
		push_warning("Music context has no path: %s" % context)
		return

	var target_volume = float(track_data.get("volume_db", -12.0))
	play_track(path, target_volume, context, fade_duration)

func stop_music(fade_duration := DEFAULT_FADE_DURATION) -> void:
	if fade_tween:
		fade_tween.kill()

	if not player.playing:
		return

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_duration)
	fade_tween.tween_callback(Callable(player, "stop"))
	current_context = ""
	current_track_path = ""

func play_track(path: String, target_volume := -12.0, context := "", fade_duration := DEFAULT_FADE_DURATION) -> void:
	if current_track_path == path and player.playing:
		current_context = context
		fade_to_volume(target_volume, fade_duration)
		return

	var stream = load(path)
	if not stream:
		push_warning("Could not load music track: %s" % path)
		return

	set_stream_loop(stream)

	if fade_tween:
		fade_tween.kill()

	if player.playing and fade_duration > 0.0:
		fade_tween = create_tween()
		fade_tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_duration * 0.5)
		fade_tween.tween_callback(Callable(self, "_start_stream").bind(stream, path, context))
		fade_tween.tween_property(player, "volume_db", target_volume, fade_duration * 0.5)
	else:
		_start_stream(stream, path, context)
		fade_to_volume(target_volume, fade_duration)

func fade_to_volume(target_volume: float, fade_duration := DEFAULT_FADE_DURATION) -> void:
	if fade_tween:
		fade_tween.kill()

	if fade_duration <= 0.0:
		player.volume_db = target_volume
		return

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", target_volume, fade_duration)

func _start_stream(stream: AudioStream, path: String, context: String) -> void:
	player.stream = stream
	player.volume_db = SILENT_VOLUME_DB
	player.play()
	current_track_path = path
	current_context = context

func set_stream_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
