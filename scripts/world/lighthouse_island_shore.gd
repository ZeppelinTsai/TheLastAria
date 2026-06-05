extends "res://scripts/world/lighthouse_island.gd"

@export var shore_lumi_spawn_offset := Vector2(-19, 74)

func on_world_ready() -> void:
	super.on_world_ready()
	init_lumi_follow()
	_place_lumi_near_player()
	_hide_underwater_effects()

func _place_lumi_near_player() -> void:
	if not lumi or not player:
		return

	lumi.global_position = player.global_position + shore_lumi_spawn_offset * get_lumi_follow_scale_factor()

func _hide_underwater_effects() -> void:
	for node_path in [
		"UI/WaterDistortion",
		"UI/UnderwaterFG",
		"UI/LightRays",
		"Player/BubbleParticles"
	]:
		var effect := get_node_or_null(node_path)
		if effect:
			effect.visible = false
			if effect.has_method("set_emitting"):
				effect.set("emitting", false)
