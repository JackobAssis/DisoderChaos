extends ProgressBar
class_name XPBar
# xp_bar.gd - Experience bar with advanced features

# Animation properties
var target_value: float = 0
var current_display_value: float = 0
var animation_speed: float = 2.0
var is_animating: bool = false

# Visual feedback
var glow_effect: bool = false
var pulse_animation: Tween
var level_up_effect: bool = false

# Labels and text
var xp_label: Label
var level_label: Label

# Colors for different states
var normal_color: Color = Color.YELLOW
var level_up_color: Color = Color.GOLD
var full_color: Color = Color.ORANGE

func _ready():
	print("[XPBar] XP Bar initialized")
	setup_xp_bar()
	create_labels()
	connect_signals()
	update_display()

func setup_xp_bar():
	"""Initialize XP bar properties"""
	show_percentage = false
	step = 1
	
	# Create custom style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = normal_color
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color.BLACK
	
	add_theme_stylebox_override("fill", style_box)
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color.BLACK
	
	add_theme_stylebox_override("background", bg_style)

func create_labels():
	"""Create text labels for the XP bar"""
	# XP amount label
	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_color_override("font_color", Color.WHITE)
	xp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	xp_label.add_theme_constant_override("shadow_offset_x", 1)
	xp_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Position label to center of progress bar
	xp_label.anchors_preset = Control.PRESET_FULL_RECT
	
	add_child(xp_label)
	
	# Level label (positioned above or beside the bar)
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_color_override("font_color", Color.GOLD)
	level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	level_label.add_theme_font_size_override("font_size", 14)
	
	# Position level label above the XP bar
	level_label.position = Vector2(0, -20)
	
	add_child(level_label)

func connect_signals():
	"""Connect to game events"""
	EventBus.player_xp_gained.connect(_on_xp_gained)
	EventBus.player_level_up.connect(_on_level_up)
	
	# Connect to player data changes
	if GameState.player_data_changed.is_connected(_on_player_data_changed):
		GameState.player_data_changed.disconnect(_on_player_data_changed)
	GameState.player_data_changed.connect(_on_player_data_changed)

func update_display():
	"""Update XP bar display with current player data"""
	if not GameState.player_data:
		return
	
	var current_xp = GameState.player_data.get("experience", 0)
	var level = GameState.player_data.get("level", 1)
	
	# Calculate XP for current level range
	var xp_for_current_level = GameState.get_required_experience_for_level(level)
	var xp_for_next_level = GameState.get_required_experience_for_level(level + 1)
	
	var xp_in_current_level = current_xp - xp_for_current_level
	var xp_needed_for_level = xp_for_next_level - xp_for_current_level
	
	# Set bar values
	max_value = xp_needed_for_level
	target_value = xp_in_current_level
	
	# Update labels
	update_xp_label(xp_in_current_level, xp_needed_for_level)
	update_level_label(level)
	
	# Start animation if needed
	if abs(value - target_value) > 0.1:
		start_value_animation()
	else:
		value = target_value
		current_display_value = target_value

func update_xp_label(current_xp: int, max_xp: int):
	"""Update XP text display"""
	if xp_label:
		var percentage = 0
		if max_xp > 0:
			percentage = int((float(current_xp) / float(max_xp)) * 100)
		
		xp_label.text = str(current_xp) + " / " + str(max_xp) + " (" + str(percentage) + "%)"

func update_level_label(level: int):
	"""Update level display"""
	if level_label:
		level_label.text = "Level " + str(level)

func start_value_animation():
	"""Start smooth animation to target value"""
	if is_animating:
		return
	
	is_animating = true
	current_display_value = value

func _process(delta):
	"""Handle smooth value animation"""
	if is_animating:
		# Animate towards target value
		var difference = target_value - current_display_value
		
		if abs(difference) < 0.1:
			# Animation complete
			current_display_value = target_value
			value = target_value
			is_animating = false
		else:
			# Continue animation
			current_display_value += difference * animation_speed * delta
			value = current_display_value
	
	# Handle special effects
	if glow_effect:
		update_glow_effect(delta)
	
	if level_up_effect:
		update_level_up_effect(delta)

func update_glow_effect(delta):
	"""Update glow visual effect"""
	var time = Time.get_time_dict_from_system()
	var glow_intensity = (sin(time.second * 3.0) + 1.0) * 0.5
	modulate = Color.WHITE.lerp(Color.YELLOW, glow_intensity * 0.3)

func update_level_up_effect(delta):
	"""Update level up visual effect"""
	# This effect is handled by the pulse animation
	pass

func gain_experience(amount: int):
	"""Add experience with visual feedback"""
	var old_level = GameState.player_data.get("level", 1)
	var old_xp = GameState.player_data.get("experience", 0)
	
	# Update game state
	GameState.gain_experience(amount)
	
	var new_level = GameState.player_data.get("level", 1)
	var new_xp = GameState.player_data.get("experience", 0)
	
	# Check for level up
	if new_level > old_level:
		handle_level_up(new_level)
	else:
		# Regular XP gain animation
		start_xp_gain_effect(amount)
	
	# Update display
	update_display()

func start_xp_gain_effect(amount: int):
	"""Start visual effect for XP gain"""
	glow_effect = true
	
	# Create floating text effect
	create_floating_text("+" + str(amount) + " XP", Color.YELLOW)
	
	# Stop glow after short duration
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(stop_glow_effect)
	add_child(timer)
	timer.start()

func handle_level_up(new_level: int):
	"""Handle level up with special effects"""
	level_up_effect = true
	
	# Change bar color temporarily
	change_bar_color(level_up_color)
	
	# Create level up animation
	start_level_up_pulse()
	
	# Create floating text
	create_floating_text("LEVEL UP!", Color.GOLD)
	
	# Play level up sound (if audio system exists)
	EventBus.audio_sfx_requested.emit("level_up")
	
	# Reset effects after animation
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(reset_level_up_effects)
	add_child(timer)
	timer.start()

func start_level_up_pulse():
	"""Start pulsing animation for level up"""
	if pulse_animation:
		pulse_animation.kill()
	
	pulse_animation = create_tween()
	pulse_animation.set_loops()
	
	# Pulse scale animation
	pulse_animation.tween_property(self, "scale", Vector2(1.1, 1.1), 0.3)
	pulse_animation.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func change_bar_color(color: Color):
	"""Change the fill color of the progress bar"""
	var style_box = get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	style_box.bg_color = color
	add_theme_stylebox_override("fill", style_box)

func stop_glow_effect():
	"""Stop glow visual effect"""
	glow_effect = false
	modulate = Color.WHITE

func reset_level_up_effects():
	"""Reset all level up effects"""
	level_up_effect = false
	
	# Stop pulse animation
	if pulse_animation:
		pulse_animation.kill()
	
	# Reset scale and color
	scale = Vector2(1.0, 1.0)
	change_bar_color(normal_color)

func create_floating_text(text: String, color: Color):
	"""Create floating text animation"""
	var floating_label = Label.new()
	floating_label.text = text
	floating_label.add_theme_color_override("font_color", color)
	floating_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	floating_label.add_theme_constant_override("shadow_offset_x", 2)
	floating_label.add_theme_constant_override("shadow_offset_y", 2)
	floating_label.add_theme_font_size_override("font_size", 16)
	
	# Position above the XP bar
	floating_label.position = Vector2(size.x / 2 - 30, -30)
	
	add_child(floating_label)
	
	# Animate the floating text
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move upward and fade out
	tween.tween_property(floating_label, "position:y", floating_label.position.y - 50, 2.0)
	tween.tween_property(floating_label, "modulate:a", 0.0, 2.0)
	
	# Remove after animation
	tween.tween_callback(floating_label.queue_free).set_delay(2.0)

# Signal handlers
func _on_xp_gained(amount: int):
	"""Handle XP gain event"""
	gain_experience(0)  # The XP has already been added to GameState
	start_xp_gain_effect(amount)

func _on_level_up(new_level: int):
	"""Handle level up event"""
	handle_level_up(new_level)

func _on_player_data_changed():
	"""Handle player data changes"""
	update_display()

func set_xp_directly(current_xp: int, max_xp: int):
	"""Set XP values directly (for testing or loading)"""
	max_value = max_xp
	value = current_xp
	target_value = current_xp
	current_display_value = current_xp
	
	update_xp_label(current_xp, max_xp)

# Utility functions
func get_xp_percentage() -> float:
	"""Get current XP as percentage of level progress"""
	if max_value <= 0:
		return 0.0
	return (value / max_value) * 100.0

func is_at_max_level() -> bool:
	"""Check if player is at maximum level"""
	var current_level = GameState.player_data.get("level", 1)
	return current_level >= GameState.max_level

func get_xp_until_next_level() -> int:
	"""Get XP needed for next level"""
	return int(max_value - value)

# TODO: Future enhancements
# - Skill point notification on level up
# - Attribute point allocation popup
# - XP multiplier display during bonuses
# - Rest state XP bonus indicator
# - Party XP sharing visualization