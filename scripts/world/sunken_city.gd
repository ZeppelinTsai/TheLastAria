extends "res://scripts/world/world_base.gd"

@export var map_data_path := "res://data/maps/sunken_city.json"
@export var swim_depth_enabled := true
@export var swim_depth_near_y := 500.0
@export var swim_depth_far_y := -500.0
@export var swim_depth_background_offset := Vector2(0.0, 42.0)
@export var swim_depth_background_scale := Vector2(1.035, 1.035)
@export var swim_depth_player_far_scale := 0.3
@export var swim_depth_lerp_speed := 4.0

var map_data: Dictionary = {}
var music_context := "overworld"
var swim_depth_background: Node2D
var swim_depth_background_base_position := Vector2.ZERO
var swim_depth_background_base_scale := Vector2.ONE
var swim_depth_player_sprite: Node2D
var swim_depth_player_sprite_base_scale := Vector2.ONE

func on_world_ready() -> void:
	map_data = MapDataLoader.load_map_data(map_data_path)
	_apply_map_data(map_data)
	WalkableAreaSpawner.spawn_walkable_area(self, map_data)
	EventSpawner.spawn_events(map_data, get_node_or_null("EventRoot"))
	setup_swim_depth_effect()
	MusicManager.play_context(music_context)

func on_world_physics_process(delta: float) -> void:
	update_swim_depth_effect(delta)

func _apply_map_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	apply_background_from_map_data(data)

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

func setup_swim_depth_effect() -> void:
	swim_depth_background = get_node_or_null("Background") as Node2D
	if swim_depth_background:
		swim_depth_background_base_position = swim_depth_background.position
		swim_depth_background_base_scale = swim_depth_background.scale

	swim_depth_player_sprite = null
	if player:
		swim_depth_player_sprite = player.get_node_or_null("AnimatedSprite2D") as Node2D
	if swim_depth_player_sprite:
		swim_depth_player_sprite_base_scale = swim_depth_player_sprite.scale

func update_swim_depth_effect(delta: float) -> void:
	if not swim_depth_enabled or not player:
		return

	var depth_amount := get_swim_depth_amount()
	var lerp_weight := clampf(swim_depth_lerp_speed * delta, 0.0, 1.0)

	if swim_depth_background:
		var target_position := swim_depth_background_base_position + swim_depth_background_offset * depth_amount
		var target_scale := swim_depth_background_base_scale.lerp(swim_depth_background_base_scale * swim_depth_background_scale, depth_amount)
		swim_depth_background.position = swim_depth_background.position.lerp(target_position, lerp_weight)
		swim_depth_background.scale = swim_depth_background.scale.lerp(target_scale, lerp_weight)

	if swim_depth_player_sprite:
		var target_player_scale := swim_depth_player_sprite_base_scale * lerpf(1.0, swim_depth_player_far_scale, depth_amount)
		swim_depth_player_sprite.scale = swim_depth_player_sprite.scale.lerp(target_player_scale, lerp_weight)
	
	if player:
		var target_speed = lerpf(150.0, 200.0, depth_amount)
		player.speed = target_speed

func get_swim_depth_amount() -> float:
	var y_span := swim_depth_far_y - swim_depth_near_y
	if is_zero_approx(y_span):
		return 0.0
	return clampf((player.global_position.y - swim_depth_near_y) / y_span, 0.0, 1.0)
