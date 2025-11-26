extends Node
# GameState.gd - Global game state management
# Manages player data, current dungeon, inventory, and world state

# Player data structure
var player_data = {
	"level": 1,
	"experience": 0,
	"race": "human",
	"class": "warrior",
	"attributes": {
		"strength": 10,
		"agility": 10,
		"vitality": 10,
		"intelligence": 10,
		"willpower": 10,
		"luck": 10
	},
	"current_hp": 100,
	"max_hp": 100,
	"current_mp": 50,
	"max_mp": 50,
	"skills": ["slash"],
	"inventory": [],
	"equipped": {
		"weapon": null,
		"armor": null,
		"accessory": null
	},
	"currency": 0
}

# World state
var current_dungeon_id = "root_forest"
var visited_dungeons = []
var world_events = []
var game_time = 0.0

# Combat state
var in_combat = false
var combat_participants = []

# Settings
var settings = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"auto_save": true
}

func _ready():
	print("[GameState] Initialized")
	# Connect to EventBus signals
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.dungeon_changed.connect(_on_dungeon_changed)
	EventBus.item_collected.connect(_on_item_collected)

# Player management functions
func create_new_player(race_id: String, class_id: String, name: String = "Hero"):
	"""Initialize a new player with selected race and class"""
	print("[GameState] Creating new player: ", name)
	
	var race_data = DataLoader.get_race(race_id)
	var class_data = DataLoader.get_class(class_id)
	
	if not race_data or not class_data:
		push_error("Invalid race or class ID")
		return false
	
	# Apply race bonuses
	for attribute in race_data.attribute_bonus:
		player_data.attributes[attribute] += race_data.attribute_bonus[attribute]
	
	# Apply class data
	player_data.race = race_id
	player_data.class = class_id
	player_data.skills = class_data.skills.duplicate()
	player_data.max_hp = class_data.base_hp + (player_data.attributes.vitality * 5)
	player_data.max_mp = class_data.base_mp + (player_data.attributes.intelligence * 3)
	player_data.current_hp = player_data.max_hp
	player_data.current_mp = player_data.max_mp
	
	EventBus.player_created.emit(player_data)
	return true

func get_player_data():
	"""Returns current player data"""
	return player_data

func update_player_hp(amount: int):
	"""Update player HP and emit signal if changed"""
	var old_hp = player_data.current_hp
	player_data.current_hp = clamp(player_data.current_hp + amount, 0, player_data.max_hp)
	
	if old_hp != player_data.current_hp:
		EventBus.player_hp_changed.emit(player_data.current_hp, player_data.max_hp)
		
		if player_data.current_hp <= 0:
			EventBus.player_died.emit()

func update_player_mp(amount: int):
	"""Update player MP and emit signal if changed"""
	var old_mp = player_data.current_mp
	player_data.current_mp = clamp(player_data.current_mp + amount, 0, player_data.max_mp)
	
	if old_mp != player_data.current_mp:
		EventBus.player_mp_changed.emit(player_data.current_mp, player_data.max_mp)

func gain_experience(amount: int):
	"""Add experience and handle level ups"""
	player_data.experience += amount
	var required_exp = get_required_experience_for_level(player_data.level + 1)
	
	if player_data.experience >= required_exp:
		level_up()

func get_required_experience_for_level(level: int) -> int:
	"""Calculate required experience for given level"""
	return level * 100 + (level - 1) * 50  # Simple progression formula

func level_up():
	"""Handle player leveling up"""
	player_data.level += 1
	
	# Increase max HP/MP
	var hp_gain = 10 + player_data.attributes.vitality
	var mp_gain = 5 + player_data.attributes.intelligence
	
	player_data.max_hp += hp_gain
	player_data.max_mp += mp_gain
	player_data.current_hp = player_data.max_hp
	player_data.current_mp = player_data.max_mp
	
	EventBus.player_level_up.emit(player_data.level, hp_gain, mp_gain)

# Inventory management
func add_item_to_inventory(item_id: String, quantity: int = 1):
	"""Add item to player inventory"""
	var existing_item = null
	for item in player_data.inventory:
		if item.id == item_id:
			existing_item = item
			break
	
	if existing_item:
		existing_item.quantity += quantity
	else:
		player_data.inventory.append({
			"id": item_id,
			"quantity": quantity
		})
	
	EventBus.inventory_updated.emit(player_data.inventory)

func remove_item_from_inventory(item_id: String, quantity: int = 1) -> bool:
	"""Remove item from inventory, returns true if successful"""
	for i in range(player_data.inventory.size()):
		var item = player_data.inventory[i]
		if item.id == item_id:
			if item.quantity >= quantity:
				item.quantity -= quantity
				if item.quantity <= 0:
					player_data.inventory.remove_at(i)
				EventBus.inventory_updated.emit(player_data.inventory)
				return true
			else:
				return false
	return false

func use_item(item_id: String) -> bool:
	"""Use a consumable item"""
	var item_data = DataLoader.get_item(item_id)
	if not item_data or item_data.type != "consumable":
		return false
	
	if not remove_item_from_inventory(item_id, 1):
		return false
	
	# Apply item effects
	if "heal" in item_data:
		update_player_hp(item_data.heal)
	if "mana_restore" in item_data:
		update_player_mp(item_data.mana_restore)
	
	EventBus.item_used.emit(item_id)
	return true

# Dungeon management
func change_dungeon(dungeon_id: String):
	"""Change current dungeon"""
	if dungeon_id == current_dungeon_id:
		return
	
	if dungeon_id not in visited_dungeons:
		visited_dungeons.append(dungeon_id)
	
	current_dungeon_id = dungeon_id
	EventBus.dungeon_changed.emit(dungeon_id)

func get_current_dungeon_data():
	"""Get data for current dungeon"""
	return DataLoader.get_dungeon(current_dungeon_id)

# Save/Load functions
func save_game(slot: int = 0):
	"""Save current game state"""
	var save_data = {
		"player_data": player_data,
		"current_dungeon_id": current_dungeon_id,
		"visited_dungeons": visited_dungeons,
		"world_events": world_events,
		"game_time": game_time,
		"settings": settings,
		"save_timestamp": Time.get_unix_time_from_system()
	}
	
	var save_file = FileAccess.open("user://save_game_" + str(slot) + ".dat", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		print("[GameState] Game saved to slot ", slot)
		return true
	else:
		push_error("Failed to save game")
		return false

func load_game(slot: int = 0) -> bool:
	"""Load game state from save file"""
	var save_file = FileAccess.open("user://save_game_" + str(slot) + ".dat", FileAccess.READ)
	if not save_file:
		print("[GameState] No save file found for slot ", slot)
		return false
	
	var json_string = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse save file")
		return false
	
	var save_data = json.data
	
	# Restore data
	player_data = save_data.player_data
	current_dungeon_id = save_data.current_dungeon_id
	visited_dungeons = save_data.visited_dungeons
	world_events = save_data.world_events
	game_time = save_data.game_time
	settings = save_data.settings
	
	print("[GameState] Game loaded from slot ", slot)
	EventBus.game_loaded.emit()
	return true

# Signal handlers
func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
	print("[GameState] Player reached level ", level)

func _on_dungeon_changed(dungeon_id: String):
	print("[GameState] Changed to dungeon: ", dungeon_id)

func _on_item_collected(item_id: String):
	add_item_to_inventory(item_id)

# Utility functions
func reset_game():
	"""Reset to new game state"""
	player_data = {
		"level": 1,
		"experience": 0,
		"race": "human",
		"class": "warrior",
		"attributes": {
			"strength": 10,
			"agility": 10,
			"vitality": 10,
			"intelligence": 10,
			"willpower": 10,
			"luck": 10
		},
		"current_hp": 100,
		"max_hp": 100,
		"current_mp": 50,
		"max_mp": 50,
		"skills": ["slash"],
		"inventory": [],
		"equipped": {
			"weapon": null,
			"armor": null,
			"accessory": null
		},
		"currency": 0
	}
	
	current_dungeon_id = "root_forest"
	visited_dungeons = []
	world_events = []
	game_time = 0.0
	in_combat = false
	combat_participants = []

# TODO: Future expansions
# - Equipment system with stat modifiers
# - Status effects system
# - Achievement system
# - Multiplayer state synchronization
# - Dynamic world events
# - Reputation system with factions