extends Area2D

@export var dialogue_id: String
@export var trigger_once: bool = true
@export var flag_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	if trigger_once and flag_name != "" and SaveManager.has_flag(flag_name):
		return

	var scene_root = get_tree().current_scene
	if not scene_root or not scene_root.has_method("start_dialog"):
		push_warning("EventTrigger could not find start_dialog on the current scene root.")
		return

	scene_root.start_dialog(dialogue_id)

	if flag_name != "":
		SaveManager.set_flag(flag_name)
