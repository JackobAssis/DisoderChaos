extends Control
class_name SaveLoadUI
# SaveLoadUI.gd - User interface for save/load system
# Provides comprehensive save slot management, load confirmations, and save information display

# UI References
@onready var save_slots_container: VBoxContainer = $SaveSlotsPanel/ScrollContainer/VBoxContainer
@onready var save_button: Button = $ActionsPanel/SaveButton
@onready var load_button: Button = $ActionsPanel/LoadButton
@onready var delete_button: Button = $ActionsPanel/DeleteButton
@onready var quick_save_button: Button = $ActionsPanel/QuickSaveButton
@onready var auto_save_toggle: CheckBox = $ActionsPanel/AutoSaveToggle
@onready var save_info_panel: Panel = $SaveInfoPanel
@onready var save_info_label: RichTextLabel = $SaveInfoPanel/SaveInfoLabel
@onready var confirmation_dialog: ConfirmationDialog = $ConfirmationDialog
@onready var new_save_dialog: AcceptDialog = $NewSaveDialog
@onready var save_name_input: LineEdit = $NewSaveDialog/VBoxContainer/NameInput

# Save system references
var game_state: Node
var save_integration: SaveIntegration
var selected_slot: int = -1
var save_slots_data: Array = []

# UI Configuration
var max_displayed_slots: int = 10
var save_slot_scene: PackedScene = preload("res://ui/components/SaveSlot.tscn")

signal save_slot_selected(slot: int)
signal save_requested(slot: int)
signal load_requested(slot: int)
signal delete_requested(slot: int)

func _ready():
	print("[SaveLoadUI] Initializing save/load interface")
	
	# Get references
	game_state = get_node("/root/GameState")
	save_integration = get_node("/root/SaveIntegration") if get_node_or_null("/root/SaveIntegration") else null
	
	# Setup UI
	setup_ui_connections()
	refresh_save_slots()
	update_ui_state()
	
	# Connect to EventBus
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.save_deleted.connect(_on_save_deleted)
	
	print("[SaveLoadUI] Save/Load UI ready")

func setup_ui_connections():
	# Connect UI signals
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	quick_save_button.pressed.connect(_on_quick_save_pressed)
	auto_save_toggle.toggled.connect(_on_auto_save_toggled)
	
	confirmation_dialog.confirmed.connect(_on_confirmation_confirmed)
	new_save_dialog.confirmed.connect(_on_new_save_confirmed)

func refresh_save_slots():
	# Refresh the display of save slots
	print("[SaveLoadUI] Refreshing save slots display")
	
	# Clear existing slots
	for child in save_slots_container.get_children():
		child.queue_free()
	
	# Get save slots data
	if game_state:
		save_slots_data = game_state.get_save_slots()
	
	# Create slot UI elements
	for i in range(max_displayed_slots):
		create_save_slot_ui(i)
	
	update_save_info_display()

func create_save_slot_ui(slot_index: int):
	# Create UI element for a save slot
	var slot_container = HBoxContainer.new()
	slot_container.custom_minimum_size = Vector2(500, 80)
	
	# Slot button
	var slot_button = Button.new()
	slot_button.custom_minimum_size = Vector2(400, 80)
	slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Find save data for this slot
	var save_data = null
	for save in save_slots_data:
		if save.slot == slot_index:
			save_data = save
			break
	
	if save_data:
		# Populated slot
		var save_text = format_save_slot_text(save_data)
		slot_button.text = save_text
		slot_button.modulate = Color.WHITE
	else:
		# Empty slot
		slot_button.text = "Slot " + str(slot_index) + "\n[Empty]"
		slot_button.modulate = Color.GRAY
	
	slot_button.pressed.connect(_on_save_slot_selected.bind(slot_index))
	
	# Quick actions
	var actions_container = VBoxContainer.new()
	actions_container.custom_minimum_size = Vector2(100, 80)
	
	var quick_load_btn = Button.new()
	quick_load_btn.text = "Load"
	quick_load_btn.custom_minimum_size = Vector2(80, 25)
	quick_load_btn.disabled = save_data == null
	quick_load_btn.pressed.connect(_on_quick_load_pressed.bind(slot_index))
	
	var quick_save_btn = Button.new()
	quick_save_btn.text = "Save"
	quick_save_btn.custom_minimum_size = Vector2(80, 25)
	quick_save_btn.pressed.connect(_on_quick_save_to_slot_pressed.bind(slot_index))
	
	var quick_delete_btn = Button.new()
	quick_delete_btn.text = "Del"
	quick_delete_btn.custom_minimum_size = Vector2(80, 25)
	quick_delete_btn.disabled = save_data == null
	quick_delete_btn.modulate = Color.LIGHT_CORAL
	quick_delete_btn.pressed.connect(_on_quick_delete_pressed.bind(slot_index))
	
	actions_container.add_child(quick_load_btn)
	actions_container.add_child(quick_save_btn)
	actions_container.add_child(quick_delete_btn)
	
	slot_container.add_child(slot_button)
	slot_container.add_child(actions_container)
	save_slots_container.add_child(slot_container)

func format_save_slot_text(save_data: Dictionary) -> String:
	# Format save slot display text
	var text = "Slot " + str(save_data.slot) + "\n"
	
	# Player info
	if "player_level" in save_data:
		text += "Level " + str(save_data.player_level) + " " + str(save_data.get("player_class", "Hero"))
	
	# Location info
	if "location" in save_data:
		text += " • " + str(save_data.location)
	
	text += "\n"
	
	# Timestamp
	if "timestamp" in save_data:
		var datetime = Time.get_datetime_dict_from_unix_time(save_data.timestamp)
		text += "%02d/%02d/%d %02d:%02d" % [datetime.day, datetime.month, datetime.year, datetime.hour, datetime.minute]
	
	# Play time
	if "play_time" in save_data:
		text += " • " + format_play_time(save_data.play_time)
	
	return text

func format_play_time(seconds: float) -> String:
	# Format play time for display
	var total_seconds = int(seconds)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes

func update_save_info_display():
	# Update the save information panel
	if selected_slot == -1:
		save_info_label.text = "Select a save slot to view details"
		return
	
	var save_data = null
	for save in save_slots_data:
		if save.slot == selected_slot:
			save_data = save
			break
	
	if not save_data:
		save_info_label.text = "Empty save slot"
		return
	
	var info_text = "[b]Save Slot " + str(selected_slot) + "[/b]\n\n"
	
	# Player information
	if "player_level" in save_data:
		info_text += "[b]Player:[/b] Level " + str(save_data.player_level)
		if "player_class" in save_data:
			info_text += " " + str(save_data.player_class)
		if "player_race" in save_data:
			info_text += " (" + str(save_data.player_race) + ")"
		info_text += "\n"
	
	# Progress information
	if "location" in save_data:
		info_text += "[b]Location:[/b] " + str(save_data.location) + "\n"
	
	if "progress" in save_data:
		info_text += "[b]Progress:[/b] " + str(save_data.progress) + "%\n"
	
	# Game statistics
	if "play_time" in save_data:
		info_text += "[b]Play Time:[/b] " + format_play_time(save_data.play_time) + "\n"
	
	if "save_count" in save_data:
		info_text += "[b]Saves:[/b] " + str(save_data.save_count) + "\n"
	
	# File information
	if "file_size" in save_data:
		info_text += "[b]File Size:[/b] " + format_file_size(save_data.file_size) + "\n"
	
	if "compressed" in save_data:
		info_text += "[b]Compressed:[/b] " + ("Yes" if save_data.compressed else "No") + "\n"
	
	if "version" in save_data:
		info_text += "[b]Save Version:[/b] " + str(save_data.version) + "\n"
	
	# Timestamp
	if "timestamp" in save_data:
		var datetime = Time.get_datetime_dict_from_unix_time(save_data.timestamp)
		info_text += "[b]Last Saved:[/b] %02d/%02d/%d at %02d:%02d" % [
			datetime.day, datetime.month, datetime.year, datetime.hour, datetime.minute
		]
	
	save_info_label.text = info_text

func format_file_size(bytes: int) -> String:
	# Format file size for display
	if bytes < 1024:
		return str(bytes) + " B"
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	else:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))

func update_ui_state():
	# Update UI button states based on selection
	var has_selection = selected_slot != -1
	var has_save_data = false
	
	if has_selection:
		for save in save_slots_data:
			if save.slot == selected_slot:
				has_save_data = true
				break
	
	load_button.disabled = not (has_selection and has_save_data)
	delete_button.disabled = not (has_selection and has_save_data)
	save_button.disabled = not has_selection
	
	# Update auto-save toggle
	if save_integration:
		var status = save_integration.get_save_system_status()
		auto_save_toggle.button_pressed = status.auto_save_enabled

# Signal handlers
func _on_save_slot_selected(slot: int):
	# Handle save slot selection
	selected_slot = slot
	update_save_info_display()
	update_ui_state()
	save_slot_selected.emit(slot)
	print("[SaveLoadUI] Selected save slot: ", slot)

func _on_save_button_pressed():
	# Handle save button press
	if selected_slot != -1:
		save_name_input.text = "Save " + str(selected_slot)
		new_save_dialog.popup_centered()

func _on_load_button_pressed():
	# Handle load button press
	if selected_slot != -1:
		confirmation_dialog.dialog_text = "Load save slot " + str(selected_slot) + "?\nAny unsaved progress will be lost."
		confirmation_dialog.popup_centered()

func _on_delete_button_pressed():
	# Handle delete button press
	if selected_slot != -1:
		confirmation_dialog.dialog_text = "Delete save slot " + str(selected_slot) + "?\nThis action cannot be undone."
		confirmation_dialog.popup_centered()

func _on_quick_save_pressed():
	# Handle quick save button press
	if save_integration:
		await save_integration.request_quick_save()

func _on_quick_load_pressed(slot: int):
	# Handle quick load for specific slot
	load_requested.emit(slot)
	if game_state:
		var result = game_state.load_game(slot)
		if result:
			get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_quick_save_to_slot_pressed(slot: int):
	# Handle quick save to specific slot
	save_requested.emit(slot)
	if save_integration:
		await save_integration.request_manual_save(slot, false)
		refresh_save_slots()

func _on_quick_delete_pressed(slot: int):
	# Handle quick delete for specific slot
	if game_state:
		game_state.delete_save(slot)

func _on_auto_save_toggled(enabled: bool):
	# Handle auto-save toggle
	if save_integration:
		save_integration.set_auto_save_enabled(enabled)
		EventBus.show_notification("Auto-save " + ("enabled" if enabled else "disabled"), "info")

func _on_confirmation_confirmed():
	# Handle confirmation dialog
	if "Load save slot" in confirmation_dialog.dialog_text:
		# Load confirmation
		load_requested.emit(selected_slot)
		if game_state:
			var result = game_state.load_game(selected_slot)
			if result:
				get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	elif "Delete save slot" in confirmation_dialog.dialog_text:
		# Delete confirmation
		delete_requested.emit(selected_slot)
		if game_state:
			game_state.delete_save(selected_slot)

func _on_new_save_confirmed():
	# Handle new save confirmation
	if selected_slot != -1:
		save_requested.emit(selected_slot)
		if save_integration:
			await save_integration.request_manual_save(selected_slot, false)
			refresh_save_slots()

# EventBus signal handlers
func _on_game_saved(slot: int):
	# Handle game saved event
	EventBus.show_notification("Game saved to slot " + str(slot), "success")
	refresh_save_slots()

func _on_game_loaded():
	# Handle game loaded event
	EventBus.show_notification("Game loaded successfully", "success")

func _on_save_deleted(slot: int):
	# Handle save deleted event
	EventBus.show_notification("Save slot " + str(slot) + " deleted", "info")
	if selected_slot == slot:
		selected_slot = -1
	refresh_save_slots()

# Public API
func show_save_interface():
	# Show the save interface
	refresh_save_slots()
	show()

func hide_save_interface():
	# Hide the save interface
	hide()

func set_auto_save_enabled(enabled: bool):
	# Set auto-save enabled from external source
	auto_save_toggle.button_pressed = enabled
	_on_auto_save_toggled(enabled)

# Keyboard shortcuts
func _input(event):
	if not visible:
		return
		
	if event.is_action_pressed("quick_save"):
		_on_quick_save_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		if selected_slot != -1:
			_on_quick_load_pressed(selected_slot)
		get_viewport().set_input_as_handled()