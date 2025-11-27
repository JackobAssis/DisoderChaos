extends Control
class_name PopupNotification
# popup_notification.gd - Customizable popup notification system

@onready var background: Panel
@onready var icon: TextureRect  
@onready var label: Label
@onready var progress_bar: ProgressBar

# Animation properties
var lifetime: float = 3.0
var fade_duration: float = 1.0
var move_speed: float = 50.0
var time_alive: float = 0.0

# Visual properties
var notification_type: String = "info"
var auto_destroy: bool = true

# Type configurations
var type_configs = {
	"info": {
		"color": Color.WHITE,
		"bg_color": Color(0.2, 0.3, 0.5, 0.9),
		"icon": "res://assets/ui/icons/info.png",
		"lifetime": 3.0
	},
	"success": {
		"color": Color.GREEN,
		"bg_color": Color(0.2, 0.5, 0.2, 0.9),
		"icon": "res://assets/ui/icons/success.png", 
		"lifetime": 2.5
	},
	"warning": {
		"color": Color.YELLOW,
		"bg_color": Color(0.5, 0.4, 0.2, 0.9),
		"icon": "res://assets/ui/icons/warning.png",
		"lifetime": 4.0
	},
	"error": {
		"color": Color.RED,
		"bg_color": Color(0.5, 0.2, 0.2, 0.9),
		"icon": "res://assets/ui/icons/error.png",
		"lifetime": 5.0
	},
	"loot": {
		"color": Color.GOLD,
		"bg_color": Color(0.4, 0.3, 0.1, 0.9),
		"icon": "res://assets/ui/icons/loot.png",
		"lifetime": 3.0
	},
	"xp": {
		"color": Color.CYAN,
		"bg_color": Color(0.1, 0.3, 0.4, 0.9),
		"icon": "res://assets/ui/icons/xp.png",
		"lifetime": 2.0
	},
	"level_up": {
		"color": Color.GOLD,
		"bg_color": Color(0.5, 0.4, 0.1, 1.0),
		"icon": "res://assets/ui/icons/level_up.png",
		"lifetime": 6.0
	},
	"damage": {
		"color": Color.ORANGE_RED,
		"bg_color": Color(0.4, 0.1, 0.1, 0.8),
		"icon": "res://assets/ui/icons/damage.png",
		"lifetime": 1.5
	},
	"heal": {
		"color": Color.LIME_GREEN,
		"bg_color": Color(0.1, 0.4, 0.1, 0.8),
		"icon": "res://assets/ui/icons/heal.png",
		"lifetime": 2.0
	}
}

func _ready():
	print("[PopupNotification] Popup notification ready")
	setup_notification_ui()

func setup_notification_ui():
# Create the notification UI elements
	# Set size and position
	size = Vector2(250, 60)
	
	# Create background panel
	background = Panel.new()
	background.name = "Background"
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	# Create horizontal container for layout
	var hbox = HBoxContainer.new()
	hbox.name = "Container"
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	
	# Create icon
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	
	# Create text container
	var vbox = VBoxContainer.new()
	vbox.name = "TextContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# Create label
	label = Label.new()
	label.name = "Label"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label)
	
	# Create optional progress bar (hidden by default)
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.visible = false
	progress_bar.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(progress_bar)

func setup_notification(text: String, type: String = "info", duration: float = -1):
# Setup notification with text and type
	notification_type = type
	label.text = text
	
	# Get type configuration
	var config = type_configs.get(type, type_configs["info"])
	
	# Set lifetime
	if duration > 0:
		lifetime = duration
	else:
		lifetime = config.lifetime
	
	# Apply visual styling
	apply_visual_style(config)
	
	# Start animations
	start_entrance_animation()

func apply_visual_style(config: Dictionary):
# Apply visual styling based on notification type
	# Set text color
	label.add_theme_color_override("font_color", config.color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Set background color
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = config.bg_color
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = config.color
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	background.add_theme_stylebox_override("panel", style_box)
	
	# Set icon
	var icon_path = config.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Hide icon if no texture available
		icon.visible = false

func start_entrance_animation():
# Start entrance animation
	# Start from slightly transparent and smaller
	modulate = Color(1, 1, 1, 0.8)
	scale = Vector2(0.9, 0.9)
	
	# Animate to full visibility and size
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Add slight bounce effect
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_delay(0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.3)

func _process(delta):
# Update notification lifetime and effects
	time_alive += delta
	
	# Update progress bar if visible
	if progress_bar.visible:
		var progress = 1.0 - (time_alive / lifetime)
		progress_bar.value = progress * 100
	
	# Check for fade out
	if time_alive >= (lifetime - fade_duration):
		var fade_time = time_alive - (lifetime - fade_duration)
		var fade_progress = fade_time / fade_duration
		modulate.a = 1.0 - fade_progress
	
	# Auto destroy when lifetime expires
	if auto_destroy and time_alive >= lifetime:
		destroy_notification()

func destroy_notification():
# Destroy the notification with exit animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out and scale down
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)
	
	# Remove after animation
	tween.tween_callback(queue_free).set_delay(0.3)

func show_with_progress(text: String, type: String = "info", duration: float = -1):
# Show notification with progress bar
	setup_notification(text, type, duration)
	progress_bar.visible = true
	progress_bar.value = 100

func extend_lifetime(additional_time: float):
# Extend the notification lifetime
	lifetime += additional_time

func update_text(new_text: String):
# Update the notification text
	label.text = new_text
	
	# Slight flash effect to indicate update
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color.WHITE * 1.3, 0.1)
	tween.tween_property(label, "modulate", Color.WHITE, 0.1)

func set_clickable(on_click: Callable):
# Make the notification clickable
	var button = Button.new()
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.flat = true
	button.pressed.connect(on_click)
	add_child(button)
	
	# Add hover effect
	button.mouse_entered.connect(_on_hover_entered)
	button.mouse_exited.connect(_on_hover_exited)

func _on_hover_entered():
# Handle mouse hover
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_hover_exited():
# Handle mouse exit
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# Static factory methods for common notification types
static func create_damage_number(damage: int, position: Vector2) -> PopupNotification:
# Create a damage number popup
	var popup = PopupNotification.new()
	popup.setup_notification(str(damage), "damage", 1.5)
	popup.position = position
	popup.auto_destroy = true
	
	# Add special movement for damage numbers
	var tween = popup.create_tween()
	tween.tween_property(popup, "position", position + Vector2(randf_range(-20, 20), -50), 1.5)
	
	return popup

static func create_heal_number(heal: int, position: Vector2) -> PopupNotification:
# Create a heal number popup
	var popup = PopupNotification.new()
	popup.setup_notification("+" + str(heal), "heal", 2.0)
	popup.position = position
	popup.auto_destroy = true
	
	# Add special movement for heal numbers
	var tween = popup.create_tween()
	tween.tween_property(popup, "position", position + Vector2(0, -30), 2.0)
	
	return popup

static func create_item_pickup(item_name: String, quantity: int, position: Vector2) -> PopupNotification:
# Create an item pickup popup
	var popup = PopupNotification.new()
	var text = item_name
	if quantity > 1:
		text += " x" + str(quantity)
	
	popup.setup_notification(text, "loot", 3.0)
	popup.position = position
	popup.auto_destroy = true
	
	return popup

static func create_xp_gain(xp: int, position: Vector2) -> PopupNotification:
# Create an XP gain popup
	var popup = PopupNotification.new()
	popup.setup_notification("+" + str(xp) + " XP", "xp", 2.0)
	popup.position = position
	popup.auto_destroy = true
	
	return popup

static func create_level_up(level: int, center_position: Vector2) -> PopupNotification:
# Create a level up popup
	var popup = PopupNotification.new()
	popup.setup_notification("LEVEL UP!\nLevel " + str(level), "level_up", 6.0)
	popup.position = center_position - popup.size / 2
	popup.auto_destroy = true
	
	return popup

static func create_quest_update(quest_text: String, position: Vector2) -> PopupNotification:
# Create a quest update popup
	var popup = PopupNotification.new()
	popup.setup_notification(quest_text, "info", 4.0)
	popup.position = position
	popup.auto_destroy = true
	
	return popup

# Utility functions
func get_remaining_time() -> float:
# Get remaining display time
	return max(0, lifetime - time_alive)

func is_fading() -> bool:
# Check if notification is in fade state
	return time_alive >= (lifetime - fade_duration)

func pause_timer():
# Pause the notification timer
	set_process(false)

func resume_timer():
# Resume the notification timer
	set_process(true)

# TODO: Future enhancements
# - Sound effects for different notification types
# - Stacking behavior for multiple similar notifications
# - Rich text formatting support
# - Animation easing options
# - Custom icon support from external sources
# - Notification queuing system
# - Screen edge collision detection
# - Multi-line text layout improvements
