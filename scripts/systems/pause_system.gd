extends Node
class_name PauseSystem

var owner: Node
var paused: bool = false
var pause_menu: Control
var pause_status_label: Label
var pause_slot_modal: Control
var pause_slot_title_label: Label
var pause_slot_status_label: Label
var pause_slot_action_button: Button
var pause_slot_buttons: Array[Button] = []
var pause_selected_slot := 1
var pause_slot_mode := 0
var pause_overwrite_confirm_slot := -1
var pause_last_slot_press_slot := -1
var pause_last_slot_press_msec := 0
const PauseSlotMode = { "NONE": 0, "SAVE": 1, "LOAD": 2 }

func init(owner_node: Node) -> void:
    owner = owner_node

func toggle_pause() -> void:
    paused = not paused
    get_tree().paused = paused

func is_paused() -> bool:
    return paused

func setup_pause_menu() -> void:
    var layer = CanvasLayer.new()
    layer.name = "PauseMenuLayer"
    owner.add_child(layer)

    pause_menu = Control.new()
    pause_menu.name = "PauseMenu"
    pause_menu.visible = false
    pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(pause_menu)

    var shade = ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.55)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_menu.add_child(shade)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(280, 260)
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -140
    panel.offset_top = -130
    panel.offset_right = 140
    panel.offset_bottom = 130
    pause_menu.add_child(panel)

    var menu = VBoxContainer.new()
    menu.add_theme_constant_override("separation", 8)
    panel.add_child(menu)

    var title = Label.new()
    title.text = "Menu"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    menu.add_child(title)

    pause_status_label = Label.new()
    pause_status_label.text = ""
    pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_status_label.custom_minimum_size = Vector2(240, 30)
    menu.add_child(pause_status_label)

    var resume_button = create_pause_button("Resume")
    resume_button.pressed.connect(self.close_pause_menu)
    menu.add_child(resume_button)

    var save_button = create_pause_button("Save")
    save_button.pressed.connect(self.save_from_pause_menu)
    menu.add_child(save_button)

    var load_button = create_pause_button("Load")
    load_button.pressed.connect(self.load_from_pause_menu)
    menu.add_child(load_button)

    var title_button = create_pause_button("Title")
    title_button.pressed.connect(self.return_to_title)
    menu.add_child(title_button)

    build_pause_slot_modal(layer)

func build_pause_slot_modal(layer: CanvasLayer) -> void:
    pause_slot_modal = Control.new()
    pause_slot_modal.name = "PauseSlotModal"
    pause_slot_modal.visible = false
    pause_slot_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(pause_slot_modal)

    var shade = ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.62)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_slot_modal.add_child(shade)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(460, 540)
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -230
    panel.offset_top = -270
    panel.offset_right = 230
    panel.offset_bottom = 270
    pause_slot_modal.add_child(panel)

    var content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    pause_slot_title_label = Label.new()
    pause_slot_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_slot_title_label.add_theme_font_size_override("font_size", 24)
    pause_slot_title_label.custom_minimum_size = Vector2(360, 38)
    content.add_child(pause_slot_title_label)

    var slot_scroll = ScrollContainer.new()
    slot_scroll.custom_minimum_size = Vector2(360, 310)
    content.add_child(slot_scroll)

    var slot_list = VBoxContainer.new()
    slot_list.add_theme_constant_override("separation", 8)
    slot_scroll.add_child(slot_list)

    for slot in range(1, SaveManager.SLOT_COUNT + 1):
        var slot_button = create_pause_button("")
        slot_button.custom_minimum_size = Vector2(360, 38)
        slot_button.toggle_mode = true
        slot_button.pressed.connect(self.select_pause_slot.bind(slot))
        pause_slot_buttons.append(slot_button)
        slot_list.add_child(slot_button)

    pause_slot_status_label = Label.new()
    pause_slot_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_slot_status_label.custom_minimum_size = Vector2(360, 30)
    pause_slot_status_label.modulate = Color(0.78, 0.9, 1.0, 1.0)
    content.add_child(pause_slot_status_label)

    pause_slot_action_button = create_pause_button("")
    pause_slot_action_button.custom_minimum_size = Vector2(360, 38)
    pause_slot_action_button.pressed.connect(self.confirm_pause_slot_action)
    content.add_child(pause_slot_action_button)

    var back_button = create_pause_button("Back")
    back_button.custom_minimum_size = Vector2(360, 38)
    back_button.pressed.connect(self.close_pause_slot_modal)
    content.add_child(back_button)

func create_pause_button(text: String) -> Button:
    var button = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(220, 38)
    return button

func toggle_pause_menu() -> void:
    if pause_menu and pause_menu.visible:
        close_pause_menu()
    else:
        open_pause_menu()

func open_pause_menu() -> void:
    var p = owner.get_player() if owner and owner.has_method("get_player") else null
    was_player_movable_before_menu = p.can_move if p else true
    if p:
        p.can_move = false
    pause_status_label.text = ""
    if pause_menu:
        pause_menu.visible = true

func close_pause_menu() -> void:
    close_pause_slot_modal()
    if pause_menu:
        pause_menu.visible = false
    var p = owner.get_player() if owner and owner.has_method("get_player") else null
    if p:
        p.can_move = was_player_movable_before_menu

func save_from_pause_menu() -> void:
    open_pause_slot_modal(PauseSlotMode.SAVE)

func load_from_pause_menu() -> void:
    if not has_any_pause_save():
        if pause_status_label:
            pause_status_label.text = "No save data"
        return
    open_pause_slot_modal(PauseSlotMode.LOAD)

func open_pause_slot_modal(mode: int) -> void:
    pause_slot_mode = mode
    pause_overwrite_confirm_slot = -1
    pause_last_slot_press_slot = -1
    if pause_slot_mode == PauseSlotMode.SAVE:
        pause_selected_slot = SaveManager.active_slot
        pause_slot_title_label.text = "Save"
        pause_slot_action_button.text = "Save"
    else:
        pause_selected_slot = SaveManager.get_latest_save_slot(SaveManager.active_slot)
        pause_slot_title_label.text = "Load"
        pause_slot_action_button.text = "Load"

    pause_slot_modal.visible = true
    refresh_pause_slots()
    pause_slot_buttons[pause_selected_slot - 1].grab_focus()

func close_pause_slot_modal() -> void:
    if not pause_slot_modal:
        return
    pause_slot_mode = PauseSlotMode.NONE
    pause_overwrite_confirm_slot = -1
    pause_last_slot_press_slot = -1
    pause_slot_modal.visible = false

func select_pause_slot(slot: int) -> void:
    var now = Time.get_ticks_msec()
    var is_double_press = slot == pause_selected_slot and slot == pause_last_slot_press_slot and now - pause_last_slot_press_msec <= SLOT_DOUBLE_PRESS_MS
    pause_selected_slot = slot
    if not is_double_press:
        pause_overwrite_confirm_slot = -1
    refresh_pause_slots()
    pause_last_slot_press_slot = slot
    pause_last_slot_press_msec = now
    if is_double_press:
        quick_confirm_pause_slot_action()

func refresh_pause_slots() -> void:
    for index in range(pause_slot_buttons.size()):
        var slot = index + 1
        var summary = SaveManager.get_save_summary(slot)
        var button = pause_slot_buttons[index]
        button.button_pressed = slot == pause_selected_slot
        button.disabled = pause_slot_mode == PauseSlotMode.LOAD and not bool(summary["exists"])
        button.text = format_pause_slot_summary(summary)

    var selected_summary = SaveManager.get_save_summary(pause_selected_slot)
    if pause_slot_mode == PauseSlotMode.LOAD:
        pause_slot_action_button.text = "Load"
        pause_slot_action_button.disabled = not bool(selected_summary["exists"])
        pause_slot_status_label.text = ""
    else:
        pause_slot_action_button.disabled = false
        if selected_summary["exists"]:
            if pause_overwrite_confirm_slot == pause_selected_slot:
                pause_slot_action_button.text = "Confirm Overwrite"
                pause_slot_status_label.text = "Press again to overwrite Slot %d." % pause_selected_slot
            else:
                pause_slot_action_button.text = "Save"
                pause_slot_status_label.text = "This will overwrite existing save data."
        else:
            pause_slot_action_button.text = "Save"
            pause_slot_status_label.text = ""

func confirm_pause_slot_action() -> void:
    if pause_slot_mode == PauseSlotMode.SAVE:
        var selected_summary = SaveManager.get_save_summary(pause_selected_slot)
        if bool(selected_summary["exists"]) and pause_overwrite_confirm_slot != pause_selected_slot:
            pause_overwrite_confirm_slot = pause_selected_slot
            refresh_pause_slots()
            return

        var p = owner.get_player() if owner and owner.has_method("get_player") else null
        if p:
            SaveManager.set_player_position(p.global_position)
        if SaveManager.save_game(pause_selected_slot):
            pause_status_label.text = "Saved Slot %d" % pause_selected_slot
            close_pause_slot_modal()
        else:
            pause_slot_status_label.text = "Save failed"
    elif pause_slot_mode == PauseSlotMode.LOAD:
        load_pause_slot()

func quick_confirm_pause_slot_action() -> void:
    if pause_slot_mode == PauseSlotMode.SAVE:
        var p = owner.get_player() if owner and owner.has_method("get_player") else null
        if p:
            SaveManager.set_player_position(p.global_position)
        if SaveManager.save_game(pause_selected_slot):
            pause_status_label.text = "Saved Slot %d" % pause_selected_slot
            close_pause_slot_modal()
        else:
            pause_slot_status_label.text = "Save failed"
    elif pause_slot_mode == PauseSlotMode.LOAD:
        if bool(SaveManager.get_save_summary(pause_selected_slot)["exists"]):
            load_pause_slot()

func load_pause_slot() -> void:
    if not SaveManager.load_game(pause_selected_slot):
        pause_slot_status_label.text = "No save data"
        refresh_pause_slots()
        return

    var saved_scene = SaveManager.get_saved_scene_path()
    if saved_scene != owner.get_tree().current_scene.scene_file_path:
        owner.get_tree().change_scene_to_file(saved_scene)
        return

    SaveManager.apply_player_position()
    pause_status_label.text = "Loaded Slot %d" % pause_selected_slot
    close_pause_slot_modal()
    close_pause_menu()

func has_any_pause_save() -> bool:
    for slot in range(1, SaveManager.SLOT_COUNT + 1):
        if bool(SaveManager.get_save_summary(slot)["exists"]):
            return true
    return false

func format_pause_slot_summary(summary: Dictionary) -> String:
    var slot = int(summary["slot"])
    if not bool(summary["exists"]):
        return "Slot %d - Empty" % slot

    var location = str(summary.get("location", ""))
    if location == "":
        location = "Unknown"

    var saved_at = int(summary.get("saved_at_unix", 0))
    var time_text = "No time"
    if saved_at > 0:
        var time_data = Time.get_datetime_dict_from_unix_time(saved_at)
        time_text = "%04d-%02d-%02d %02d:%02d" % [
            int(time_data["year"]),
            int(time_data["month"]),
            int(time_data["day"]),
            int(time_data["hour"]),
            int(time_data["minute"]),
        ]

    return "Slot %d - %s  %s" % [slot, location, time_text]

func return_to_title() -> void:
    SaveManager.autosave(true)
    owner.get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
