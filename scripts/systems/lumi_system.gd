extends Node
class_name LumiSystem

const LUMI_FOLLOW_OFFSET := Vector2(-42, -34)
const LUMI_FOLLOW_SPEED := 165.0
const LUMI_FOLLOW_STOP_DISTANCE := 18.0
const LUMI_FOLLOW_DRIFT_DISTANCE := 7.0
const LUMI_FOLLOW_DRIFT_SPEED := 2.2

var owner: Node
var player: Node2D
var lumi: CharacterBody2D
var follow_enabled := false
var follow_time := 0.0

func init(owner_node: Node) -> void:
	owner = owner_node
	player = owner.get_node_or_null("Player") as Node2D
	lumi = owner.get_node_or_null("Lumi") as CharacterBody2D
	follow_enabled = bool(owner.get("lumi_follow_enabled")) if owner else false

func physics_process(delta: float) -> void:
	update_follow(delta)

func set_target(target: Node) -> void:
	player = target as Node2D

func set_follow_enabled(value: bool) -> void:
	follow_enabled = value
	if owner:
		owner.set("lumi_follow_enabled", value)

func update_follow(delta: float) -> void:
	if owner:
		follow_enabled = bool(owner.get("lumi_follow_enabled"))
	if not follow_enabled or not lumi or not player:
		return

	var previous_position: Vector2 = lumi.global_position
	follow_time += delta
	var drift := Vector2(
		sin(follow_time * LUMI_FOLLOW_DRIFT_SPEED),
		cos(follow_time * LUMI_FOLLOW_DRIFT_SPEED * 0.8)
	) * LUMI_FOLLOW_DRIFT_DISTANCE
	var target_position: Vector2 = player.global_position + LUMI_FOLLOW_OFFSET + drift
	var distance: float = lumi.global_position.distance_to(target_position)

	if distance <= LUMI_FOLLOW_STOP_DISTANCE:
		lumi.velocity = Vector2.ZERO
		lumi.move_and_slide()
		return

	var direction: Vector2 = lumi.global_position.direction_to(target_position)
	lumi.velocity = direction * LUMI_FOLLOW_SPEED
	lumi.move_and_slide()

	var movement: Vector2 = lumi.global_position - previous_position
	update_animation(movement, delta)

func play_idle() -> void:
	if not lumi:
		return
	for lumi_sprite in lumi.find_children("*", "AnimatedSprite2D", true, false):
		if not lumi_sprite or not lumi_sprite.sprite_frames:
			continue

		var idle_animation: StringName = lumi_sprite.animation
		if not lumi_sprite.sprite_frames.has_animation(idle_animation):
			if lumi_sprite.sprite_frames.has_animation("idle_down"):
				idle_animation = &"idle_down"
			elif lumi_sprite.sprite_frames.has_animation("default"):
				idle_animation = &"default"
			else:
				continue

		lumi_sprite.play(idle_animation)

func update_animation(movement: Vector2, delta: float) -> void:
	if not lumi or movement == Vector2.ZERO:
		play_idle()
		return

	var speed: float = movement.length() / maxf(delta, 0.0001)
	if speed < 8.0:
		play_idle()
		return

	var dx: float = movement.x
	var dy: float = movement.y
	var anim := "walk_down"
	if abs(dx) > abs(dy):
		if dx > 0.0:
			anim = "walk_right"
		else:
			anim = "walk_left"
	else:
		if dy < 0.0:
			anim = "walk_up"
		else:
			anim = "walk_down"

	for lumi_sprite in lumi.find_children("*", "AnimatedSprite2D", true, false):
		if not lumi_sprite or not lumi_sprite.sprite_frames:
			continue
		if lumi_sprite.sprite_frames.has_animation(anim):
			lumi_sprite.play(anim)
		else:
			play_idle()

func ensure_spriteframes() -> void:
	if not lumi:
		return
	var sprite_node := lumi.get_node_or_null("AnimatedSprite2D")
	if not sprite_node:
		return
	var sf: SpriteFrames = sprite_node.sprite_frames
	var need_build := false
	if not sf or not (sf is SpriteFrames):
		need_build = true
	else:
		for name in ["walk_up", "walk_down", "walk_left", "walk_right", "idle_down"]:
			if not sf.has_animation(name):
				need_build = true
				break

	if not need_build:
		return

	var new_sf := SpriteFrames.new()
	var up: Array[Texture2D] = _load_lumi_frames([2, 3, 4])
	var down: Array[Texture2D] = _load_lumi_frames([5, 6, 7])
	var right: Array[Texture2D] = _load_lumi_frames([8, 9, 10])
	var left: Array[Texture2D] = _load_lumi_frames([11, 12, 13])

	_add_animation(new_sf, "idle_down", down, 5.0)
	_add_animation(new_sf, "walk_down", down, 8.0)
	_add_animation(new_sf, "walk_up", up, 8.0)
	_add_animation(new_sf, "walk_right", right, 8.0)
	_add_animation(new_sf, "walk_left", left, 8.0)

	sprite_node.sprite_frames = new_sf
	if new_sf.has_animation("idle_down"):
		sprite_node.animation = "idle_down"

func _load_lumi_frames(indices: Array[int]) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for index in indices:
		var path := "res://img/sprite/lumi/default/Layer %d.png" % index
		var texture := load(path) as Texture2D
		if texture:
			frames.append(texture)
	return frames

func _add_animation(sprite_frames: SpriteFrames, name: String, frames: Array[Texture2D], speed: float) -> void:
	if frames.is_empty():
		return
	sprite_frames.add_animation(name)
	for texture in frames:
		sprite_frames.add_frame(name, texture)
	sprite_frames.set_animation_speed(name, speed)
	sprite_frames.set_animation_loop(name, true)

