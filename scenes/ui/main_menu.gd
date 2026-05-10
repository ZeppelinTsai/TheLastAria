extends Control

const GAME_SCENE_PATH = "res://scenes/main.tscn"
const BACKGROUND_PATH = "res://img/sunken_city.png"

var continue_button: Button
var status_label: Label

func _ready() -> void:
	MusicManager.play_context("overworld")
	build_menu()
	update_continue_state()

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
	shade.color = Color(0.01, 0.02, 0.04, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var menu = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(320, 0)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 10)
	menu.anchor_left = 0.08
	menu.anchor_top = 0.52
	menu.anchor_right = 0.08
	menu.anchor_bottom = 0.52
	menu.offset_left = 0
	menu.offset_top = -120
	menu.offset_right = 320
	menu.offset_bottom = 120
	add_child(menu)

	var title = Label.new()
	title.text = "The Last Aria"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 42)
	menu.add_child(title)

	status_label = Label.new()
	status_label.text = ""
	status_label.custom_minimum_size = Vector2(320, 28)
	status_label.modulate = Color(0.78, 0.9, 1.0, 1.0)
	menu.add_child(status_label)

	var new_game_button = create_menu_button("New Game")
	new_game_button.pressed.connect(start_new_game)
	menu.add_child(new_game_button)

	continue_button = create_menu_button("Continue")
	continue_button.pressed.connect(continue_game)
	menu.add_child(continue_button)

	var quit_button = create_menu_button("Quit")
	quit_button.pressed.connect(Callable(get_tree(), "quit"))
	menu.add_child(quit_button)

	new_game_button.grab_focus()

func create_menu_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 42)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button

func update_continue_state() -> void:
	var has_save = SaveManager.has_save_file()
	var save_loaded = has_save and SaveManager.load_game()
	continue_button.disabled = not save_loaded

	if save_loaded:
		var summary = SaveManager.get_save_summary()
		status_label.text = "Save found: %s" % summary["scene"]
	else:
		status_label.text = "No save data"

func start_new_game() -> void:
	SaveManager.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func continue_game() -> void:
	if not SaveManager.load_game():
		update_continue_state()
		return

	get_tree().change_scene_to_file(SaveManager.get_saved_scene_path())
