extends Control
# main_menu.gd - Main menu interface and navigation

# Menu panels
@onready var main_panel: VBoxContainer
@onready var character_creation_panel: Control
@onready var load_game_panel: Control
@onready var settings_panel: Control

# Buttons
@onready var new_game_button: Button
@onready var load_game_button: Button
@onready var settings_button: Button
@onready var exit_button: Button

# Character creation controls
@onready var race_option: OptionButton
@onready var class_option: OptionButton
@onready var name_input: LineEdit
@onready var create_character_button: Button
@onready var back_from_creation_button: Button

func _ready():
	setup_main_menu()
	setup_character_creation()
	connect_signals()

func setup_main_menu():
# Setup main menu UI
	# Create main panel
	main_panel = VBoxContainer.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_panel.add_theme_constant_override("separation", 20)
	add_child(main_panel)
	
	# Add title
	var title = Label.new()
	title.text = "DISORDER CHAOS"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_panel.add_child(title)
	
	# Add subtitle
	var subtitle = Label.new()
	subtitle.text = "A Modular RPG Adventure"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_panel.add_child(subtitle)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 40
	main_panel.add_child(spacer)
	
	# Create buttons
	new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.custom_minimum_size = Vector2(200, 50)
	main_panel.add_child(new_game_button)
	
	load_game_button = Button.new()
	load_game_button.text = "Load Game"
	load_game_button.custom_minimum_size = Vector2(200, 50)
	main_panel.add_child(load_game_button)
	
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(200, 50)
	main_panel.add_child(settings_button)
	
	exit_button = Button.new()
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(200, 50)
	main_panel.add_child(exit_button)

func setup_character_creation():
# Setup character creation panel
	character_creation_panel = Control.new()
	character_creation_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_creation_panel.visible = false
	add_child(character_creation_panel)
	
	var creation_container = VBoxContainer.new()
	creation_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	creation_container.add_theme_constant_override("separation", 15)
	character_creation_panel.add_child(creation_container)
	
	# Title
	var creation_title = Label.new()
	creation_title.text = "Create Character"
	creation_title.add_theme_font_size_override("font_size", 32)
	creation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creation_container.add_child(creation_title)
	
	# Character name input
	var name_container = HBoxContainer.new()
	creation_container.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 80
	name_container.add_child(name_label)
	
	name_input = LineEdit.new()
	name_input.text = "Hero"
	name_input.custom_minimum_size.x = 200
	name_container.add_child(name_input)
	
	# Race selection
	var race_container = HBoxContainer.new()
	creation_container.add_child(race_container)
	
	var race_label = Label.new()
	race_label.text = "Race:"
	race_label.custom_minimum_size.x = 80
	race_container.add_child(race_label)
	
	race_option = OptionButton.new()
	race_option.custom_minimum_size.x = 200
	race_container.add_child(race_option)
	
	# Class selection
	var class_container = HBoxContainer.new()
	creation_container.add_child(class_container)
	
	var class_label = Label.new()
	class_label.text = "Class:"
	class_label.custom_minimum_size.x = 80
	class_container.add_child(class_label)
	
	class_option = OptionButton.new()
	class_option.custom_minimum_size.x = 200
	class_container.add_child(class_option)
	
	# Buttons
	var button_container = HBoxContainer.new()
	creation_container.add_child(button_container)
	
	create_character_button = Button.new()
	create_character_button.text = "Create Character"
	create_character_button.custom_minimum_size = Vector2(150, 40)
	button_container.add_child(create_character_button)
	
	back_from_creation_button = Button.new()
	back_from_creation_button.text = "Back"
	back_from_creation_button.custom_minimum_size = Vector2(100, 40)
	button_container.add_child(back_from_creation_button)
	
	# Populate race and class options
	populate_race_options()
	populate_class_options()

func populate_race_options():
# Populate race selection dropdown
	var races = DataLoader.get_all_races()
	for race_id in races:
		var race_data = DataLoader.get_race(race_id)
		if race_data:
			race_option.add_item(race_data.name)
			race_option.set_item_metadata(race_option.get_item_count() - 1, race_id)

func populate_class_options():
# Populate class selection dropdown
	var classes = DataLoader.get_all_classes()
	for class_id in classes:
		var class_data = DataLoader.get_class(class_id)
		if class_data:
			class_option.add_item(class_data.name)
			class_option.set_item_metadata(class_option.get_item_count() - 1, class_id)

func connect_signals():
# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	create_character_button.pressed.connect(_on_create_character_pressed)
	back_from_creation_button.pressed.connect(_on_back_from_creation_pressed)
	
	# Connect to EventBus
	EventBus.ui_menu_opened.connect(_on_menu_opened)
	EventBus.ui_menu_closed.connect(_on_menu_closed)

func _on_new_game_pressed():
# Handle new game button
	show_character_creation()

func _on_load_game_pressed():
# Handle load game button
	# Try to load saved game
	if GameState.load_game(0):
		start_game()
	else:
		show_notification("No saved game found!")

func _on_settings_pressed():
# Handle settings button
	show_notification("Settings not yet implemented!")

func _on_exit_pressed():
# Handle exit button
	get_tree().quit()

func _on_create_character_pressed():
# Handle create character button
	var character_name = name_input.text.strip_edges()
	if character_name.is_empty():
		show_notification("Please enter a character name!")
		return
	
	var race_id = race_option.get_item_metadata(race_option.selected)
	var class_id = class_option.get_item_metadata(class_option.selected)
	
	if not race_id or not class_id:
		show_notification("Please select race and class!")
		return
	
	# Create new player
	if GameState.create_new_player(race_id, class_id, character_name):
		start_game()
	else:
		show_notification("Failed to create character!")

func _on_back_from_creation_pressed():
# Handle back from character creation
	show_main_menu()

func show_character_creation():
# Show character creation panel
	main_panel.visible = false
	character_creation_panel.visible = true
	EventBus.ui_menu_opened.emit("character_creation")

func show_main_menu():
# Show main menu panel
	main_panel.visible = true
	character_creation_panel.visible = false
	if load_game_panel:
		load_game_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	EventBus.ui_menu_opened.emit("main_menu")

func start_game():
# Start the game
	EventBus.ui_menu_closed.emit("main_menu")
	get_tree().change_scene_to_file("res://scenes/world/world_test.tscn")

func show_notification(message: String):
# Show a temporary notification
	# Create simple notification popup
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Disorder Chaos"
	add_child(popup)
	popup.popup_centered()
	
	# Auto close after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(popup):
		popup.queue_free()

func _input(event):
# Handle global input
	if event.is_action_pressed("ui_cancel"):
		if character_creation_panel.visible:
			show_main_menu()

func _on_menu_opened(menu_name: String):
# Handle menu opened event
	print("[MainMenu] Menu opened: ", menu_name)

func _on_menu_closed(menu_name: String):
# Handle menu closed event
	print("[MainMenu] Menu closed: ", menu_name)

# TODO: Future enhancements
# - Character preview with stats display
# - Save slot selection for multiple characters
# - Settings panel with audio/video options
# - Credits and about information
# - Character customization options
# - Background music and sound effects
# - Animated UI elements and transitions
