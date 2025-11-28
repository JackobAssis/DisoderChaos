extends Control
class_name SaveSlot
# SaveSlot.gd - Individual save slot component
# Displays save slot information and handles interaction

# UI References
@onready var background: Panel = $Background
@onready var slot_number_label: Label = $SlotNumber
@onready var save_info_container: VBoxContainer = $SaveInfo
@onready var player_info_label: Label = $SaveInfo/PlayerInfo
@onready var location_label: Label = $SaveInfo/LocationInfo
@onready var timestamp_label: Label = $SaveInfo/TimestampInfo
@onready var empty_label: Label = $EmptyLabel
@onready var action_buttons: HBoxContainer = $ActionButtons
@onready var load_button: Button = $ActionButtons/LoadButton
@onready var save_button: Button = $ActionButtons/SaveButton
@onready var delete_button: Button = $ActionButtons/DeleteButton

# Save data
var slot_index: int = -1
var save_data: Dictionary = {}
var is_empty: bool = true
var is_selected: bool = false

# Colors
var normal_color = Color(0.2, 0.2, 0.2, 0.8)
var selected_color = Color(0.3, 0.4, 0.6, 0.9)
var empty_color = Color(0.15, 0.15, 0.15, 0.6)
var hover_color = Color(0.25, 0.25, 0.25, 0.8)

signal slot_selected(slot_index: int)
signal save_requested(slot_index: int)
signal load_requested(slot_index: int)
signal delete_requested(slot_index: int)

func _ready():
	# Setup UI
	setup_ui()
	
	# Connect signals
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	
	# Setup mouse detection
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func setup_ui():
	# Setup initial UI state
	custom_minimum_size = Vector2(500, 100)
	
	# Background panel
	if not background:
		background = Panel.new()
		add_child(background)
		move_child(background, 0)
	
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	update_visual_state()

func configure_slot(index: int, data: Dictionary = {}):
	# Configure the save slot with data
	slot_index = index
	save_data = data
	is_empty = data.is_empty()
	
	update_display()
	update_visual_state()

func update_display():
	# Update the display based on save data
	# Slot number
	slot_number_label.text = str(slot_index)
	
	if is_empty:
		# Empty slot
		save_info_container.hide()
		empty_label.show()
		empty_label.text = "Empty Slot"
		
		# Button states
		load_button.disabled = true
		delete_button.disabled = true
		save_button.disabled = false
	else:
		# Populated slot
		save_info_container.show()
		empty_label.hide()
		
		# Player information
		var player_text = ""
		if "player_level" in save_data:
			player_text += "Level " + str(save_data.player_level)
		if "player_class" in save_data:
			player_text += " " + str(save_data.player_class)
		if "player_race" in save_data:
			player_text += " (" + str(save_data.player_race) + ")"
		player_info_label.text = player_text
		
		# Location information
		if "location" in save_data:
			location_label.text = "Location: " + str(save_data.location)
		else:
			location_label.text = ""
		
		# Timestamp information
		if "timestamp" in save_data:
			var datetime = Time.get_datetime_dict_from_unix_time(save_data.timestamp)
			timestamp_label.text = "%02d/%02d/%d %02d:%02d" % [
				datetime.day, datetime.month, datetime.year, datetime.hour, datetime.minute
			]
			
			# Add play time if available
			if "play_time" in save_data:
				timestamp_label.text += " • " + format_play_time(save_data.play_time)
		else:
			timestamp_label.text = ""
		
		# Button states
		load_button.disabled = false
		delete_button.disabled = false
		save_button.disabled = false

func format_play_time(seconds: float) -> String:
	# Format play time for display
	var total_seconds = int(seconds)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes

func update_visual_state():
	# Update visual appearance
	if not background:
		return
		
	var style_box = StyleBoxFlat.new()
	
	if is_selected:
		style_box.bg_color = selected_color
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color.WHITE
	elif is_empty:
		style_box.bg_color = empty_color
	else:
		style_box.bg_color = normal_color
	
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	background.add_theme_stylebox_override("panel", style_box)

func set_selected(selected: bool):
	# Set the selection state
	is_selected = selected
	update_visual_state()
	
	if selected:
		slot_selected.emit(slot_index)

func get_slot_info() -> Dictionary:
	# Get information about this slot
	return {
		"slot_index": slot_index,
		"is_empty": is_empty,
		"save_data": save_data
	}

# Signal handlers
func _on_load_pressed():
	# Handle load button press
	if not is_empty:
		load_requested.emit(slot_index)

func _on_save_pressed():
	# Handle save button press
	save_requested.emit(slot_index)

func _on_delete_pressed():
	# Handle delete button press
	if not is_empty:
		delete_requested.emit(slot_index)

func _on_mouse_entered():
	# Handle mouse entering the slot
	if not is_selected and background:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = hover_color if not is_empty else empty_color.lightened(0.1)
		style_box.corner_radius_top_left = 5
		style_box.corner_radius_top_right = 5
		style_box.corner_radius_bottom_left = 5
		style_box.corner_radius_bottom_right = 5
		background.add_theme_stylebox_override("panel", style_box)

func _on_mouse_exited():
	# Handle mouse exiting the slot
	if not is_selected:
		update_visual_state()

func _on_gui_input(event: InputEvent):
	# Handle GUI input events
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			set_selected(true)

# Animation effects
func animate_save_success():
	# Animate successful save
	var tween = create_tween()
	tween.tween_method(_set_flash_color, Color.GREEN, normal_color, 0.5)

func animate_load_success():
	# Animate successful load
	var tween = create_tween()
	tween.tween_method(_set_flash_color, Color.BLUE, normal_color, 0.5)

func animate_delete():
	# Animate deletion
	var tween = create_tween()
	tween.tween_method(_set_flash_color, Color.RED, empty_color, 0.3)
	tween.tween_callback(func(): configure_slot(slot_index, {}))

func _set_flash_color(color: Color):
	# Helper for animation
	if background:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = color
		style_box.corner_radius_top_left = 5
		style_box.corner_radius_top_right = 5
		style_box.corner_radius_bottom_left = 5
		style_box.corner_radius_bottom_right = 5
		background.add_theme_stylebox_override("panel", style_box)