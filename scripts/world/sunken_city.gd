extends "res://scripts/world/world_base.gd"

@export var map_data_path := "res://data/maps/sunken_city.json"
@export var swim_depth_enabled := true
@export var swim_depth_near_y := 500.0
@export var swim_depth_far_y := -500.0
@export var swim_depth_background_offset := Vector2(0.0, 42.0)
@export var swim_depth_background_scale := Vector2(1.035, 1.035)
@export var swim_depth_player_far_scale := 0.3
@export var swim_depth_lerp_speed := 4.0

const LYRA_ROOM_TRANSITION_META := "from_lyra_room_to_sunken_city"
const LYRA_ROOM_ENTRY_DIALOGUE_ID := "lyra_room_entry_surface_hint"
const ORION_FOUND_DIALOGUE_ID := "orion_found_on_surface"
const SUNKEN_CITY_CENTER_POSITION := Vector2(0, 0)
const SURFACE_HINT_POSITION := Vector2(610, -500)
const SURFACE_HINT_RADIUS := 68.0
const SURFACE_HINT_FLAG := "sunken_city_surface_hint_found"
const ORION_PRELUDE_IMAGE_PATH := "res://img/prelude/9.png"
const ORION_CG_MUSIC_CONTEXT := "orion_cg"
const LIGHTHOUSE_SHORE_SCENE_PATH := "res://scenes/world/lighthouse_island_shore.tscn"

var map_data: Dictionary = {}
var music_context := "overworld"
var swim_depth_background: Node2D
var swim_depth_background_base_position := Vector2.ZERO
var swim_depth_background_base_scale := Vector2.ONE
var swim_depth_player_sprite: Node2D
var swim_depth_player_sprite_base_scale := Vector2.ONE
var swim_depth_breathe_t := 0.0
var swim_depth_breathe_speed := 0.22
var swim_depth_breathe_amplitude := 10.0

@export var swim_depth_lumi_follow_offset_near := Vector2(28, -12)
@export var swim_depth_lumi_follow_offset_far := Vector2(8, -4)

@export var swim_depth_lumi_drift_far_factor := 0.03

@export var swim_depth_lumi_far_scale := 0.3

var swim_depth_lumi_sprite: Node2D
var swim_depth_lumi_sprite_base_scale := Vector2.ONE
var surface_hint_area: Area2D
var surface_hint_ring_outer: Line2D
var surface_hint_ring_inner: Line2D
var surface_hint_t := 0.0
var orion_image_container: Control
var orion_image_rect: TextureRect
var orion_event_active := false

func on_world_ready() -> void:
	map_data = MapDataLoader.load_map_data(map_data_path)
	_apply_map_data(map_data)
	WalkableAreaSpawner.spawn_walkable_area(self, map_data)
	EventSpawner.spawn_events(map_data, get_node_or_null("EventRoot"))

	init_lumi_follow()
	setup_swim_depth_effect()

	MusicManager.play_context(music_context)

	var uw := get_node_or_null("UI/UnderwaterFG")
	if uw and uw.material:
		uw.material.set_shader_parameter("time_scale", 1.0)

	if _consume_lyra_room_transition_meta():
		call_deferred("_start_lyra_room_entry_sequence")

func on_world_physics_process(delta: float) -> void:
	swim_depth_breathe_t += delta
	update_swim_depth_effect(delta)
	update_underwater_fx()
	update_lumi_depth_follow(delta)
	update_surface_hint(delta)

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

func _consume_lyra_room_transition_meta() -> bool:
	if not SceneTransition.has_meta(LYRA_ROOM_TRANSITION_META):
		return false

	SceneTransition.remove_meta(LYRA_ROOM_TRANSITION_META)
	return true

func _start_lyra_room_entry_sequence() -> void:
	_place_player_at_sunken_city_center()
	set_player_can_move(false)
	await get_tree().process_frame
	if dialogue_sets.has(LYRA_ROOM_ENTRY_DIALOGUE_ID):
		start_dialog(LYRA_ROOM_ENTRY_DIALOGUE_ID)
	else:
		push_warning("Dialogue id not found: %s" % LYRA_ROOM_ENTRY_DIALOGUE_ID)
		_show_surface_hint()

func _place_player_at_sunken_city_center() -> void:
	if not player:
		return

	player.global_position = SUNKEN_CITY_CENTER_POSITION
	player.set("target_position", SUNKEN_CITY_CENTER_POSITION)
	player.set("auto_move", false)
	if player.has_method("pull_inside_walkable_area"):
		player.pull_inside_walkable_area()
	if lumi:
		lumi.global_position = SUNKEN_CITY_CENTER_POSITION + swim_depth_lumi_follow_offset_near
	SaveManager.set_player_position(player.global_position)

func _show_surface_hint() -> void:
	if SaveManager.has_flag(SURFACE_HINT_FLAG):
		return
	if surface_hint_area and is_instance_valid(surface_hint_area):
		surface_hint_area.visible = true
		return

	var event_root := get_node_or_null("EventRoot")
	if not event_root:
		push_warning("Sunken City needs EventRoot for the surface hint.")
		return

	surface_hint_area = Area2D.new()
	surface_hint_area.name = "SurfaceHintTrigger"
	surface_hint_area.position = SURFACE_HINT_POSITION
	surface_hint_area.body_entered.connect(_on_surface_hint_body_entered)
	event_root.add_child(surface_hint_area)

	var shape := CircleShape2D.new()
	shape.radius = SURFACE_HINT_RADIUS
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	surface_hint_area.add_child(collision)

	surface_hint_ring_outer = _create_surface_hint_ring(SURFACE_HINT_RADIUS, 5.0, Color(0.28, 1.0, 0.45, 0.82))
	surface_hint_ring_inner = _create_surface_hint_ring(SURFACE_HINT_RADIUS * 0.62, 3.0, Color(0.70, 1.0, 0.76, 0.58))
	surface_hint_area.add_child(surface_hint_ring_outer)
	surface_hint_area.add_child(surface_hint_ring_inner)

func _create_surface_hint_ring(radius: float, width: float, color: Color) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.closed = true
	ring.z_index = 120
	for index in range(48):
		var angle := TAU * float(index) / 48.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	return ring

func update_surface_hint(delta: float) -> void:
	if not surface_hint_area or not surface_hint_area.visible:
		return

	surface_hint_t += delta
	var pulse := 1.0 + sin(surface_hint_t * 3.2) * 0.08
	surface_hint_area.scale = Vector2(pulse, pulse)
	if surface_hint_ring_outer:
		surface_hint_ring_outer.modulate.a = 0.72 + sin(surface_hint_t * 4.1) * 0.18

func _on_surface_hint_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	_trigger_orion_found_event()

func _trigger_orion_found_event() -> void:
	if orion_event_active or SaveManager.has_flag(SURFACE_HINT_FLAG):
		return

	orion_event_active = true
	SaveManager.set_flag(SURFACE_HINT_FLAG)
	if surface_hint_area:
		surface_hint_area.visible = false
	show_orion_prelude_image()
	if dialogue_sets.has(ORION_FOUND_DIALOGUE_ID):
		start_dialog(ORION_FOUND_DIALOGUE_ID)
	else:
		push_warning("Dialogue id not found: %s" % ORION_FOUND_DIALOGUE_ID)
		_transition_to_lighthouse()

func show_orion_prelude_image() -> void:
	MusicManager.play_context(ORION_CG_MUSIC_CONTEXT, 0.8)

	if not orion_image_container:
		var ui_layer := get_node_or_null("UI")
		if not ui_layer:
			push_warning("Sunken City needs UI for Orion prelude image.")
			return

		orion_image_container = Control.new()
		orion_image_container.name = "OrionPreludeImageContainer"
		orion_image_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		orion_image_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orion_image_container.z_index = EFFECTS_LAYER_Z_INDEX + 20
		ui_layer.add_child(orion_image_container)

		orion_image_rect = TextureRect.new()
		orion_image_rect.name = "OrionPreludeImage"
		orion_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		orion_image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		orion_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		orion_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orion_image_container.add_child(orion_image_rect)

	var texture := load(ORION_PRELUDE_IMAGE_PATH) as Texture2D
	if texture:
		orion_image_rect.texture = texture
	else:
		push_warning("Could not load Orion prelude image: %s" % ORION_PRELUDE_IMAGE_PATH)
	orion_image_container.visible = true

func hide_orion_prelude_image() -> void:
	if orion_image_container:
		orion_image_container.visible = false

func on_dialog_finished(dialogue_id: String) -> void:
	if dialogue_id == LYRA_ROOM_ENTRY_DIALOGUE_ID:
		_show_surface_hint()
	elif dialogue_id == ORION_FOUND_DIALOGUE_ID:
		call_deferred("_transition_to_lighthouse")

func _transition_to_lighthouse() -> void:
	set_player_can_move(false)
	hide_orion_prelude_image()
	await SceneTransition.fade_to_black(0.8)
	await get_tree().create_timer(1.2).timeout
	await SceneTransition.go(LIGHTHOUSE_SHORE_SCENE_PATH, "燈塔島岸邊")

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

	swim_depth_lumi_sprite = null
	if lumi:
		swim_depth_lumi_sprite = lumi.get_node_or_null("AnimatedSprite2D") as Node2D
	if swim_depth_lumi_sprite:
		swim_depth_lumi_sprite_base_scale = swim_depth_lumi_sprite.scale

func update_swim_depth_effect(delta: float) -> void:
	if not swim_depth_enabled or not player:
		return

	var depth_amount: float = get_swim_depth_amount()
	var lerp_weight: float = clamp(swim_depth_lerp_speed * delta, 0.0, 1.0)

	if swim_depth_background:
		var breathe_offset: float = sin(swim_depth_breathe_t * swim_depth_breathe_speed) * swim_depth_breathe_amplitude
		var target_position: Vector2 = swim_depth_background_base_position + swim_depth_background_offset * depth_amount + Vector2(0, breathe_offset)
		var target_scale: Vector2 = swim_depth_background_base_scale.lerp(swim_depth_background_base_scale * swim_depth_background_scale, depth_amount)
		swim_depth_background.position = swim_depth_background.position.lerp(target_position, lerp_weight)
		swim_depth_background.scale = swim_depth_background.scale.lerp(target_scale, lerp_weight)

	if swim_depth_player_sprite:
		var target_player_scale: Vector2 = swim_depth_player_sprite_base_scale * lerp(1.0, swim_depth_player_far_scale, depth_amount)
		swim_depth_player_sprite.scale = swim_depth_player_sprite.scale.lerp(target_player_scale, lerp_weight)

	if player:
		var target_speed: float = lerp(150.0, 200.0, depth_amount)
		player.speed = target_speed

	if swim_depth_lumi_sprite:
		var target_lumi_scale: Vector2 = swim_depth_lumi_sprite_base_scale * lerp(1.0, swim_depth_lumi_far_scale, depth_amount)
		swim_depth_lumi_sprite.scale = swim_depth_lumi_sprite.scale.lerp(target_lumi_scale, lerp_weight)

func update_underwater_fx() -> void:
	var uw: Node = get_node_or_null("UI/UnderwaterFG")
	if uw and uw.material and player:
		uw.material.set_shader_parameter("time_scale", 0.8 + abs(player.velocity.y) * 0.001)

	var lr: Node = get_node_or_null("UI/LightRays")
	if lr and lr.material and player:
		var depth_val: float = clamp(-player.global_position.y / 3000.0, 0.0, 1.0)
		lr.material.set_shader_parameter("depth", depth_val)

func get_swim_depth_amount() -> float:
	var y_span := swim_depth_far_y - swim_depth_near_y
	if is_zero_approx(y_span):
		return 0.0
	return clamp((player.global_position.y - swim_depth_near_y) / y_span, 0.0, 1.0)


func update_lumi_depth_follow(delta: float) -> void:
	if not lumi_follow_enabled or not lumi or not player:
		return

	var depth_amount: float = get_swim_depth_amount()
	lumi_follow_time += delta

	var visual_scale: float = lerp(1.0, swim_depth_lumi_far_scale, depth_amount)
	var drift_factor: float = lerp(1.0, swim_depth_lumi_drift_far_factor, depth_amount)

	var drift: Vector2 = Vector2(
		sin(lumi_follow_time * LUMI_FOLLOW_DRIFT_SPEED),
		cos(lumi_follow_time * LUMI_FOLLOW_DRIFT_SPEED * 0.8)
	) * LUMI_FOLLOW_DRIFT_DISTANCE * drift_factor

	var scaled_offset: Vector2 = swim_depth_lumi_follow_offset_near.lerp(
		swim_depth_lumi_follow_offset_far,
		depth_amount
	)

	var follow_origin: Vector2 = player.global_position
	if swim_depth_player_sprite:
		follow_origin = swim_depth_player_sprite.global_position

	var target: Vector2 = follow_origin + scaled_offset + drift
	var distance: float = lumi.global_position.distance_to(target)

	var snap_distance: float = lerp(90.0, 28.0, depth_amount)
	var follow_lerp: float = clamp(10.0 * delta, 0.0, 1.0)

	if distance > snap_distance:
		lumi.global_position = target
		lumi.velocity = Vector2.ZERO
	else:
		var old_position: Vector2 = lumi.global_position
		lumi.global_position = lumi.global_position.lerp(target, follow_lerp)
		lumi.velocity = (lumi.global_position - old_position) / maxf(delta, 0.0001)

	_update_lumi_animation(lumi.velocity, delta)
