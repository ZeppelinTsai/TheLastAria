extends Node
class_name LumiSystem

var owner: Node
var target: Node

func init(owner_node: Node) -> void:
    owner = owner_node

func physics_process(delta: float) -> void:
    # Lumi follow / AI update logic goes here
    pass

func set_target(t: Node) -> void:
    target = t
