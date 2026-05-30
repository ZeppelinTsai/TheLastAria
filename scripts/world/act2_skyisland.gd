extends "res://scripts/world/world_base.gd"

func on_world_ready() -> void:
	MusicManager.play_context("overworld")

func _on_lumi_event_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	print("Lumi event entered.")
	if dialogue_sets.has("lumi_event"):
		start_dialog("lumi_event")

func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	print("Boss trigger entered.")
	if dialogue_sets.has("boss_intro"):
		start_dialog("boss_intro")

func _on_exit_portal_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	print("Exit portal entered.")
	if dialogue_sets.has("exit_portal"):
		start_dialog("exit_portal")
