extends CharacterBody2D
class_name PlayerController
# player_controller.gd - Main player controller with movement, combat, and stats

# Player configuration
@export var move_speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Player state
var player_data: Dictionary
var current_health: int
var current_mana: int
var max_health: int
var max_mana: int

# XP and Level system
var current_xp: int
var level: int
var xp_to_next_level: int

# Derived attributes (calculated from base attributes)
var attack_power: int
var magic_power: int
var defense: int
var dodge_chance: float
var critical_rate: float

# Equipment and inventory
var equipped_weapon: Dictionary
var equipped_armor: Dictionary
var quick_use_item: String = ""

# Animation system
var animation_tree: AnimationTree
var animation_state_machine: AnimationNodeStateMachinePlayback
var current_animation_state: String = "idle"

# Combat state
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var skill_cooldowns: Dictionary = {}

# Status effects
var status_effects: Array = []

# Components
var combat_system: CombatSystem
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var attack_area: Area2D
var ui_healthbar: ProgressBar
var ui_manabar: ProgressBar

# Movement input vector
var input_vector: Vector2

func _ready():
	print("[Player] Player controller initialized")
	setup_player()
	setup_combat_system()
	connect_signals()
	
	# Load player data from GameState
	load_player_data()

func setup_player():
	"""Initialize player components"""
	# Create sprite
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Setup animation system
	setup_animation_system()
	
	# Create collision shape
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 16
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Create attack area
	setup_attack_area()
	
	# Set collision layers
	collision_layer = 1  # Player layer
	collision_mask = 0b1110  # Collide with enemies, environment, items

func setup_attack_area():
	"""Setup attack detection area"""
	attack_area = Area2D.new()
	var attack_collision = CollisionShape2D.new()
	var attack_shape = CircleShape2D.new()
	attack_shape.radius = 32
	attack_collision.shape = attack_shape
	
	attack_area.add_child(attack_collision)
	add_child(attack_area)
	
	# Connect attack area signals
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)

func setup_combat_system():
	"""Initialize combat system"""
	combat_system = CombatSystem.new()
	add_child(combat_system)

func connect_signals():
	"""Connect to global event bus"""
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.player_mp_changed.connect(_on_mp_changed)
	EventBus.item_equipped.connect(_on_item_equipped)

func load_player_data():
	"""Load player data from GameState"""
	player_data = GameState.get_player_data()
	
	current_health = player_data.current_hp
	max_health = player_data.max_hp
	current_mana = player_data.current_mp
	max_mana = player_data.max_mp
	current_xp = player_data.experience
	level = player_data.level
	
	# Calculate derived attributes
	calculate_derived_attributes()
	
	# Calculate XP requirements
	xp_to_next_level = GameState.get_required_experience_for_level(level + 1)
	
	# Update UI
	update_health_display()
	update_mana_display()

func _physics_process(delta):
	handle_input()
	handle_movement(delta)
	handle_combat(delta)
	handle_status_effects(delta)
	update_skill_cooldowns(delta)

func handle_input():
	"""Process player input"""
	# Movement input
	input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	
	input_vector = input_vector.normalized()
	
	# Combat input
	if Input.is_action_just_pressed("attack"):
		attempt_attack()
	
	# Item usage
	if Input.is_action_just_pressed("use_item"):
		use_quick_item()
	
	if Input.is_action_just_pressed("use_item_1"):
		use_quick_item_slot(0)
	if Input.is_action_just_pressed("use_item_2"):
		use_quick_item_slot(1)
	if Input.is_action_just_pressed("use_item_3"):
		use_quick_item_slot(2)
	
	# Interaction
	if Input.is_action_just_pressed("interact"):
		attempt_interact()

func handle_movement(delta):
	"""Handle player movement with acceleration and friction"""
	if input_vector != Vector2.ZERO:
		# Accelerate towards input direction
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
		# Change to walk animation
		change_animation_state("walk")
	else:
		# Apply friction when not moving
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# Change to idle animation
		if current_animation_state == "walk":
			change_animation_state("idle")
	
	# Move the player
	move_and_slide()
	
	# Emit movement event if actually moved
	if velocity.length() > 1.0:
		EventBus.player_moved.emit(global_position)

func handle_combat(delta):
	"""Handle combat-related updates"""
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			is_attacking = false

func handle_status_effects(delta):
	"""Process active status effects"""
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		effect.remaining_time -= delta
		
		# Apply effect tick (for DOT/HOT effects)
		apply_status_effect_tick(effect)
		
		# Remove expired effects
		if effect.remaining_time <= 0:
			remove_status_effect_by_index(i)

func update_skill_cooldowns(delta):
	"""Update skill cooldown timers"""
	var keys_to_remove = []
	for skill_id in skill_cooldowns:
		skill_cooldowns[skill_id] -= delta
		if skill_cooldowns[skill_id] <= 0:
			keys_to_remove.append(skill_id)
	
	for key in keys_to_remove:
		skill_cooldowns.erase(key)

func attempt_attack():
	"""Attempt to perform basic attack"""
	if is_attacking or attack_cooldown > 0:
		return
	
	var skill_id = "slash"  # Default attack skill
	if not combat_system.can_use_skill(self, skill_id):
		return
	
	# Find targets in attack range
	var targets = get_enemies_in_attack_range()
	if targets.is_empty():
		return
	
	# Attack the closest enemy
	var closest_target = get_closest_target(targets)
	perform_attack(closest_target, skill_id)

func perform_attack(target: Node, skill_id: String):
	"""Perform attack on target"""
	is_attacking = true
	attack_cooldown = 1.0  # Base attack cooldown
	
	# Change to attack animation
	change_animation_state("attack")
	
	# Use combat system to handle the attack
	combat_system.use_skill(self, skill_id, target)
	
	# Play attack animation/sound
	EventBus.sound_play_requested.emit("attack", global_position)
	
	# Return to idle after attack
	await get_tree().create_timer(0.5).timeout
	if current_animation_state == "attack":
		change_animation_state("idle")

func get_enemies_in_attack_range() -> Array:
	"""Get all enemies within attack range"""
	var enemies = []
	var bodies = attack_area.get_overlapping_bodies()
	
	for body in bodies:
		if body.has_method("take_damage") and body != self:
			enemies.append(body)
	
	return enemies

func get_closest_target(targets: Array) -> Node:
	"""Get the closest target from array"""
	var closest_target = null
	var closest_distance = INF
	
	for target in targets:
		var distance = global_position.distance_to(target.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target
	
	return closest_target

func use_quick_item():
	"""Use the currently equipped quick use item"""
	if quick_use_item.is_empty():
		return
	
	if GameState.use_item(quick_use_item):
		EventBus.show_notification("Used " + quick_use_item)
	else:
		EventBus.show_notification("Cannot use " + quick_use_item)

func attempt_interact():
	"""Attempt to interact with nearby objects"""
	# TODO: Implement interaction system
	# Check for interactable objects in range
	EventBus.show_notification("No interactable objects nearby")

# Combat interface methods (required by CombatSystem)
func take_damage(amount: int):
	"""Take damage and update health"""
	current_health = max(0, current_health - amount)
	GameState.update_player_hp(-amount)
	
	# Play hurt animation
	change_animation_state("hurt")
	await get_tree().create_timer(0.3).timeout
	if current_animation_state == "hurt":
		change_animation_state("idle")
	
	if current_health <= 0:
		die()

func heal(amount: int) -> int:
	"""Heal player and return actual amount healed"""
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	var actual_heal = current_health - old_health
	
	GameState.update_player_hp(actual_heal)
	return actual_heal

func get_stats() -> Dictionary:
	"""Get player combat stats"""
	return {
		"strength": player_data.attributes.strength,
		"agility": player_data.attributes.agility,
		"vitality": player_data.attributes.vitality,
		"intelligence": player_data.attributes.intelligence,
		"willpower": player_data.attributes.willpower,
		"luck": player_data.attributes.luck,
		"attack_power": attack_power,
		"magic_power": magic_power,
		"armor": defense,
		"magic_resistance": get_total_magic_resistance(),
		"dodge_chance": dodge_chance,
		"critical_rate": critical_rate
	}

func get_total_armor() -> int:
	"""Calculate total armor from equipment"""
	var total_armor = 0
	
	# Add base armor from equipment
	if equipped_weapon.has("defense"):
		total_armor += equipped_weapon.defense
	
	# TODO: Add armor from other equipment slots
	
	return total_armor

func get_total_magic_resistance() -> int:
	"""Calculate total magic resistance"""
	var base_resistance = player_data.attributes.willpower / 2
	# TODO: Add resistance from equipment and buffs
	return base_resistance

func get_current_mp() -> int:
	"""Get current mana points"""
	return current_mana

func consume_mp(amount: int):
	"""Consume mana points"""
	current_mana = max(0, current_mana - amount)
	GameState.update_player_mp(-amount)

func is_skill_on_cooldown(skill_id: String) -> bool:
	"""Check if skill is on cooldown"""
	return skill_id in skill_cooldowns

func start_skill_cooldown(skill_id: String, cooldown_time: float):
	"""Start cooldown for a skill"""
	skill_cooldowns[skill_id] = cooldown_time

# Status effect methods
func add_status_effect(effect_data: Dictionary):
	"""Add a status effect"""
	# Check if effect already exists
	for existing_effect in status_effects:
		if existing_effect.id == effect_data.id:
			# Refresh duration or stack
			existing_effect.remaining_time = effect_data.duration
			existing_effect.stacks += 1
			return
	
	# Add new effect
	status_effects.append(effect_data)
	apply_status_effect_start(effect_data)

func remove_status_effect(effect_id: String):
	"""Remove a status effect by ID"""
	for i in range(status_effects.size()):
		if status_effects[i].id == effect_id:
			remove_status_effect_by_index(i)
			break

func remove_status_effect_by_index(index: int):
	"""Remove status effect by array index"""
	var effect = status_effects[index]
	apply_status_effect_end(effect)
	status_effects.remove_at(index)

func apply_status_effect_start(effect: Dictionary):
	"""Apply initial status effect"""
	# TODO: Implement specific status effect logic
	pass

func apply_status_effect_tick(effect: Dictionary):
	"""Apply per-frame status effect"""
	# TODO: Implement DOT/HOT and other recurring effects
	pass

func apply_status_effect_end(effect: Dictionary):
	"""Apply status effect removal"""
	# TODO: Implement cleanup for status effects
	pass

# Player death and respawn
func die():
	"""Handle player death"""
	change_animation_state("death")
	EventBus.player_died.emit()
	# TODO: Implement death mechanics
	print("[Player] Player died!")

func respawn():
	"""Respawn the player"""
	current_health = max_health
	current_mana = max_mana
	GameState.update_player_hp(max_health - current_health)
	GameState.update_player_mp(max_mana - current_mana)
	
	EventBus.player_respawned.emit()

# Equipment methods
func equip_item(item_id: String, slot: String):
	"""Equip an item to specified slot"""
	var item_data = DataLoader.get_item(item_id)
	if not item_data:
		return false
	
	match slot:
		"weapon":
			equipped_weapon = item_data
		_:
			push_warning("Unknown equipment slot: " + slot)
			return false
	
	EventBus.item_equipped.emit(item_id, slot)
	return true

# UI update methods
func update_health_display():
	"""Update health bar display"""
	# TODO: Connect to actual UI elements
	pass

func update_mana_display():
	"""Update mana bar display"""
	# TODO: Connect to actual UI elements
	pass

# Signal handlers
func _on_hp_changed(current_hp: int, max_hp: int):
	current_health = current_hp
	max_health = max_hp
	update_health_display()

func _on_mp_changed(current_mp: int, max_mp: int):
	current_mana = current_mp
	max_mana = max_mp
	update_mana_display()

func _on_item_equipped(item_id: String, slot: String):
	print("[Player] Equipped ", item_id, " to ", slot)

func _on_attack_area_entered(body):
	"""Handle entity entering attack range"""
	pass

func _on_attack_area_exited(body):
	"""Handle entity leaving attack range"""
	pass

# XP and Level System
func add_xp(amount: int):
	"""Add experience points and handle level up"""
	current_xp += amount
	EventBus.ui_notification_shown.emit("+" + str(amount) + " XP", "success")
	
	# Check for level up
	while current_xp >= xp_to_next_level:
		level_up()

func level_up():
	"""Handle player leveling up"""
	current_xp -= xp_to_next_level
	level += 1
	
	# Update GameState
	GameState.player_data.level = level
	GameState.player_data.experience = current_xp
	
	# Calculate new stats
	var hp_gain = 10 + player_data.attributes.vitality * 2
	var mp_gain = 5 + player_data.attributes.intelligence * 2
	
	# Increase max HP/MP
	max_health += hp_gain
	max_mana += mp_gain
	current_health = max_health  # Full heal on level up
	current_mana = max_mana
	
	# Update GameState values
	GameState.player_data.max_hp = max_health
	GameState.player_data.max_mp = max_mana
	GameState.player_data.current_hp = current_health
	GameState.player_data.current_mp = current_mana
	
	# Recalculate derived attributes
	calculate_derived_attributes()
	
	# Calculate new XP requirement
	xp_to_next_level = GameState.get_required_experience_for_level(level + 1)
	
	# Emit level up event
	EventBus.player_level_up.emit(level, hp_gain, mp_gain)
	EventBus.ui_notification_shown.emit("LEVEL UP! Level " + str(level), "success")

func calculate_derived_attributes():
	"""Calculate derived stats from base attributes"""
	var attrs = player_data.attributes
	
	# Attack power based on strength and equipped weapon
	attack_power = attrs.strength + 5  # Base attack
	if equipped_weapon.has("damage"):
		attack_power += equipped_weapon.damage
	
	# Magic power based on intelligence
	magic_power = attrs.intelligence + 3
	
	# Defense based on vitality and equipped armor
	defense = attrs.vitality / 2
	if equipped_armor.has("defense"):
		defense += equipped_armor.defense
	
	# Dodge chance based on agility (max 25%)
	dodge_chance = min(0.25, attrs.agility * 0.01)
	
	# Critical rate based on luck (max 30%)
	critical_rate = min(0.30, 0.05 + attrs.luck * 0.01)

func setup_animation_system():
	"""Setup animation tree and state machine"""
	# Create AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	
	# Create AnimationTree
	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"
	add_child(animation_tree)
	
	# TODO: Create animation state machine with states:
	# - idle: default standing animation
	# - walk: movement animation
	# - attack: combat animation
	# - hurt: damage taken animation
	# - death: death animation
	# For now, use placeholder system
	current_animation_state = "idle"

func change_animation_state(new_state: String):
	"""Change current animation state"""
	if new_state == current_animation_state:
		return
	
	current_animation_state = new_state
	# TODO: Implement actual animation state changes when animations are added
	print("[Player] Animation state changed to: ", new_state)

# Inventory Management (connects to GameState)
func add_item_to_inventory(item_id: String, quantity: int = 1):
	"""Add item to player inventory via GameState"""
	GameState.add_item_to_inventory(item_id, quantity)
	EventBus.ui_notification_shown.emit("Received: " + item_id, "info")

func remove_item_from_inventory(item_id: String, quantity: int = 1) -> bool:
	"""Remove item from inventory via GameState"""
	return GameState.remove_item_from_inventory(item_id, quantity)

func has_item_in_inventory(item_id: String, quantity: int = 1) -> bool:
	"""Check if player has item in inventory"""
	var inventory = GameState.player_data.inventory
	for item in inventory:
		if item.id == item_id and item.quantity >= quantity:
			return true
	return false

func equip_weapon(item_id: String):
	"""Equip weapon and update attack power"""
	var item_data = DataLoader.get_item(item_id)
	if item_data and item_data.type == "weapon":
		equipped_weapon = item_data
		calculate_derived_attributes()  # Recalculate attack power
		EventBus.item_equipped.emit(item_id, "weapon")
		EventBus.ui_notification_shown.emit("Equipped: " + item_data.name, "info")

func equip_armor(item_id: String):
	"""Equip armor and update defense"""
	var item_data = DataLoader.get_item(item_id)
	if item_data and item_data.type == "armor":
		equipped_armor = item_data
		calculate_derived_attributes()  # Recalculate defense
		EventBus.item_equipped.emit(item_id, "armor")
		EventBus.ui_notification_shown.emit("Equipped: " + item_data.name, "info")

# TODO: Future enhancements
# - Weapon-specific attack animations and effects
# - Skill tree progression system
# - Advanced equipment system with set bonuses

# Item usage system
func use_quick_item():
	"""Use the currently selected quick item"""
	if GameState.player_data.has("quick_item"):
		var item_id = GameState.player_data.quick_item
		if item_id and item_id != "":
			use_item_by_id(item_id)

func use_quick_item_slot(slot: int):
	"""Use item from specific quick slot"""
	if GameState.player_data.has("quick_items"):
		var quick_items = GameState.player_data.quick_items
		if slot < quick_items.size() and quick_items[slot]:
			use_item_by_id(quick_items[slot])

func use_item_by_id(item_id: String, quantity: int = 1) -> bool:
	"""Use item through the item system"""
	var item_system = get_node("/root/ItemSystem")
	if item_system:
		return item_system.use_item(self, item_id, quantity)
	else:
		print("[Player] ItemSystem not found")
		return false

func use_item_from_inventory(inventory_slot: int) -> bool:
	"""Use item from specific inventory slot"""
	var inventory = GameState.player_data.inventory
	if inventory_slot < inventory.size():
		var item = inventory[inventory_slot]
		return use_item_by_id(item.id, 1)
	return false

func get_item_cooldown(item_id: String) -> float:
	"""Get remaining cooldown for an item"""
	var item_system = get_node("/root/ItemSystem")
	if item_system:
		return item_system.get_cooldown_remaining(item_id)
	return 0.0

func is_item_on_cooldown(item_id: String) -> bool:
	"""Check if item is on cooldown"""
	var item_system = get_node("/root/ItemSystem")
	if item_system:
		return item_system.is_item_on_cooldown(item_id)
	return false
# - Player customization and cosmetics
# - Gesture-based skill casting
# - Mounted movement system
# - Environmental interaction system
# - Player housing/base building
# - Equipment durability system
# - Enchantment and upgrade system