class_name EventSpawner
extends RefCounted

const DIALOGUE_TRIGGER_SCRIPT := preload("res://scripts/world/EventTrigger.gd")
const SCENE_EXIT_TRIGGER_SCRIPT := preload("res://scripts/world/SceneExitTrigger.gd")
const DIALOGUE_TRIGGER_SCRIPT_PATH := "res://scripts/world/EventTrigger.gd"
const SCENE_EXIT_TRIGGER_SCRIPT_PATH := "res://scripts/world/SceneExitTrigger.gd"

static func spawn_events(map_data: Dictionary, event_root: Node) -> void:
	if not event_root:
		push_warning("EventSpawner needs an EventRoot node.")
		return

	var events = map_data.get("events", [])
	if typeof(events) != TYPE_ARRAY:
		push_warning("Map data events must be an Array.")
		return

	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			push_warning("EventSpawner skipped non-Dictionary event.")
			continue

		_spawn_event(event, event_root)

static func _spawn_event(event: Dictionary, event_root: Node) -> void:
	var event_type := str(event.get("type", "")).strip_edges()
	if event_type == "":
		push_warning("Map event missing type.")
		return

	if _has_existing_equivalent(event, event_root):
		return

	match event_type:
		"dialogue":
			_spawn_dialogue_event(event, event_root)
		"scene_exit":
			_spawn_scene_exit_event(event, event_root)
		_:
			push_warning("Unsupported map event type: %s" % event_type)

static func _spawn_dialogue_event(event: Dictionary, event_root: Node) -> void:
	var dialogue_id := str(event.get("dialogue_id", "")).strip_edges()
	var dialogue_ids := _event_dialogue_ids(event)
	if dialogue_id == "" and dialogue_ids.is_empty():
		push_warning("Dialogue map event missing dialogue_id.")
		return

	var trigger := Area2D.new()
	trigger.name = _event_node_name(event, "JsonDialogueTrigger")
	trigger.set_script(DIALOGUE_TRIGGER_SCRIPT)
	trigger.dialogue_id = dialogue_id
	trigger.dialogue_ids = dialogue_ids
	trigger.trigger_once = bool(event.get("trigger_once", true))
	trigger.flag_name = str(event.get("flag_name", "")).strip_edges()
	trigger.position = _event_position(event)
	_add_collision_shape(trigger, _event_radius(event))
	event_root.add_child(trigger)

static func _spawn_scene_exit_event(event: Dictionary, event_root: Node) -> void:
	var target_scene := str(event.get("target_scene", "")).strip_edges()
	if target_scene == "":
		push_warning("Scene exit map event missing target_scene.")
		return

	var trigger := Area2D.new()
	trigger.name = _event_node_name(event, "JsonSceneExitTrigger")
	trigger.set_script(SCENE_EXIT_TRIGGER_SCRIPT)
	trigger.target_scene = target_scene
	trigger.location_title = str(event.get("location_title", "")).strip_edges()
	if event.has("spawn_point_name"):
		trigger.spawn_point_name = str(event.get("spawn_point_name", "")).strip_edges()
	trigger.position = _event_position(event)
	_add_collision_shape(trigger, _event_radius(event))
	event_root.add_child(trigger)

static func _add_collision_shape(trigger: Area2D, radius: float) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	trigger.add_child(collision)

static func _event_position(event: Dictionary) -> Vector2:
	var position_data = event.get("position", [0, 0])
	if typeof(position_data) != TYPE_ARRAY or position_data.size() < 2:
		push_warning("Map event position must be [x, y].")
		return Vector2.ZERO

	return Vector2(float(position_data[0]), float(position_data[1]))

static func _event_radius(event: Dictionary) -> float:
	var radius := float(event.get("radius", 80.0))
	if radius <= 0.0:
		push_warning("Map event radius must be greater than 0.")
		return 80.0

	return radius

static func _event_dialogue_ids(event: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var id_data = event.get("dialogue_ids", [])
	if typeof(id_data) != TYPE_ARRAY:
		return ids

	for id in id_data:
		var clean_id := str(id).strip_edges()
		if clean_id != "":
			ids.append(clean_id)

	return ids

static func _has_existing_equivalent(event: Dictionary, event_root: Node) -> bool:
	var event_type := str(event.get("type", "")).strip_edges()

	for child in event_root.get_children():
		if not child is Area2D:
			continue

		var script: Resource = child.get_script()
		if not script:
			continue

		var script_path := script.resource_path
		if event_type == "dialogue":
			if script_path == DIALOGUE_TRIGGER_SCRIPT_PATH:
				if str(child.get("dialogue_id")) == str(event.get("dialogue_id", "")):
					return true
		elif event_type == "scene_exit":
			if script_path == SCENE_EXIT_TRIGGER_SCRIPT_PATH:
				if str(child.get("target_scene")) == str(event.get("target_scene", "")):
					return true

	return false

static func _event_node_name(event: Dictionary, fallback: String) -> String:
	var event_id := str(event.get("id", "")).strip_edges()
	if event_id == "":
		return fallback

	var words := event_id.split("_", false)
	var node_name := "Json"
	for word in words:
		if word.is_empty():
			continue
		node_name += word.substr(0, 1).to_upper() + word.substr(1)

	return node_name + "Trigger"
