extends Area2D

@export var target_scene: String
@export var location_title: String = ""
@export var spawn_point_name: String = ""

var _is_triggering := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	if _is_triggering:
		return

	var scene_path = target_scene.strip_edges()
	if scene_path == "":
		push_warning("SceneExitTrigger target_scene is empty.")
		return

	_is_triggering = true
	await SceneTransition.go(scene_path, location_title)
