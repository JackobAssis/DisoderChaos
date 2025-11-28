extends Node

class_name SaveManager

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, data: Dictionary)
signal backup_created(file_path: String)

# Save file paths
const SAVE_FILE_PATH = "user://save_data.json"
const BACKUP_FILE_PATH = "user://save_data_backup.json"
const CONFIG_FILE_PATH = "user://config.json"
const TEMP_SAVE_PATH = "user://temp_save.json"

# Save version and compatibility
const CURRENT_SAVE_VERSION = 1.2
const MIN_COMPATIBLE_VERSION = 1.0
const SAVE_MAGIC_NUMBER = "DISCORD_CHAOS_SAVE"

# Compression settings
const USE_COMPRESSION = true
const COMPRESSION_LEVEL = 6  # 1-9, higher = better compression but slower

# Save data structure template
var save_template: Dictionary = {
	"version": CURRENT_SAVE_VERSION,
	"magic_number": SAVE_MAGIC_NUMBER,
	"timestamp": 0,
	"checksum": "",
	"player_data": {},
	"world_data": {},
	"progress_data": {},
	"settings_data": {},
	"session_data": {}
}

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")

# Save operation state
var is_saving: bool = false
var is_loading: bool = false
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var auto_save_timer: Timer

func _ready():
	setup_save_manager()
	setup_auto_save()
	connect_events()
	print("[SaveManager] Sistema de Save/Load inicializado")

func setup_save_manager():
# Setup save manager configuration
	# Ensure save directory exists
	DirAccess.open("user://").make_dir_recursive("saves")
	
	# Create auto-save timer
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_on_auto_save_timer)
	add_child(auto_save_timer)

func setup_auto_save():
# Setup automatic saving
	if auto_save_enabled:
		auto_save_timer.start()

func connect_events():
# Connect to game events for save triggers
	if event_bus:
		event_bus.connect("player_level_up", _on_auto_save_trigger)
		event_bus.connect("quest_completed", _on_auto_save_trigger)
		event_bus.connect("dungeon_completed", _on_auto_save_trigger)
		event_bus.connect("significant_progress", _on_auto_save_trigger)

# Main Save Functions
func save_game(slot_name: String = "main") -> bool:
# Save current game state
	if is_saving:
		print("[SaveManager] Save already in progress")
		return false
	
	is_saving = true
	print("[SaveManager] Starting save operation...")
	
	# Create save data
	var save_data = create_save_data()
	
	# Validate save data
	if not validate_save_data(save_data):
		is_saving = false
		save_completed.emit(false, "Save data validation failed")
		return false
	
	# Create backup before saving
	create_backup()
	
	# Save to file
	var success = write_save_file(save_data, slot_name)
	
	is_saving = false
	var message = "Game saved successfully" if success else "Failed to save game"
	save_completed.emit(success, message)
	
	print("[SaveManager] Save operation completed: %s" % message)
	return success

func save_game_async(slot_name: String = "main") -> void:
# Save game asynchronously without blocking
	if is_saving:
		print("[SaveManager] Save already in progress")
		return
	
	# Start async save operation
	var callable = func(): save_game(slot_name)
	callable.call_deferred()

func load_game(slot_name: String = "main") -> bool:
# Load game state from file
	if is_loading:
		print("[SaveManager] Load already in progress")
		return false
	
	is_loading = true
	print("[SaveManager] Starting load operation...")
	
	# Read save file
	var save_data = read_save_file(slot_name)
	
	if save_data.is_empty():
		is_loading = false
		load_completed.emit(false, {})
		return false
	
	# Validate and migrate if necessary
	save_data = validate_and_migrate_save(save_data)
	
	if save_data.is_empty():
		is_loading = false
		load_completed.emit(false, {})
		return false
	
	# Apply loaded data to game
	var success = apply_loaded_data(save_data)
	
	is_loading = false
	load_completed.emit(success, save_data)
	
	var message = "Game loaded successfully" if success else "Failed to load game"
	print("[SaveManager] Load operation completed: %s" % message)
	return success

# Save Data Creation
func create_save_data() -> Dictionary:
# Create complete save data structure
	var save_data = save_template.duplicate(true)
	
	# Update metadata
	save_data.timestamp = Time.get_unix_time_from_system()
	save_data.version = CURRENT_SAVE_VERSION
	
	# Player data
	save_data.player_data = create_player_data()
	
	# World data
	save_data.world_data = create_world_data()
	
	# Progress data
	save_data.progress_data = create_progress_data()
	
	# Settings data
	save_data.settings_data = create_settings_data()
	
	# Session data
	save_data.session_data = create_session_data()
	
	# Generate checksum for integrity
	save_data.checksum = generate_checksum(save_data)
	
	return save_data

func create_player_data() -> Dictionary:
# Create player-specific save data
	var player_data = {}
	
	if not game_state or not game_state.player_stats:
		return player_data
	
	var stats = game_state.player_stats
	
	# Basic player info
	player_data.name = game_state.player_name
	player_data.race = stats.race
	player_data.character_class = stats.character_class
	player_data.created_at = game_state.character_created_time
	
	# Level and experience
	player_data.level = stats.current_level
	player_data.experience = stats.experience
	player_data.experience_to_next_level = stats.experience_to_next_level
	player_data.skill_points_available = stats.skill_points_available
	player_data.attribute_points_available = stats.attribute_points_available
	
	# Health and resources
	player_data.current_health = stats.current_health
	player_data.max_health = stats.max_health
	player_data.current_stamina = stats.current_stamina
	player_data.max_stamina = stats.max_stamina
	player_data.current_mana = stats.current_mana
	player_data.max_mana = stats.max_mana
	
	# Primary attributes
	player_data.strength = stats.strength
	player_data.agility = stats.agility
	player_data.intelligence = stats.intelligence
	player_data.vitality = stats.vitality
	player_data.luck = stats.luck
	
	# Secondary attributes
	player_data.attack_power = stats.attack_power
	player_data.defense = stats.defense
	player_data.critical_chance = stats.critical_chance
	player_data.critical_damage = stats.critical_damage
	player_data.movement_speed = stats.movement_speed
	
	# Currency
	player_data.currency = game_state.currency
	player_data.premium_currency = game_state.get("premium_currency", 0)
	player_data.magic_fragments = game_state.get("magic_fragments", 0)
	player_data.rare_essences = game_state.get("rare_essences", 0)
	
	# Position and location
	player_data.current_location = game_state.current_location
	player_data.current_dungeon = game_state.get("current_dungeon", "")
	player_data.current_floor = game_state.get("current_floor", 1)
	player_data.spawn_point = game_state.get("spawn_point", Vector2.ZERO)
	
	# Inventory
	player_data.inventory = serialize_inventory()
	
	# Equipment
	player_data.equipment = serialize_equipment()
	
	# Skills and talents
	player_data.unlocked_skills = serialize_skills()
	player_data.skill_tree_progress = serialize_skill_trees()
	player_data.talents = serialize_talents()
	
	# Player stats and achievements
	player_data.play_time = game_state.get_play_time()
	player_data.total_deaths = stats.get("total_deaths", 0)
	player_data.total_kills = stats.get("total_kills", 0)
	player_data.dungeons_cleared = stats.get("dungeons_cleared", 0)
	player_data.bosses_defeated = stats.get("bosses_defeated", 0)
	
	return player_data

func create_world_data() -> Dictionary:
# Create world state save data
	var world_data = {}
	
	# Unlocked dungeons
	world_data.unlocked_dungeons = game_state.get("unlocked_dungeons", [])
	world_data.completed_dungeons = game_state.get("completed_dungeons", [])
	world_data.discovered_locations = game_state.get("discovered_locations", [])
	
	# World state flags
	world_data.world_flags = game_state.get("world_flags", {})
	world_data.npc_states = game_state.get("npc_states", {})
	world_data.environment_states = game_state.get("environment_states", {})
	
	# Time and weather
	world_data.game_time = game_state.get("game_time", 0.0)
	world_data.current_weather = game_state.get("current_weather", "clear")
	world_data.season = game_state.get("season", "spring")
	
	# Faction relationships
	world_data.faction_standings = game_state.get("faction_standings", {})
	
	return world_data

func create_progress_data() -> Dictionary:
# Create quest and progress save data
	var progress_data = {}
	
	# Quest progress
	progress_data.active_quests = serialize_active_quests()
	progress_data.completed_quests = game_state.get("completed_quests", [])
	progress_data.failed_quests = game_state.get("failed_quests", [])
	progress_data.available_quests = game_state.get("available_quests", [])
	
	# Story progress
	progress_data.story_flags = game_state.get("story_flags", {})
	progress_data.dialogue_history = game_state.get("dialogue_history", {})
	progress_data.choices_made = game_state.get("choices_made", {})
	
	# Collections and discoveries
	progress_data.discovered_items = game_state.get("discovered_items", [])
	progress_data.bestiary = game_state.get("bestiary", {})
	progress_data.lore_entries = game_state.get("lore_entries", [])
	
	# Achievements
	progress_data.unlocked_achievements = game_state.get("unlocked_achievements", [])
	progress_data.achievement_progress = game_state.get("achievement_progress", {})
	
	return progress_data

func create_settings_data() -> Dictionary:
# Create user settings save data
	var settings_data = {}
	
	# Graphics settings
	settings_data.graphics = {
		"fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"vsync": DisplayServer.window_get_vsync_mode(),
		"resolution": DisplayServer.window_get_size(),
		"quality_preset": ProjectSettings.get_setting("rendering/quality_preset", "medium"),
		"shadow_quality": ProjectSettings.get_setting("rendering/shadow_quality", "medium"),
		"texture_quality": ProjectSettings.get_setting("rendering/texture_quality", "high")
	}
	
	# Audio settings
	settings_data.audio = {
		"master_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")),
		"music_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),
		"sfx_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),
		"voice_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice")),
		"mute_when_unfocused": ProjectSettings.get_setting("audio/mute_when_unfocused", false)
	}
	
	# Controls settings
	settings_data.controls = {
		"mouse_sensitivity": ProjectSettings.get_setting("input/mouse_sensitivity", 1.0),
		"invert_mouse": ProjectSettings.get_setting("input/invert_mouse", false),
		"key_bindings": get_custom_key_bindings()
	}
	
	# UI settings
	settings_data.ui = {
		"ui_scale": ProjectSettings.get_setting("gui/ui_scale", 1.0),
		"show_damage_numbers": game_state.get("show_damage_numbers", true),
		"show_tooltips": game_state.get("show_tooltips", true),
		"auto_pause": game_state.get("auto_pause", false),
		"hud_opacity": game_state.get("hud_opacity", 1.0),
		"minimap_enabled": game_state.get("minimap_enabled", true)
	}
	
	# Gameplay settings
	settings_data.gameplay = {
		"difficulty": game_state.get("difficulty", "normal"),
		"auto_save_enabled": auto_save_enabled,
		"auto_save_interval": auto_save_interval,
		"tutorial_completed": game_state.get("tutorial_completed", false),
		"hints_enabled": game_state.get("hints_enabled", true)
	}
	
	return settings_data

func create_session_data() -> Dictionary:
# Create session-specific save data
	var session_data = {}
	
	# Current session info
	session_data.session_start_time = Time.get_unix_time_from_system()
	session_data.previous_session_duration = game_state.get("previous_session_duration", 0.0)
	session_data.total_sessions = game_state.get("total_sessions", 1) + 1
	
	# Temporary states
	session_data.active_buffs = serialize_active_buffs()
	session_data.cooldowns = serialize_cooldowns()
	session_data.temporary_flags = game_state.get("temporary_flags", {})
	
	# Performance data
	session_data.performance_metrics = {
		"fps_average": Engine.get_frames_per_second(),
		"memory_usage": OS.get_static_memory_usage_by_type(),
		"load_times": game_state.get("load_times", [])
	}
	
	return session_data

# Serialization Functions
func serialize_inventory() -> Array:
# Serialize inventory data
	var inventory_data = []
	
	var inventory_system = get_node_or_null("/root/InventorySystem")
	if inventory_system:
		var items = inventory_system.get_all_items()
		for item in items:
			if item:
				inventory_data.append({
					"id": item.get("id", ""),
					"count": item.get("count", 1),
					"durability": item.get("durability", 100.0),
					"enchantments": item.get("enchantments", []),
					"custom_properties": item.get("custom_properties", {})
				})
	
	return inventory_data

func serialize_equipment() -> Dictionary:
# Serialize equipment data
	var equipment_data = {}
	
	var equipment_system = get_node_or_null("/root/EquipmentSystem")
	if equipment_system:
		for slot in equipment_system.EQUIPMENT_SLOTS:
			var item = equipment_system.get_equipped_item(slot)
			if item:
				equipment_data[slot] = {
					"id": item.get("id", ""),
					"durability": item.get("durability", 100.0),
					"enchantments": item.get("enchantments", []),
					"custom_properties": item.get("custom_properties", {})
				}
	
	return equipment_data

func serialize_skills() -> Array:
# Serialize unlocked skills
	var skills_data = []
	
	var progression_system = get_node_or_null("/root/PlayerProgression")
	if progression_system:
		skills_data = progression_system.get_unlocked_skills()
	
	return skills_data

func serialize_skill_trees() -> Dictionary:
# Serialize skill tree progress
	var skill_tree_data = {}
	
	var progression_system = get_node_or_null("/root/PlayerProgression")
	if progression_system:
		skill_tree_data = progression_system.get_skill_tree_progress()
	
	return skill_tree_data

func serialize_talents() -> Dictionary:
# Serialize talent selections
	var talent_data = {}
	
	var progression_system = get_node_or_null("/root/PlayerProgression")
	if progression_system:
		talent_data = progression_system.get_selected_talents()
	
	return talent_data

func serialize_active_quests() -> Array:
# Serialize active quest states
	var quest_data = []
	
	var quest_system = get_node_or_null("/root/QuestSystem")
	if quest_system:
		var active_quests = quest_system.get_active_quests()
		for quest in active_quests:
			quest_data.append({
				"id": quest.get("id", ""),
				"progress": quest.get("progress", {}),
				"objectives_completed": quest.get("objectives_completed", []),
				"start_time": quest.get("start_time", 0),
				"variables": quest.get("variables", {})
			})
	
	return quest_data

func serialize_active_buffs() -> Array:
# Serialize active buffs/debuffs
	var buff_data = []
	
	var buff_system = get_node_or_null("/root/BuffSystem")
	if buff_system:
		var active_buffs = buff_system.get_active_buffs()
		for buff in active_buffs:
			buff_data.append({
				"id": buff.get("id", ""),
				"remaining_time": buff.get("remaining_time", 0.0),
				"stacks": buff.get("stacks", 1),
				"source": buff.get("source", "unknown")
			})
	
	return buff_data

func serialize_cooldowns() -> Dictionary:
# Serialize ability cooldowns
	var cooldown_data = {}
	
	# This would be implemented based on your skill/ability system
	# For now, return empty dictionary
	
	return cooldown_data

func get_custom_key_bindings() -> Dictionary:
# Get custom key bindings
	var bindings = {}
	
	for action in InputMap.get_actions():
		var events = InputMap.action_get_events(action)
		var event_data = []
		for event in events:
			if event is InputEventKey:
				event_data.append({
					"type": "key",
					"keycode": event.keycode,
					"physical_keycode": event.physical_keycode,
					"unicode": event.unicode,
					"pressed": event.pressed,
					"modifiers": {
						"alt": event.alt_pressed,
						"shift": event.shift_pressed,
						"ctrl": event.ctrl_pressed,
						"meta": event.meta_pressed
					}
				})
			elif event is InputEventMouseButton:
				event_data.append({
					"type": "mouse",
					"button_index": event.button_index,
					"pressed": event.pressed,
					"modifiers": {
						"alt": event.alt_pressed,
						"shift": event.shift_pressed,
						"ctrl": event.ctrl_pressed,
						"meta": event.meta_pressed
					}
				})
		
		if not event_data.is_empty():
			bindings[action] = event_data
	
	return bindings

# File Operations
func write_save_file(data: Dictionary, slot_name: String = "main") -> bool:
# Write save data to file
	var file_path = get_save_file_path(slot_name)
	
	# Convert to JSON
	var json_string = JSON.stringify(data)
	if json_string.is_empty():
		print("[SaveManager] Failed to serialize save data")
		return false
	
	# Compress if enabled
	if USE_COMPRESSION:
		json_string = compress_data(json_string)
	
	# Write to temporary file first
	var temp_file = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if not temp_file:
		print("[SaveManager] Failed to create temporary save file")
		return false
	
	temp_file.store_string(json_string)
	temp_file.flush()
	temp_file.close()
	
	# Move temporary file to actual save file (atomic operation)
	var dir = DirAccess.open("user://")
	if dir.rename(TEMP_SAVE_PATH, file_path) != OK:
		print("[SaveManager] Failed to move temporary file to save file")
		dir.remove(TEMP_SAVE_PATH)
		return false
	
	print("[SaveManager] Save written to: %s" % file_path)
	return true

func read_save_file(slot_name: String = "main") -> Dictionary:
# Read save data from file
	var file_path = get_save_file_path(slot_name)
	
	if not FileAccess.file_exists(file_path):
		print("[SaveManager] Save file does not exist: %s" % file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[SaveManager] Failed to open save file: %s" % file_path)
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	# Decompress if needed
	if USE_COMPRESSION:
		content = decompress_data(content)
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(content)
	
	if parse_result != OK:
		print("[SaveManager] Failed to parse save file JSON: %s" % json.get_error_message())
		return {}
	
	var data = json.data
	if not data is Dictionary:
		print("[SaveManager] Save file contains invalid data structure")
		return {}
	
	print("[SaveManager] Save loaded from: %s" % file_path)
	return data

func get_save_file_path(slot_name: String) -> String:
# Get save file path for slot
	if slot_name == "main":
		return SAVE_FILE_PATH
	else:
		return "user://save_data_%s.json" % slot_name

# Data Validation and Migration
func validate_save_data(data: Dictionary) -> bool:
# Validate save data integrity
	# Check magic number
	if data.get("magic_number", "") != SAVE_MAGIC_NUMBER:
		print("[SaveManager] Invalid magic number in save data")
		return false
	
	# Check version
	var version = data.get("version", 0.0)
	if version < MIN_COMPATIBLE_VERSION:
		print("[SaveManager] Save version too old: %s (min: %s)" % [version, MIN_COMPATIBLE_VERSION])
		return false
	
	# Check required sections
	var required_sections = ["player_data", "world_data", "progress_data", "settings_data"]
	for section in required_sections:
		if not data.has(section):
			print("[SaveManager] Missing required section: %s" % section)
			return false
	
	# Verify checksum if present
	var stored_checksum = data.get("checksum", "")
	if stored_checksum != "":
		var calculated_checksum = generate_checksum(data, true)  # Exclude checksum from calculation
		if stored_checksum != calculated_checksum:
			print("[SaveManager] Checksum mismatch - save file may be corrupted")
			return false
	
	return true

func validate_and_migrate_save(data: Dictionary) -> Dictionary:
# Validate and migrate save data if necessary
	if not validate_save_data(data):
		return {}
	
	var version = data.get("version", 0.0)
	
	# Migrate if necessary
	if version < CURRENT_SAVE_VERSION:
		print("[SaveManager] Migrating save from version %s to %s" % [version, CURRENT_SAVE_VERSION])
		data = migrate_save(data, version, CURRENT_SAVE_VERSION)
		
		if data.is_empty():
			print("[SaveManager] Save migration failed")
			return {}
	
	return data

func migrate_save(data: Dictionary, from_version: float, to_version: float) -> Dictionary:
# Migrate save data between versions
	var migrated_data = data.duplicate(true)
	
	# Version 1.0 to 1.1 migration
	if from_version < 1.1 and to_version >= 1.1:
		print("[SaveManager] Applying v1.0 -> v1.1 migration")
		migrated_data = migrate_1_0_to_1_1(migrated_data)
	
	# Version 1.1 to 1.2 migration
	if from_version < 1.2 and to_version >= 1.2:
		print("[SaveManager] Applying v1.1 -> v1.2 migration")
		migrated_data = migrate_1_1_to_1_2(migrated_data)
	
	# Update version number
	migrated_data.version = to_version
	
	# Regenerate checksum
	migrated_data.checksum = generate_checksum(migrated_data)
	
	return migrated_data

func migrate_1_0_to_1_1(data: Dictionary) -> Dictionary:
# Migrate from version 1.0 to 1.1
	# Add new currency types introduced in v1.1
	if not data.player_data.has("magic_fragments"):
		data.player_data.magic_fragments = 0
	if not data.player_data.has("rare_essences"):
		data.player_data.rare_essences = 0
	
	# Add faction standings introduced in v1.1
	if not data.world_data.has("faction_standings"):
		data.world_data.faction_standings = {}
	
	return data

func migrate_1_1_to_1_2(data: Dictionary) -> Dictionary:
# Migrate from version 1.1 to 1.2
	# Add performance metrics introduced in v1.2
	if not data.session_data.has("performance_metrics"):
		data.session_data.performance_metrics = {
			"fps_average": 60,
			"memory_usage": {},
			"load_times": []
		}
	
	# Restructure inventory data for new system
	if data.player_data.has("inventory") and data.player_data.inventory is Array:
		var new_inventory = []
		for item in data.player_data.inventory:
			if item is Dictionary:
				# Add new fields introduced in v1.2
				if not item.has("durability"):
					item.durability = 100.0
				if not item.has("enchantments"):
					item.enchantments = []
				if not item.has("custom_properties"):
					item.custom_properties = {}
				new_inventory.append(item)
		data.player_data.inventory = new_inventory
	
	return data

# Utility Functions
func generate_checksum(data: Dictionary, exclude_checksum: bool = false) -> String:
# Generate checksum for data integrity
	var data_copy = data.duplicate(true)
	
	# Remove checksum field from calculation if requested
	if exclude_checksum:
		data_copy.erase("checksum")
	
	# Convert to consistent string representation
	var json_string = JSON.stringify(data_copy)
	
	# Generate simple hash (in production, use proper cryptographic hash)
	return json_string.md5_text()

func compress_data(data: String) -> String:
# Compress data string
	var compressed = data.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return Marshalls.raw_to_base64(compressed)

func decompress_data(compressed_data: String) -> String:
# Decompress data string
	var raw_data = Marshalls.base64_to_raw(compressed_data)
	var decompressed = raw_data.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	return decompressed.get_string_from_utf8()

func create_backup() -> bool:
# Create backup of current save file
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return true  # No save to backup
	
	var dir = DirAccess.open("user://")
	if dir.copy(SAVE_FILE_PATH, BACKUP_FILE_PATH) == OK:
		backup_created.emit(BACKUP_FILE_PATH)
		print("[SaveManager] Backup created: %s" % BACKUP_FILE_PATH)
		return true
	else:
		print("[SaveManager] Failed to create backup")
		return false

func restore_backup() -> bool:
# Restore save from backup
	if not FileAccess.file_exists(BACKUP_FILE_PATH):
		print("[SaveManager] No backup file found")
		return false
	
	var dir = DirAccess.open("user://")
	if dir.copy(BACKUP_FILE_PATH, SAVE_FILE_PATH) == OK:
		print("[SaveManager] Save restored from backup")
		return true
	else:
		print("[SaveManager] Failed to restore from backup")
		return false

func delete_save(slot_name: String = "main") -> bool:
# Delete save file
	var file_path = get_save_file_path(slot_name)
	var dir = DirAccess.open("user://")
	
	if dir.remove(file_path) == OK:
		print("[SaveManager] Save deleted: %s" % file_path)
		return true
	else:
		print("[SaveManager] Failed to delete save: %s" % file_path)
		return false

func save_exists(slot_name: String = "main") -> bool:
# Check if save file exists
	return FileAccess.file_exists(get_save_file_path(slot_name))

func get_save_info(slot_name: String = "main") -> Dictionary:
# Get save file information without loading
	var file_path = get_save_file_path(slot_name)
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	# Try to read just the header info
	var content = file.get_as_text()
	file.close()
	
	if USE_COMPRESSION:
		content = decompress_data(content)
	
	var json = JSON.new()
	if json.parse(content) != OK:
		return {}
	
	var data = json.data
	if not data is Dictionary:
		return {}
	
	# Extract basic info
	var info = {
		"version": data.get("version", 0.0),
		"timestamp": data.get("timestamp", 0),
		"player_name": data.get("player_data", {}).get("name", "Unknown"),
		"player_level": data.get("player_data", {}).get("level", 1),
		"play_time": data.get("player_data", {}).get("play_time", 0.0),
		"location": data.get("player_data", {}).get("current_location", "Unknown")
	}
	
	# Format timestamp
	if info.timestamp > 0:
		var datetime = Time.get_datetime_dict_from_unix_time(info.timestamp)
		info.formatted_date = "%04d-%02d-%02d %02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute
		]
	
	# Format play time
	var hours = int(info.play_time) / 3600
	var minutes = (int(info.play_time) % 3600) / 60
	info.formatted_play_time = "%02d:%02d" % [hours, minutes]
	
	return info

# Data Application
func apply_loaded_data(save_data: Dictionary) -> bool:
# Apply loaded save data to game systems
	print("[SaveManager] Applying loaded save data...")
	
	# Apply player data
	if not apply_player_data(save_data.get("player_data", {})):
		return false
	
	# Apply world data
	if not apply_world_data(save_data.get("world_data", {})):
		return false
		
		# Apply progress data
		if not apply_progress_data(save_data.get("progress_data", {})):
			return false
		
		# Apply settings data
		if not apply_settings_data(save_data.get("settings_data", {})):
			return false
		
		# Apply session data
		if not apply_session_data(save_data.get("session_data", {})):
			return false
		
		print("[SaveManager] Save data applied successfully")
		return true

func apply_player_data(player_data: Dictionary) -> bool:
# Apply player data to game state
	if not game_state or not game_state.player_stats:
		print("[SaveManager] Game state or player stats not available")
		return false
	
	var stats = game_state.player_stats
	
	# Basic info
	game_state.player_name = player_data.get("name", "Unknown")
	stats.race = player_data.get("race", "human")
	stats.character_class = player_data.get("character_class", "warrior")
	
	# Level and experience
	stats.current_level = player_data.get("level", 1)
	stats.experience = player_data.get("experience", 0)
	stats.experience_to_next_level = player_data.get("experience_to_next_level", 100)
	stats.skill_points_available = player_data.get("skill_points_available", 0)
	stats.attribute_points_available = player_data.get("attribute_points_available", 0)
	
	# Health and resources
	stats.current_health = player_data.get("current_health", stats.max_health)
	stats.max_health = player_data.get("max_health", 100)
	stats.current_stamina = player_data.get("current_stamina", stats.max_stamina)
	stats.max_stamina = player_data.get("max_stamina", 100)
	stats.current_mana = player_data.get("current_mana", stats.max_mana)
	stats.max_mana = player_data.get("max_mana", 100)
	
	# Attributes
	stats.strength = player_data.get("strength", 10)
	stats.agility = player_data.get("agility", 10)
	stats.intelligence = player_data.get("intelligence", 10)
	stats.vitality = player_data.get("vitality", 10)
	stats.luck = player_data.get("luck", 10)
	
	# Currency
	game_state.currency = player_data.get("currency", 0)
	game_state.set("premium_currency", player_data.get("premium_currency", 0))
	game_state.set("magic_fragments", player_data.get("magic_fragments", 0))
	game_state.set("rare_essences", player_data.get("rare_essences", 0))
	
	# Location
	game_state.current_location = player_data.get("current_location", "town")
	game_state.set("current_dungeon", player_data.get("current_dungeon", ""))
	game_state.set("current_floor", player_data.get("current_floor", 1))
	
	# Apply inventory
	apply_inventory_data(player_data.get("inventory", []))
	
	# Apply equipment
	apply_equipment_data(player_data.get("equipment", {}))
	
	# Apply skills and talents
	apply_skills_data(player_data.get("unlocked_skills", []))
	apply_skill_tree_data(player_data.get("skill_tree_progress", {}))
	apply_talents_data(player_data.get("talents", {}))
	
	# Recalculate derived stats
	stats.calculate_secondary_attributes()
	
	return true

func apply_world_data(world_data: Dictionary) -> bool:
# Apply world state data
	game_state.set("unlocked_dungeons", world_data.get("unlocked_dungeons", []))
	game_state.set("completed_dungeons", world_data.get("completed_dungeons", []))
	game_state.set("discovered_locations", world_data.get("discovered_locations", []))
	game_state.set("world_flags", world_data.get("world_flags", {}))
	game_state.set("npc_states", world_data.get("npc_states", {}))
	game_state.set("faction_standings", world_data.get("faction_standings", {}))
	
	return true

func apply_progress_data(progress_data: Dictionary) -> bool:
# Apply quest and progress data
	game_state.set("completed_quests", progress_data.get("completed_quests", []))
	game_state.set("failed_quests", progress_data.get("failed_quests", []))
	game_state.set("available_quests", progress_data.get("available_quests", []))
	game_state.set("story_flags", progress_data.get("story_flags", {}))
	game_state.set("dialogue_history", progress_data.get("dialogue_history", {}))
	game_state.set("unlocked_achievements", progress_data.get("unlocked_achievements", []))
	
	# Apply active quests
	apply_active_quests_data(progress_data.get("active_quests", []))
	
	return true

func apply_settings_data(settings_data: Dictionary) -> bool:
# Apply settings data
	var graphics = settings_data.get("graphics", {})
	var audio = settings_data.get("audio", {})
	var controls = settings_data.get("controls", {})
	var ui = settings_data.get("ui", {})
	var gameplay = settings_data.get("gameplay", {})
	
	# Apply graphics settings
	if graphics.has("fullscreen"):
		var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if graphics.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	
	# Apply audio settings
	if audio.has("master_volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), audio.master_volume)
	if audio.has("music_volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), audio.music_volume)
	if audio.has("sfx_volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), audio.sfx_volume)
	
	# Apply control settings
	if controls.has("key_bindings"):
		apply_key_bindings(controls.key_bindings)
	
	# Apply gameplay settings
	if gameplay.has("auto_save_enabled"):
		auto_save_enabled = gameplay.auto_save_enabled
	if gameplay.has("auto_save_interval"):
		auto_save_interval = gameplay.auto_save_interval
		auto_save_timer.wait_time = auto_save_interval
	
	return true

func apply_session_data(session_data: Dictionary) -> bool:
# Apply session data
	# Apply active buffs
	apply_active_buffs_data(session_data.get("active_buffs", []))
	
	# Apply temporary flags
	game_state.set("temporary_flags", session_data.get("temporary_flags", {}))
	
	return true

func apply_inventory_data(inventory_data: Array):
# Apply inventory data
	var inventory_system = get_node_or_null("/root/InventorySystem")
	if inventory_system:
		inventory_system.clear_inventory()
		for item_data in inventory_data:
			inventory_system.add_item_from_save(item_data)

func apply_equipment_data(equipment_data: Dictionary):
# Apply equipment data
	var equipment_system = get_node_or_null("/root/EquipmentSystem")
	if equipment_system:
		equipment_system.clear_all_equipment()
		for slot in equipment_data:
			equipment_system.equip_item_from_save(slot, equipment_data[slot])

func apply_skills_data(skills_data: Array):
# Apply skills data
	var progression_system = get_node_or_null("/root/PlayerProgression")
	if progression_system:
		progression_system.set_unlocked_skills(skills_data)

func apply_skill_tree_data(skill_tree_data: Dictionary):
# Apply skill tree progress data
	var progression_system = get_node_or_null("/root/PlayerProgression")
	if progression_system:
		progression_system.set_skill_tree_progress(skill_tree_data)

func apply_talents_data(talents_data: Dictionary):
# Apply talents data
	var progression_system = get_node_or_null("/root/PlayerProgression")
	if progression_system:
		progression_system.set_selected_talents(talents_data)

func apply_active_quests_data(quests_data: Array):
# Apply active quests data
	var quest_system = get_node_or_null("/root/QuestSystem")
	if quest_system:
		for quest_data in quests_data:
			quest_system.restore_quest_from_save(quest_data)

func apply_active_buffs_data(buffs_data: Array):
# Apply active buffs data
	var buff_system = get_node_or_null("/root/BuffSystem")
	if buff_system:
		for buff_data in buffs_data:
			buff_system.restore_buff_from_save(buff_data)

func apply_key_bindings(bindings_data: Dictionary):
# Apply custom key bindings
	for action in bindings_data:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for event_data in bindings_data[action]:
				var event = create_input_event_from_data(event_data)
				if event:
					InputMap.action_add_event(action, event)

func create_input_event_from_data(event_data: Dictionary) -> InputEvent:
# Create input event from save data
	match event_data.get("type", ""):
		"key":
			var event = InputEventKey.new()
			event.keycode = event_data.get("keycode", 0)
			event.physical_keycode = event_data.get("physical_keycode", 0)
			event.unicode = event_data.get("unicode", 0)
			event.pressed = event_data.get("pressed", false)
			var modifiers = event_data.get("modifiers", {})
			event.alt_pressed = modifiers.get("alt", false)
			event.shift_pressed = modifiers.get("shift", false)
			event.ctrl_pressed = modifiers.get("ctrl", false)
			event.meta_pressed = modifiers.get("meta", false)
			return event
		
		"mouse":
			var event = InputEventMouseButton.new()
			event.button_index = event_data.get("button_index", 0)
			event.pressed = event_data.get("pressed", false)
			var modifiers = event_data.get("modifiers", {})
			event.alt_pressed = modifiers.get("alt", false)
			event.shift_pressed = modifiers.get("shift", false)
			event.ctrl_pressed = modifiers.get("ctrl", false)
			event.meta_pressed = modifiers.get("meta", false)
			return event
	
	return null

# Default Save Creation
func create_default_save() -> Dictionary:
# Create default save data for new game
	var default_save = save_template.duplicate(true)
	
	default_save.timestamp = Time.get_unix_time_from_system()
	default_save.version = CURRENT_SAVE_VERSION
	
	# Default player data
	default_save.player_data = {
		"name": "New Hero",
		"race": "human",
		"character_class": "warrior",
		"level": 1,
		"experience": 0,
		"experience_to_next_level": 100,
		"current_health": 100,
		"max_health": 100,
		"current_stamina": 100,
		"max_stamina": 100,
		"current_mana": 50,
		"max_mana": 50,
		"strength": 10,
		"agility": 10,
		"intelligence": 10,
		"vitality": 10,
		"luck": 10,
		"currency": 50,
		"current_location": "town",
		"inventory": [],
		"equipment": {},
		"play_time": 0.0
	}
	
	# Default world data
	default_save.world_data = {
		"unlocked_dungeons": ["tutorial_cave"],
		"completed_dungeons": [],
		"discovered_locations": ["town"],
		"world_flags": {},
		"faction_standings": {}
	}
	
	# Default progress data
	default_save.progress_data = {
		"active_quests": [],
		"completed_quests": [],
		"failed_quests": [],
		"story_flags": {},
		"unlocked_achievements": []
	}
	
	# Default settings
	default_save.settings_data = {
		"graphics": {
			"fullscreen": false,
			"quality_preset": "medium"
		},
		"audio": {
			"master_volume": 0.0,
			"music_volume": -5.0,
			"sfx_volume": -3.0
		},
		"gameplay": {
			"difficulty": "normal",
			"auto_save_enabled": true,
			"tutorial_completed": false
		}
	}
	
	# Default session data
	default_save.session_data = {
		"active_buffs": [],
		"temporary_flags": {}
	}
	
	default_save.checksum = generate_checksum(default_save)
	
	return default_save

# Auto-save System
func enable_auto_save(enabled: bool = true):
# Enable or disable auto-save
	auto_save_enabled = enabled
	if enabled:
		auto_save_timer.start()
	else:
		auto_save_timer.stop()

func set_auto_save_interval(interval: float):
# Set auto-save interval in seconds
	auto_save_interval = interval
	auto_save_timer.wait_time = interval

func _on_auto_save_timer():
# Handle auto-save timer timeout
	if auto_save_enabled and not is_saving and not is_loading:
		print("[SaveManager] Auto-saving game...")
		save_game_async("autosave")

func _on_auto_save_trigger():
# Trigger auto-save on significant events
	if auto_save_enabled and not is_saving and not is_loading:
		# Small delay to avoid saving during rapid events
		await get_tree().create_timer(2.0).timeout
		if auto_save_enabled:  # Check again after delay
			save_game_async("quicksave")

# Public API
func quick_save():
# Perform quick save
	save_game("quicksave")

func quick_load():
# Perform quick load
	load_game("quicksave")

func new_game():
# Start new game with default save
	var default_data = create_default_save()
	apply_loaded_data(default_data)
	save_game("main")

func has_save_data() -> bool:
# Check if main save file exists
	return save_exists("main")

# Debug Functions
func debug_print_save_info():
# Debug: Print save file information
	print("[SaveManager] Save System Status:")
	print("  Current Version: %s" % CURRENT_SAVE_VERSION)
	print("  Min Compatible: %s" % MIN_COMPATIBLE_VERSION)
	print("  Compression: %s" % ("Enabled" if USE_COMPRESSION else "Disabled"))
	print("  Auto-save: %s" % ("Enabled" if auto_save_enabled else "Disabled"))
	print("  Auto-save Interval: %s seconds" % auto_save_interval)
	
	var main_save_info = get_save_info("main")
	if main_save_info.is_empty():
		print("  Main Save: Not found")
	else:
		print("  Main Save:")
		print("    Version: %s" % main_save_info.get("version", "Unknown"))
		print("    Player: %s (Level %s)" % [main_save_info.get("player_name", "Unknown"), main_save_info.get("player_level", 1)])
		print("    Play Time: %s" % main_save_info.get("formatted_play_time", "Unknown"))
		print("    Last Saved: %s" % main_save_info.get("formatted_date", "Unknown"))
		print("    Location: %s" % main_save_info.get("location", "Unknown"))

func debug_create_test_save():
# Debug: Create test save file
	var test_data = create_default_save()
	test_data.player_data.name = "Test Hero"
	test_data.player_data.level = 15
	test_data.player_data.currency = 1000
	write_save_file(test_data, "test")
	print("[SaveManager] Test save created")

func debug_validate_current_save():
# Debug: Validate current save file
	var save_data = read_save_file("main")
	if save_data.is_empty():
		print("[SaveManager] No main save found")
		return
	
	var is_valid = validate_save_data(save_data)
	print("[SaveManager] Save validation result: %s" % ("VALID" if is_valid else "INVALID"))
	
	if is_valid:
		print("[SaveManager] Save details:")
		print("  Version: %s" % save_data.get("version", "Unknown"))
		print("  Timestamp: %s" % save_data.get("timestamp", 0))
		print("  Player: %s" % save_data.get("player_data", {}).get("name", "Unknown"))
		print("  Checksum: %s" % save_data.get("checksum", "Missing"))
