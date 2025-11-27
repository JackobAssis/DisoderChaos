extends Control
class_name MenuSettings
# menu_settings.gd - Game settings menu with full configuration options

# UI References
@onready var master_volume_slider: HSlider
@onready var master_volume_label: Label
@onready var music_volume_slider: HSlider
@onready var music_volume_label: Label
@onready var sfx_volume_slider: HSlider
@onready var sfx_volume_label: Label

@onready var fullscreen_checkbox: CheckBox
@onready var resolution_option: OptionButton
@onready var vsync_checkbox: CheckBox

@onready var autosave_checkbox: CheckBox
@onready var autosave_interval_spinbox: SpinBox
@onready var damage_numbers_checkbox: CheckBox

# Resolution options
var resolution_list = [
	Vector2i(1280, 720),
	Vector2i(1366, 768), 
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

# Settings changed tracking
var settings_changed: bool = false
var config_manager: ConfigManager

func _ready():
	print("[Settings] Settings menu initialized")
	
	# Get config manager
	config_manager = get_node("/root/ConfigManager")
	if not config_manager:
		push_error("ConfigManager not found!")
		return
	
	setup_ui_references()
	setup_resolution_options()
	load_current_settings()
	connect_signals()

func setup_ui_references():
# Setup references to UI elements
	# Audio sliders
	master_volume_slider = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MasterVolumeContainer/MasterVolumeSlider
	master_volume_label = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MasterVolumeContainer/ValueLabel
	music_volume_slider = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolumeContainer/MusicVolumeSlider
	music_volume_label = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolumeContainer/ValueLabel
	sfx_volume_slider = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SFXVolumeContainer/SFXVolumeSlider
	sfx_volume_label = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SFXVolumeContainer/ValueLabel
	
	# Video options
	fullscreen_checkbox = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/VideoSection/FullscreenContainer/FullscreenCheckbox
	resolution_option = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/VideoSection/ResolutionContainer/ResolutionOption
	vsync_checkbox = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/VideoSection/VSyncContainer/VSyncCheckbox
	
	# Gameplay options
	autosave_checkbox = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/AutosaveContainer/AutosaveCheckbox
	autosave_interval_spinbox = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/AutosaveIntervalContainer/AutosaveIntervalSpinBox
	damage_numbers_checkbox = $SettingsPanel/VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/DamageNumbersContainer/DamageNumbersCheckbox

func setup_resolution_options():
# Setup resolution dropdown options
	resolution_option.clear()
	
	for resolution in resolution_list:
		var text = str(resolution.x) + " x " + str(resolution.y)
		resolution_option.add_item(text)

func load_current_settings():
# Load current settings into UI
	if not config_manager:
		return
	
	# Audio settings
	master_volume_slider.value = config_manager.get_setting("audio", "master_volume", 80.0)
	music_volume_slider.value = config_manager.get_setting("audio", "music_volume", 70.0)
	sfx_volume_slider.value = config_manager.get_setting("audio", "sfx_volume", 90.0)
	
	# Video settings
	fullscreen_checkbox.button_pressed = config_manager.get_setting("video", "fullscreen", false)
	vsync_checkbox.button_pressed = config_manager.get_setting("video", "vsync", true)
	
	# Set current resolution
	var current_resolution = Vector2i(
		config_manager.get_setting("video", "resolution_width", 1280),
		config_manager.get_setting("video", "resolution_height", 720)
	)
	
	var resolution_index = resolution_list.find(current_resolution)
	if resolution_index >= 0:
		resolution_option.selected = resolution_index
	
	# Gameplay settings
	autosave_checkbox.button_pressed = config_manager.get_setting("gameplay", "autosave_enabled", true)
	autosave_interval_spinbox.value = config_manager.get_setting("gameplay", "autosave_interval", 5.0)
	damage_numbers_checkbox.button_pressed = config_manager.get_setting("gameplay", "show_damage_numbers", true)
	
	# Update volume labels
	update_volume_labels()

func connect_signals():
# Connect additional signals if needed
	# Settings change tracking
	master_volume_slider.value_changed.connect(_on_setting_changed)
	music_volume_slider.value_changed.connect(_on_setting_changed)
	sfx_volume_slider.value_changed.connect(_on_setting_changed)
	fullscreen_checkbox.toggled.connect(_on_setting_changed_bool)
	vsync_checkbox.toggled.connect(_on_setting_changed_bool)
	autosave_checkbox.toggled.connect(_on_setting_changed_bool)
	autosave_interval_spinbox.value_changed.connect(_on_setting_changed)
	damage_numbers_checkbox.toggled.connect(_on_setting_changed_bool)

func update_volume_labels():
# Update volume percentage labels
	master_volume_label.text = str(int(master_volume_slider.value)) + "%"
	music_volume_label.text = str(int(music_volume_slider.value)) + "%"
	sfx_volume_label.text = str(int(sfx_volume_slider.value)) + "%"

# Signal handlers
func _on_master_volume_slider_value_changed(value):
# Handle master volume change
	master_volume_label.text = str(int(value)) + "%"
	config_manager.set_setting("audio", "master_volume", value)
	apply_audio_settings()

func _on_music_volume_slider_value_changed(value):
# Handle music volume change
	music_volume_label.text = str(int(value)) + "%"
	config_manager.set_setting("audio", "music_volume", value)
	apply_audio_settings()

func _on_sfx_volume_slider_value_changed(value):
# Handle SFX volume change
	sfx_volume_label.text = str(int(value)) + "%"
	config_manager.set_setting("audio", "sfx_volume", value)
	apply_audio_settings()

func _on_fullscreen_checkbox_toggled(button_pressed):
# Handle fullscreen toggle
	config_manager.set_setting("video", "fullscreen", button_pressed)
	apply_video_settings()

func _on_resolution_option_item_selected(index):
# Handle resolution selection
	if index >= 0 and index < resolution_list.size():
		var selected_resolution = resolution_list[index]
		config_manager.set_setting("video", "resolution_width", selected_resolution.x)
		config_manager.set_setting("video", "resolution_height", selected_resolution.y)
		apply_video_settings()

func _on_vsync_checkbox_toggled(button_pressed):
# Handle VSync toggle
	config_manager.set_setting("video", "vsync", button_pressed)
	apply_video_settings()

func _on_autosave_checkbox_toggled(button_pressed):
# Handle autosave toggle
	config_manager.set_setting("gameplay", "autosave_enabled", button_pressed)
	autosave_interval_spinbox.editable = button_pressed

func _on_autosave_interval_spin_box_value_changed(value):
# Handle autosave interval change
	config_manager.set_setting("gameplay", "autosave_interval", value)

func _on_damage_numbers_checkbox_toggled(button_pressed):
# Handle damage numbers toggle
	config_manager.set_setting("gameplay", "show_damage_numbers", button_pressed)

func _on_reset_button_pressed():
# Reset all settings to defaults
	show_confirmation_dialog("Reset all settings to defaults?", reset_to_defaults)

func _on_apply_button_pressed():
# Apply current settings
	apply_all_settings()
	settings_changed = false
	EventBus.show_notification("Settings applied", "success")

func _on_close_button_pressed():
# Close settings menu
	if settings_changed:
		show_confirmation_dialog("You have unsaved changes. Close without saving?", close_settings)
	else:
		close_settings()

func _on_setting_changed(_value):
# Track that settings have changed
	settings_changed = true

func _on_setting_changed_bool(_pressed):
# Track that settings have changed (bool version)
	settings_changed = true

# Settings application
func apply_all_settings():
# Apply all settings to the game
	apply_audio_settings()
	apply_video_settings()
	apply_gameplay_settings()
	
	# Save settings to file
	config_manager.save_settings()

func apply_audio_settings():
# Apply audio settings immediately
	var master_volume = master_volume_slider.value / 100.0
	var music_volume = music_volume_slider.value / 100.0
	var sfx_volume = sfx_volume_slider.value / 100.0
	
	# Apply to audio buses
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	
	if AudioServer.get_bus_index("Music") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	
	if AudioServer.get_bus_index("SFX") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))

func apply_video_settings():
# Apply video settings immediately
	# Fullscreen
	if fullscreen_checkbox.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# Resolution
	var selected_index = resolution_option.selected
	if selected_index >= 0 and selected_index < resolution_list.size():
		var resolution = resolution_list[selected_index]
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_size(resolution)
	
	# VSync
	if vsync_checkbox.button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func apply_gameplay_settings():
# Apply gameplay settings
	# Autosave settings are applied through ConfigManager
	# Damage numbers setting is used by the UI system
	
	# Update autosave timer if GameState has one
	if GameState.has_method("set_autosave_interval"):
		GameState.set_autosave_interval(autosave_interval_spinbox.value * 60) # Convert to seconds

func reset_to_defaults():
# Reset all settings to default values
	# Audio defaults
	master_volume_slider.value = 80.0
	music_volume_slider.value = 70.0
	sfx_volume_slider.value = 90.0
	
	# Video defaults
	fullscreen_checkbox.button_pressed = false
	resolution_option.selected = 0  # 1280x720
	vsync_checkbox.button_pressed = true
	
	# Gameplay defaults
	autosave_checkbox.button_pressed = true
	autosave_interval_spinbox.value = 5.0
	damage_numbers_checkbox.button_pressed = true
	
	# Update labels
	update_volume_labels()
	
	# Save defaults
	config_manager.reset_to_defaults()
	apply_all_settings()
	
	settings_changed = false
	EventBus.show_notification("Settings reset to defaults", "info")

func close_settings():
# Close the settings menu
	# Hide the settings menu
	visible = false
	
	# If this is a popup, queue_free it
	if get_parent().name == "PopupLayer" or get_parent() == get_tree().current_scene:
		queue_free()

func show_confirmation_dialog(message: String, callback: Callable):
# Show confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.add_button("Yes", true, "yes")
	dialog.add_button("No", false, "no")
	
	add_child(dialog)
	dialog.popup_centered()
	
	# Connect signals
	dialog.custom_action.connect(_on_confirmation_dialog_action.bind(dialog, callback))
	dialog.confirmed.connect(callback)

func _on_confirmation_dialog_action(dialog: AcceptDialog, callback: Callable, action: String):
# Handle confirmation dialog actions
	if action == "yes":
		callback.call()
	
	dialog.queue_free()

# Utility functions
func get_current_settings() -> Dictionary:
# Get current settings as dictionary
	return {
		"audio": {
			"master_volume": master_volume_slider.value,
			"music_volume": music_volume_slider.value,
			"sfx_volume": sfx_volume_slider.value
		},
		"video": {
			"fullscreen": fullscreen_checkbox.button_pressed,
			"resolution_index": resolution_option.selected,
			"vsync": vsync_checkbox.button_pressed
		},
		"gameplay": {
			"autosave_enabled": autosave_checkbox.button_pressed,
			"autosave_interval": autosave_interval_spinbox.value,
			"show_damage_numbers": damage_numbers_checkbox.button_pressed
		}
	}

func load_settings_from_dict(settings_dict: Dictionary):
# Load settings from dictionary
	if settings_dict.has("audio"):
		var audio = settings_dict.audio
		master_volume_slider.value = audio.get("master_volume", 80.0)
		music_volume_slider.value = audio.get("music_volume", 70.0)
		sfx_volume_slider.value = audio.get("sfx_volume", 90.0)
	
	if settings_dict.has("video"):
		var video = settings_dict.video
		fullscreen_checkbox.button_pressed = video.get("fullscreen", false)
		resolution_option.selected = video.get("resolution_index", 0)
		vsync_checkbox.button_pressed = video.get("vsync", true)
	
	if settings_dict.has("gameplay"):
		var gameplay = settings_dict.gameplay
		autosave_checkbox.button_pressed = gameplay.get("autosave_enabled", true)
		autosave_interval_spinbox.value = gameplay.get("autosave_interval", 5.0)
		damage_numbers_checkbox.button_pressed = gameplay.get("show_damage_numbers", true)
	
	update_volume_labels()

func validate_settings() -> bool:
# Validate current settings
	# Check if resolution is valid
	if resolution_option.selected < 0 or resolution_option.selected >= resolution_list.size():
		return false
	
	# Check volume ranges
	if master_volume_slider.value < 0 or master_volume_slider.value > 100:
		return false
	
	# Check autosave interval
	if autosave_interval_spinbox.value < 1 or autosave_interval_spinbox.value > 30:
		return false
	
	return true

# Input handling
func _input(event):
# Handle input events
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_button_pressed()

# TODO: Future enhancements
# - Key binding configuration
# - Graphics quality presets
# - Accessibility options
# - Language selection
# - Advanced audio settings (individual channel volumes)
# - Game-specific settings (combat preferences, UI layout)
# - Profile-based settings
# - Settings import/export
