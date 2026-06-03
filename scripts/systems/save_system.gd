extends Node
class_name SaveSystem

var owner: Node

func init(owner_node: Node) -> void:
    owner = owner_node

func save_to_slot(slot: int) -> bool:
    if owner and owner.has_method("get_player"):
        var p = owner.get_player()
        if p:
            SaveManager.set_player_position(p.global_position)
    return SaveManager.save_game(slot)

func load_from_slot(slot: int) -> bool:
    return SaveManager.load_game(slot)

func autosave() -> void:
    SaveManager.autosave(true)
