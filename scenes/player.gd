extends CharacterBody2D

const SPEED = 200.0
const ARRIVE_DISTANCE = 6.0

@export var walkable_area: Area2D

var can_move = true
var current_anim = ""
var auto_move = false
var target_position: Vector2

@onready var anim = $AnimatedSprite2D

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

	velocity = direction * SPEED
	move_and_slide()

	if walkable_area and not is_inside_walkable_area(global_position):
		global_position = before_move
		velocity = Vector2.ZERO
		auto_move = false

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


func get_nearest_walkable_point(point: Vector2) -> Vector2:
	if is_inside_walkable_area(point):
		return point

	var best_point = global_position
	var best_distance = INF

	for polygon_node in walkable_area.get_children():
		if polygon_node is CollisionPolygon2D:
			var points = polygon_node.polygon

			for i in range(points.size()):
				var a = walkable_area.to_global(points[i])
				var b = walkable_area.to_global(points[(i + 1) % points.size()])
				var candidate = get_closest_point_on_segment(point, a, b)
				var distance = point.distance_to(candidate)

				if distance < best_distance:
					best_distance = distance
					best_point = candidate

	return best_point


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
