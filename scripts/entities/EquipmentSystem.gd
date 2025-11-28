extends Node

class_name EquipmentSystem

signal equipment_changed(slot: String, item_data: Dictionary)
signal item_equipped(item_id: String, slot: String)
signal item_unequipped(item_id: String, slot: String)
signal stats_changed(attribute_modifiers: Dictionary)

# Equipment slots
enum EquipmentSlot {
	HELMET,
	ARMOR,
	GLOVES,
	BOOTS,
	WEAPON_MAIN,
	WEAPON_OFF,
	RING_1,
	RING_2,
	AMULET,
	CLOAK
}

# Slot names for easier reference
var slot_names = {
	EquipmentSlot.HELMET: "helmet",
	EquipmentSlot.ARMOR: "armor", 
	EquipmentSlot.GLOVES: "gloves",
	EquipmentSlot.BOOTS: "boots",
	EquipmentSlot.WEAPON_MAIN: "weapon_main",
	EquipmentSlot.WEAPON_OFF: "weapon_off",
	EquipmentSlot.RING_1: "ring_1",
	EquipmentSlot.RING_2: "ring_2",
	EquipmentSlot.AMULET: "amulet",
	EquipmentSlot.CLOAK: "cloak"
}

# Currently equipped items
var equipped_items: Dictionary = {}

# Calculated bonuses from equipment
var total_attribute_modifiers: Dictionary = {}
var total_damage_bonus: int = 0
var total_defense_bonus: int = 0
var total_special_effects: Array = []

# References
@onready var data_loader: DataLoader = get_node("/root/DataLoader")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var player_stats: PlayerStats

func _ready():
	print("[EquipmentSystem] Equipment system initialized")

func initialize():
# Initialize equipment system
	# Clear all slots
	for slot in EquipmentSlot.values():
		equipped_items[slot_names[slot]] = null
	
	# Get reference to player stats
	player_stats = get_parent().get_node("PlayerStats")
	
	# Initialize empty bonuses
	recalculate_bonuses()
	
	print("[EquipmentSystem] %d equipment slots initialized" % equipped_items.size())

func equip_item(item_id: String, slot: int = -1) -> bool:
# Equip an item to appropriate slot
	var item_data = data_loader.get_item(item_id)
	if not item_data:
		print("[EquipmentSystem] âŒ Item not found: %s" % item_id)
		return false
	
	# Determine slot if not specified
	if slot == -1:
		slot = determine_item_slot(item_data)
		if slot == -1:
			print("[EquipmentSystem] âŒ Cannot determine slot for item: %s" % item_id)
			return false
	
	# Check if item can be equipped in this slot
	if not can_equip_in_slot(item_data, slot):
		print("[EquipmentSystem] âŒ Item %s cannot be equipped in slot %s" % [item_id, slot_names[slot]])
		return false
	
	var slot_name = slot_names[slot]
	
	# Unequip current item in slot if any
	if equipped_items[slot_name] != null:
		unequip_item_from_slot(slot)
	
	# Equip new item
	equipped_items[slot_name] = {
		"item_id": item_id,
		"item_data": item_data
	}
	
	# Recalculate bonuses
	recalculate_bonuses()
	
	# Emit signals
	equipment_changed.emit(slot_name, item_data)
	item_equipped.emit(item_id, slot_name)
	
	print("[EquipmentSystem] âœ… Equipped %s to %s" % [item_data.name, slot_name])
	return true

func unequip_item_from_slot(slot: int) -> Dictionary:
# Unequip item from slot and return item data
	var slot_name = slot_names[slot]
	var current_item = equipped_items[slot_name]
	
	if current_item == null:
		return {}
	
	var item_data = current_item.item_data
	var item_id = current_item.item_id
	
	# Clear slot
	equipped_items[slot_name] = null
	
	# Recalculate bonuses
	recalculate_bonuses()
	
	# Emit signals
	equipment_changed.emit(slot_name, {})
	item_unequipped.emit(item_id, slot_name)
	
	print("[EquipmentSystem] Unequipped %s from %s" % [item_data.name, slot_name])
	return item_data

func determine_item_slot(item_data: Dictionary) -> int:
# Determine appropriate slot for item based on type
	var item_type = item_data.get("type", "")
	var subtype = item_data.get("subtype", "")
	
	match item_type:
		"armor":
			match subtype:
				"helmet":
					return EquipmentSlot.HELMET
				"chest":
					return EquipmentSlot.ARMOR
				"gloves":
					return EquipmentSlot.GLOVES
				"boots":
					return EquipmentSlot.BOOTS
				_:
					return EquipmentSlot.ARMOR
		
		"weapon":
			match subtype:
				"shield":
					return EquipmentSlot.WEAPON_OFF
				"two_handed":
					return EquipmentSlot.WEAPON_MAIN
				_:
					return EquipmentSlot.WEAPON_MAIN
		
		"accessory":
			match subtype:
				"ring":
					# Try to equip in first empty ring slot
					if equipped_items["ring_1"] == null:
						return EquipmentSlot.RING_1
					else:
						return EquipmentSlot.RING_2
				"amulet":
					return EquipmentSlot.AMULET
				"cloak":
					return EquipmentSlot.CLOAK
				_:
					return EquipmentSlot.AMULET
	
	return -1  # No appropriate slot found

func can_equip_in_slot(item_data: Dictionary, slot: int) -> bool:
# Check if item can be equipped in specific slot
	var item_type = item_data.get("type", "")
	var subtype = item_data.get("subtype", "")
	
	match slot:
		EquipmentSlot.HELMET:
			return item_type == "armor" and subtype == "helmet"
		
		EquipmentSlot.ARMOR:
			return item_type == "armor" and subtype == "chest"
		
		EquipmentSlot.GLOVES:
			return item_type == "armor" and subtype == "gloves"
		
		EquipmentSlot.BOOTS:
			return item_type == "armor" and subtype == "boots"
		
		EquipmentSlot.WEAPON_MAIN:
			return item_type == "weapon"
		
		EquipmentSlot.WEAPON_OFF:
			return item_type == "weapon" and (subtype == "shield" or item_data.get("can_dual_wield", false))
		
		EquipmentSlot.RING_1, EquipmentSlot.RING_2:
			return item_type == "accessory" and subtype == "ring"
		
		EquipmentSlot.AMULET:
			return item_type == "accessory" and subtype == "amulet"
		
		EquipmentSlot.CLOAK:
			return item_type == "accessory" and subtype == "cloak"
	
	return false

func recalculate_bonuses():
# Recalculate all equipment bonuses
	# Clear previous bonuses
	total_attribute_modifiers.clear()
	total_damage_bonus = 0
	total_defense_bonus = 0
	total_special_effects.clear()
	
	# Sum bonuses from all equipped items
	for slot_name in equipped_items.keys():
		var equipped_item = equipped_items[slot_name]
		if equipped_item == null:
			continue
		
		var item_data = equipped_item.item_data
		
		# Add attribute modifiers
		var attr_mods = item_data.get("attribute_modifiers", {})
		for attribute in attr_mods.keys():
			total_attribute_modifiers[attribute] = total_attribute_modifiers.get(attribute, 0) + attr_mods[attribute]
		
		# Add damage bonus
		total_damage_bonus += item_data.get("damage_bonus", 0)
		
		# Add defense bonus
		total_defense_bonus += item_data.get("defense_bonus", 0)
		
		# Add special effects
		var effects = item_data.get("special_effects", [])
		total_special_effects.append_array(effects)
	
	# Update player stats with new equipment modifiers
	if player_stats:
		player_stats.update_equipment_modifiers(total_attribute_modifiers)
	
	# Emit stats changed signal
	stats_changed.emit(total_attribute_modifiers)
	
	print("[EquipmentSystem] Bonuses recalculated")

func get_equipped_item(slot: EquipmentSlot) -> Dictionary:
# Get item equipped in slot
	var slot_name = slot_names[slot]
	var equipped_item = equipped_items.get(slot_name)
	
	if equipped_item == null:
		return {}
	
	return equipped_item.item_data

func get_equipped_item_id(slot: EquipmentSlot) -> String:
# Get ID of item equipped in slot
	var slot_name = slot_names[slot]
	var equipped_item = equipped_items.get(slot_name)
	
	if equipped_item == null:
		return ""
	
	return equipped_item.item_id

func is_slot_empty(slot: EquipmentSlot) -> bool:
# Check if equipment slot is empty
	var slot_name = slot_names[slot]
	return equipped_items.get(slot_name) == null

func get_total_damage_bonus() -> int:
# Get total damage bonus from equipment
	return total_damage_bonus

func get_total_defense_bonus() -> int:
# Get total defense bonus from equipment
	return total_defense_bonus

func get_attribute_modifiers() -> Dictionary:
# Get all attribute modifiers from equipment
	return total_attribute_modifiers.duplicate()

func get_special_effects() -> Array:
# Get all special effects from equipment
	return total_special_effects.duplicate()

func has_special_effect(effect_name: String) -> bool:
# Check if player has specific special effect from equipment
	return effect_name in total_special_effects

# Equipment sets functionality
func check_equipment_sets() -> Array:
# Check for complete equipment sets and return set bonuses
	var completed_sets = []
	var set_items = {}
	
	# Group items by set
	for slot_name in equipped_items.keys():
		var equipped_item = equipped_items[slot_name]
		if equipped_item == null:
			continue
		
		var item_data = equipped_item.item_data
		var set_name = item_data.get("set_name", "")
		
		if set_name != "":
			if not set_items.has(set_name):
				set_items[set_name] = []
			set_items[set_name].append(item_data)
	
	# Check for complete sets
	for set_name in set_items.keys():
		var items = set_items[set_name]
		var required_pieces = get_set_required_pieces(set_name)
		
		if items.size() >= required_pieces:
			completed_sets.append(set_name)
	
	return completed_sets

func get_set_required_pieces(set_name: String) -> int:
# Get number of pieces required for set bonus
	# This would come from a sets data file eventually
	return 3  # Default to 3 pieces

func apply_set_bonuses(completed_sets: Array):
# Apply bonuses from completed equipment sets
	for set_name in completed_sets:
		# This would apply set-specific bonuses
		print("[EquipmentSystem] Set bonus active: %s" % set_name)

# Durability system (placeholder)
func damage_equipment(damage_amount: int, slot: int = -1):
# Damage equipment durability
	# If no slot specified, damage random piece
	if slot == -1:
		var equipped_slots = []
		for i in EquipmentSlot.values():
			if not is_slot_empty(i):
				equipped_slots.append(i)
		
		if equipped_slots.size() > 0:
			slot = equipped_slots[randi() % equipped_slots.size()]
		else:
			return  # No equipment to damage
	
	# TODO: Implement durability system
	print("[EquipmentSystem] Equipment in %s damaged for %d points" % [slot_names[slot], damage_amount])

func repair_equipment(slot: EquipmentSlot) -> int:
# Repair equipment and return cost
	# TODO: Implement repair system
	var repair_cost = 100  # Placeholder
	print("[EquipmentSystem] Equipment in %s repaired for %d gold" % [slot_names[slot], repair_cost])
	return repair_cost

# Save/Load functionality
func get_save_data() -> Dictionary:
# Get equipment save data
	var save_data = {
		"equipped_items": {},
		"attribute_modifiers": total_attribute_modifiers,
		"damage_bonus": total_damage_bonus,
		"defense_bonus": total_defense_bonus
	}
	
	# Save equipped items (just the IDs)
	for slot_name in equipped_items.keys():
		var equipped_item = equipped_items[slot_name]
		if equipped_item != null:
			save_data.equipped_items[slot_name] = equipped_item.item_id
		else:
			save_data.equipped_items[slot_name] = null
	
	return save_data

func load_save_data(data: Dictionary):
# Load equipment save data
	if data.has("equipped_items"):
		var equipped_items_data = data.equipped_items
		
		# Clear current equipment
		for slot_name in equipped_items.keys():
			equipped_items[slot_name] = null
		
		# Load equipped items
		for slot_name in equipped_items_data.keys():
			var item_id = equipped_items_data[slot_name]
			if item_id != null and item_id != "":
				var item_data = data_loader.get_item(item_id)
				if item_data:
					equipped_items[slot_name] = {
						"item_id": item_id,
						"item_data": item_data
					}
		
		# Recalculate bonuses
		recalculate_bonuses()

# Utility functions
func get_all_equipped_items() -> Dictionary:
# Get all equipped items
	var result = {}
	
	for slot_name in equipped_items.keys():
		var equipped_item = equipped_items[slot_name]
		if equipped_item != null:
			result[slot_name] = equipped_item.item_data
	
	return result

func get_equipment_power_level() -> int:
# Calculate overall equipment power level
	var power_level = 0
	
	for slot_name in equipped_items.keys():
		var equipped_item = equipped_items[slot_name]
		if equipped_item != null:
			var item_data = equipped_item.item_data
			power_level += item_data.get("item_level", 1)
	
	return power_level

# Debug methods
func debug_equip_item(item_id: String):
# Debug: Equip item
	equip_item(item_id)

func debug_unequip_all():
# Debug: Unequip all items
	for slot in EquipmentSlot.values():
		if not is_slot_empty(slot):
			unequip_item_from_slot(slot)

func debug_print_equipment():
# Debug: Print all equipped items
	print("[EquipmentSystem] === EQUIPPED ITEMS ===")
	for slot_name in equipped_items.keys():
		var equipped_item = equipped_items[slot_name]
		if equipped_item != null:
			var item_data = equipped_item.item_data
			print("  %s: %s" % [slot_name.capitalize(), item_data.name])
		else:
			print("  %s: Empty" % slot_name.capitalize())
	
	print("Total Damage Bonus: %d" % total_damage_bonus)
	print("Total Defense Bonus: %d" % total_defense_bonus)
	print("Attribute Modifiers: %s" % total_attribute_modifiers)
	print("============================")
