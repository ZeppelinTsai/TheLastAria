extends CharacterBody2D

const SPEED = 200.0
var can_move = true
@onready var anim = $AnimatedSprite2D
var current_anim = ""

func _physics_process(delta):
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		if current_anim != "":
			anim.stop()
			current_anim = ""
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
