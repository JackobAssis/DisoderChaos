extends CharacterBody2D
class_name EnemyBase
# enemy_base.gd - Advanced enemy base class with JSON-driven stats and improved AI

# Enemy identification and data
@export var enemy_id: String = ""
var enemy_data: Dictionary = {}

# Core stats (loaded from JSON)
var max_health: int = 40
var current_health: int = 40
var attack_damage: int = 6
var defense: int = 0
var move_speed: float = 100.0
var detection_range: float = 150.0
var attack_range: float = 32.0
var exp_reward: int = 10

# Loot system
var loot_table: Array = []

# AI and behavior
enum AIType { PASSIVE, AGGRESSIVE, GUARDIAN, AMBUSH }
enum EnemyState { IDLE, PATROL, CHASE, ATTACK, STUNNED, CASTING, DEAD }

var ai_type: AIType = AIType.AGGRESSIVE
var current_state: EnemyState = EnemyState.IDLE
var target: Node = null
var last_attack_time: float = 0.0
var attack_cooldown: float = 2.0

# Advanced AI variables
var patrol_points: Array = []
var patrol_radius: float = 100.0
var home_position: Vector2
var last_player_position: Vector2
var chase_timer: float = 0.0
var max_chase_time: float = 10.0
var aggro_timeout: float = 5.0

# Status effects and resistances
var status_effects: Array = []
var resistances: Array = []
var weaknesses: Array = []
var element: String = "neutral"

# Special abilities
var special_abilities: Array = []
var ability_cooldowns: Dictionary = {}

# Components
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var detection_area: Area2D
var attack_area: Area2D
var health_bar: ProgressBar

# Animation system
var animation_player: AnimationPlayer
var current_animation: String = "idle"

# Signals
signal enemy_defeated(enemy_id: String, loot: Array, exp: int)
signal enemy_damaged(enemy_id: String, damage: int)
signal enemy_aggro(enemy_id: String, target: Node)

func _ready():
	setup_enemy_components()
	if not enemy_id.is_empty():
		load_enemy_data(enemy_id)
	setup_ai_behavior()

func setup_enemy_components():
	"""Initialize enemy visual and collision components"""
	# Create sprite with placeholder
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create collision
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set collision layers
	collision_layer = 2  # Enemy layer
	collision_mask = 0b1101  # Player, environment, items
	
	# Setup detection area
	setup_detection_area()
	setup_attack_area()
	setup_health_bar()

func setup_detection_area():
	"""Setup enemy detection range"""
	detection_area = Area2D.new()
	var detection_collision = CollisionShape2D.new()
	var detection_shape = CircleShape2D.new()
	detection_shape.radius = detection_range
	detection_collision.shape = detection_shape
	
	detection_area.add_child(detection_collision)
	add_child(detection_area)
	
	# Connect signals
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)

func setup_attack_area():
	"""Setup attack range area"""
	attack_area = Area2D.new()
	var attack_collision = CollisionShape2D.new()
	var attack_shape = CircleShape2D.new()
	attack_shape.radius = attack_range
	attack_collision.shape = attack_shape
	
	attack_area.add_child(attack_collision)
	add_child(attack_area)

func setup_health_bar():
	"""Setup floating health bar"""
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -25)
	health_bar.show_percentage = false
	health_bar.modulate = Color(1, 0, 0, 0.8)
	add_child(health_bar)

func load_enemy_data(id: String):
	"""Load enemy statistics and behavior from JSON data"""
	enemy_data = DataLoader.get_enemy_data(id)
	if not enemy_data:
		push_error("Enemy data not found: " + id)
		return
	
	# Load basic stats
	max_health = enemy_data.get("max_hp", 40)
	current_health = max_health
	attack_damage = enemy_data.get("attack", 6)
	defense = enemy_data.get("defense", 0)
	move_speed = enemy_data.get("speed", 100.0)
	detection_range = enemy_data.get("detection_range", 150.0)
	attack_range = enemy_data.get("attack_range", 32.0)
	exp_reward = enemy_data.get("exp_reward", 10)
	
	# Load AI type
	var ai_type_str = enemy_data.get("ai_type", "aggressive")
	match ai_type_str:
		"passive":
			ai_type = AIType.PASSIVE
		"aggressive":
			ai_type = AIType.AGGRESSIVE
		"guardian":
			ai_type = AIType.GUARDIAN
		"ambush":
			ai_type = AIType.AMBUSH
	
	# Load resistances and weaknesses
	resistances = enemy_data.get("resistances", [])
	weaknesses = enemy_data.get("weaknesses", [])
	element = enemy_data.get("element", "neutral")
	
	# Load special abilities
	special_abilities = enemy_data.get("special_abilities", [])
	
	# Load loot table
	loot_table = enemy_data.get("loot_table", [])
	
	# Update visual components
	update_detection_range()
	update_health_bar()
	
	print("[EnemyBase] Loaded enemy: ", enemy_data.name, " HP:", max_health, " ATK:", attack_damage)

func update_detection_range():
	"""Update detection area size based on loaded data"""
	if detection_area and detection_area.get_child(0):
		var detection_shape = detection_area.get_child(0).shape as CircleShape2D
		detection_shape.radius = detection_range

func update_health_bar():
	"""Update health bar display"""
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.visible = current_health < max_health

func setup_ai_behavior():
	"""Initialize AI behavior based on type"""
	home_position = global_position
	
	match ai_type:
		AIType.PASSIVE:
			# Passive enemies only defend when attacked
			change_state(EnemyState.IDLE)
		AIType.AGGRESSIVE:
			# Aggressive enemies patrol and chase players
			setup_patrol_points()
			change_state(EnemyState.PATROL)
		AIType.GUARDIAN:
			# Guardians stay near their home position
			change_state(EnemyState.IDLE)
		AIType.AMBUSH:
			# Ambush enemies hide and wait
			change_state(EnemyState.IDLE)

func setup_patrol_points():
	"""Setup patrol points around home position"""
	patrol_points.clear()
	for i in range(3):
		var angle = i * TAU / 3
		var patrol_point = home_position + Vector2(cos(angle), sin(angle)) * patrol_radius
		patrol_points.append(patrol_point)

func _physics_process(delta):
	if current_state == EnemyState.DEAD:
		return
	
	process_status_effects(delta)
	update_ai_behavior(delta)
	move_and_slide()

func update_ai_behavior(delta):
	"""Main AI behavior update"""
	match current_state:
		EnemyState.IDLE:
			handle_idle_state(delta)
		EnemyState.PATROL:
			handle_patrol_state(delta)
		EnemyState.CHASE:
			handle_chase_state(delta)
		EnemyState.ATTACK:
			handle_attack_state(delta)
		EnemyState.STUNNED:
			handle_stunned_state(delta)
		EnemyState.CASTING:
			handle_casting_state(delta)

func handle_idle_state(delta):
	"""Handle idle behavior based on AI type"""
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta)
	
	# Check for nearby threats based on AI type
	if ai_type != AIType.PASSIVE and target:
		if can_see_target():
			change_state(EnemyState.CHASE)

func handle_patrol_state(delta):
	"""Handle patrol behavior"""
	if target and ai_type == AIType.AGGRESSIVE:
		change_state(EnemyState.CHASE)
		return
	
	# Simple patrol implementation
	if patrol_points.is_empty():
		change_state(EnemyState.IDLE)
		return
	
	# Move toward closest patrol point
	var closest_patrol = get_closest_patrol_point()
	if closest_patrol != Vector2.ZERO:
		var direction = (closest_patrol - global_position).normalized()
		velocity = direction * move_speed * 0.5

func handle_chase_state(delta):
	"""Handle chasing target"""
	if not target or not is_instance_valid(target):
		change_state(EnemyState.IDLE)
		return
	
	chase_timer += delta
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Check if close enough to attack
	if distance_to_target <= attack_range:
		change_state(EnemyState.ATTACK)
		return
	
	# Check if chase timeout exceeded
	if chase_timer > max_chase_time or distance_to_target > detection_range * 1.5:
		target = null
		change_state(EnemyState.IDLE)
		return
	
	# Move toward target
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * move_speed

func handle_attack_state(delta):
	"""Handle attacking behavior"""
	if not target or not is_instance_valid(target):
		change_state(EnemyState.IDLE)
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# If target moved out of range, chase again
	if distance_to_target > attack_range:
		change_state(EnemyState.CHASE)
		return
	
	# Stop moving when attacking
	velocity = Vector2.ZERO
	
	# Attack if cooldown is ready
	if Time.get_time_dict_from_system()["unix"] - last_attack_time > attack_cooldown:
		perform_attack()

func handle_stunned_state(delta):
	"""Handle stunned state"""
	velocity = Vector2.ZERO
	# Stunned duration handled by status effects

func handle_casting_state(delta):
	"""Handle special ability casting"""
	velocity = Vector2.ZERO
	# Casting handled by special abilities

func change_state(new_state: EnemyState):
	"""Change enemy AI state"""
	if new_state == current_state:
		return
	
	# State exit actions
	match current_state:
		EnemyState.CHASE:
			chase_timer = 0.0
	
	current_state = new_state
	
	# State entry actions
	match new_state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
		EnemyState.ATTACK:
			velocity = Vector2.ZERO
		EnemyState.CHASE:
			if target:
				enemy_aggro.emit(enemy_id, target)

func perform_attack():
	"""Execute basic attack"""
	if not target:
		return
	
	last_attack_time = Time.get_time_dict_from_system()["unix"]
	
	# Calculate damage with defense
	var final_damage = max(1, attack_damage - get_target_defense())
	
	# Apply damage to target
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
		
		# Visual feedback
		EventBus.damage_number_requested.emit(target.global_position, final_damage, "normal")
		EventBus.sound_play_requested.emit("enemy_attack", global_position)

func get_target_defense() -> int:
	"""Get target's defense value"""
	if target.has_method("get_stats"):
		var stats = target.get_stats()
		return stats.get("armor", 0)
	return 0

func take_damage(amount: int, damage_type: String = "physical"):
	"""Take damage with resistances and weaknesses"""
	var final_damage = calculate_damage_with_resistances(amount, damage_type)
	
	current_health = max(0, current_health - final_damage)
	update_health_bar()
	
	# Flash red or show damage effect
	flash_damage_effect()
	
	# Emit damage event
	enemy_damaged.emit(enemy_id, final_damage)
	
	# Get angry if not already targeting
	if current_state == EnemyState.IDLE and ai_type != AIType.PASSIVE:
		find_attacker_as_target()
	
	if current_health <= 0:
		die()

func calculate_damage_with_resistances(damage: int, damage_type: String) -> int:
	"""Calculate final damage considering resistances and weaknesses"""
	var final_damage = damage
	
	# Apply resistances
	if damage_type in resistances:
		final_damage = int(final_damage * 0.5)  # 50% resistance
	
	# Apply weaknesses
	if damage_type in weaknesses:
		final_damage = int(final_damage * 1.5)  # 50% extra damage
	
	# Apply defense
	final_damage = max(1, final_damage - defense)
	
	return final_damage

func heal(amount: int) -> int:
	"""Heal the enemy"""
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	update_health_bar()
	return current_health - old_health

func die():
	"""Handle enemy death"""
	current_state = EnemyState.DEAD
	
	# Generate loot and XP
	var dropped_loot = generate_loot()
	
	# Emit death event
	enemy_defeated.emit(enemy_id, dropped_loot, exp_reward)
	EventBus.enemy_defeated.emit(name, dropped_loot)
	
	# Award XP to nearby players
	award_experience_to_players()
	
	# Play death effects
	EventBus.sound_play_requested.emit("enemy_death", global_position)
	
	# Remove after delay
	await get_tree().create_timer(2.0).timeout
	queue_free()

func generate_loot() -> Array:
	"""Generate loot based on loot table"""
	var dropped_loot = []
	
	for loot_entry in loot_table:
		var item_id = loot_entry.get("item", "")
		var chance = loot_entry.get("chance", 0.0)
		
		if randf() < chance:
			dropped_loot.append(item_id)
			
			# TODO: Create actual loot objects in world
			# For now, add directly to player inventory
			if is_instance_valid(target) and target.has_method("add_item_to_inventory"):
				target.add_item_to_inventory(item_id, 1)
	
	return dropped_loot

func award_experience_to_players():
	"""Award experience to nearby players"""
	# Find all players in range
	var players_in_range = []
	var bodies = detection_area.get_overlapping_bodies()
	
	for body in bodies:
		if body.has_method("add_xp"):
			players_in_range.append(body)
	
	# Award XP
	for player in players_in_range:
		player.add_xp(exp_reward)

func flash_damage_effect():
	"""Visual damage feedback"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func can_see_target() -> bool:
	"""Check if enemy can see the target"""
	if not target:
		return false
	
	var distance = global_position.distance_to(target.global_position)
	return distance <= detection_range

func find_attacker_as_target():
	"""Find nearby player as target when attacked"""
	var bodies = detection_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("get_stats"):
			target = body
			break

func get_closest_patrol_point() -> Vector2:
	"""Get closest patrol point to current position"""
	if patrol_points.is_empty():
		return Vector2.ZERO
	
	var closest_point = patrol_points[0]
	var closest_distance = global_position.distance_to(closest_point)
	
	for point in patrol_points:
		var distance = global_position.distance_to(point)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point
	
	return closest_point

# Status effect system
func process_status_effects(delta):
	"""Process active status effects"""
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		effect.remaining_time -= delta
		
		# Apply effect tick
		process_status_effect(effect)
		
		# Remove expired effects
		if effect.remaining_time <= 0:
			remove_status_effect_at_index(i)

func process_status_effect(effect: Dictionary):
	"""Process a single status effect"""
	match effect.id:
		"poison":
			if effect.get("last_tick", 0) + 1.0 < Time.get_time_dict_from_system()["unix"]:
				take_damage(effect.get("damage", 2), "poison")
				effect["last_tick"] = Time.get_time_dict_from_system()["unix"]
		"slow":
			move_speed = move_speed * 0.5
		"stun":
			change_state(EnemyState.STUNNED)

func add_status_effect(effect_id: String, duration: float, data: Dictionary = {}):
	"""Add a status effect"""
	var effect = {
		"id": effect_id,
		"remaining_time": duration,
		"data": data
	}
	status_effects.append(effect)

func remove_status_effect_at_index(index: int):
	"""Remove status effect at specific index"""
	var effect = status_effects[index]
	
	# Cleanup effect
	match effect.id:
		"slow":
			# Restore speed (this is simplified)
			move_speed = enemy_data.get("speed", 100.0)
	
	status_effects.remove_at(index)

# Signal handlers
func _on_detection_entered(body):
	"""Handle body entering detection range"""
	if body.has_method("get_stats") and ai_type != AIType.PASSIVE:
		target = body
		if current_state == EnemyState.IDLE or current_state == EnemyState.PATROL:
			change_state(EnemyState.CHASE)

func _on_detection_exited(body):
	"""Handle body leaving detection range"""
	if body == target:
		last_player_position = body.global_position
		# Don't immediately lose target, let chase timer handle it

# Utility methods
func get_display_name() -> String:
	"""Get display name for UI"""
	return enemy_data.get("name", name)

func is_alive() -> bool:
	"""Check if enemy is alive"""
	return current_state != EnemyState.DEAD

func get_health_percentage() -> float:
	"""Get health as percentage"""
	return float(current_health) / float(max_health)

func scale_stats(multiplier: float):
	"""Scale enemy stats for difficulty"""
	max_health = int(max_health * multiplier)
	current_health = max_health
	attack_damage = int(attack_damage * multiplier)
	exp_reward = int(exp_reward * multiplier)

# TODO: Future enhancements
# - Advanced pathfinding with Navigation2D
# - Group coordination and pack behavior
# - Dynamic difficulty scaling based on player level
# - Environmental awareness and interaction
# - Special ability system implementation
# - Elite and boss enemy variants
# - Faction-based enemy relationships
# - Procedural enemy generation