extends "res://scripts/world/world_base.gd"

@export var map_data_path := "res://data/maps/act2_skyisland.json"

var map_data: Dictionary = {}
var music_context := "overworld"

func on_world_ready() -> void:
	map_data = MapDataLoader.load_map_data(map_data_path)
	_apply_map_data(map_data)
	WalkableAreaSpawner.spawn_walkable_area(self, map_data)
	EventSpawner.spawn_events(map_data, get_node_or_null("EventRoot"))
	MusicManager.play_context(music_context)

func _apply_map_data(data: Dictionary) -> void:
	if data.is_empty():
		return

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

func _on_lumi_event_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	print("Lumi event entered.")
	if dialogue_sets.has("lumi_event"):
		start_dialog("lumi_event")

func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	print("Boss trigger entered.")
	if dialogue_sets.has("boss_intro"):
		start_dialog("boss_intro")

func _on_exit_portal_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	print("Exit portal entered.")
	if dialogue_sets.has("exit_portal"):
		start_dialog("exit_portal")
