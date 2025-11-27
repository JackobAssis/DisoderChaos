extends Node
class_name ItemSystem
# item_system.gd - Advanced item management and usage system

# Item type handlers
var item_handlers = {}

# Cooldown system
var item_cooldowns = {}
var global_cooldown = 1.0  # 1 second global cooldown

# Item stacking rules
var max_stack_sizes = {
	"consumable": 99,
	"material": 999,
	"currency": 9999,
	"weapon": 1,
	"armor": 1,
	"accessory": 1,
	"key": 1
}

func _ready():
	print("[ItemSystem] Item system initialized")
	setup_item_handlers()

func setup_item_handlers():
# Setup handlers for different item types
	item_handlers["consumable"] = use_consumable_item
	item_handlers["weapon"] = equip_weapon_item
	item_handlers["armor"] = equip_armor_item
	item_handlers["accessory"] = equip_accessory_item
	item_handlers["material"] = use_material_item
	item_handlers["currency"] = use_currency_item
	item_handlers["key"] = use_key_item

func use_item(player: Node, item_id: String, quantity: int = 1) -> bool:
# Use an item with the player
	var item_data = get_item_data(item_id)
	if not item_data:
		EventBus.show_notification("Unknown item: " + item_id, "error")
		return false
	
	# Check if item is on cooldown
	if is_item_on_cooldown(item_id):
		var remaining = get_cooldown_remaining(item_id)
		EventBus.show_notification("Item on cooldown: " + str(int(remaining)) + "s", "warning")
		return false
	
	# Check if player has the item
	if not player_has_item(player, item_id, quantity):
		EventBus.show_notification("Not enough " + item_data.name, "error")
		return false
	
	# Get item type handler
	var item_type = item_data.get("type", "unknown")
	var handler = item_handlers.get(item_type)
	
	if not handler:
		EventBus.show_notification("Cannot use " + item_data.name, "error")
		return false
	
	# Execute item usage
	var success = handler.call(player, item_data, quantity)
	
	if success:
		# Remove item from inventory (except for equipment)
		if item_type in ["consumable", "material", "currency", "key"]:
			remove_item_from_player(player, item_id, quantity)
		
		# Start cooldown if item has one
		if item_data.has("cooldown"):
			start_item_cooldown(item_id, item_data.cooldown)
		
		# Emit usage event
		EventBus.item_used.emit(item_id)
		
		return true
	
	return false

func get_item_data(item_id: String) -> Dictionary:
# Get item data with error handling
	var item_data = DataLoader.get_item(item_id)
	if not item_data:
		push_warning("[ItemSystem] Item data not found: " + item_id)
		return {}
	return item_data

func player_has_item(player: Node, item_id: String, quantity: int) -> bool:
# Check if player has sufficient quantity of item
	if player.has_method("has_item_in_inventory"):
		return player.has_item_in_inventory(item_id, quantity)
	return false

func remove_item_from_player(player: Node, item_id: String, quantity: int) -> bool:
# Remove item from player inventory
	if player.has_method("remove_item_from_inventory"):
		return player.remove_item_from_inventory(item_id, quantity)
	return false

# Item type handlers
func use_consumable_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle consumable item usage
	var item_name = item_data.get("name", "Unknown Item")
	var effects_applied = 0
	
	for i in quantity:
		var success = false
		
		# Health restoration
		if item_data.has("heal"):
			var heal_amount = item_data.heal
			if player.has_method("heal"):
				var actual_heal = player.heal(heal_amount)
				if actual_heal > 0:
					success = true
					EventBus.show_notification("Healed " + str(actual_heal) + " HP", "success")
		
		# Mana restoration
		if item_data.has("mana_restore"):
			var mana_amount = item_data.mana_restore
			if player.has_method("restore_mana"):
				player.restore_mana(mana_amount)
				success = true
				EventBus.show_notification("Restored " + str(mana_amount) + " MP", "success")
			elif player.has_method("update_player_mp"):
				GameState.update_player_mp(mana_amount)
				success = true
		
		# Status effect removal
		if item_data.has("removes_effects"):
			for effect_id in item_data.removes_effects:
				if player.has_method("remove_status_effect"):
					player.remove_status_effect(effect_id)
					success = true
		
		# Temporary buffs
		if item_data.has("buffs"):
			for buff in item_data.buffs:
				apply_temporary_buff(player, buff)
				success = true
		
		if success:
			effects_applied += 1
	
	if effects_applied > 0:
		EventBus.show_notification("Used " + item_name + " x" + str(effects_applied), "info")
		return true
	
	return false

func equip_weapon_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle weapon equipment
	if not player.has_method("equip_weapon"):
		return false
	
	# Check requirements
	if item_data.has("requirements"):
		if not check_item_requirements(player, item_data.requirements):
			var req_text = format_requirements(item_data.requirements)
			EventBus.show_notification("Requirements not met: " + req_text, "warning")
			return false
	
	player.equip_weapon(item_data.id)
	EventBus.show_notification("Equipped: " + item_data.name, "success")
	return true

func equip_armor_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle armor equipment
	if not player.has_method("equip_armor"):
		return false
	
	# Check requirements
	if item_data.has("requirements"):
		if not check_item_requirements(player, item_data.requirements):
			var req_text = format_requirements(item_data.requirements)
			EventBus.show_notification("Requirements not met: " + req_text, "warning")
			return false
	
	player.equip_armor(item_data.id)
	EventBus.show_notification("Equipped: " + item_data.name, "success")
	return true

func equip_accessory_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle accessory equipment
	# TODO: Implement accessory system
	EventBus.show_notification("Accessory system not yet implemented", "warning")
	return false

func use_material_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle material item usage
	# Materials are typically used in crafting
	# For now, just show that they can't be used directly
	EventBus.show_notification(item_data.name + " is a crafting material", "info")
	return false

func use_currency_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle currency item usage
	# Currency is automatically added to player's currency pool
	var value = item_data.get("value", 1) * quantity
	GameState.player_data.currency += value
	EventBus.show_notification("Gained " + str(value) + " coins", "success")
	return true

func use_key_item(player: Node, item_data: Dictionary, quantity: int) -> bool:
# Handle key item usage
	# TODO: Implement key item system for unlocking doors/areas
	EventBus.show_notification("Key item: " + item_data.name, "info")
	return false

# Requirement checking
func check_item_requirements(player: Node, requirements: Dictionary) -> bool:
# Check if player meets item requirements
	if not player.has_method("get_stats"):
		return false
	
	var player_stats = player.get_stats()
	
	# Check attribute requirements
	for requirement in requirements:
		var required_value = requirements[requirement]
		var player_value = player_stats.get(requirement, 0)
		
		if player_value < required_value:
			return false
	
	return true

func format_requirements(requirements: Dictionary) -> String:
# Format requirements as readable text
	var req_parts = []
	for attribute in requirements:
		req_parts.append(attribute.capitalize() + " " + str(requirements[attribute]))
	return " ".join(req_parts)

# Buff system
func apply_temporary_buff(player: Node, buff_data: Dictionary):
# Apply temporary buff to player
	var buff_id = buff_data.get("id", "unknown")
	var duration = buff_data.get("duration", 10.0)
	var effects = buff_data.get("effects", {})
	
	if player.has_method("add_status_effect"):
		player.add_status_effect(buff_id, duration, effects)

# Cooldown system
func is_item_on_cooldown(item_id: String) -> bool:
# Check if item is on cooldown
	return item_id in item_cooldowns

func get_cooldown_remaining(item_id: String) -> float:
# Get remaining cooldown time for item
	if item_id in item_cooldowns:
		return item_cooldowns[item_id]
	return 0.0

func start_item_cooldown(item_id: String, cooldown_time: float):
# Start cooldown for an item
	item_cooldowns[item_id] = cooldown_time

func _process(delta):
# Update item cooldowns
	update_cooldowns(delta)

func update_cooldowns(delta):
# Update all item cooldowns
	var items_to_remove = []
	
	for item_id in item_cooldowns:
		item_cooldowns[item_id] -= delta
		if item_cooldowns[item_id] <= 0:
			items_to_remove.append(item_id)
	
	# Remove expired cooldowns
	for item_id in items_to_remove:
		item_cooldowns.erase(item_id)

# Item stacking
func get_max_stack_size(item_id: String) -> int:
# Get maximum stack size for an item
	var item_data = get_item_data(item_id)
	if not item_data:
		return 1
	
	var item_type = item_data.get("type", "unknown")
	
	# Check for custom stack size
	if item_data.has("max_stack"):
		return item_data.max_stack
	
	# Use default for item type
	return max_stack_sizes.get(item_type, 1)

func can_items_stack(item_id1: String, item_id2: String) -> bool:
# Check if two items can stack together
	if item_id1 != item_id2:
		return false
	
	return get_max_stack_size(item_id1) > 1

# Item comparison and sorting
func compare_item_rarity(item_id1: String, item_id2: String) -> int:
# Compare items by rarity for sorting
	var rarity_values = {
		"common": 1,
		"uncommon": 2,
		"rare": 3,
		"epic": 4,
		"legendary": 5,
		"mythic": 6
	}
	
	var item1_data = get_item_data(item_id1)
	var item2_data = get_item_data(item_id2)
	
	var rarity1 = item1_data.get("rarity", "common")
	var rarity2 = item2_data.get("rarity", "common")
	
	var value1 = rarity_values.get(rarity1, 1)
	var value2 = rarity_values.get(rarity2, 1)
	
	return value2 - value1  # Higher rarity first

func compare_item_value(item_id1: String, item_id2: String) -> int:
# Compare items by value for sorting
	var item1_data = get_item_data(item_id1)
	var item2_data = get_item_data(item_id2)
	
	var value1 = item1_data.get("value", 0)
	var value2 = item2_data.get("value", 0)
	
	return value2 - value1  # Higher value first

func sort_inventory(inventory: Array, sort_type: String = "type") -> Array:
# Sort inventory array by specified criteria
	var sorted_inv = inventory.duplicate()
	
	match sort_type:
		"type":
			sorted_inv.sort_custom(compare_item_type)
		"rarity":
			sorted_inv.sort_custom(compare_by_rarity)
		"value":
			sorted_inv.sort_custom(compare_by_value)
		"name":
			sorted_inv.sort_custom(compare_by_name)
	
	return sorted_inv

func compare_item_type(a, b):
# Compare items by type for sorting
	var item_a = get_item_data(a.id)
	var item_b = get_item_data(b.id)
	
	var type_a = item_a.get("type", "")
	var type_b = item_b.get("type", "")
	
	return type_a < type_b

func compare_by_rarity(a, b):
# Compare items by rarity for sorting
	return compare_item_rarity(a.id, b.id) > 0

func compare_by_value(a, b):
# Compare items by value for sorting
	return compare_item_value(a.id, b.id) > 0

func compare_by_name(a, b):
# Compare items by name for sorting
	var item_a = get_item_data(a.id)
	var item_b = get_item_data(b.id)
	
	var name_a = item_a.get("name", "")
	var name_b = item_b.get("name", "")
	
	return name_a < name_b

# Utility functions
func get_item_tooltip(item_id: String) -> String:
# Generate tooltip text for an item
	var item_data = get_item_data(item_id)
	if not item_data:
		return "Unknown Item"
	
	var tooltip = "[b]" + item_data.name + "[/b]\n"
	tooltip += "[color=gray]" + item_data.get("description", "No description") + "[/color]\n"
	
	# Add item type and rarity
	var item_type = item_data.get("type", "unknown").capitalize()
	var rarity = item_data.get("rarity", "common").capitalize()
	tooltip += "\n[color=yellow]Type:[/color] " + item_type
	tooltip += "\n[color=yellow]Rarity:[/color] " + rarity
	
	# Add stats for equipment
	if item_data.get("type") == "weapon":
		if item_data.has("damage"):
			tooltip += "\n[color=red]Damage:[/color] " + str(item_data.damage)
		if item_data.has("durability"):
			tooltip += "\n[color=blue]Durability:[/color] " + str(item_data.durability)
	
	if item_data.get("type") == "armor":
		if item_data.has("defense"):
			tooltip += "\n[color=green]Defense:[/color] " + str(item_data.defense)
	
	# Add value
	if item_data.has("value"):
		tooltip += "\n[color=yellow]Value:[/color] " + str(item_data.value) + " coins"
	
	return tooltip

# TODO: Future enhancements
# - Advanced crafting system integration
# - Item enchantment and upgrade system
# - Set item bonuses when multiple pieces equipped
# - Item repair and durability system
# - Item trading and marketplace integration
# - Custom item effects and scripting
# - Item collections and achievements
# - Seasonal and event-specific items
