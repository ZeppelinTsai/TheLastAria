extends Node
class_name OrionSystem

var owner: Node

func init(owner_node: Node) -> void:
    owner = owner_node

func on_orion_trigger_entered(body: Node) -> void:
    # Handle Orion-specific event triggers
    pass

func show_orion_choice(options: Array) -> void:
    pass
