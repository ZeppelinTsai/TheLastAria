extends Node
class_name GameSceneController

@onready var dialogue: DialogueSystem = DialogueSystem.new()
@onready var lumi: LumiSystem = LumiSystem.new()
@onready var pause_system: PauseSystem = PauseSystem.new()
@onready var orion_system: OrionSystem = OrionSystem.new()
@onready var save_system: SaveSystem = SaveSystem.new()

func _ready() -> void:
    # Register systems as children so they participate in the scene tree
    add_child(dialogue)
    add_child(lumi)
    add_child(pause_system)
    add_child(orion_system)
    add_child(save_system)

    dialogue.init(self)
    lumi.init(self)
    pause_system.init(self)
    orion_system.init(self)
    save_system.init(self)

func _physics_process(delta: float) -> void:
    # Delegate physics updates to systems that need them
    lumi.physics_process(delta)

func start_dialog(dialogue_id: String) -> void:
    dialogue.start_dialog(dialogue_id)

func toggle_pause() -> void:
    pause_system.toggle_pause()

func get_player() -> Node:
    return get_node_or_null("Player")
