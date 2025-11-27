extends CharacterBody2D
class_name BasicEnemy
# basic_enemy.gd - Basic enemy AI and behavior

# Enemy stats
@export var max_health: int = 40
@export var current_health: int = 40
@export var damage: int = 6
@export var move_speed: float = 100.0
@export var attack_range: float = 32.0
@export var detection_range: float = 150.0
@export var attack_cooldown: float = 2.0

# Enemy state
enum EnemyState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	STUNNED,
	DEAD
}

var current_state: EnemyState = EnemyState.IDLE
var target: Node = null
var last_attack_time: float = 0.0

# Movement
var patrol_points: Array = []
var current_patrol_index: int = 0
var patrol_wait_time: float = 2.0
var patrol_timer: float = 0.0

# Components
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var detection_area: Area2D
var attack_area: Area2D

# AI variables
var state_timer: float = 0.0
var random_move_target: Vector2
var last_player_position: Vector2

func _ready():
	setup_enemy()
	setup_detection()
	setup_attack_area()
	current_health = max_health

func setup_enemy():
# Initialize enemy components
	# Create sprite (placeholder)
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create collision
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set collision layers
	collision_layer = 2  # Enemy layer
	collision_mask = 0b1101  # Collide with player, environment, items

func setup_detection():
# Setup player detection area
	detection_area = Area2D.new()
	var detection_collision = CollisionShape2D.new()
	var detection_shape = CircleShape2D.new()
	detection_shape.radius = detection_range
	detection_collision.shape = detection_shape
	
	detection_area.add_child(detection_collision)
	add_child(detection_area)
	
	# Connect detection signals
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)

func setup_attack_area():
# Setup attack area
	attack_area = Area2D.new()
	var attack_collision = CollisionShape2D.new()
	var attack_shape = CircleShape2D.new()
	attack_shape.radius = attack_range
	attack_collision.shape = attack_shape
	
	attack_area.add_child(attack_collision)
	add_child(attack_area)

func _physics_process(delta):
	if current_state == EnemyState.DEAD:
		return
	
	state_timer += delta
	
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
	
	# Move the enemy
	move_and_slide()

func handle_idle_state(delta):
# Handle idle behavior
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta)
	
	# Check for player nearby
	if target:
		change_state(EnemyState.CHASE)
	elif state_timer > 3.0:  # Idle for 3 seconds, then patrol
		change_state(EnemyState.PATROL)

func handle_patrol_state(delta):
# Handle patrol behavior
	if target:
		change_state(EnemyState.CHASE)
		return
	
	# Simple random movement patrol
	if random_move_target == Vector2.ZERO or global_position.distance_to(random_move_target) < 20:
		# Get new random patrol target
		random_move_target = global_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)
	
	# Move towards patrol target
	var direction = (random_move_target - global_position).normalized()
	velocity = direction * move_speed * 0.5  # Slower patrol speed

func handle_chase_state(delta):
# Handle chasing player
	if not target or not is_instance_valid(target):
		change_state(EnemyState.IDLE)
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Check if close enough to attack
	if distance_to_target <= attack_range:
		change_state(EnemyState.ATTACK)
		return
	
	# Check if target is too far away
	if distance_to_target > detection_range * 1.5:
		target = null
		change_state(EnemyState.IDLE)
		return
	
	# Move towards target
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * move_speed

func handle_attack_state(delta):
# Handle attacking player
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
# Handle stunned state
	velocity = Vector2.ZERO
	
	if state_timer > 1.5:  # Stunned for 1.5 seconds
		change_state(EnemyState.IDLE)

func change_state(new_state: EnemyState):
# Change enemy state
	current_state = new_state
	state_timer = 0.0
	
	# State entry actions
	match new_state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
		EnemyState.PATROL:
			random_move_target = Vector2.ZERO
		EnemyState.ATTACK:
			velocity = Vector2.ZERO

func perform_attack():
# Perform attack on target
	if not target:
		return
	
	last_attack_time = Time.get_time_dict_from_system()["unix"]
	
	# Check if target is still in range
	var distance = global_position.distance_to(target.global_position)
	if distance <= attack_range:
		# Deal damage to target
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
			# Create visual effect
			EventBus.damage_number_requested.emit(target.global_position, damage, "normal")
			EventBus.sound_play_requested.emit("enemy_attack", global_position)
	
	# Brief pause after attack
	change_state(EnemyState.STUNNED)

func take_damage(amount: int):
# Take damage from attack
	current_health -= amount
	
	# Show damage number
	EventBus.damage_number_requested.emit(global_position, amount, "normal")
	
	# Flash red or show damage effect
	flash_damage_effect()
	
	if current_health <= 0:
		die()
	else:
		# Get angry and target attacker if not already targeting
		if current_state == EnemyState.IDLE or current_state == EnemyState.PATROL:
			find_player_target()
			if target:
				change_state(EnemyState.CHASE)

func heal(amount: int) -> int:
# Heal the enemy
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	return current_health - old_health

func flash_damage_effect():
# Visual effect when taking damage
	# TODO: Implement damage flash effect
	# Could change sprite color briefly or play animation
	pass

func die():
# Handle enemy death
	current_state = EnemyState.DEAD
	
	# Generate loot
	var loot = generate_loot()
	
	# Emit death event
	EventBus.enemy_defeated.emit(name, loot)
	
	# TODO: Play death animation/sound
	EventBus.sound_play_requested.emit("enemy_death", global_position)
	
	# Remove after short delay
	await get_tree().create_timer(1.0).timeout
	queue_free()

func generate_loot() -> Array:
# Generate loot drops based on enemy type
	var loot = []
	
	# Basic loot table
	var loot_chances = {
		"bronze_coin": 0.8,
		"minor_potion": 0.3,
		"wood": 0.2
	}
	
	for item_id in loot_chances:
		if randf() < loot_chances[item_id]:
			loot.append(item_id)
	
	return loot

func find_player_target():
# Find the player as target
	var bodies = detection_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("get_player_data") or body.name == "Player":
			target = body
			last_player_position = body.global_position
			break

func scale_stats(scale_factor: float):
# Scale enemy stats by factor (for difficulty scaling)
	max_health = int(max_health * scale_factor)
	current_health = max_health
	damage = int(damage * scale_factor)
	move_speed *= scale_factor

# Combat system integration methods
func get_stats() -> Dictionary:
# Get enemy combat stats
	return {
		"strength": damage,
		"agility": int(move_speed / 10),
		"vitality": int(max_health / 10),
		"intelligence": 5,
		"willpower": 5,
		"luck": 5,
		"armor": 0,
		"magic_resistance": 0
	}

# Status effect support
var status_effects = []

func add_status_effect(effect_data: Dictionary):
# Add status effect to enemy
	status_effects.append(effect_data)
	
	# Apply immediate effects
	match effect_data.id:
		"stun":
			change_state(EnemyState.STUNNED)
		"slow":
			move_speed *= 0.5
		"burn":
			# TODO: Implement burn damage over time
			pass

func remove_status_effect(effect_id: String):
# Remove status effect from enemy
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].id == effect_id:
			var effect = status_effects[i]
			
			# Remove effect
			match effect.id:
				"slow":
					move_speed *= 2.0  # Restore speed
			
			status_effects.remove_at(i)
			break

# Signal handlers
func _on_detection_entered(body):
# Handle body entering detection area
	if body.has_method("get_player_data") or body.name == "Player":
		target = body
		if current_state == EnemyState.IDLE or current_state == EnemyState.PATROL:
			change_state(EnemyState.CHASE)

func _on_detection_exited(body):
# Handle body leaving detection area
	if body == target:
		# Don't immediately lose target, give some time
		last_player_position = body.global_position

# Utility methods
func get_display_name() -> String:
# Get display name for UI
	return name.replace("_", " ").capitalize()

func is_alive() -> bool:
# Check if enemy is alive
	return current_state != EnemyState.DEAD

func get_health_percentage() -> float:
# Get health as percentage
	return float(current_health) / float(max_health)

# TODO: Future enhancements
# - More sophisticated AI behaviors
# - Group coordination between enemies
# - Special abilities and attack patterns
# - Environmental awareness and pathfinding
# - Dynamic difficulty based on player performance
# - Elite/boss enemy variants
# - Faction-based enemy relationships
