extends Node
# DataLoader.gd - Loads and manages all JSON data files
# Provides getter methods for all game data

# Cached data dictionaries
var races = {}
var classes = {}
var spells = {}
var dungeons = {}
var items = {}
var enemies = {}
var attributes = []

# Data file paths
var data_paths = {
	"races": "res://data/races.json",
	"classes": "res://data/classes.json", 
	"spells": "res://data/spells.json",
	"dungeons": "res://data/dungeons.json",
	"items": "res://data/items.json",
	"enemies": "res://data/enemies.json",
	"attributes": "res://data/base_attributes.json"
}

func _ready():
	print("[DataLoader] Starting data loading...")
	load_all_data()

func load_all_data():
	"""Load all JSON data files into memory"""
	load_attributes()
	load_races()
	load_classes()
	load_spells()
	load_dungeons()
	load_items()
	load_enemies()
	print("[DataLoader] All data loaded successfully")

func load_json_file(file_path: String):
	"""Generic JSON file loader with error handling"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON file: " + file_path + " Error: " + json.get_error_message())
		return null
	
	return json.data

# Specific data loaders
func load_attributes():
	"""Load base attributes list"""
	var data = load_json_file(data_paths.attributes)
	if data:
		attributes = data.attributes
		print("[DataLoader] Loaded ", attributes.size(), " attributes")

func load_races():
	"""Load race data into dictionary"""
	var data = load_json_file(data_paths.races)
	if data:
		races.clear()
		for race in data:
			races[race.id] = race
		print("[DataLoader] Loaded ", races.size(), " races")

func load_classes():
	"""Load class data into dictionary"""
	var data = load_json_file(data_paths.classes)
	if data:
		classes.clear()
		for class_data in data:
			classes[class_data.id] = class_data
		print("[DataLoader] Loaded ", classes.size(), " classes")

func load_spells():
	"""Load spell data into dictionary"""
	var data = load_json_file(data_paths.spells)
	if data:
		spells.clear()
		for spell in data:
			spells[spell.id] = spell
		print("[DataLoader] Loaded ", spells.size(), " spells")

func load_dungeons():
	"""Load dungeon data into dictionary"""
	var data = load_json_file(data_paths.dungeons)
	if data:
		dungeons.clear()
		for dungeon in data:
			dungeons[dungeon.id] = dungeon
		print("[DataLoader] Loaded ", dungeons.size(), " dungeons")

func load_items():
	"""Load item data into dictionary"""
	var data = load_json_file(data_paths.items)
	if data:
		items.clear()
		for item in data:
			items[item.id] = item
		print("[DataLoader] Loaded ", items.size(), " items")

func load_enemies():
	"""Load enemy data into dictionary"""
	var data = load_json_file(data_paths.enemies)
	if data:
		enemies.clear()
		for enemy in data:
			enemies[enemy.id] = enemy
		print("[DataLoader] Loaded ", enemies.size(), " enemies")

# Getter methods with validation
func get_race(race_id: String):
	"""Get race data by ID"""
	if race_id in races:
		return races[race_id]
	else:
		push_warning("Race not found: " + race_id)
		return null

func get_class(class_id: String):
	"""Get class data by ID"""
	if class_id in classes:
		return classes[class_id]
	else:
		push_warning("Class not found: " + class_id)
		return null

func get_spell(spell_id: String):
	"""Get spell data by ID"""
	if spell_id in spells:
		return spells[spell_id]
	else:
		push_warning("Spell not found: " + spell_id)
		return null

func get_dungeon(dungeon_id: String):
	"""Get dungeon data by ID"""
	if dungeon_id in dungeons:
		return dungeons[dungeon_id]
	else:
		push_warning("Dungeon not found: " + dungeon_id)
		return null

func get_item(item_id: String):
	"""Get item data by ID"""
	if item_id in items:
		return items[item_id]
	else:
		push_warning("Item not found: " + item_id)
		return null

func get_enemy_data(enemy_id: String):
	"""Get enemy data by ID"""
	if enemy_id in enemies:
		return enemies[enemy_id]
	else:
		push_warning("Enemy not found: " + enemy_id)
		return null

# Utility getter methods
func get_all_races() -> Array:
	"""Get all race IDs"""
	return races.keys()

func get_all_classes() -> Array:
	"""Get all class IDs"""
	return classes.keys()

func get_all_spells() -> Array:
	"""Get all spell IDs"""
	return spells.keys()

func get_all_dungeons() -> Array:
	"""Get all dungeon IDs"""
	return dungeons.keys()

func get_all_items() -> Array:
	"""Get all item IDs"""
	return items.keys()

func get_all_enemies() -> Array:
	"""Get all enemy IDs"""
	return enemies.keys()

func get_attributes() -> Array:
	"""Get base attributes list"""
	return attributes

# Filtered getters
func get_spells_by_type(spell_type: String) -> Array:
	"""Get all spells of a specific type"""
	var filtered_spells = []
	for spell_id in spells:
		var spell = spells[spell_id]
		if spell.type == spell_type:
			filtered_spells.append(spell)
	return filtered_spells

func get_items_by_type(item_type: String) -> Array:
	"""Get all items of a specific type"""
	var filtered_items = []
	for item_id in items:
		var item = items[item_id]
		if item.type == item_type:
			filtered_items.append(item)
	return filtered_items

func get_items_by_rarity(rarity: String) -> Array:
	"""Get all items of a specific rarity"""
	var filtered_items = []
	for item_id in items:
		var item = items[item_id]
		if "rarity" in item and item.rarity == rarity:
			filtered_items.append(item)
	return filtered_items

func get_dungeons_by_difficulty(difficulty: int) -> Array:
	"""Get all dungeons of specific difficulty"""
	var filtered_dungeons = []
	for dungeon_id in dungeons:
		var dungeon = dungeons[dungeon_id]
		if dungeon.difficulty == difficulty:
			filtered_dungeons.append(dungeon)
	return filtered_dungeons

func get_enemies_by_element(element: String) -> Array:
	"""Get all enemies of specific element"""
	var filtered_enemies = []
	for enemy_id in enemies:
		var enemy = enemies[enemy_id]
		if enemy.get("element", "neutral") == element:
			filtered_enemies.append(enemy)
	return filtered_enemies

func get_enemies_by_ai_type(ai_type: String) -> Array:
	"""Get all enemies of specific AI type"""
	var filtered_enemies = []
	for enemy_id in enemies:
		var enemy = enemies[enemy_id]
		if enemy.get("ai_type", "aggressive") == ai_type:
			filtered_enemies.append(enemy)
	return filtered_enemies

# Data validation methods
func validate_race_id(race_id: String) -> bool:
	"""Check if race ID exists"""
	return race_id in races

func validate_class_id(class_id: String) -> bool:
	"""Check if class ID exists"""
	return class_id in classes

func validate_spell_id(spell_id: String) -> bool:
	"""Check if spell ID exists"""
	return spell_id in spells

func validate_dungeon_id(dungeon_id: String) -> bool:
	"""Check if dungeon ID exists"""
	return dungeon_id in dungeons

func validate_item_id(item_id: String) -> bool:
	"""Check if item ID exists"""
	return item_id in items

func validate_enemy_id(enemy_id: String) -> bool:
	"""Check if enemy ID exists"""
	return enemy_id in enemies

# Hot reload functionality (for development)
func reload_data():
	"""Reload all data files (useful for development)"""
	print("[DataLoader] Reloading all data...")
	load_all_data()
	EventBus.data_reloaded.emit()

func reload_specific_data(data_type: String):
	"""Reload specific data type"""
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