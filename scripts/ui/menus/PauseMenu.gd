extends Control

class_name PauseMenu

# Menu components
@onready var main_panel: Panel
@onready var continue_button: Button
@onready var inventory_button: Button
@onready var character_button: Button
@onready var journal_button: Button
@onready var settings_button: Button
@onready var save_button: Button
@onready var main_menu_button: Button

# Quick access panels
var quick_stats_panel: Control
var quick_inventory_panel: Control

# Animation
var menu_tween: Tween
var blur_effect: Control

# Style
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var dark_bg: Color = Color(0.0, 0.1, 0.05, 0.9)
var darker_bg: Color = Color(0.0, 0.05, 0.025, 0.95)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var ui_manager: UIManager

func _ready():
	setup_pause_menu()
	setup_animations()
	setup_connections()
	print("[PauseMenu] Menu de Pausa inicializado")

func setup_pause_menu():
	"""Setup pause menu layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()  # Assuming UIManager -> MenuContainer -> PauseMenu
	
	create_blur_background()
	create_main_panel()
	create_menu_buttons()
	create_quick_panels()

func create_blur_background():
	"""Create blurred background overlay"""
	blur_effect = Control.new()
	blur_effect.name = "BlurBackground"
	blur_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_effect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blur_effect)
	
	var blur_panel = Panel.new()
	blur_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_effect.add_child(blur_panel)
	
	var blur_style = StyleBoxFlat.new()
	blur_style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	blur_panel.add_theme_stylebox_override("panel", blur_style)

func create_main_panel():
	"""Create main pause menu panel"""
	main_panel = Panel.new()
	main_panel.name = "MainPanel"
	main_panel.anchor_left = 0.3
	main_panel.anchor_right = 0.7
	main_panel.anchor_top = 0.2
	main_panel.anchor_bottom = 0.8
	add_child(main_panel)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = dark_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.4)
	panel_style.shadow_size = 8
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Add title
	create_pause_title()

func create_pause_title():
	"""Create pause menu title"""
	var title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "GAME PAUSED"
	title_label.anchor_left = 0.5
	title_label.anchor_right = 0.5
	title_label.offset_left = -100
	title_label.offset_right = 100
	title_label.offset_top = 20
	title_label.offset_bottom = 50
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", neon_green)
	title_label.add_theme_font_size_override("font_size", 24)
	main_panel.add_child(title_label)

func create_menu_buttons():
	"""Create pause menu buttons"""
	var button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.anchor_left = 0.5
	button_container.anchor_right = 0.5
	button_container.anchor_top = 0.2
	button_container.anchor_bottom = 0.9
	button_container.offset_left = -120
	button_container.offset_right = 120
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 15)
	main_panel.add_child(button_container)
	
	# Continue Button
	continue_button = create_pause_button("CONTINUE", "resume_game")
	continue_button.pressed.connect(_on_continue_pressed)
	button_container.add_child(continue_button)
	
	# Inventory Button
	inventory_button = create_pause_button("INVENTORY", "open_inventory")
	inventory_button.pressed.connect(_on_inventory_pressed)
	button_container.add_child(inventory_button)
	
	# Character Stats Button
	character_button = create_pause_button("CHARACTER", "open_character")
	character_button.pressed.connect(_on_character_pressed)
	button_container.add_child(character_button)
	
	# Quest Journal Button
	journal_button = create_pause_button("JOURNAL", "open_journal")
	journal_button.pressed.connect(_on_journal_pressed)
	button_container.add_child(journal_button)
	
	# Settings Button
	settings_button = create_pause_button("SETTINGS", "open_settings")
	settings_button.pressed.connect(_on_settings_pressed)
	button_container.add_child(settings_button)
	
	# Save Game Button
	save_button = create_pause_button("SAVE GAME", "save_game")
	save_button.pressed.connect(_on_save_pressed)
	button_container.add_child(save_button)
	
	# Return to Main Menu Button
	main_menu_button = create_pause_button("MAIN MENU", "main_menu")
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	button_container.add_child(main_menu_button)

func create_pause_button(text: String, icon_name: String = "") -> Button:
	"""Create styled pause menu button"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 45)
	
	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.2)
	hover_style.border_color = Color.WHITE
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.shadow_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.5)
	hover_style.shadow_size = 6
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed state
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = neon_green
	pressed_style.border_color = Color.WHITE
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.corner_radius_top_left = 6
	pressed_style.corner_radius_top_right = 6
	pressed_style.corner_radius_bottom_left = 6
	pressed_style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Font styling
	button.add_theme_color_override("font_color", neon_green)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_font_size_override("font_size", 16)
	
	# Add hover effects
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.pressed.connect(_on_button_press.bind(button))
	
	return button

func create_quick_panels():
	"""Create quick access info panels"""
	create_quick_stats_panel()
	create_quick_time_panel()

func create_quick_stats_panel():
	"""Create quick player stats panel"""
	quick_stats_panel = Panel.new()
	quick_stats_panel.name = "QuickStats"
	quick_stats_panel.anchor_left = 0.05
	quick_stats_panel.anchor_right = 0.25
	quick_stats_panel.anchor_top = 0.2
	quick_stats_panel.anchor_bottom = 0.6
	add_child(quick_stats_panel)
	
	# Style the panel
	var stats_style = StyleBoxFlat.new()
	stats_style.bg_color = darker_bg
	stats_style.border_color = neon_green
	stats_style.border_width_left = 2
	stats_style.border_width_right = 2
	stats_style.border_width_top = 2
	stats_style.border_width_bottom = 2
	stats_style.corner_radius_top_left = 8
	stats_style.corner_radius_top_right = 8
	stats_style.corner_radius_bottom_left = 8
	stats_style.corner_radius_bottom_right = 8
	quick_stats_panel.add_theme_stylebox_override("panel", stats_style)
	
	# Add stats content
	var stats_container = VBoxContainer.new()
	stats_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_container.add_theme_constant_override("separation", 8)
	quick_stats_panel.add_child(stats_container)
	
	# Title
	var stats_title = Label.new()
	stats_title.text = "STATS"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_color_override("font_color", neon_green)
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_container.add_child(stats_title)

func create_quick_time_panel():
	"""Create quick time/location info panel"""
	var time_panel = Panel.new()
	time_panel.name = "QuickTime"
	time_panel.anchor_left = 0.75
	time_panel.anchor_right = 0.95
	time_panel.anchor_top = 0.2
	time_panel.anchor_bottom = 0.5
	add_child(time_panel)
	
	# Style the panel
	var time_style = StyleBoxFlat.new()
	time_style.bg_color = darker_bg
	time_style.border_color = neon_green
	time_style.border_width_left = 2
	time_style.border_width_right = 2
	time_style.border_width_top = 2
	time_style.border_width_bottom = 2
	time_style.corner_radius_top_left = 8
	time_style.corner_radius_top_right = 8
	time_style.corner_radius_bottom_left = 8
	time_style.corner_radius_bottom_right = 8
	time_panel.add_theme_stylebox_override("panel", time_style)
	
	# Add time content
	var time_container = VBoxContainer.new()
	time_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_container.add_theme_constant_override("separation", 8)
	time_panel.add_child(time_container)
	
	# Title
	var time_title = Label.new()
	time_title.text = "LOCATION"
	time_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_title.add_theme_color_override("font_color", neon_green)
	time_title.add_theme_font_size_override("font_size", 16)
	time_container.add_child(time_title)

func setup_animations():
	"""Setup menu animations"""
	menu_tween = Tween.new()
	add_child(menu_tween)

func setup_connections():
	"""Setup event connections"""
	if event_bus:
		event_bus.connect("game_paused", _on_game_paused)
		event_bus.connect("game_resumed", _on_game_resumed)

func show():
	"""Show pause menu with animation"""
	super.show()
	animate_show()
	refresh_data()

func hide():
	"""Hide pause menu with animation"""
	animate_hide()

func animate_show():
	"""Animate menu appearance"""
	if not menu_tween:
		return
	
	# Start with transparent and scaled down
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	# Animate in
	menu_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	menu_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3)

func animate_hide():
	"""Animate menu disappearance"""
	if not menu_tween:
		super.hide()
		return
	
	# Animate out
	menu_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	menu_tween.tween_callback(func(): super.hide())

func refresh_data():
	"""Refresh displayed data"""
	refresh_stats_panel()
	refresh_time_panel()

func refresh_stats_panel():
	"""Refresh stats panel with current player data"""
	if not quick_stats_panel or not game_state:
		return
	
	var stats_container = quick_stats_panel.get_child(0)
	if not stats_container:
		return
	
	# Clear existing stats (except title)
	while stats_container.get_child_count() > 1:
		stats_container.get_child(-1).queue_free()
	
	# Add current stats
	var player_stats = game_state.player_stats
	if player_stats:
		add_stat_line(stats_container, "Level", str(player_stats.current_level))
		add_stat_line(stats_container, "Health", str(player_stats.current_health) + "/" + str(player_stats.max_health))
		add_stat_line(stats_container, "XP", str(player_stats.experience))
		add_stat_line(stats_container, "Gold", str(game_state.currency))

func refresh_time_panel():
	"""Refresh time panel with current game info"""
	var time_panel = get_node_or_null("QuickTime")
	if not time_panel or not game_state:
		return
	
	var time_container = time_panel.get_child(0)
	if not time_container:
		return
	
	# Clear existing info (except title)
	while time_container.get_child_count() > 1:
		time_container.get_child(-1).queue_free()
	
	# Add current info
	add_info_line(time_container, "Dungeon", game_state.current_location)
	add_info_line(time_container, "Play Time", format_play_time(game_state.get_play_time()))

func add_stat_line(container: VBoxContainer, label: String, value: String):
	"""Add a stat line to container"""
	var line_container = HBoxContainer.new()
	container.add_child(line_container)
	
	var label_node = Label.new()
	label_node.text = label + ":"
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_node.add_theme_color_override("font_color", Color.WHITE)
	label_node.add_theme_font_size_override("font_size", 12)
	line_container.add_child(label_node)
	
	var value_node = Label.new()
	value_node.text = value
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_node.add_theme_color_override("font_color", neon_green)
	value_node.add_theme_font_size_override("font_size", 12)
	line_container.add_child(value_node)

func add_info_line(container: VBoxContainer, label: String, value: String):
	"""Add an info line to container"""
	var info_label = Label.new()
	info_label.text = label + ": " + value
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_font_size_override("font_size", 12)
	container.add_child(info_label)

func format_play_time(seconds: float) -> String:
	"""Format play time for display"""
	var hours = int(seconds) / 3600
	var minutes = (int(seconds) % 3600) / 60
	return "%02d:%02d" % [hours, minutes]

# Button Event Handlers
func _on_continue_pressed():
	"""Continue game"""
	if ui_manager:
		ui_manager.close_pause_menu()

func _on_inventory_pressed():
	"""Open inventory"""
	if ui_manager:
		ui_manager.close_pause_menu()
		ui_manager.open_inventory()

func _on_character_pressed():
	"""Open character screen"""
	show_character_screen()

func _on_journal_pressed():
	"""Open quest journal"""
	if ui_manager:
		ui_manager.close_pause_menu()
		ui_manager.open_quest_journal()

func _on_settings_pressed():
	"""Open settings"""
	show_settings_screen()

func _on_save_pressed():
	"""Save game"""
	if game_state:
		game_state.save_game()
		show_save_confirmation()

func _on_main_menu_pressed():
	"""Return to main menu"""
	show_main_menu_confirmation()

func _on_button_hover(button: Button):
	"""Handle button hover"""
	event_bus.emit_signal("play_ui_sound", "button_hover")
	
	var hover_tween = create_tween()
	hover_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_press(button: Button):
	"""Handle button press"""
	event_bus.emit_signal("play_ui_sound", "button_click")
	
	var press_tween = create_tween()
	press_tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	press_tween.tween_property(button, "scale", Vector2.ONE, 0.05)

func show_character_screen():
	"""Show character stats screen"""
	var char_overlay = create_character_overlay()
	add_child(char_overlay)

func create_character_overlay() -> Control:
	"""Create character screen overlay"""
	var overlay = Control.new()
	overlay.name = "CharacterOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	
	# Character panel
	var char_panel = Panel.new()
	char_panel.anchor_left = 0.2
	char_panel.anchor_right = 0.8
	char_panel.anchor_top = 0.1
	char_panel.anchor_bottom = 0.9
	overlay.add_child(char_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = dark_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	char_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Title
	var title = Label.new()
	title.text = "CHARACTER"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -80
	title.offset_right = 80
	title.offset_top = 20
	title.offset_bottom = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", neon_green)
	title.add_theme_font_size_override("font_size", 24)
	char_panel.add_child(title)
	
	# Close button
	var close_btn = create_pause_button("CLOSE")
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.anchor_top = 1.0
	close_btn.anchor_bottom = 1.0
	close_btn.offset_left = -60
	close_btn.offset_right = 60
	close_btn.offset_top = -60
	close_btn.offset_bottom = -20
	close_btn.pressed.connect(func(): overlay.queue_free())
	char_panel.add_child(close_btn)
	
	return overlay

func show_settings_screen():
	"""Show settings screen"""
	var settings_overlay = create_settings_overlay()
	add_child(settings_overlay)

func create_settings_overlay() -> Control:
	"""Create settings overlay"""
	var overlay = Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	
	# Settings panel
	var settings_panel = Panel.new()
	settings_panel.anchor_left = 0.25
	settings_panel.anchor_right = 0.75
	settings_panel.anchor_top = 0.2
	settings_panel.anchor_bottom = 0.8
	overlay.add_child(settings_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = dark_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -60
	title.offset_right = 60
	title.offset_top = 20
	title.offset_bottom = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", neon_green)
	title.add_theme_font_size_override("font_size", 24)
	settings_panel.add_child(title)
	
	# Close button
	var close_btn = create_pause_button("CLOSE")
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.anchor_top = 1.0
	close_btn.anchor_bottom = 1.0
	close_btn.offset_left = -60
	close_btn.offset_right = 60
	close_btn.offset_top = -60
	close_btn.offset_bottom = -20
	close_btn.pressed.connect(func(): overlay.queue_free())
	settings_panel.add_child(close_btn)
	
	return overlay

func show_save_confirmation():
	"""Show save confirmation message"""
	var notification = create_notification("Game Saved!", neon_green)
	add_child(notification)

func create_notification(message: String, color: Color) -> Control:
	"""Create notification popup"""
	var notification = Control.new()
	notification.name = "Notification"
	notification.anchor_left = 0.5
	notification.anchor_right = 0.5
	notification.anchor_top = 0.1
	notification.anchor_bottom = 0.1
	notification.offset_left = -150
	notification.offset_right = 150
	notification.offset_top = -25
	notification.offset_bottom = 25
	
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification.add_child(panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = color
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var label = Label.new()
	label.text = message
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 16)
	notification.add_child(label)
	
	# Auto-remove after 2 seconds
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func(): notification.queue_free())
	notification.add_child(timer)
	timer.start()
	
	return notification

func show_main_menu_confirmation():
	"""Show main menu confirmation dialog"""
	var confirm_dialog = create_confirmation_dialog(
		"Return to Main Menu?",
		"Unsaved progress will be lost!",
		func(): return_to_main_menu(),
		func(): pass  # Cancel - do nothing
	)
	add_child(confirm_dialog)

func create_confirmation_dialog(title: String, message: String, on_confirm: Callable, on_cancel: Callable) -> Control:
	"""Create confirmation dialog"""
	var overlay = Control.new()
	overlay.name = "ConfirmDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	
	# Dialog panel
	var dialog = Panel.new()
	dialog.anchor_left = 0.35
	dialog.anchor_right = 0.65
	dialog.anchor_top = 0.35
	dialog.anchor_bottom = 0.65
	overlay.add_child(dialog)
	
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = dark_bg
	dialog_style.border_color = neon_green
	dialog_style.border_width_left = 3
	dialog_style.border_width_right = 3
	dialog_style.border_width_top = 3
	dialog_style.border_width_bottom = 3
	dialog_style.corner_radius_top_left = 10
	dialog_style.corner_radius_top_right = 10
	dialog_style.corner_radius_bottom_left = 10
	dialog_style.corner_radius_bottom_right = 10
	dialog.add_theme_stylebox_override("panel", dialog_style)
	
	# Title
	var title_label = Label.new()
	title_label.text = title
	title_label.anchor_left = 0.5
	title_label.anchor_right = 0.5
	title_label.offset_left = -100
	title_label.offset_right = 100
	title_label.offset_top = 20
	title_label.offset_bottom = 50
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", neon_green)
	title_label.add_theme_font_size_override("font_size", 20)
	dialog.add_child(title_label)
	
	# Message
	var message_label = Label.new()
	message_label.text = message
	message_label.anchor_left = 0.1
	message_label.anchor_right = 0.9
	message_label.anchor_top = 0.3
	message_label.anchor_bottom = 0.6
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_font_size_override("font_size", 14)
	dialog.add_child(message_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.anchor_left = 0.2
	button_container.anchor_right = 0.8
	button_container.anchor_top = 0.7
	button_container.anchor_bottom = 0.9
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	dialog.add_child(button_container)
	
	var confirm_btn = create_pause_button("CONFIRM")
	confirm_btn.pressed.connect(func(): 
		overlay.queue_free()
		on_confirm.call()
	)
	button_container.add_child(confirm_btn)
	
	var cancel_btn = create_pause_button("CANCEL")
	cancel_btn.pressed.connect(func(): 
		overlay.queue_free()
		on_cancel.call()
	)
	button_container.add_child(cancel_btn)
	
	return overlay

func return_to_main_menu():
	"""Return to main menu"""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/menus/MainMenu.tscn")

# Event Handlers
func _on_game_paused():
	"""Handle game pause event"""
	show()

func _on_game_resumed():
	"""Handle game resume event"""
	hide()

# Input Handling
func _input(event):
	"""Handle input events"""
	if visible and event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()

# Debug Functions
func debug_show_all_panels():
	"""Debug: Show all overlay panels"""
	show_character_screen()
	await get_tree().create_timer(0.5).timeout
	show_settings_screen()

func debug_test_notifications():
	"""Debug: Test notification system"""
	show_save_confirmation()
	await get_tree().create_timer(1.0).timeout
	show_main_menu_confirmation()