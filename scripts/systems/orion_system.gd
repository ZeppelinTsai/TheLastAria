extends Node
class_name OrionSystem

const ORION_GLOW_BASE_SCALE := Vector2(1.0, 1.0)
const ORION_GLOW_PEAK_SCALE := Vector2(1.22, 1.22)
const ORION_GLOW_DIM_ALPHA := 0.62
const ORION_GLOW_PEAK_ALPHA := 1.0

var host: Node
var player: Node
var orion_glow: Node2D
var orion_light: Light2D
var choice_layer: CanvasLayer
var choice_default_button: Button

func init(owner_node: Node) -> void:
	host = owner_node
	player = host.get_node_or_null("Player")
	orion_glow = host.get_node_or_null("OrionTrigger/GlowSprite") as Node2D
	orion_light = host.get_node_or_null("OrionTrigger/PointLight2D") as Light2D

func pulse_orion_light() -> void:
	if not orion_light or not orion_glow:
		return
	orion_light.energy = 2.0
	orion_glow.scale = ORION_GLOW_BASE_SCALE
	orion_glow.modulate.a = ORION_GLOW_DIM_ALPHA

	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(orion_light, "energy", 3.4, 0.9)
	tween.parallel().tween_property(orion_glow, "scale", ORION_GLOW_PEAK_SCALE, 0.9)
	tween.parallel().tween_property(orion_glow, "modulate:a", ORION_GLOW_PEAK_ALPHA, 0.9)
	tween.tween_property(orion_light, "energy", 1.35, 0.9)
	tween.parallel().tween_property(orion_glow, "scale", ORION_GLOW_BASE_SCALE, 0.9)
	tween.parallel().tween_property(orion_glow, "modulate:a", ORION_GLOW_DIM_ALPHA, 0.9)

func on_orion_trigger_entered(body: Node) -> void:
	if body.name != "Player":
		return
	if not host or bool(host.get("dialog_active")):
		return
	if SaveManager.has_flag("orion_discovered"):
		return

	MusicManager.play_context("mystery")
	if host.has_method("start_dialog"):
		host.start_dialog("orion_first_seen")

func show_orion_choice(layer: CanvasLayer, default_button: Button) -> void:
	choice_layer = layer
	choice_default_button = default_button
	if player:
		player.set("can_move", false)
	if choice_layer:
		choice_layer.visible = true
	if choice_default_button:
		choice_default_button.grab_focus()

func on_orion_choice_selected(_choice_id: String) -> void:
	if choice_layer:
		choice_layer.visible = false
	if host and host.has_method("start_dialog"):
		host.start_dialog("orion_rescue")

func on_dungeon_area_entered(body: Node) -> void:
	if body.name != "Player":
		return
	SaveManager.set_flag("entered_dungeon_area")
	MusicManager.play_context("dungeon")
	if host:
		host.set("lumi_follow_enabled", true)

func on_dungeon_area_exited(body: Node) -> void:
	if body.name != "Player":
		return
	MusicManager.play_context("overworld")
	if host:
		host.set("lumi_follow_enabled", false)
