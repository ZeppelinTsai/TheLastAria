extends Area2D

@export var dialogue_id: String
@export var trigger_once: bool = true
@export var flag_name: String = ""

var _has_triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else null
	if player and _is_player_inside_trigger(player):
		_try_trigger(player)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	_try_trigger(body)

func _try_trigger(body: Node2D) -> void:
	if trigger_once and _has_triggered:
		return

	if trigger_once and flag_name != "" and SaveManager.has_flag(flag_name):
		return

	var scene_root = get_tree().current_scene
	if not scene_root or not scene_root.has_method("start_dialog"):
		push_warning("EventTrigger could not find start_dialog on the current scene root.")
		return

	print("EventTrigger started dialogue: %s" % dialogue_id)
	scene_root.start_dialog(dialogue_id)
	_has_triggered = true

	if flag_name != "":
		SaveManager.set_flag(flag_name)

func _is_player_inside_trigger(player: Node) -> bool:
	for point in _get_player_trigger_points(player):
		if _contains_global_point(point):
			return true

	return false

func _get_player_trigger_points(player: Node) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if player is Node2D:
		points.append(player.global_position)
	if player.has_method("get_walkable_sample_points"):
		points.append_array(player.get_walkable_sample_points())
	elif player.has_method("get_walkable_check_position"):
		points.append(player.get_walkable_check_position())

	return points

func _contains_global_point(point: Vector2) -> bool:
	for child in get_children():
		if child is CollisionShape2D and child.shape:
			if _shape_contains_global_point(child, point):
				return true

	return false

func _shape_contains_global_point(collision: CollisionShape2D, point: Vector2) -> bool:
	var shape := collision.shape
	var local_point := collision.to_local(point)

	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return local_point.length() <= circle.radius
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size: Vector2 = rectangle.size * 0.5
		return abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_height: float = capsule.height * 0.5
		var clamped_y: float = clamp(local_point.y, -half_height, half_height)
		return Vector2(local_point.x, local_point.y - clamped_y).length() <= capsule.radius

	return false
