extends Node
# DataLoader.gd - ROBUST JSON Data Loader with validation and error handling
# Provides safe getter methods for all game data with crash prevention

signal data_loaded(data_type: String, count: int)
signal data_error(data_type: String, error_message: String)
signal all_data_loaded()

# Cached data dictionaries
var races = {}
var classes = {}
var spells = {}
var dungeons = {}
var items = {}
var enemies = {}
var attributes = []
var npcs = {}
var quests = {}
var dialogue_trees = {}
var lore = {}

# Data loading status
var loading_status = {}
var load_errors = {}
var is_fully_loaded = false

# Data file paths with required fields validation
var data_schemas = {
	"races": {
		"path": "res://data/json/races.json",
		"required_fields": ["id", "name", "attribute_modifiers"],
		"root_key": null
	},
	"classes": {
		"path": "res://data/json/classes.json", 
		"required_fields": ["id", "name", "base_stats"],
		"root_key": null
	},
	"spells": {
		"path": "res://data/json/spells.json",
		"required_fields": ["id", "name", "cost", "effect"],
		"root_key": null
	},
	"dungeons": {
		"path": "res://data/json/dungeons.json",
		"required_fields": ["id", "name", "level_range"],
		"root_key": null
	},
	"items": {
		"path": "res://data/json/items.json",
		"required_fields": ["id", "name", "type"],
		"root_key": null
	},
	"enemies": {
		"path": "res://data/json/enemies.json",
		"required_fields": ["id", "name", "stats", "level"],
		"root_key": null
	},
	"attributes": {
		"path": "res://data/json/base_attributes.json",
		"required_fields": ["attributes"],
		"root_key": "attributes"
	},
	"npcs": {
		"path": "res://data/json/npcs.json",
		"required_fields": ["id", "name", "faction"],
		"root_key": "npcs"
	},
	"quests": {
		"path": "res://data/json/quests.json",
		"required_fields": ["id", "title", "objectives"],
		"root_key": "quests"
	},
	"dialogues": {
		"path": "res://data/json/dialogues.json",
		"required_fields": ["root", "nodes"],
		"root_key": "dialogue_trees"
	},
	"world_timeline": {
		"path": "res://data/lore/world_timeline.json",
		"required_fields": ["timeline"],
		"root_key": "timeline"
	},
	"factions": {
		"path": "res://data/lore/factions.json",
		"required_fields": ["factions"],
		"root_key": "factions"
	}
}

func _ready():
	print("[DataLoader] Initializing ROBUST data loading system...")
	initialize_loading_status()
	await load_all_data()

func initialize_loading_status():
# Initialize loading status tracking
	for data_type in data_schemas.keys():
		loading_status[data_type] = "pending"
		load_errors[data_type] = []

func load_all_data():
# Load all JSON data files with comprehensive error handling
	print("[DataLoader] Starting comprehensive data loading...")
	
	var successful_loads = 0
	var total_loads = data_schemas.size()
	
	# Load core systems first
	var core_systems = ["attributes", "races", "classes", "items", "enemies", "spells", "dungeons"]
	for data_type in core_systems:
		if await load_data_type(data_type):
			successful_loads += 1
	
	# Load narrative systems
	var narrative_systems = ["npcs", "quests", "dialogues"]
	for data_type in narrative_systems:
		if await load_data_type(data_type):
			successful_loads += 1
	
	# Load lore systems
	var lore_systems = ["world_timeline", "factions"]
	for data_type in lore_systems:
		if await load_data_type(data_type):
			successful_loads += 1
	
	# Final status report
	is_fully_loaded = (successful_loads == total_loads)
	
	if is_fully_loaded:
		print("[DataLoader] âœ… ALL DATA LOADED SUCCESSFULLY (%d/%d)" % [successful_loads, total_loads])
		all_data_loaded.emit()
	else:
		print("[DataLoader] âš ï¸ PARTIAL DATA LOAD (%d/%d) - Some systems may be unavailable" % [successful_loads, total_loads])
		print_load_errors()

func load_data_type(data_type: String) -> bool:
# Load a specific data type with validation
	if not data_schemas.has(data_type):
		loading_status[data_type] = "failed"
		load_errors[data_type].append("Unknown data type")
		return false
	
	var schema = data_schemas[data_type]
	var file_path = schema.path
	
	print("[DataLoader] Loading %s from %s..." % [data_type, file_path])
	
	var raw_data = load_json_file_safe(file_path, data_type)
	if raw_data == null:
		return false
	
	var processed_data = process_raw_data(raw_data, schema, data_type)
	if processed_data == null:
		return false
	
	if not validate_data_structure(processed_data, schema, data_type):
		return false
	
	# Store processed data
	store_data(data_type, processed_data)
	
	loading_status[data_type] = "success"
	var count = get_data_count(processed_data)
	data_loaded.emit(data_type, count)
	print("[DataLoader] âœ… %s loaded successfully (%d items)" % [data_type.capitalize(), count])
	
	return true

func load_json_file_safe(file_path: String, data_type: String):
# Safe JSON file loader with comprehensive error handling
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		var error = "File does not exist: " + file_path
		load_errors[data_type].append(error)
		loading_status[data_type] = "failed"
		print("[DataLoader] âŒ %s: %s" % [data_type, error])
		data_error.emit(data_type, error)
		return null
	
	# Open file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var error = "Failed to open file: " + file_path + " (Error: " + str(FileAccess.get_open_error()) + ")"
		load_errors[data_type].append(error)
		loading_status[data_type] = "failed"
		print("[DataLoader] âŒ %s: %s" % [data_type, error])
		data_error.emit(data_type, error)
		return null
	
	# Read file content
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		var error = "File is empty: " + file_path
		load_errors[data_type].append(error)
		loading_status[data_type] = "failed"
		print("[DataLoader] âŒ %s: %s" % [data_type, error])
		data_error.emit(data_type, error)
		return null
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		var error = "JSON parse error in " + file_path + ": " + json.get_error_message() + " at line " + str(json.get_error_line())
		load_errors[data_type].append(error)
		loading_status[data_type] = "failed"
		print("[DataLoader] âŒ %s: %s" % [data_type, error])
		data_error.emit(data_type, error)
		return null
	
	return json.data

func process_raw_data(raw_data, schema: Dictionary, data_type: String):
# Process raw JSON data based on schema
	var root_key = schema.get("root_key")
	
	if root_key:
		# Extract data from root key
		if not raw_data.has(root_key):
			var error = "Missing root key '%s' in %s" % [root_key, data_type]
			load_errors[data_type].append(error)
			print("[DataLoader] âŒ %s: %s" % [data_type, error])
			data_error.emit(data_type, error)
			return null
		return raw_data[root_key]
	else:
		# Use raw data as-is
		return raw_data

func validate_data_structure(data, schema: Dictionary, data_type: String) -> bool:
# Validate data structure against required fields
	var required_fields = schema.get("required_fields", [])
	var validation_errors = []
	
	if data is Array:
		# Validate array of objects
		for i in range(data.size()):
			var item = data[i]
			if not item is Dictionary:
				validation_errors.append("Item %d is not a dictionary" % i)
				continue
			
			for field in required_fields:
				if not item.has(field):
					validation_errors.append("Item %d missing required field: %s" % [i, field])
	
	elif data is Dictionary:
		# Validate single dictionary or dictionary of objects
		if data_type in ["npcs", "quests", "dialogues"]:
			# Dictionary of objects
			for key in data.keys():
				var item = data[key]
				if not item is Dictionary:
					validation_errors.append("Item '%s' is not a dictionary" % key)
					continue
				
				for field in required_fields:
					if not item.has(field):
						validation_errors.append("Item '%s' missing required field: %s" % [key, field])
		else:
			# Single dictionary
			for field in required_fields:
				if not data.has(field):
					validation_errors.append("Missing required field: %s" % field)
	
	else:
		validation_errors.append("Data is not array or dictionary")
	
	if validation_errors.size() > 0:
		load_errors[data_type].extend(validation_errors)
		loading_status[data_type] = "failed"
		for error in validation_errors:
			print("[DataLoader] âŒ %s validation: %s" % [data_type, error])
			data_error.emit(data_type, error)
		return false
	
	return true

func store_data(data_type: String, data):
# Store validated data in appropriate containers
	match data_type:
		"races":
			races.clear()
			for race in data:
				races[race.id] = race
		
		"classes":
			classes.clear()
			for class_data in data:
				classes[class_data.id] = class_data
		
		"spells":
			spells.clear()
			for spell in data:
				spells[spell.id] = spell
		
		"dungeons":
			dungeons.clear()
			for dungeon in data:
				dungeons[dungeon.id] = dungeon
		
		"items":
			items.clear()
			for item in data:
				items[item.id] = item
		
		"enemies":
			enemies.clear()
			for enemy in data:
				enemies[enemy.id] = enemy
		
		"attributes":
			attributes = data
		
		"npcs":
			npcs = data
		
		"quests":
			quests = data
		
		"dialogues":
			dialogue_trees = data
		
		"world_timeline":
			if not lore.has("timeline"):
				lore["timeline"] = {}
			lore["timeline"] = data
		
		"factions":
			if not lore.has("factions"):
				lore["factions"] = {}
			lore["factions"] = data

func get_data_count(data) -> int:
# Get count of items in data structure
	if data is Array:
		return data.size()
	elif data is Dictionary:
		return data.size()
	else:
		return 1

# ROBUST GETTER METHODS with validation and fallbacks
func get_race(race_id: String):
# Get race data by ID with validation
	if not is_data_loaded("races"):
		print("[DataLoader] âš ï¸ Races not loaded - returning null")
		return null
	
	if race_id in races:
		return races[race_id]
	else:
		print("[DataLoader] âš ï¸ Race not found: " + race_id)
		return null

func get_class(class_id: String):
# Get class data by ID with validation
	if not is_data_loaded("classes"):
		print("[DataLoader] âš ï¸ Classes not loaded - returning null")
		return null
	
	if class_id in classes:
		return classes[class_id]
	else:
		print("[DataLoader] âš ï¸ Class not found: " + class_id)
		return null

func get_spell(spell_id: String):
# Get spell data by ID with validation
	if not is_data_loaded("spells"):
		print("[DataLoader] âš ï¸ Spells not loaded - returning null")
		return null
	
	if spell_id in spells:
		return spells[spell_id]
	else:
		print("[DataLoader] âš ï¸ Spell not found: " + spell_id)
		return null

func get_dungeon(dungeon_id: String):
# Get dungeon data by ID with validation
	if not is_data_loaded("dungeons"):
		print("[DataLoader] âš ï¸ Dungeons not loaded - returning null")
		return null
	
	if dungeon_id in dungeons:
		return dungeons[dungeon_id]
	else:
		print("[DataLoader] âš ï¸ Dungeon not found: " + dungeon_id)
		return null

func get_item(item_id: String):
# Get item data by ID with validation
	if not is_data_loaded("items"):
		print("[DataLoader] âš ï¸ Items not loaded - returning null")
		return null
	
	if item_id in items:
		return items[item_id]
	else:
		print("[DataLoader] âš ï¸ Item not found: " + item_id)
		return null

func get_enemy(enemy_id: String):
# Get enemy data by ID with validation
	if not is_data_loaded("enemies"):
		print("[DataLoader] âš ï¸ Enemies not loaded - returning null")
		return null
	
	if enemy_id in enemies:
		return enemies[enemy_id]
	else:
		print("[DataLoader] âš ï¸ Enemy not found: " + enemy_id)
		return null

func get_npc(npc_id: String):
# Get NPC data by ID with validation
	if not is_data_loaded("npcs"):
		print("[DataLoader] âš ï¸ NPCs not loaded - returning null")
		return null
	
	if npc_id in npcs:
		return npcs[npc_id]
	else:
		print("[DataLoader] âš ï¸ NPC not found: " + npc_id)
		return null

func get_quest(quest_id: String):
# Get quest data by ID with validation
	if not is_data_loaded("quests"):
		print("[DataLoader] âš ï¸ Quests not loaded - returning null")
		return null
	
	if quest_id in quests:
		return quests[quest_id]
	else:
		print("[DataLoader] âš ï¸ Quest not found: " + quest_id)
		return null

func get_dialogue_tree(dialogue_id: String):
# Get dialogue tree by ID with validation
	if not is_data_loaded("dialogues"):
		print("[DataLoader] âš ï¸ Dialogues not loaded - returning null")
		return null
	
	if dialogue_id in dialogue_trees:
		return dialogue_trees[dialogue_id]
	else:
		print("[DataLoader] âš ï¸ Dialogue tree not found: " + dialogue_id)
		return null

# COLLECTION GETTERS
func get_all_races() -> Dictionary:
# Get all race data
	if not is_data_loaded("races"):
		return {}
	return races

func get_all_classes() -> Dictionary:
# Get all class data
	if not is_data_loaded("classes"):
		return {}
	return classes

func get_all_spells() -> Dictionary:
# Get all spell data
	if not is_data_loaded("spells"):
		return {}
	return spells

func get_all_dungeons() -> Dictionary:
# Get all dungeon data
	if not is_data_loaded("dungeons"):
		return {}
	return dungeons

func get_all_items() -> Dictionary:
# Get all item data
	if not is_data_loaded("items"):
		return {}
	return items

func get_all_enemies() -> Dictionary:
# Get all enemy data
	if not is_data_loaded("enemies"):
		return {}
	return enemies

func get_all_npcs() -> Dictionary:
# Get all NPC data
	if not is_data_loaded("npcs"):
		return {}
	return npcs

func get_all_quests() -> Dictionary:
# Get all quest data
	if not is_data_loaded("quests"):
		return {}
	return quests

func get_attributes() -> Array:
# Get attributes list
	if not is_data_loaded("attributes"):
		return []
	return attributes

func get_lore_data(lore_type: String):
# Get specific lore data (timeline, factions, etc.)
	if lore.has(lore_type):
		return lore[lore_type]
	else:
		print("[DataLoader] âš ï¸ Lore type not found: " + lore_type)
		return null

# UTILITY METHODS
func is_data_loaded(data_type: String) -> bool:
# Check if specific data type is loaded successfully
	return loading_status.get(data_type, "pending") == "success"

func is_fully_loaded() -> bool:
# Check if all data is loaded successfully
	for status in loading_status.values():
		if status != "success":
			return false
	return true

func get_loading_status() -> Dictionary:
# Get loading status of all data types
	return loading_status

func get_load_errors() -> Dictionary:
# Get all load errors
	return load_errors

func print_load_errors():
# Print all load errors for debugging
	print("[DataLoader] ðŸ“Š LOAD ERROR SUMMARY:")
	for data_type in load_errors.keys():
		var errors = load_errors[data_type]
		if errors.size() > 0:
			print("  âŒ %s: %d errors" % [data_type, errors.size()])
			for error in errors:
				print("    - %s" % error)

func reload_data_type(data_type: String) -> bool:
# Reload specific data type
	if not data_schemas.has(data_type):
		print("[DataLoader] âŒ Cannot reload unknown data type: " + data_type)
		return false
	
	loading_status[data_type] = "pending"
	load_errors[data_type].clear()
	
	print("[DataLoader] ðŸ”„ Reloading " + data_type + "...")
	return await load_data_type(data_type)

# DYNAMIC DATA LOADING (for runtime additions)
func load_data_file(file_path: String, data_type: String = "custom"):
# Load any JSON file dynamically with validation
	return load_json_file_safe(file_path, data_type)

func validate_json_structure(data, required_fields: Array) -> Array:
# Validate JSON structure and return list of missing fields
	var missing_fields = []
	
	if not data is Dictionary:
		missing_fields.append("Root must be a dictionary")
		return missing_fields
	
	for field in required_fields:
		if not data.has(field):
			missing_fields.append("Missing required field: " + field)
	
	return missing_fields

# DEBUG AND DEVELOPMENT METHODS
func debug_print_all_data():
# Print summary of all loaded data
	print("[DataLoader] ðŸ” DATA SUMMARY:")
	print("  Races: %d" % races.size())
	print("  Classes: %d" % classes.size())
	print("  Spells: %d" % spells.size())
	print("  Dungeons: %d" % dungeons.size())
	print("  Items: %d" % items.size())
	print("  Enemies: %d" % enemies.size())
	print("  Attributes: %d" % attributes.size())
	print("  NPCs: %d" % npcs.size())
	print("  Quests: %d" % quests.size())
	print("  Dialogue Trees: %d" % dialogue_trees.size())
	print("  Lore Sections: %d" % lore.size())

func debug_validate_all_references():
# Validate all cross-references in data
	print("[DataLoader] ðŸ” VALIDATING CROSS-REFERENCES...")
	
	# Validate spell references in classes
	for class_data in classes.values():
		if class_data.has("spells"):
			for spell_id in class_data.spells:
				if not spells.has(spell_id):
					print("[DataLoader] âš ï¸ Class %s references unknown spell: %s" % [class_data.id, spell_id])
	
	# Add more validation as needed
	print("[DataLoader] âœ… Cross-reference validation complete")
	else:
		push_warning("Dungeon not found: " + dungeon_id)
		return null

func get_item(item_id: String):
# Get item data by ID
	if item_id in items:
		return items[item_id]
	else:
		push_warning("Item not found: " + item_id)
		return null

func get_enemy_data(enemy_id: String):
# Get enemy data by ID
	if enemy_id in enemies:
		return enemies[enemy_id]
	else:
		push_warning("Enemy not found: " + enemy_id)
		return null

# Utility getter methods
func get_all_races() -> Array:
# Get all race IDs
	return races.keys()

func get_all_classes() -> Array:
# Get all class IDs
	return classes.keys()

func get_all_spells() -> Array:
# Get all spell IDs
	return spells.keys()

func get_all_dungeons() -> Array:
# Get all dungeon IDs
	return dungeons.keys()

func get_all_items() -> Array:
# Get all item IDs
	return items.keys()

func get_all_enemies() -> Array:
# Get all enemy IDs
	return enemies.keys()

func get_attributes() -> Array:
# Get base attributes list
	return attributes

# Filtered getters
func get_spells_by_type(spell_type: String) -> Array:
# Get all spells of a specific type
	var filtered_spells = []
	for spell_id in spells:
		var spell = spells[spell_id]
		if spell.type == spell_type:
			filtered_spells.append(spell)
	return filtered_spells

func get_items_by_type(item_type: String) -> Array:
# Get all items of a specific type
	var filtered_items = []
	for item_id in items:
		var item = items[item_id]
		if item.type == item_type:
			filtered_items.append(item)
	return filtered_items

func get_items_by_rarity(rarity: String) -> Array:
# Get all items of a specific rarity
	var filtered_items = []
	for item_id in items:
		var item = items[item_id]
		if "rarity" in item and item.rarity == rarity:
			filtered_items.append(item)
	return filtered_items

func get_dungeons_by_difficulty(difficulty: int) -> Array:
# Get all dungeons of specific difficulty
	var filtered_dungeons = []
	for dungeon_id in dungeons:
		var dungeon = dungeons[dungeon_id]
		if dungeon.difficulty == difficulty:
			filtered_dungeons.append(dungeon)
	return filtered_dungeons

func get_enemies_by_element(element: String) -> Array:
# Get all enemies of specific element
	var filtered_enemies = []
	for enemy_id in enemies:
		var enemy = enemies[enemy_id]
		if enemy.get("element", "neutral") == element:
			filtered_enemies.append(enemy)
	return filtered_enemies

func get_enemies_by_ai_type(ai_type: String) -> Array:
# Get all enemies of specific AI type
	var filtered_enemies = []
	for enemy_id in enemies:
		var enemy = enemies[enemy_id]
		if enemy.get("ai_type", "aggressive") == ai_type:
			filtered_enemies.append(enemy)
	return filtered_enemies

# Data validation methods
func validate_race_id(race_id: String) -> bool:
# Check if race ID exists
	return race_id in races

func validate_class_id(class_id: String) -> bool:
# Check if class ID exists
	return class_id in classes

func validate_spell_id(spell_id: String) -> bool:
# Check if spell ID exists
	return spell_id in spells

func validate_dungeon_id(dungeon_id: String) -> bool:
# Check if dungeon ID exists
	return dungeon_id in dungeons

func validate_item_id(item_id: String) -> bool:
# Check if item ID exists
	return item_id in items

func validate_enemy_id(enemy_id: String) -> bool:
# Check if enemy ID exists
	return enemy_id in enemies

# Hot reload functionality (for development)
func reload_data():
# Reload all data files (useful for development)
	print("[DataLoader] Reloading all data...")
	load_all_data()
	EventBus.data_reloaded.emit()

func reload_specific_data(data_type: String):
# Reload specific data type
	match data_type:
		"races":
			load_races()
		"classes":
			load_classes()
		"spells":
			load_spells()
		"dungeons":
			load_dungeons()
		"items":
			load_items()
		"enemies":
			load_enemies()
		"attributes":
			load_attributes()
		_:
			push_warning("Unknown data type for reload: " + data_type)

# TODO: Future enhancements
# - Data versioning and migration system
# - Modding support with external data loading
# - Data integrity validation
# - Localization support for text fields
# - Dynamic data loading based on game state
# - Compressed data storage for larger datasets
# - Server-side data synchronization for multiplayer
