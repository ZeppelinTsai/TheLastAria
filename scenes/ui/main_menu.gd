extends Control

const GAME_SCENE_PATH = "res://scenes/world/prelude_storybook.tscn"
const NEW_GAME_LOCATION_TITLE = "序章・童話書"
const BACKGROUND_PATH = "res://img/bg/sunken_city.png"
const SLOT_DOUBLE_PRESS_MS = 450

enum SlotMode { NONE, NEW_GAME, LOAD_GAME }

var load_game_button: Button
var status_label: Label
var options_modal: Control
var options_status_label: Label
var localized_controls := {}
var language_select: OptionButton
var language_locale_ids: Array[String] = []
var slot_modal_layer: CanvasLayer
var slot_modal: Control
var slot_title_label: Label
var slot_status_label: Label
var slot_action_button: Button
var slot_buttons: Array[Button] = []
var selected_slot := 1
var slot_mode := SlotMode.NONE
var overwrite_confirm_slot := -1
var last_slot_press_slot := -1
var last_slot_press_msec := 0

func _ready() -> void:
	MusicManager.play_context("overworld")
	build_menu()
	build_options_modal()
	build_slot_modal()
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	show_main_actions()

func build_menu() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var background = TextureRect.new()
	background.texture = load(BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shade = ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.58)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var menu = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(380, 0)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 10)
	menu.anchor_left = 0.5
	menu.anchor_top = 0.52
	menu.anchor_right = 0.5
	menu.anchor_bottom = 0.52
	menu.offset_left = -190
	menu.offset_top = -120
	menu.offset_right = 190
	menu.offset_bottom = 120
	add_child(menu)

	var title = Label.new()
	title.text = "The Last Aria"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 42)
	menu.add_child(title)

	status_label = Label.new()
	status_label.text = ""
	status_label.custom_minimum_size = Vector2(360, 30)
	status_label.modulate = Color(0.78, 0.9, 1.0, 1.0)
	menu.add_child(status_label)

	var new_game_button = create_menu_button(localize("menu.new_game"))
	register_localized_control(new_game_button, "menu.new_game")
	new_game_button.pressed.connect(open_new_game_slots)
	menu.add_child(new_game_button)

	load_game_button = create_menu_button(localize("menu.load_game"))
	register_localized_control(load_game_button, "menu.load_game")
	load_game_button.pressed.connect(open_load_game_slots)
	menu.add_child(load_game_button)

	var options_button = create_menu_button(localize("menu.options"))
	register_localized_control(options_button, "menu.options")
	options_button.pressed.connect(open_options_modal)
	menu.add_child(options_button)

	var quit_button = create_menu_button(localize("menu.quit"))
	register_localized_control(quit_button, "menu.quit")
	quit_button.pressed.connect(Callable(get_tree(), "quit"))
	menu.add_child(quit_button)

	new_game_button.grab_focus()

func build_options_modal() -> void:
	var options_layer = CanvasLayer.new()
	options_layer.layer = 25
	add_child(options_layer)

	options_modal = Control.new()
	options_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_modal.visible = false
	options_layer.add_child(options_modal)

	var shade = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_modal.add_child(shade)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 430)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_top = -215
	panel.offset_right = 230
	panel.offset_bottom = 215
	options_modal.add_child(panel)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var title = Label.new()
	title.text = localize("options.title")
	register_localized_control(title, "options.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.custom_minimum_size = Vector2(360, 38)
	content.add_child(title)

	var resolution_label = Label.new()
	resolution_label.text = localize("options.resolution")
	register_localized_control(resolution_label, "options.resolution")
	content.add_child(resolution_label)

	var resolution_select = OptionButton.new()
	resolution_select.custom_minimum_size = Vector2(360, 38)
	resolution_select.add_item("1920 x 1080")
	resolution_select.add_item("1600 x 900")
	resolution_select.add_item("1280 x 720")
	resolution_select.item_selected.connect(_on_options_changed)
	content.add_child(resolution_select)

	var language_label = Label.new()
	language_label.text = localize("options.language")
	register_localized_control(language_label, "options.language")
	content.add_child(language_label)

	language_select = OptionButton.new()
	language_select.custom_minimum_size = Vector2(360, 38)
	populate_language_select()
	language_select.item_selected.connect(_on_language_selected)
	content.add_child(language_select)

	var controls_label = Label.new()
	controls_label.text = localize("options.controls")
	register_localized_control(controls_label, "options.controls")
	content.add_child(controls_label)

	var controls_button = create_menu_button(localize("options.controls_mapping"))
	register_localized_control(controls_button, "options.controls_mapping")
	controls_button.custom_minimum_size = Vector2(360, 42)
	controls_button.pressed.connect(_on_options_changed.bind(0))
	content.add_child(controls_button)

	options_status_label = Label.new()
	options_status_label.text = localize("options.ui_only")
	options_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_status_label.custom_minimum_size = Vector2(360, 30)
	options_status_label.modulate = Color(0.78, 0.9, 1.0, 1.0)
	content.add_child(options_status_label)

	var back_button = create_menu_button(localize("menu.back"))
	register_localized_control(back_button, "menu.back")
	back_button.custom_minimum_size = Vector2(360, 42)
	back_button.pressed.connect(close_options_modal)
	content.add_child(back_button)

func build_slot_modal() -> void:
	slot_modal_layer = CanvasLayer.new()
	slot_modal_layer.layer = 30
	add_child(slot_modal_layer)

	slot_modal = Control.new()
	slot_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_modal_layer.add_child(slot_modal)

	var shade = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_modal.add_child(shade)

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
	slot_modal.add_child(panel)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	slot_title_label = Label.new()
	slot_title_label.text = ""
	slot_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_title_label.add_theme_font_size_override("font_size", 24)
	slot_title_label.custom_minimum_size = Vector2(360, 38)
	content.add_child(slot_title_label)

	var slot_scroll = ScrollContainer.new()
	slot_scroll.custom_minimum_size = Vector2(360, 310)
	content.add_child(slot_scroll)

	var slot_list = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 8)
	slot_scroll.add_child(slot_list)

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var slot_button = create_menu_button("")
		slot_button.toggle_mode = true
		slot_button.pressed.connect(select_slot.bind(slot))
		slot_buttons.append(slot_button)
		slot_list.add_child(slot_button)

	slot_status_label = Label.new()
	slot_status_label.text = ""
	slot_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_status_label.custom_minimum_size = Vector2(360, 30)
	slot_status_label.modulate = Color(0.78, 0.9, 1.0, 1.0)
	content.add_child(slot_status_label)

	slot_action_button = create_menu_button("")
	slot_action_button.pressed.connect(confirm_slot_action)
	content.add_child(slot_action_button)

	var back_button = create_menu_button(localize("menu.back"))
	register_localized_control(back_button, "menu.back")
	back_button.pressed.connect(close_slot_modal)
	content.add_child(back_button)

	slot_modal.visible = false

func create_menu_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 42)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button

func register_localized_control(control: Control, key: String) -> void:
	localized_controls[control] = key

func localize(key: String) -> String:
	return LocalizationManager.tr_text(key)

func refresh_localized_text() -> void:
	for control in localized_controls.keys():
		if not is_instance_valid(control):
			continue
		control.text = localize(str(localized_controls[control]))
	refresh_language_select_selection()
	refresh_slots()

func populate_language_select() -> void:
	language_select.clear()
	language_locale_ids.clear()
	for locale_id in LocalizationManager.get_supported_locales():
		language_locale_ids.append(locale_id)
		language_select.add_item(LocalizationManager.get_locale_name(locale_id))
	refresh_language_select_selection()

func refresh_language_select_selection() -> void:
	if not language_select:
		return
	var locale_index := language_locale_ids.find(LocalizationManager.locale)
	if locale_index >= 0:
		language_select.select(locale_index)

func show_main_actions() -> void:
	slot_mode = SlotMode.NONE
	close_slot_modal()
	status_label.text = ""
	load_game_button.disabled = not has_any_save()

func close_slot_modal() -> void:
	overwrite_confirm_slot = -1
	last_slot_press_slot = -1
	slot_modal.visible = false

func open_options_modal() -> void:
	close_slot_modal()
	options_status_label.text = localize("options.ui_only")
	options_modal.visible = true

func close_options_modal() -> void:
	options_modal.visible = false

func _on_options_changed(_value = 0) -> void:
	options_status_label.text = localize("options.changed")

func _on_language_selected(index: int) -> void:
	if index < 0 or index >= language_locale_ids.size():
		return
	LocalizationManager.set_locale(language_locale_ids[index])
	_on_options_changed(index)

func _on_locale_changed(_locale: String) -> void:
	refresh_localized_text()

func open_new_game_slots() -> void:
	slot_mode = SlotMode.NEW_GAME
	overwrite_confirm_slot = -1
	last_slot_press_slot = -1
	selected_slot = get_default_new_game_slot()
	SaveManager.set_active_slot(selected_slot)
	slot_title_label.text = localize("slot.new_game")
	slot_action_button.text = localize("slot.start_new_game")
	slot_modal.visible = true
	refresh_slots()
	slot_buttons[selected_slot - 1].grab_focus()

func open_load_game_slots() -> void:
	if not has_any_save():
		status_label.text = localize("status.no_save_data")
		return

	slot_mode = SlotMode.LOAD_GAME
	overwrite_confirm_slot = -1
	last_slot_press_slot = -1
	selected_slot = SaveManager.get_latest_save_slot(1)
	SaveManager.set_active_slot(selected_slot)
	slot_title_label.text = localize("slot.load_game")
	slot_action_button.text = localize("slot.load_game")
	slot_modal.visible = true
	refresh_slots()
	slot_buttons[selected_slot - 1].grab_focus()

func get_default_new_game_slot() -> int:
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if not bool(SaveManager.get_save_summary(slot)["exists"]):
			return slot

	return SaveManager.get_latest_save_slot(1)

func has_any_save() -> bool:
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if bool(SaveManager.get_save_summary(slot)["exists"]):
			return true

	return false

func select_slot(slot: int) -> void:
	var now = Time.get_ticks_msec()
	var is_double_press = slot == selected_slot and slot == last_slot_press_slot and now - last_slot_press_msec <= SLOT_DOUBLE_PRESS_MS
	selected_slot = slot
	SaveManager.set_active_slot(slot)
	if not is_double_press:
		overwrite_confirm_slot = -1
	refresh_slots()
	last_slot_press_slot = slot
	last_slot_press_msec = now
	if is_double_press:
		quick_confirm_slot_action()

func refresh_slots() -> void:
	for index in range(slot_buttons.size()):
		var slot = index + 1
		var summary = SaveManager.get_save_summary(slot)
		var button = slot_buttons[index]
		button.button_pressed = slot == selected_slot
		button.disabled = slot_mode == SlotMode.LOAD_GAME and not bool(summary["exists"])
		button.text = format_slot_summary(summary)

	var selected_summary = SaveManager.get_save_summary(selected_slot)
	if slot_mode == SlotMode.LOAD_GAME:
		slot_action_button.text = localize("slot.load_game")
		slot_action_button.disabled = not bool(selected_summary["exists"])
		slot_status_label.text = ""
	else:
		slot_action_button.disabled = false
		if selected_summary["exists"]:
			if overwrite_confirm_slot == selected_slot:
				slot_action_button.text = localize("slot.confirm_overwrite")
				slot_status_label.text = LocalizationManager.format_text("slot.overwrite_prompt", [selected_slot])
			else:
				slot_action_button.text = localize("slot.start_new_game")
				slot_status_label.text = localize("slot.overwrite_warning")
		else:
			slot_action_button.text = localize("slot.start_new_game")
			slot_status_label.text = ""

func format_slot_summary(summary: Dictionary) -> String:
	var slot = int(summary["slot"])
	if not bool(summary["exists"]):
		return LocalizationManager.format_text("slot.empty", [slot])

	var location = str(summary.get("location", ""))
	if location == "":
		location = localize("slot.unknown")

	var saved_at = int(summary.get("saved_at_unix", 0))
	var time_text = localize("slot.no_time")
	if saved_at > 0:
		var time_data = Time.get_datetime_dict_from_unix_time(saved_at)
		time_text = "%04d-%02d-%02d %02d:%02d" % [
			int(time_data["year"]),
			int(time_data["month"]),
			int(time_data["day"]),
			int(time_data["hour"]),
			int(time_data["minute"]),
		]

	return LocalizationManager.format_text("slot.summary", [slot, location, time_text])

func confirm_slot_action() -> void:
	if slot_mode == SlotMode.NEW_GAME:
		var selected_summary = SaveManager.get_save_summary(selected_slot)
		if bool(selected_summary["exists"]) and overwrite_confirm_slot != selected_slot:
			overwrite_confirm_slot = selected_slot
			refresh_slots()
			return

		start_new_game()
	elif slot_mode == SlotMode.LOAD_GAME:
		load_game()

func quick_confirm_slot_action() -> void:
	if slot_mode == SlotMode.LOAD_GAME:
		if bool(SaveManager.get_save_summary(selected_slot)["exists"]):
			load_game()
	elif slot_mode == SlotMode.NEW_GAME:
		start_new_game()

func start_new_game() -> void:
	SaveManager.start_new_game(selected_slot)
	SaveManager.set_location(NEW_GAME_LOCATION_TITLE)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func load_game() -> void:
	if not SaveManager.load_game(selected_slot):
		refresh_slots()
		return

	get_tree().change_scene_to_file(SaveManager.get_saved_scene_path())
