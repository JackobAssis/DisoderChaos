extends Node
class_name LootSystem
# loot_system.gd - Advanced loot generation and management system

# Loot rarity weights (higher = more common)
var rarity_weights = {
	"common": 70.0,
	"uncommon": 20.0,
	"rare": 8.0,
	"epic": 1.8,
	"legendary": 0.2,
	"mythic": 0.01
}

# Base drop chances
var base_drop_chance = 0.8  # 80% chance for any loot
var bonus_drop_chance = 0.3  # 30% chance for bonus item

# Player luck influence
var luck_modifier = 0.01  # 1% increase per luck point

func _ready():
	print("[LootSystem] Loot system initialized")

func drop_loot_from_enemy(enemy_id: String, player: Node, enemy_position: Vector2) -> Array:
	"""Generate and drop loot from defeated enemy"""
	var enemy_data = DataLoader.get_enemy_data(enemy_id)
	if not enemy_data:
		print("[LootSystem] No enemy data found for: ", enemy_id)
		return []
	
	var dropped_items = []
	var loot_table = enemy_data.get("loot_table", [])
	
	if loot_table.is_empty():
		return []
	
	# Calculate player luck modifier
	var player_luck = 10  # Default luck
	if player and player.has_method("get_stats"):
		var stats = player.get_stats()
		player_luck = stats.get("luck", 10)
	
	var luck_bonus = (player_luck - 10) * luck_modifier
	
	# Process each item in loot table
	for loot_entry in loot_table:
		var item_id = loot_entry.get("item", "")
		var base_chance = loot_entry.get("chance", 0.0)
		var final_chance = min(0.95, base_chance + luck_bonus)  # Max 95% chance
		
		if randf() < final_chance:
			var quantity = loot_entry.get("quantity", 1)
			if loot_entry.has("quantity_range"):
				var range_array = loot_entry.quantity_range
				quantity = randi_range(range_array[0], range_array[1])
			
			dropped_items.append({
				"item_id": item_id,
				"quantity": quantity
			})
	
	# Chance for bonus rare drop
	if randf() < bonus_drop_chance + luck_bonus:
		var bonus_item = generate_bonus_loot(enemy_data, player_luck)
		if bonus_item:
			dropped_items.append(bonus_item)
	
	# Create loot objects in world and add to player inventory
	for loot_item in dropped_items:
		create_loot_pickup(loot_item, enemy_position, player)
		add_item_to_player_inventory(loot_item, player)
	
	return dropped_items

func generate_bonus_loot(enemy_data: Dictionary, player_luck: int) -> Dictionary:
	"""Generate bonus loot based on enemy type and player luck"""
	var enemy_element = enemy_data.get("element", "neutral")
	var enemy_difficulty = enemy_data.get("max_hp", 40)
	
	# Select rarity based on luck and enemy difficulty
	var rarity = select_loot_rarity(player_luck, enemy_difficulty)
	
	# Get items of selected rarity
	var available_items = DataLoader.get_items_by_rarity(rarity)
	if available_items.is_empty():
		available_items = DataLoader.get_items_by_rarity("common")
	
	if available_items.is_empty():
		return {}
	
	# Select random item
	var random_item = available_items[randi() % available_items.size()]
	
	return {
		"item_id": random_item.id,
		"quantity": 1
	}

func select_loot_rarity(player_luck: int, enemy_difficulty: int) -> String:
	"""Select loot rarity based on player luck and enemy strength"""
	var modified_weights = rarity_weights.duplicate()
	
	# Increase rare item chances based on luck
	var luck_factor = 1.0 + (player_luck - 10) * 0.1
	modified_weights["uncommon"] *= luck_factor
	modified_weights["rare"] *= luck_factor * 1.5
	modified_weights["epic"] *= luck_factor * 2.0
	modified_weights["legendary"] *= luck_factor * 3.0
	
	# Increase rare chances based on enemy difficulty
	var difficulty_factor = 1.0 + (enemy_difficulty - 40) * 0.02
	if difficulty_factor > 1.0:
		modified_weights["rare"] *= difficulty_factor
		modified_weights["epic"] *= difficulty_factor
		modified_weights["legendary"] *= difficulty_factor
	
	# Select rarity using weighted random
	return weighted_random_selection(modified_weights)

func weighted_random_selection(weights: Dictionary) -> String:
	"""Select item using weighted random selection"""
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for rarity in weights:
		current_weight += weights[rarity]
		if random_value <= current_weight:
			return rarity
	
	return "common"  # Fallback

func create_loot_pickup(loot_item: Dictionary, position: Vector2, player: Node):
	"""Create visual loot pickup in the world"""
	# TODO: Create actual loot pickup objects in the world
	# For now, just show notification
	var item_data = DataLoader.get_item(loot_item.item_id)
	if item_data:
		var message = "Found: " + item_data.name
		if loot_item.quantity > 1:
			message += " x" + str(loot_item.quantity)
		
		EventBus.ui_notification_shown.emit(message, "success")
		EventBus.item_collected.emit(loot_item.item_id)

func add_item_to_player_inventory(loot_item: Dictionary, player: Node):
	"""Add loot item to player inventory"""
	if player and player.has_method("add_item_to_inventory"):
		player.add_item_to_inventory(loot_item.item_id, loot_item.quantity)

func generate_currency_loot(base_amount: int, player_luck: int) -> Dictionary:
	"""Generate currency loot with luck modifier"""
	var luck_multiplier = 1.0 + (player_luck - 10) * 0.05
	var final_amount = int(base_amount * luck_multiplier * randf_range(0.8, 1.2))
	
	# Select currency type based on amount
	var currency_type = "bronze_coin"
	if final_amount >= 100:
		currency_type = "gold_coin"
		final_amount = final_amount / 100
	elif final_amount >= 10:
		currency_type = "silver_coin" 
		final_amount = final_amount / 10
	
	return {
		"item_id": currency_type,
		"quantity": max(1, final_amount)
	}

func generate_material_loot(enemy_element: String) -> Array:
	"""Generate element-specific material loot"""
	var materials = []
	
	match enemy_element:
		"fire":
			materials = ["fire_crystal", "ash", "sulfur"]
		"ice":
			materials = ["ice_crystal", "frozen_essence"]
		"nature":
			materials = ["nature_essence", "corrupted_bark", "living_wood"]
		"undead":
			materials = ["bone_fragment", "soul_shard", "ectoplasm"]
		"earth":
			materials = ["stone_core", "crystal_shard", "iron_ore"]
		"crystal":
			materials = ["crystal_shard", "mana_crystal", "prismatic_dust"]
		_:
			materials = ["wood", "stone", "bronze_coin"]
	
	# Filter materials that exist in the game
	var valid_materials = []
	for material in materials:
		if DataLoader.validate_item_id(material):
			valid_materials.append(material)
	
	if valid_materials.is_empty():
		return []
	
	# Return random material
	var selected_material = valid_materials[randi() % valid_materials.size()]
	return [{
		"item_id": selected_material,
		"quantity": randi_range(1, 3)
	}]

func calculate_loot_modifier(player_level: int, enemy_level: int) -> float:
	"""Calculate loot quantity modifier based on level difference"""
	var level_diff = enemy_level - player_level
	
	if level_diff >= 5:
		return 1.5  # 50% bonus for challenging enemies
	elif level_diff >= 2:
		return 1.2  # 20% bonus
	elif level_diff <= -5:
		return 0.5  # 50% penalty for easy enemies
	elif level_diff <= -2:
		return 0.8  # 20% penalty
	else:
		return 1.0  # Normal loot

func drop_container_loot(container_type: String, player: Node, position: Vector2) -> Array:
	"""Generate loot from containers (chests, barrels, etc.)"""
	var loot_items = []
	
	match container_type:
		"wooden_chest":
			loot_items = generate_chest_loot("common", 2, player)
		"iron_chest":
			loot_items = generate_chest_loot("uncommon", 3, player)
		"treasure_chest":
			loot_items = generate_chest_loot("rare", 4, player)
		"barrel":
			loot_items = generate_barrel_loot(player)
		"crate":
			loot_items = generate_crate_loot(player)
	
	# Create pickups for each item
	for loot_item in loot_items:
		create_loot_pickup(loot_item, position, player)
		add_item_to_player_inventory(loot_item, player)
	
	return loot_items

func generate_chest_loot(min_rarity: String, max_items: int, player: Node) -> Array:
	"""Generate loot for treasure chests"""
	var loot_items = []
	var num_items = randi_range(1, max_items)
	
	for i in num_items:
		var rarity = select_chest_rarity(min_rarity)
		var items = DataLoader.get_items_by_rarity(rarity)
		
		if not items.is_empty():
			var item = items[randi() % items.size()]
			loot_items.append({
				"item_id": item.id,
				"quantity": 1
			})
	
	return loot_items

func generate_barrel_loot(player: Node) -> Array:
	"""Generate loot for barrels (consumables and materials)"""
	var barrel_items = ["minor_potion", "mana_potion", "wood", "bronze_coin"]
	var selected_item = barrel_items[randi() % barrel_items.size()]
	
	return [{
		"item_id": selected_item,
		"quantity": randi_range(1, 2)
	}]

func generate_crate_loot(player: Node) -> Array:
	"""Generate loot for crates (materials and equipment)"""
	var crate_items = ["wood", "stone", "bronze_coin", "rusty_sword", "leather_armor"]
	var selected_item = crate_items[randi() % crate_items.size()]
	
	return [{
		"item_id": selected_item,
		"quantity": 1
	}]

func select_chest_rarity(min_rarity: String) -> String:
	"""Select rarity for chest loot with minimum guarantee"""
	var available_rarities = []
	var rarity_order = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	var min_index = rarity_order.find(min_rarity)
	
	if min_index == -1:
		min_index = 0
	
	# Include rarities from minimum upward
	for i in range(min_index, rarity_order.size()):
		available_rarities.append(rarity_order[i])
	
	# Weight toward lower rarities but allow higher ones
	var weights = {}
	for i in range(available_rarities.size()):
		var rarity = available_rarities[i]
		weights[rarity] = pow(0.3, i)  # Exponential decay
	
	return weighted_random_selection(weights)

# Utility functions for external use
func get_loot_value(loot_items: Array) -> int:
	"""Calculate total value of loot items"""
	var total_value = 0
	for loot_item in loot_items:
		var item_data = DataLoader.get_item(loot_item.item_id)
		if item_data:
			total_value += item_data.get("value", 0) * loot_item.quantity
	return total_value

func format_loot_summary(loot_items: Array) -> String:
	"""Create formatted string of loot items"""
	if loot_items.is_empty():
		return "No loot found"
	
	var summary = "Loot found:\n"
	for loot_item in loot_items:
		var item_data = DataLoader.get_item(loot_item.item_id)
		if item_data:
			summary += "• " + item_data.name
			if loot_item.quantity > 1:
				summary += " x" + str(loot_item.quantity)
			summary += "\n"
	
	return summary

# TODO: Future enhancements
# - Physical loot objects that players can pick up
# - Loot sharing for party/group play
# - Set item drops with bonuses
# - Seasonal/event-specific loot tables
# - Loot quality based on player performance
# - Salvaging and disenchanting systems
# - Auction house integration for rare items
# - Achievement tracking for loot milestones