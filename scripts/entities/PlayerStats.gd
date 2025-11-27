extends Node

class_name PlayerStats

signal health_changed(current: int, max_health: int)
signal stamina_changed(current: float, max_stamina: float)
signal mana_changed(current: float, max_mana: float)
signal level_changed(new_level: int)
signal experience_changed(current_xp: int, needed_xp: int)
signal attribute_changed(attribute_name: String, new_value: int)

# Core attributes from character creation
var base_attributes: Dictionary = {}
var race_modifiers: Dictionary = {}
var class_modifiers: Dictionary = {}
var level_modifiers: Dictionary = {}
var equipment_modifiers: Dictionary = {}

# Calculated final attributes
var final_attributes: Dictionary = {}

# Vital statistics
var current_health: int = 100
var max_health: int = 100
var current_stamina: float = 100.0
var max_stamina: float = 100.0
var current_mana: float = 100.0
var max_mana: float = 100.0

# Experience and leveling
var current_level: int = 1
var current_experience: int = 0
var experience_to_next_level: int = 1000

# Character creation data
var selected_race_id: String = ""
var selected_class_id: String = ""

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var data_loader: DataLoader = get_node("/root/DataLoader")
@onready var event_bus: EventBus = get_node("/root/EventBus")

func _ready():
	print("[PlayerStats] PlayerStats component initialized")

func initialize_from_character_creation():
# Initialize stats from character creation choices
	# Get character creation data from game state
	var character_data = game_state.get_character_creation_data()
	
	if character_data.is_empty():
		# Use default values for testing
		selected_race_id = "human"
		selected_class_id = "warrior"
		print("[PlayerStats] âš ï¸ No character creation data - using defaults")
	else:
		selected_race_id = character_data.get("race_id", "human")
		selected_class_id = character_data.get("class_id", "warrior")
		current_level = character_data.get("level", 1)
		current_experience = character_data.get("experience", 0)
	
	# Load base attributes
	load_base_attributes()
	
	# Apply race modifiers
	apply_race_modifiers()
	
	# Apply class modifiers
	apply_class_modifiers()
	
	# Calculate final attributes
	calculate_final_attributes()
	
	# Calculate vital statistics
	calculate_vital_statistics()
	
	print("[PlayerStats] âœ… Stats initialized for %s %s (Level %d)" % [selected_race_id, selected_class_id, current_level])

func load_base_attributes():
# Load base attribute values
	var attributes_list = data_loader.get_attributes()
	
	# Initialize all attributes to base value
	for attribute in attributes_list:
		base_attributes[attribute.id] = attribute.get("base_value", 10)
	
	print("[PlayerStats] Loaded %d base attributes" % base_attributes.size())

func apply_race_modifiers():
# Apply racial attribute modifiers
	var race_data = data_loader.get_race(selected_race_id)
	
	if not race_data:
		print("[PlayerStats] âš ï¸ Race data not found: %s" % selected_race_id)
		return
	
	race_modifiers.clear()
	var modifiers = race_data.get("attribute_modifiers", {})
	
	for attribute in modifiers.keys():
		race_modifiers[attribute] = modifiers[attribute]
	
	print("[PlayerStats] Applied %s racial modifiers" % selected_race_id)

func apply_class_modifiers():
# Apply class attribute modifiers
	var class_data = data_loader.get_class(selected_class_id)
	
	if not class_data:
		print("[PlayerStats] âš ï¸ Class data not found: %s" % selected_class_id)
		return
	
	class_modifiers.clear()
	var modifiers = class_data.get("attribute_modifiers", {})
	
	for attribute in modifiers.keys():
		class_modifiers[attribute] = modifiers[attribute]
	
	print("[PlayerStats] Applied %s class modifiers" % selected_class_id)

func calculate_final_attributes():
# Calculate final attribute values from all sources
	final_attributes.clear()
	
	for attribute in base_attributes.keys():
		var final_value = base_attributes.get(attribute, 10)
		
		# Add race modifier
		final_value += race_modifiers.get(attribute, 0)
		
		# Add class modifier
		final_value += class_modifiers.get(attribute, 0)
		
		# Add level modifier (points from leveling up)
		final_value += level_modifiers.get(attribute, 0)
		
		# Add equipment modifier
		final_value += equipment_modifiers.get(attribute, 0)
		
		# Ensure minimum value
		final_value = max(final_value, 1)
		
		final_attributes[attribute] = final_value
	
	print("[PlayerStats] Final attributes calculated")

func calculate_vital_statistics():
# Calculate health, stamina, mana from attributes
	# Health = Constitution * 10 + level * 5
	var constitution = final_attributes.get("constitution", 10)
	max_health = constitution * 10 + current_level * 5
	
	# Stamina = Dexterity * 8 + level * 3
	var dexterity = final_attributes.get("dexterity", 10)
	max_stamina = dexterity * 8.0 + current_level * 3.0
	
	# Mana = Intelligence * 12 + level * 4
	var intelligence = final_attributes.get("intelligence", 10)
	max_mana = intelligence * 12.0 + current_level * 4.0
	
	# Set current values to max (full health/stamina/mana)
	current_health = max_health
	current_stamina = max_stamina
	current_mana = max_mana
	
	# Emit change signals
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	mana_changed.emit(current_mana, max_mana)
	
	print("[PlayerStats] Vitals: HP=%d, SP=%.0f, MP=%.0f" % [max_health, max_stamina, max_mana])

# Attribute management
func get_attribute_value(attribute_name: String) -> int:
# Get final value of an attribute
	return final_attributes.get(attribute_name, 10)

func get_base_attribute(attribute_name: String) -> int:
# Get base attribute value (before modifiers)
	return base_attributes.get(attribute_name, 10)

func add_attribute_points(attribute_name: String, points: int):
# Add points to an attribute (from leveling up)
	if not base_attributes.has(attribute_name):
		print("[PlayerStats] âš ï¸ Unknown attribute: %s" % attribute_name)
		return
	
	level_modifiers[attribute_name] = level_modifiers.get(attribute_name, 0) + points
	
	# Recalculate everything
	calculate_final_attributes()
	calculate_vital_statistics()
	
	attribute_changed.emit(attribute_name, get_attribute_value(attribute_name))
	print("[PlayerStats] Added %d points to %s" % [points, attribute_name])

func update_equipment_modifiers(new_modifiers: Dictionary):
# Update attribute modifiers from equipment
	equipment_modifiers = new_modifiers.duplicate()
	
	# Recalculate everything
	calculate_final_attributes()
	calculate_vital_statistics()
	
	print("[PlayerStats] Equipment modifiers updated")

# Health management
func take_damage(amount: int, damage_type: String = "physical") -> bool:
# Take damage and return true if still alive
	# Apply damage reduction based on attributes/equipment
	var actual_damage = calculate_actual_damage(amount, damage_type)
	
	current_health = max(current_health - actual_damage, 0)
	health_changed.emit(current_health, max_health)
	
	# Notify event system
	event_bus.emit_signal("player_damaged", actual_damage, damage_type)
	
	if current_health <= 0:
		event_bus.emit_signal("player_died")
		return false
	
	return true

func heal(amount: int) -> int:
# Heal and return actual amount healed
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	var actual_heal = current_health - old_health
	
	if actual_heal > 0:
		health_changed.emit(current_health, max_health)
		event_bus.emit_signal("player_healed", actual_heal)
	
	return actual_heal

func calculate_actual_damage(base_damage: int, damage_type: String) -> int:
# Calculate actual damage after resistances
	var actual_damage = base_damage
	
	# Basic damage reduction from Constitution
	var constitution = get_attribute_value("constitution")
	var damage_reduction = (constitution - 10) * 0.5  # 0.5 damage reduction per point above 10
	actual_damage = max(actual_damage - damage_reduction, 1)  # Minimum 1 damage
	
	# TODO: Add damage type resistances from equipment/race
	
	return int(actual_damage)

# Stamina management
func consume_stamina(amount: float) -> bool:
# Consume stamina and return true if successful
	if current_stamina < amount:
		return false
	
	current_stamina = max(current_stamina - amount, 0.0)
	stamina_changed.emit(current_stamina, max_stamina)
	
	return true

func regenerate_stamina(amount: float):
# Regenerate stamina
	current_stamina = min(current_stamina + amount, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

# Mana management
func consume_mana(amount: float) -> bool:
# Consume mana and return true if successful
	if current_mana < amount:
		return false
	
	current_mana = max(current_mana - amount, 0.0)
	mana_changed.emit(current_mana, max_mana)
	
	return true

func regenerate_mana(amount: float):
# Regenerate mana
	current_mana = min(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)

# Experience and leveling
func add_experience(amount: int):
# Add experience points
	current_experience += amount
	experience_changed.emit(current_experience, experience_to_next_level)
	
	# Check for level up
	while current_experience >= experience_to_next_level:
		level_up()

func level_up():
# Level up the player
	current_experience -= experience_to_next_level
	current_level += 1
	
	# Calculate new experience requirement (increases by 10% each level)
	experience_to_next_level = int(experience_to_next_level * 1.1)
	
	# Recalculate vital statistics for new level
	calculate_vital_statistics()
	
	# Heal to full on level up
	current_health = max_health
	current_stamina = max_stamina
	current_mana = max_mana
	
	# Emit signals
	level_changed.emit(current_level)
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	mana_changed.emit(current_mana, max_mana)
	experience_changed.emit(current_experience, experience_to_next_level)
	
	# Notify event system
	event_bus.emit_signal("player_leveled_up", current_level)
	
	print("[PlayerStats] âœ¨ LEVEL UP! Now level %d" % current_level)

# Getters
func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_current_stamina() -> float:
	return current_stamina

func get_max_stamina() -> float:
	return max_stamina

func get_current_mana() -> float:
	return current_mana

func get_max_mana() -> float:
	return max_mana

func get_level() -> int:
	return current_level

func get_experience() -> int:
	return current_experience

func get_experience_to_next_level() -> int:
	return experience_to_next_level

func get_race_id() -> String:
	return selected_race_id

func get_class_id() -> String:
	return selected_class_id

func get_all_attributes() -> Dictionary:
	return final_attributes.duplicate()

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"race_id": selected_race_id,
		"class_id": selected_class_id,
		"level": current_level,
		"experience": current_experience,
		"experience_to_next_level": experience_to_next_level,
		"current_health": current_health,
		"current_stamina": current_stamina,
		"current_mana": current_mana,
		"base_attributes": base_attributes,
		"level_modifiers": level_modifiers,
		"final_attributes": final_attributes
	}

func load_save_data(data: Dictionary):
	if data.has("race_id"):
		selected_race_id = data.race_id
	
	if data.has("class_id"):
		selected_class_id = data.class_id
	
	if data.has("level"):
		current_level = data.level
	
	if data.has("experience"):
		current_experience = data.experience
	
	if data.has("experience_to_next_level"):
		experience_to_next_level = data.experience_to_next_level
	
	if data.has("current_health"):
		current_health = data.current_health
	
	if data.has("current_stamina"):
		current_stamina = data.current_stamina
	
	if data.has("current_mana"):
		current_mana = data.current_mana
	
	if data.has("base_attributes"):
		base_attributes = data.base_attributes
	
	if data.has("level_modifiers"):
		level_modifiers = data.level_modifiers
	
	if data.has("final_attributes"):
		final_attributes = data.final_attributes
	
	# Recalculate vitals and emit signals
	calculate_vital_statistics()

# Debug methods
func debug_add_experience(amount: int):
# Debug: Add experience
	add_experience(amount)

func debug_level_up():
# Debug: Force level up
	level_up()

func debug_max_attribute(attribute_name: String):
# Debug: Max out an attribute
	level_modifiers[attribute_name] = 20
	calculate_final_attributes()
	calculate_vital_statistics()

func debug_print_stats():
# Debug: Print all stats
	print("[PlayerStats] === PLAYER STATS ===")
	print("Race: %s, Class: %s, Level: %d" % [selected_race_id, selected_class_id, current_level])
	print("Health: %d/%d" % [current_health, max_health])
	print("Stamina: %.1f/%.1f" % [current_stamina, max_stamina])
	print("Mana: %.1f/%.1f" % [current_mana, max_mana])
	print("Experience: %d/%d" % [current_experience, experience_to_next_level])
	print("Attributes:")
	for attr in final_attributes.keys():
		print("  %s: %d" % [attr.capitalize(), final_attributes[attr]])
	print("=========================")
