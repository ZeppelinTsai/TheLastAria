extends CharacterBody2D

var speed = 200.0
const ARRIVE_DISTANCE = 6.0
const WALKABLE_INSET_DISTANCE = 8.0

@export var walkable_area: Area2D

var can_move = true
var current_anim = ""
var auto_move = false
var target_position: Vector2

@onready var anim = $AnimatedSprite2D
@onready var foot_point: Node2D = get_node_or_null("FootPoint")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready() -> void:
	call_deferred("pull_inside_walkable_area")

func _input(event):
	if not can_move:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked = get_global_mouse_position()
			target_position = get_nearest_walkable_point(clicked)
			auto_move = true


func _physics_process(delta):
	if not can_move:
		stop_player()
		return

	var direction = get_keyboard_direction()

	if direction != Vector2.ZERO:
		auto_move = false
	else:
		direction = get_auto_move_direction()

	var before_move = global_position

	velocity = direction * speed
	move_and_slide()

	if walkable_area:
		if not is_walkable_body_inside_area():
			global_position = before_move
			velocity = Vector2.ZERO
			auto_move = false
			pull_inside_walkable_area()

	update_animation(direction)



func get_keyboard_direction() -> Vector2:
	var direction = Vector2.ZERO

	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1

	return direction.normalized()


func get_auto_move_direction() -> Vector2:
	if not auto_move:
		return Vector2.ZERO

	var to_target = target_position - global_position

	if to_target.length() <= ARRIVE_DISTANCE:
		auto_move = false
		return Vector2.ZERO

	return to_target.normalized()


func is_inside_walkable_area(point: Vector2) -> bool:
	if not walkable_area:
		return true

	var space_state = get_world_2d().direct_space_state

	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results = space_state.intersect_point(query)

	for result in results:
		if result.collider == walkable_area:
			return true

	return false


func get_walkable_check_position() -> Vector2:
	if collision_shape and collision_shape.shape:
		return collision_shape.to_global(_get_collision_shape_bottom_point())

	if foot_point:
		return foot_point.global_position

	return global_position


func _get_collision_shape_bottom_point() -> Vector2:
	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		return Vector2(0.0, rectangle.size.y * 0.5)
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return Vector2(0.0, circle.radius)
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return Vector2(0.0, capsule.height * 0.5)

	return Vector2.ZERO


func is_walkable_body_inside_area() -> bool:
	if not walkable_area:
		return true

	for point in get_walkable_sample_points():
		if not is_inside_walkable_area(point):
			return false

	return true


func get_walkable_sample_points() -> Array[Vector2]:
	if collision_shape and collision_shape.shape:
		return _get_collision_shape_sample_points()

	if foot_point:
		return [foot_point.global_position]

	return [global_position]


func _get_collision_shape_sample_points() -> Array[Vector2]:
	var shape := collision_shape.shape
	var local_points: Array[Vector2] = []

	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size: Vector2 = rectangle.size * 0.5
		local_points = [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
			Vector2(0.0, -half_size.y),
			Vector2(half_size.x, 0.0),
			Vector2(0.0, half_size.y),
			Vector2(-half_size.x, 0.0),
			Vector2.ZERO
		]
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var radius: float = circle.radius
		local_points = [Vector2.ZERO]
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			local_points.append(Vector2(cos(angle), sin(angle)) * radius)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_width: float = capsule.radius
		var half_height: float = capsule.height * 0.5
		local_points = [
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height),
			Vector2(0.0, -half_height),
			Vector2(0.0, half_height),
			Vector2.ZERO
		]
	else:
		local_points = [_get_collision_shape_bottom_point()]

	var global_points: Array[Vector2] = []
	for point in local_points:
		global_points.append(collision_shape.to_global(point))

	return global_points


func get_nearest_walkable_point(point: Vector2) -> Vector2:
	return _get_nearest_walkable_point(point, 0.0)


func pull_inside_walkable_area() -> void:
	if not walkable_area:
		return

	if is_walkable_body_inside_area():
		return

	for _attempt in range(4):
		var correction := _get_walkable_body_correction()
		if correction == Vector2.ZERO:
			break

		global_position += correction
		if is_walkable_body_inside_area():
			break

	target_position = global_position
	auto_move = false


func _get_walkable_body_correction() -> Vector2:
	var total_correction := Vector2.ZERO
	var correction_count := 0

	for point in get_walkable_sample_points():
		if is_inside_walkable_area(point):
			continue

		total_correction += _get_nearest_walkable_point(point, WALKABLE_INSET_DISTANCE) - point
		correction_count += 1

	if correction_count == 0:
		return Vector2.ZERO

	return total_correction / float(correction_count)


func _get_nearest_walkable_point(point: Vector2, inset_distance: float) -> Vector2:
	if is_inside_walkable_area(point):
		return point

	var best_point = global_position
	var best_distance = INF

	for polygon_node in walkable_area.get_children():
		if polygon_node is CollisionPolygon2D:
			var points = polygon_node.polygon
			if points.size() < 3:
				continue

			var polygon_center := _get_polygon_global_center(points)

			for i in range(points.size()):
				var a = walkable_area.to_global(points[i])
				var b = walkable_area.to_global(points[(i + 1) % points.size()])
				var candidate = get_closest_point_on_segment(point, a, b)
				if inset_distance > 0.0:
					candidate = candidate.move_toward(polygon_center, inset_distance)

				var distance = point.distance_to(candidate)

				if distance < best_distance:
					best_distance = distance
					best_point = candidate

	return best_point


func _get_polygon_global_center(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += walkable_area.to_global(point)

	return total / float(points.size())


func get_closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab = b - a
	var t = (point - a).dot(ab) / ab.length_squared()
	t = clamp(t, 0.0, 1.0)
	return a + ab * t


func stop_player():
	velocity = Vector2.ZERO
	move_and_slide()
	auto_move = false

	if current_anim != "":
		anim.stop()
		current_anim = ""


func update_animation(direction: Vector2) -> void:
	var next_anim = ""

	if direction.x < 0:
		next_anim = "walk_left"
	elif direction.x > 0:
		next_anim = "walk_right"
	elif direction.y < 0:
		next_anim = "walk_up"
	elif direction.y > 0:
		next_anim = "walk_down"

	if next_anim == "":
		if current_anim != "":
			anim.stop()
			current_anim = ""
	elif current_anim != next_anim:
		anim.play(next_anim)
		current_anim = next_anim
