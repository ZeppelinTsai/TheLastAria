extends Node
class_name SaveSystem

var host: Node

func init(owner_node: Node) -> void:
    host = owner_node

func save_to_slot(slot: int) -> bool:
    if host and host.has_method("get_player"):
        var p = host.get_player()
        if p:
            SaveManager.set_player_position(p.global_position)
    return SaveManager.save_game(slot)

func load_from_slot(slot: int) -> bool:
    return SaveManager.load_game(slot)

func autosave() -> void:
    SaveManager.autosave(true)
