extends Control

class_name MainMenu

# Menu buttons
@onready var new_game_button: Button
@onready var continue_button: Button
@onready var settings_button: Button
@onready var credits_button: Button
@onready var quit_button: Button

# Background elements
@onready var title_label: Label
@onready var version_label: Label
@onready var background_panel: Panel

# Animation elements
var menu_tween: Tween
var glow_tween: Tween
var particle_system: CPUParticles2D

# Menu state
var is_animating: bool = false
var has_save_data: bool = false

# Style colors
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var dark_bg: Color = Color(0.0, 0.1, 0.05, 0.95)
var button_hover_color: Color = Color(0.0, 1.0, 0.549, 0.3)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")

func _ready():
	setup_main_menu()
	create_background_effects()
	check_save_data()
	setup_animations()
	play_intro_animation()
	print("[MainMenu] Menu Principal inicializado")

func setup_main_menu():
# Setup main menu layout
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	create_background()
	create_title()
	create_menu_buttons()
	create_version_info()

func create_background():
# Create animated background
	background_panel = Panel.new()
	background_panel.name = "Background"
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_panel)
	
	# Create gradient background
	var gradient_style = StyleBoxFlat.new()
	gradient_style.bg_color = Color.BLACK
	
	# Add subtle pattern
	var pattern_texture = create_tech_pattern()
	if pattern_texture:
		gradient_style.texture = pattern_texture
		gradient_style.texture_mode = StyleBoxTexture.TEXTURE_MODE_TILE
	
	background_panel.add_theme_stylebox_override("panel", gradient_style)

func create_tech_pattern() -> ImageTexture:
# Create tech-style background pattern
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Create circuit-like pattern
	for x in range(size):
		for y in range(size):
			var alpha = 0.0
			
			# Horizontal lines
			if y % 16 == 0 or y % 16 == 1:
				alpha = 0.1
			
			# Vertical lines
			if x % 16 == 0 or x % 16 == 1:
				alpha = max(alpha, 0.1)
			
			# Intersection points
			if (x % 16 <= 1 and y % 16 <= 1):
				alpha = 0.2
			
			var color = Color(neon_green.r, neon_green.g, neon_green.b, alpha)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_title():
# Create game title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "DISORDER CHAOS"
	title_label.anchor_left = 0.5
	title_label.anchor_right = 0.5
	title_label.anchor_top = 0.2
	title_label.anchor_bottom = 0.2
	title_label.offset_left = -300
	title_label.offset_right = 300
	title_label.offset_top = -30
	title_label.offset_bottom = 30
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title_label)
	
	# Style the title
	title_label.add_theme_color_override("font_color", neon_green)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)

func create_menu_buttons():
# Create main menu buttons
	var button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.anchor_left = 0.5
	button_container.anchor_right = 0.5
	button_container.anchor_top = 0.4
	button_container.anchor_bottom = 0.8
	button_container.offset_left = -150
	button_container.offset_right = 150
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	add_child(button_container)
	
	# New Game Button
	new_game_button = create_menu_button("NEW GAME")
	new_game_button.pressed.connect(_on_new_game_pressed)
	button_container.add_child(new_game_button)
	
	# Continue Button
	continue_button = create_menu_button("CONTINUE")
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = not has_save_data
	button_container.add_child(continue_button)
	
	# Settings Button
	settings_button = create_menu_button("SETTINGS")
	settings_button.pressed.connect(_on_settings_pressed)
	button_container.add_child(settings_button)
	
	# Credits Button
	credits_button = create_menu_button("CREDITS")
	credits_button.pressed.connect(_on_credits_pressed)
	button_container.add_child(credits_button)
	
	# Quit Button
	quit_button = create_menu_button("QUIT")
	quit_button.pressed.connect(_on_quit_pressed)
	button_container.add_child(quit_button)

func create_menu_button(text: String) -> Button:
# Create styled menu button
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 50)
	
	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.TRANSPARENT
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = button_hover_color
	hover_style.border_color = Color.WHITE
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	hover_style.shadow_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.6)
	hover_style.shadow_size = 8
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed state
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = neon_green
	pressed_style.border_color = Color.WHITE
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_left = 8
	pressed_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Font colors
	button.add_theme_color_override("font_color", neon_green)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_font_size_override("font_size", 18)
	
	# Add hover sound effects
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.pressed.connect(_on_button_press.bind(button))
	
	return button

func create_version_info():
# Create version and build info
	version_label = Label.new()
	version_label.name = "Version"
	version_label.text = "v1.0.0 - Alpha Build"
	version_label.anchor_left = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -200
	version_label.offset_right = -10
	version_label.offset_top = -30
	version_label.offset_bottom = -10
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(version_label)
	
	version_label.add_theme_color_override("font_color", Color(neon_green.r, neon_green.g, neon_green.b, 0.7))
	version_label.add_theme_font_size_override("font_size", 12)

func create_background_effects():
# Create animated background effects
	# Floating particles
	particle_system = CPUParticles2D.new()
	particle_system.name = "BackgroundParticles"
	particle_system.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)
	particle_system.emitting = true
	
	# Configure particles
	particle_system.emission_rate = 20
	particle_system.lifetime = 8.0
	particle_system.texture = create_particle_texture()
	
	# Movement
	particle_system.direction = Vector2(0, -1)
	particle_system.initial_velocity_min = 20.0
	particle_system.initial_velocity_max = 50.0
	particle_system.gravity = Vector2(0, 10)
	
	# Appearance
	particle_system.scale_amount_min = 0.1
	particle_system.scale_amount_max = 0.3
	particle_system.color = Color(neon_green.r, neon_green.g, neon_green.b, 0.5)
	
	add_child(particle_system)

func create_particle_texture() -> ImageTexture:
# Create particle texture
	var size = 8
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	for x in range(size):
		for y in range(size):
			var center = Vector2(size/2, size/2)
			var distance = Vector2(x, y).distance_to(center)
			var alpha = 1.0 - (distance / (size/2))
			alpha = clampf(alpha, 0.0, 1.0)
			
			var color = Color(1.0, 1.0, 1.0, alpha)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func setup_animations():
# Setup menu animations
	menu_tween = Tween.new()
	add_child(menu_tween)
	
	glow_tween = Tween.new()
	add_child(glow_tween)
	
	# Start title glow animation
	start_title_glow_animation()

func start_title_glow_animation():
# Start title glow effect
	if not title_label or not glow_tween:
		return
	
	var original_color = neon_green
	var bright_color = Color(neon_green.r, neon_green.g, neon_green.b, 1.0)
	bright_color = bright_color.lightened(0.3)
	
	glow_tween.set_loops()
	glow_tween.tween_method(_update_title_color, original_color, bright_color, 2.0)
	glow_tween.tween_method(_update_title_color, bright_color, original_color, 2.0)

func _update_title_color(color: Color):
# Update title color for glow effect
	if title_label:
		title_label.add_theme_color_override("font_color", color)

func play_intro_animation():
# Play menu intro animation
	if not menu_tween:
		return
	
	is_animating = true
	
	# Fade in title
	title_label.modulate.a = 0.0
	menu_tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	
	# Slide in buttons
	var buttons = [new_game_button, continue_button, settings_button, credits_button, quit_button]
	for i in range(buttons.size()):
		var button = buttons[i]
		button.position.x = 500
		button.modulate.a = 0.0
		menu_tween.parallel().tween_property(button, "position:x", 0, 0.8)
		menu_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.8)
		menu_tween.tween_delay(0.1)
	
	# Animation complete
	menu_tween.tween_callback(func(): is_animating = false)

func check_save_data():
# Check if save data exists
	has_save_data = game_state.has_save_data() if game_state else false
	
	if continue_button:
		continue_button.disabled = not has_save_data

# Button Event Handlers
func _on_new_game_pressed():
# Handle New Game button press
	if is_animating:
		return
	
	play_button_animation(new_game_button)
	
	# Start new game
	if game_state:
		game_state.start_new_game()
	
	# Transition to game scene
	transition_to_game()

func _on_continue_pressed():
# Handle Continue button press
	if is_animating or not has_save_data:
		return
	
	play_button_animation(continue_button)
	
	# Load existing game
	if game_state:
		game_state.load_game()
	
	# Transition to game scene
	transition_to_game()

func _on_settings_pressed():
# Handle Settings button press
	if is_animating:
		return
	
	play_button_animation(settings_button)
	
	# Open settings menu
	open_settings_menu()

func _on_credits_pressed():
# Handle Credits button press
	if is_animating:
		return
	
	play_button_animation(credits_button)
	
	# Show credits
	show_credits()

func _on_quit_pressed():
# Handle Quit button press
	if is_animating:
		return
	
	play_button_animation(quit_button)
	
	# Quit game
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _on_button_hover(button: Button):
# Handle button hover
	if is_animating:
		return
	
	# Play hover sound
	EventBus.play_sound("button_hover")
	
	# Subtle scale animation
	var hover_tween = create_tween()
	hover_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_press(button: Button):
# Handle button press
	# Play click sound
	EventBus.play_sound("button_click")

func play_button_animation(button: Button):
# Play button press animation
	var anim_tween = create_tween()
	anim_tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)
	anim_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func transition_to_game():
# Transition to main game scene
	# Fade out menu
	var transition_tween = create_tween()
	transition_tween.tween_property(self, "modulate:a", 0.0, 1.0)
	transition_tween.tween_callback(func(): change_to_game_scene())

func change_to_game_scene():
# Change to main game scene
	# Load main game scene
	var game_scene_path = "res://scenes/core/Main.tscn"
	if ResourceLoader.exists(game_scene_path):
		get_tree().change_scene_to_file(game_scene_path)
	else:
		print("[MainMenu] ERRO: Cena do jogo nÃ£o encontrada")

func open_settings_menu():
# Open settings submenu
	# Create settings overlay
	var settings_overlay = create_settings_overlay()
	add_child(settings_overlay)
	
	# Animate in
	settings_overlay.modulate.a = 0.0
	var settings_tween = create_tween()
	settings_tween.tween_property(settings_overlay, "modulate:a", 1.0, 0.3)

func create_settings_overlay() -> Control:
# Create settings menu overlay
	var overlay = Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Semi-transparent background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	
	# Settings panel
	var settings_panel = Panel.new()
	settings_panel.anchor_left = 0.3
	settings_panel.anchor_right = 0.7
	settings_panel.anchor_top = 0.3
	settings_panel.anchor_bottom = 0.7
	overlay.add_child(settings_panel)
	
	# Apply theme style
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
	
	# Settings title
	var title = Label.new()
	title.text = "SETTINGS"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -50
	title.offset_right = 50
	title.offset_top = 20
	title.offset_bottom = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", neon_green)
	title.add_theme_font_size_override("font_size", 24)
	settings_panel.add_child(title)
	
	# Close button
	var close_button = create_menu_button("CLOSE")
	close_button.anchor_left = 0.5
	close_button.anchor_right = 0.5
	close_button.anchor_top = 1.0
	close_button.anchor_bottom = 1.0
	close_button.offset_left = -100
	close_button.offset_right = 100
	close_button.offset_top = -70
	close_button.offset_bottom = -20
	close_button.pressed.connect(func(): overlay.queue_free())
	settings_panel.add_child(close_button)
	
	return overlay

func show_credits():
# Show credits screen
	var credits_text = """
	DISORDER CHAOS
	
	Created with Godot Engine
	
	Programming: AI Assistant
	
	Special Thanks:
	- Godot Community
	- Open Source Contributors
	
	Made with ðŸ’š in 2025
	"""
	
	# Create credits overlay
	var credits_overlay = Control.new()
	credits_overlay.name = "CreditsOverlay"
	credits_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(credits_overlay)
	
	# Semi-transparent background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	credits_overlay.add_child(bg)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.9)
	bg.add_theme_stylebox_override("panel", bg_style)
	
	# Credits text
	var credits_label = Label.new()
	credits_label.text = credits_text
	credits_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	credits_label.offset_left = -200
	credits_label.offset_right = 200
	credits_label.offset_top = -150
	credits_label.offset_bottom = 150
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credits_label.add_theme_color_override("font_color", neon_green)
	credits_label.add_theme_font_size_override("font_size", 16)
	credits_overlay.add_child(credits_label)
	
	# Auto-close after 5 seconds or on click
	credits_overlay.gui_input.connect(func(event): 
		if event is InputEventMouseButton and event.pressed:
			credits_overlay.queue_free()
	)
	
	var credits_timer = Timer.new()
	credits_timer.wait_time = 5.0
	credits_timer.one_shot = true
	credits_timer.timeout.connect(func(): credits_overlay.queue_free())
	credits_overlay.add_child(credits_timer)
	credits_timer.start()
	
	# Animate in
	credits_overlay.modulate.a = 0.0
	var credits_tween = create_tween()
	credits_tween.tween_property(credits_overlay, "modulate:a", 1.0, 0.5)

# Input handling
func _input(event):
# Handle input events
	if event.is_action_pressed("ui_cancel"):
		if get_children().any(func(child): return child.name in ["SettingsOverlay", "CreditsOverlay"]):
			# Close any open overlays
			for child in get_children():
				if child.name in ["SettingsOverlay", "CreditsOverlay"]:
					child.queue_free()

# Debug Functions
func debug_enable_continue():
# Debug: Enable continue button
	has_save_data = true
	if continue_button:
		continue_button.disabled = false

func debug_test_animations():
# Debug: Test menu animations
	play_intro_animation()
