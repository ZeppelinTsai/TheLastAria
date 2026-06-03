extends "res://scripts/world/world_base.gd"

@export var map_data_path := "res://data/maps/sunken_city_lyra_room.json"

const POST_STORYBOOK_SEQUENCE_META := "post_storybook_sequence"
const POST_STORYBOOK_DIALOGUE_ID := "opening_after_storybook"
const POST_STORYBOOK_TUTORIAL_DIALOGUE_ID := "movement_tutorial_after_storybook"
const POST_STORYBOOK_TUTORIAL_FLAG := "movement_tutorial_after_storybook_seen"
const DESK_READING_POSITION := Vector2(25, -220)
const ROOM_CENTER_POSITION := Vector2(0, 180)
const WALK_TO_CENTER_DURATION := 2

var map_data: Dictionary = {}
var music_context := "overworld"
var is_post_storybook_sequence := false

func on_world_ready() -> void:
	map_data = MapDataLoader.load_map_data(map_data_path)
	_apply_map_data(map_data)
	WalkableAreaSpawner.spawn_walkable_area(self, map_data)
	EventSpawner.spawn_events(map_data, get_node_or_null("EventRoot"))
	MusicManager.play_context(music_context)
	if _consume_post_storybook_sequence_meta():
		call_deferred("_start_post_storybook_sequence")
	init_lumi_follow()

func _apply_map_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	apply_background_from_map_data(data)
	apply_player_spawn_from_map_data(data)

	var map_dialogue_path := str(data.get("dialogue_path", "")).strip_edges()
	if map_dialogue_path != "":
		var previous_dialogue_path := dialogue_path
		dialogue_path = map_dialogue_path
		if previous_dialogue_path != dialogue_path or dialogue_sets.is_empty():
			load_dialogue_sets()
	else:
		push_warning("Map data missing dialogue_path: %s" % map_data_path)

	var map_music_context := str(data.get("music_context", "")).strip_edges()
	if map_music_context != "":
		music_context = map_music_context
	else:
		push_warning("Map data missing music_context: %s" % map_data_path)

func apply_player_spawn_from_map_data(data: Dictionary) -> void:
	if not player:
		return

	var spawn_data = data.get("player_spawn", [])
	if typeof(spawn_data) != TYPE_ARRAY or spawn_data.size() < 2:
		push_warning("Map data missing player_spawn: %s" % map_data_path)
		return

	player.global_position = Vector2(float(spawn_data[0]), float(spawn_data[1]))

func _consume_post_storybook_sequence_meta() -> bool:
	if not SceneTransition.has_meta(POST_STORYBOOK_SEQUENCE_META):
		return false

	SceneTransition.remove_meta(POST_STORYBOOK_SEQUENCE_META)
	return true

func _start_post_storybook_sequence() -> void:
	is_post_storybook_sequence = true
	if player:
		player.global_position = DESK_READING_POSITION
		player.set("target_position", DESK_READING_POSITION)
		player.set("auto_move", false)
	set_player_can_move(false)
	await get_tree().process_frame

	if dialogue_sets.has(POST_STORYBOOK_DIALOGUE_ID):
		start_dialog(POST_STORYBOOK_DIALOGUE_ID)
	else:
		push_warning("Dialogue id not found: %s" % POST_STORYBOOK_DIALOGUE_ID)
		_move_player_to_room_center()

func on_dialog_finished(dialogue_id: String) -> void:
	if dialogue_id == POST_STORYBOOK_DIALOGUE_ID:
		call_deferred("_move_player_to_room_center")
	elif dialogue_id == POST_STORYBOOK_TUTORIAL_DIALOGUE_ID:
		SaveManager.set_flag(POST_STORYBOOK_TUTORIAL_FLAG)

func _move_player_to_room_center() -> void:
	if not player:
		is_post_storybook_sequence = false
		return

	set_player_can_move(false)
	var sprite := player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.has_method("play"):
		sprite.play("walk_down")

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", ROOM_CENTER_POSITION, WALK_TO_CENTER_DURATION)
	await tween.finished

	if sprite and sprite.has_method("stop"):
		sprite.stop()
	player.set("target_position", ROOM_CENTER_POSITION)
	player.set("auto_move", false)
	if player.has_method("pull_inside_walkable_area"):
		player.pull_inside_walkable_area()
	SaveManager.set_player_position(player.global_position)
	SaveManager.autosave(true)
	is_post_storybook_sequence = false
	if dialogue_sets.has(POST_STORYBOOK_TUTORIAL_DIALOGUE_ID) and not SaveManager.has_flag(POST_STORYBOOK_TUTORIAL_FLAG):
		start_dialog(POST_STORYBOOK_TUTORIAL_DIALOGUE_ID)
	else:
		set_player_can_move(true)
