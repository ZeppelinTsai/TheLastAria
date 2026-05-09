extends CharacterBody2D

const SPEED = 200.0
var can_move = true
@onready var anim = $AnimatedSprite2D

func _physics_process(delta):
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1

	velocity = direction * SPEED
	move_and_slide()

	if direction == Vector2.ZERO:
		anim.stop()
	elif direction.x < 0:
		anim.play("walk_left")
	elif direction.x > 0:
		anim.play("walk_right")
	elif direction.y < 0:
		anim.play("walk_up")
	elif direction.y > 0:
		anim.play("walk_down")
