extends Node
class_name ConfigManager
# config_manager.gd - Comprehensive configuration management system

# Configuration file path
const CONFIG_FILE_PATH = "user://game_config.cfg"

# Configuration sections
var config: ConfigFile
var default_settings: Dictionary = {}

# Settings changed tracking
var settings_dirty: bool = false
var autosave_timer: Timer

func _ready():
	print("[ConfigManager] Configuration manager initialized")
	setup_default_settings()
	config = ConfigFile.new()
	load_settings()
	setup_autosave()

func setup_default_settings():
# Setup default configuration values
	default_settings = {
		"audio": {
			"master_volume": 80.0,
			"music_volume": 70.0,
			"sfx_volume": 90.0,
			"voice_volume": 80.0,
			"mute_when_unfocused": true
		},
		"video": {
			"fullscreen": false,
			"resolution_width": 1280,
			"resolution_height": 720,
			"vsync": true,
			"fps_limit": 60,
			"quality_preset": "medium"
		},
		"gameplay": {
			"autosave_enabled": true,
			"autosave_interval": 5.0,
			"show_damage_numbers": true,
			"show_xp_numbers": true,
			"show_loot_notifications": true,
			"combat_text_size": 1.0,
			"ui_scale": 1.0
		},
		"controls": {
			"mouse_sensitivity": 1.0,
			"invert_mouse_y": false,
			"auto_target": true,
			"hold_to_move": false
		},
		"accessibility": {
			"colorblind_mode": "none",
			"high_contrast": false,
			"large_text": false,
			"screen_flash": true,
			"screen_shake": true
		},
		"interface": {
			"show_minimap": true,
			"show_quest_tracker": true,
			"show_tooltips": true,
			"tooltip_delay": 0.5,
			"chat_opacity": 0.8
		}
	}

func setup_autosave():
# Setup autosave timer for settings
	autosave_timer = Timer.new()
	autosave_timer.timeout.connect(save_settings_if_dirty)
	autosave_timer.wait_time = 10.0  # Save every 10 seconds if dirty
	autosave_timer.autostart = true
	add_child(autosave_timer)

func load_settings():
# Load settings from configuration file
	var error = config.load(CONFIG_FILE_PATH)
	
	if error != OK:
		print("[ConfigManager] No config file found or error loading, using defaults")
		apply_default_settings()
		save_settings()
	else:
		print("[ConfigManager] Configuration loaded successfully")
		validate_loaded_settings()

func apply_default_settings():
# Apply default settings to config
	for section in default_settings:
		for key in default_settings[section]:
			var value = default_settings[section][key]
			config.set_value(section, key, value)

func validate_loaded_settings():
# Validate loaded settings and fill missing ones with defaults
	for section_name in default_settings:
		for key in default_settings[section_name]:
			if not config.has_section_key(section_name, key):
				var default_value = default_settings[section_name][key]
				config.set_value(section_name, key, default_value)
				print("[ConfigManager] Added missing setting: ", section_name, ".", key, " = ", default_value)

func save_settings():
# Save current settings to file
	var error = config.save(CONFIG_FILE_PATH)
	
	if error != OK:
		push_error("[ConfigManager] Failed to save configuration: " + str(error))
		return false
	
	print("[ConfigManager] Settings saved successfully")
	settings_dirty = false
	return true

func save_settings_if_dirty():
# Save settings only if they have been modified
	if settings_dirty:
		save_settings()

func get_setting(section: String, key: String, default_value = null):
# Get a setting value with optional default
	if not config.has_section_key(section, key):
		if default_value != null:
			return default_value
		elif section in default_settings and key in default_settings[section]:
			return default_settings[section][key]
		else:
			push_warning("[ConfigManager] Setting not found: " + section + "." + key)
			return null
	
	return config.get_value(section, key)

func set_setting(section: String, key: String, value):
# Set a setting value
	config.set_value(section, key, value)
	settings_dirty = true
	
	# Apply setting immediately if it's a critical one
	apply_critical_setting(section, key, value)

func apply_critical_setting(section: String, key: String, value):
# Apply critical settings immediately without restart
	match section:
		"audio":
			apply_audio_setting(key, value)
		"video":
			apply_video_setting(key, value)
		"gameplay":
			apply_gameplay_setting(key, value)

func apply_audio_setting(key: String, value):
# Apply audio setting immediately
	match key:
		"master_volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
		"music_volume":
			var music_bus = AudioServer.get_bus_index("Music")
			if music_bus >= 0:
				AudioServer.set_bus_volume_db(music_bus, linear_to_db(value / 100.0))
		"sfx_volume":
			var sfx_bus = AudioServer.get_bus_index("SFX")
			if sfx_bus >= 0:
				AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value / 100.0))

func apply_video_setting(key: String, value):
# Apply video setting immediately
	match key:
		"vsync":
			if value:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"fps_limit":
			Engine.max_fps = value

func apply_gameplay_setting(key: String, value):
# Apply gameplay setting immediately
	match key:
		"autosave_interval":
			if GameState.has_method("set_autosave_interval"):
				GameState.set_autosave_interval(value * 60.0)  # Convert to seconds

func get_section_settings(section: String) -> Dictionary:
# Get all settings from a section
	var section_settings = {}
	
	if config.has_section(section):
		for key in config.get_section_keys(section):
			section_settings[key] = config.get_value(section, key)
	
	return section_settings

func set_section_settings(section: String, settings: Dictionary):
# Set multiple settings in a section
	for key in settings:
		set_setting(section, key, settings[key])

func reset_section_to_defaults(section: String):
# Reset a specific section to default values
	if section in default_settings:
		for key in default_settings[section]:
			set_setting(section, key, default_settings[section][key])
		print("[ConfigManager] Reset section to defaults: ", section)

func reset_to_defaults():
# Reset all settings to default values
	apply_default_settings()
	settings_dirty = true
	save_settings()
	print("[ConfigManager] All settings reset to defaults")

func has_setting(section: String, key: String) -> bool:
# Check if a setting exists
	return config.has_section_key(section, key)

func remove_setting(section: String, key: String):
# Remove a setting
	if config.has_section_key(section, key):
		# ConfigFile doesn't have a direct remove method, so we recreate without the key
		var section_keys = config.get_section_keys(section)
		var temp_values = {}
		
		for k in section_keys:
			if k != key:
				temp_values[k] = config.get_value(section, k)
		
		# Clear section and re-add values except the removed key
		for k in section_keys:
			if k == key:
				config.set_value(section, k, null)
		
		for k in temp_values:
			config.set_value(section, k, temp_values[k])
		
		settings_dirty = true

func export_settings() -> String:
# Export settings to JSON string
	var settings_dict = {}
	
	for section in config.get_sections():
		settings_dict[section] = get_section_settings(section)
	
	return JSON.stringify(settings_dict, "\t")

func import_settings(json_string: String) -> bool:
# Import settings from JSON string
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[ConfigManager] Failed to parse settings JSON")
		return false
	
	var settings_dict = json.data
	if typeof(settings_dict) != TYPE_DICTIONARY:
		push_error("[ConfigManager] Invalid settings format")
		return false
	
	# Import settings
	for section in settings_dict:
		if typeof(settings_dict[section]) == TYPE_DICTIONARY:
			set_section_settings(section, settings_dict[section])
	
	save_settings()
	print("[ConfigManager] Settings imported successfully")
	return true

func backup_settings() -> bool:
# Create a backup of current settings
	var backup_path = CONFIG_FILE_PATH + ".backup"
	var error = config.save(backup_path)
	
	if error != OK:
		push_error("[ConfigManager] Failed to backup settings: " + str(error))
		return false
	
	print("[ConfigManager] Settings backed up to: ", backup_path)
	return true

func restore_from_backup() -> bool:
# Restore settings from backup
	var backup_path = CONFIG_FILE_PATH + ".backup"
	
	if not FileAccess.file_exists(backup_path):
		push_error("[ConfigManager] Backup file not found")
		return false
	
	var backup_config = ConfigFile.new()
	var error = backup_config.load(backup_path)
	
	if error != OK:
		push_error("[ConfigManager] Failed to load backup: " + str(error))
		return false
	
	# Copy backup to main config
	config = backup_config
	save_settings()
	
	print("[ConfigManager] Settings restored from backup")
	return true

# Settings validation
func validate_setting(section: String, key: String, value) -> bool:
# Validate a setting value
	match section:
		"audio":
			return validate_audio_setting(key, value)
		"video":
			return validate_video_setting(key, value)
		"gameplay":
			return validate_gameplay_setting(key, value)
		"controls":
			return validate_controls_setting(key, value)
	
	return true  # Default: allow any value

func validate_audio_setting(key: String, value) -> bool:
# Validate audio settings
	match key:
		"master_volume", "music_volume", "sfx_volume", "voice_volume":
			return typeof(value) == TYPE_FLOAT and value >= 0.0 and value <= 100.0
		"mute_when_unfocused":
			return typeof(value) == TYPE_BOOL
	
	return true

func validate_video_setting(key: String, value) -> bool:
# Validate video settings
	match key:
		"fullscreen", "vsync":
			return typeof(value) == TYPE_BOOL
		"resolution_width", "resolution_height":
			return typeof(value) == TYPE_INT and value > 0
		"fps_limit":
			return typeof(value) == TYPE_INT and value >= 30 and value <= 240
		"quality_preset":
			return value in ["low", "medium", "high", "ultra"]
	
	return true

func validate_gameplay_setting(key: String, value) -> bool:
# Validate gameplay settings
	match key:
		"autosave_enabled", "show_damage_numbers", "show_xp_numbers", "show_loot_notifications":
			return typeof(value) == TYPE_BOOL
		"autosave_interval":
			return typeof(value) == TYPE_FLOAT and value >= 1.0 and value <= 30.0
		"combat_text_size", "ui_scale":
			return typeof(value) == TYPE_FLOAT and value >= 0.5 and value <= 2.0
	
	return true

func validate_controls_setting(key: String, value) -> bool:
# Validate controls settings
	match key:
		"mouse_sensitivity":
			return typeof(value) == TYPE_FLOAT and value >= 0.1 and value <= 5.0
		"invert_mouse_y", "auto_target", "hold_to_move":
			return typeof(value) == TYPE_BOOL
	
	return true

# Utility functions
func get_config_file_path() -> String:
# Get the full path to config file
	return CONFIG_FILE_PATH

func get_config_file_size() -> int:
# Get config file size in bytes
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
	if file:
		var size = file.get_length()
		file.close()
		return size
	return 0

func print_current_settings():
# Print all current settings to console (for debugging)
	print("[ConfigManager] Current Settings:")
	for section in config.get_sections():
		print("  [", section, "]")
		for key in config.get_section_keys(section):
			var value = config.get_value(section, key)
			print("    ", key, " = ", value)

# Events and notifications
signal settings_loaded
signal settings_saved
signal setting_changed(section: String, key: String, value)

func emit_setting_changed(section: String, key: String, value):
# Emit setting changed signal
	setting_changed.emit(section, key, value)

# TODO: Future enhancements
# - Settings synchronization across devices
# - Cloud settings backup
# - Settings profiles/presets
# - Settings migration for version updates
# - Settings encryption for sensitive data
# - Performance monitoring for settings impact
# - A/B testing for default values
# - Settings analytics and usage tracking
