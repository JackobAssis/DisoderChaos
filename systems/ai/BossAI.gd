extends AIController
class_name BossAI
# BossAI.gd - Advanced AI system specifically for boss encounters
# Implements phase-based behavior, player prediction, environmental awareness

# Boss-specific properties
@export var boss_id: String = ""
@export var phase_health_thresholds: Array[float] = [0.75, 0.5, 0.25]  # Health % for phase transitions
@export var environmental_damage_avoidance: bool = true
@export var player_prediction_enabled: bool = true
@export var adaptive_difficulty: bool = false

# Phase management
var phase_data: Dictionary = {}
var phase_abilities: Dictionary = {}
var phase_behaviors: Dictionary = {}
var enrage_threshold: float = 0.1  # Enrage at 10% health

# Player tracking and prediction
var player_movement_history: Array = []
var player_attack_patterns: Dictionary = {}
var player_dodge_timing: Array = []
var prediction_accuracy: float = 0.5

# Environmental awareness
var dangerous_areas: Array = []
var safe_zones: Array = []
var environmental_hazards: Array = []
var arena_bounds: Rect2

# Adaptive difficulty
var player_performance_score: float = 0.0
var difficulty_modifier: float = 1.0
var last_damage_time: float = 0.0
var damage_frequency: float = 0.0

# Boss mechanics tracking
var abilities_on_cooldown: Dictionary = {}
var combo_count: int = 0
var last_ability_used: String = ""
var mechanic_rotation: Array = []

signal boss_ability_used(ability_name: String, phase: int)
signal boss_phase_started(phase: int)
signal boss_enraged()
signal environmental_hazard_created(hazard_type: String, position: Vector2)

func _ready():
	super._ready()
	
	# Override AI type
	ai_type = AIType.BOSS
	
	# Initialize boss-specific systems
	setup_boss_data()
	setup_phase_system()
	setup_prediction_system()
	setup_environmental_awareness()
	
	# Connect boss-specific signals
	connect_boss_signals()
	
	print("[BossAI] Boss AI initialized for: ", boss_id)

func setup_boss_data():
	"""Load boss-specific data and configuration"""
	# This would load from boss data files
	arena_bounds = Rect2(-500, -500, 1000, 1000)  # Default arena size
	
	# Initialize phase data
	for i in range(boss_max_phases):
		phase_data[i + 1] = {
			"health_threshold": phase_health_thresholds[i] if i < phase_health_thresholds.size() else 0.0,
			"abilities": [],
			"behavior_modifiers": {},
			"special_mechanics": []
		}

func setup_phase_system():
	"""Setup phase-based behavior system"""
	# Load phase-specific abilities and behaviors
	load_phase_abilities()
	load_phase_behaviors()
	
	# Setup phase transition triggers
	setup_phase_transitions()

func load_phase_abilities():
	"""Load abilities for each phase"""
	# Phase 1: Basic attacks and introduction to mechanics
	phase_abilities[1] = [
		"basic_attack",
		"charge_attack", 
		"area_slam"
	]
	
	# Phase 2: More complex mechanics
	phase_abilities[2] = [
		"basic_attack",
		"charge_attack",
		"area_slam",
		"projectile_barrage",
		"summon_minions"
	]
	
	# Phase 3: All abilities, environmental hazards
	phase_abilities[3] = [
		"basic_attack",
		"charge_attack",
		"area_slam",
		"projectile_barrage",
		"summon_minions",
		"environmental_devastation",
		"enrage_mode"
	]

func load_phase_behaviors():
	"""Load behavior patterns for each phase"""
	phase_behaviors[1] = {
		"aggression": 0.5,
		"ability_frequency": 0.3,
		"movement_speed": 1.0,
		"prediction_use": 0.2
	}
	
	phase_behaviors[2] = {
		"aggression": 0.7,
		"ability_frequency": 0.5,
		"movement_speed": 1.2,
		"prediction_use": 0.5
	}
	
	phase_behaviors[3] = {
		"aggression": 0.9,
		"ability_frequency": 0.8,
		"movement_speed": 1.5,
		"prediction_use": 0.8
	}

func setup_phase_transitions():
	"""Setup automatic phase transitions"""
	if health_component:
		health_component.health_changed.connect(_on_boss_health_changed)

func setup_prediction_system():
	"""Setup player movement and behavior prediction"""
	player_movement_history.resize(60)  # Track 60 frames of movement
	player_movement_history.fill(Vector2.ZERO)

func setup_environmental_awareness():
	"""Setup environmental hazard tracking"""
	# Connect to environmental systems
	if event_manager:
		event_manager.environmental_hazard_created.connect(_on_environmental_hazard_created)
		event_manager.hazard_removed.connect(_on_hazard_removed)

func connect_boss_signals():
	"""Connect boss-specific signals"""
	boss_phase_changed.connect(_on_boss_phase_changed)
	
	# Connect to combat system for damage tracking
	if combat_component:
		combat_component.damage_dealt.connect(_on_damage_dealt_to_player)

func _process(delta):
	super._process(delta)
	
	# Boss-specific updates
	update_player_tracking(delta)
	update_environmental_awareness(delta)
	update_ability_cooldowns(delta)
	update_adaptive_difficulty(delta)
	
	# Execute boss behavior
	execute_boss_ai(delta)

func update_player_tracking(delta: float):
	"""Update player movement tracking and prediction"""
	if not current_target:
		return
	
	# Record player position
	player_movement_history.push_back(current_target.global_position)
	if player_movement_history.size() > 60:
		player_movement_history.pop_front()
	
	# Track player attack patterns
	track_player_attacks(delta)
	
	# Update prediction accuracy based on success
	update_prediction_accuracy(delta)

func track_player_attacks(delta: float):
	"""Track player attack patterns for prediction"""
	# This would integrate with combat system to track player abilities
	pass

func update_prediction_accuracy(delta: float):
	"""Update prediction accuracy based on how often predictions were correct"""
	# This would compare predicted vs actual player positions
	# and adjust prediction_accuracy accordingly
	pass

func update_environmental_awareness(delta: float):
	"""Update awareness of environmental hazards"""
	# Clean up expired hazards
	for i in range(dangerous_areas.size() - 1, -1, -1):
		var hazard = dangerous_areas[i]
		if Time.get_ticks_msec() - hazard.created_time > hazard.duration:
			dangerous_areas.remove_at(i)
	
	# Check if boss is in danger
	if environmental_damage_avoidance:
		check_boss_safety()

func check_boss_safety():
	"""Check if boss needs to move to avoid environmental damage"""
	for hazard in dangerous_areas:
		if hazard.area.has_point(entity.global_position):
			# Boss is in danger, find safe position
			var safe_position = find_safe_position()
			if safe_position != Vector2.ZERO:
				# Emergency movement to safety
				force_move_to_position(safe_position)

func find_safe_position() -> Vector2:
	"""Find a safe position away from environmental hazards"""
	var grid_size = 50.0
	var search_radius = 200.0
	
	# Check positions in a grid around the boss
	for x in range(-int(search_radius / grid_size), int(search_radius / grid_size) + 1):
		for y in range(-int(search_radius / grid_size), int(search_radius / grid_size) + 1):
			var test_position = entity.global_position + Vector2(x * grid_size, y * grid_size)
			
			# Check if position is safe
			if is_position_safe(test_position):
				return test_position
	
	return Vector2.ZERO  # No safe position found

func is_position_safe(position: Vector2) -> bool:
	"""Check if a position is safe from environmental hazards"""
	# Check arena bounds
	if not arena_bounds.has_point(position):
		return false
	
	# Check environmental hazards
	for hazard in dangerous_areas:
		if hazard.area.has_point(position):
			return false
	
	return true

func force_move_to_position(position: Vector2):
	"""Force boss to move to specific position (emergency movement)"""
	if movement_component:
		var direction = (position - entity.global_position).normalized()
		movement_component.move_direction(direction * movement_component.base_speed * 2.0)  # Emergency speed

func update_ability_cooldowns(delta: float):
	"""Update ability cooldowns"""
	for ability_name in abilities_on_cooldown.keys():
		abilities_on_cooldown[ability_name] -= delta
		if abilities_on_cooldown[ability_name] <= 0:
			abilities_on_cooldown.erase(ability_name)

func update_adaptive_difficulty(delta: float):
	"""Update adaptive difficulty based on player performance"""
	if not adaptive_difficulty:
		return
	
	# Track player performance
	update_player_performance_score(delta)
	
	# Adjust boss difficulty
	adjust_difficulty_modifier()

func update_player_performance_score(delta: float):
	"""Update player performance tracking"""
	if not current_target:
		return
	
	# Track damage frequency
	if last_damage_time > 0:
		damage_frequency = 1.0 / (Time.get_ticks_msec() / 1000.0 - last_damage_time)
	
	# Calculate performance score (0.0 = poor, 1.0 = excellent)
	# This is simplified - real implementation would track dodges, damage dealt, etc.
	if damage_frequency > 0.5:
		player_performance_score += delta * 0.1  # Player doing well
	else:
		player_performance_score -= delta * 0.05  # Player struggling
	
	player_performance_score = clamp(player_performance_score, 0.0, 1.0)

func adjust_difficulty_modifier():
	"""Adjust boss difficulty based on player performance"""
	if player_performance_score > 0.7:
		# Player is doing well, increase difficulty
		difficulty_modifier = lerp(difficulty_modifier, 1.3, 0.1)
	elif player_performance_score < 0.3:
		# Player is struggling, decrease difficulty
		difficulty_modifier = lerp(difficulty_modifier, 0.7, 0.1)
	else:
		# Reset to normal
		difficulty_modifier = lerp(difficulty_modifier, 1.0, 0.05)
	
	difficulty_modifier = clamp(difficulty_modifier, 0.5, 1.5)

func execute_boss_ai(delta: float):
	"""Main boss AI execution"""
	# Check for phase transitions
	if not phase_transition_triggered:
		check_phase_transition()
	
	# Execute phase-specific behavior
	execute_current_phase_behavior(delta)
	
	# Check for enrage
	check_enrage_condition()

func execute_current_phase_behavior(delta: float):
	"""Execute behavior for current boss phase"""
	if not current_target:
		return
	
	var phase_behavior = phase_behaviors.get(boss_phase, {})
	
	# Determine action based on phase behavior
	var action_roll = randf()
	var ability_chance = phase_behavior.get("ability_frequency", 0.3) * difficulty_modifier
	
	if action_roll < ability_chance:
		# Use special ability
		use_phase_ability()
	else:
		# Use basic behavior
		execute_basic_boss_behavior(delta)

func use_phase_ability():
	"""Use an ability appropriate for current phase"""
	var available_abilities = phase_abilities.get(boss_phase, [])
	if available_abilities.is_empty():
		return
	
	# Filter out abilities on cooldown
	var usable_abilities = []
	for ability in available_abilities:
		if not ability in abilities_on_cooldown:
			usable_abilities.append(ability)
	
	if usable_abilities.is_empty():
		return
	
	# Select ability based on situation
	var selected_ability = select_optimal_ability(usable_abilities)
	execute_boss_ability(selected_ability)

func select_optimal_ability(abilities: Array) -> String:
	"""Select optimal ability based on current situation"""
	if not current_target:
		return abilities[0] if not abilities.is_empty() else ""
	
	var distance = entity.global_position.distance_to(current_target.global_position)
	
	# Simple ability selection based on distance and phase
	if distance > 200.0:
		# Long range - prefer projectiles
		for ability in abilities:
			if "projectile" in ability or "barrage" in ability:
				return ability
	elif distance < 100.0:
		# Close range - prefer melee attacks
		for ability in abilities:
			if "slam" in ability or "charge" in ability:
				return ability
	
	# Default to random selection
	return abilities[randi() % abilities.size()]

func execute_boss_ability(ability_name: String):
	"""Execute specific boss ability"""
	match ability_name:
		"basic_attack":
			execute_basic_attack()
		"charge_attack":
			execute_charge_attack()
		"area_slam":
			execute_area_slam()
		"projectile_barrage":
			execute_projectile_barrage()
		"summon_minions":
			execute_summon_minions()
		"environmental_devastation":
			execute_environmental_devastation()
		"enrage_mode":
			execute_enrage_mode()
	
	# Set cooldown
	var cooldown = get_ability_cooldown(ability_name)
	abilities_on_cooldown[ability_name] = cooldown
	
	# Track for patterns
	last_ability_used = ability_name
	combo_count += 1
	
	boss_ability_used.emit(ability_name, boss_phase)

func get_ability_cooldown(ability_name: String) -> float:
	"""Get cooldown time for specific ability"""
	match ability_name:
		"basic_attack":
			return 1.0
		"charge_attack":
			return 3.0
		"area_slam":
			return 4.0
		"projectile_barrage":
			return 6.0
		"summon_minions":
			return 15.0
		"environmental_devastation":
			return 20.0
		"enrage_mode":
			return 30.0
		_:
			return 2.0

# Boss ability implementations
func execute_basic_attack():
	"""Execute basic boss attack"""
	if not current_target or not combat_component:
		return
	
	face_target(entity, current_target)
	combat_component.melee_attack(current_target)

func execute_charge_attack():
	"""Execute charge attack with prediction"""
	if not current_target:
		return
	
	var target_position = current_target.global_position
	
	# Use prediction if enabled and accurate enough
	if player_prediction_enabled and prediction_accuracy > 0.3:
		target_position = predict_player_position(1.0)  # Predict 1 second ahead
	
	# Execute charge toward predicted position
	charge_toward_position(target_position)

func execute_area_slam():
	"""Execute area slam attack"""
	if not current_target:
		return
	
	var slam_position = current_target.global_position
	
	# Add prediction
	if player_prediction_enabled:
		slam_position = predict_player_position(0.5)
	
	# Create area damage effect
	create_area_damage(slam_position, 100.0, 50)

func execute_projectile_barrage():
	"""Execute projectile barrage attack"""
	if not current_target:
		return
	
	var base_direction = (current_target.global_position - entity.global_position).normalized()
	
	# Fire spread of projectiles
	for i in range(5):
		var angle_offset = (i - 2) * PI / 12  # 15-degree spread
		var direction = base_direction.rotated(angle_offset)
		fire_projectile(direction)

func execute_summon_minions():
	"""Execute minion summoning"""
	var spawn_points = [
		entity.global_position + Vector2(100, 0),
		entity.global_position + Vector2(-100, 0),
		entity.global_position + Vector2(0, 100),
		entity.global_position + Vector2(0, -100)
	]
	
	for point in spawn_points:
		spawn_minion(point)

func execute_environmental_devastation():
	"""Execute environmental devastation attack"""
	# Create multiple environmental hazards
	for i in range(3):
		var hazard_position = entity.global_position + Vector2(
			randf_range(-200, 200),
			randf_range(-200, 200)
		)
		create_environmental_hazard(hazard_position, "fire_pit")

func execute_enrage_mode():
	"""Execute enrage mode"""
	# Increase all stats temporarily
	if combat_component:
		combat_component.damage_modifier *= 1.5
		combat_component.attack_speed_modifier *= 1.3
	
	if movement_component:
		movement_component.speed_modifier *= 1.2
	
	boss_enraged.emit()

func execute_basic_boss_behavior(delta: float):
	"""Execute basic boss movement and positioning"""
	if not current_target:
		return
	
	var distance = entity.global_position.distance_to(current_target.global_position)
	var optimal_range = 120.0  # Optimal fighting distance
	
	if distance > optimal_range + 30.0:
		# Move closer
		move_toward_target(delta)
	elif distance < optimal_range - 30.0:
		# Move to optimal range
		maintain_distance(delta)
	else:
		# Strafe around target
		strafe_around_target(delta)

func move_toward_target(delta: float):
	"""Move toward current target"""
	if not current_target or not movement_component:
		return
	
	var target_position = current_target.global_position
	if player_prediction_enabled:
		target_position = predict_player_position(0.3)
	
	var direction = (target_position - entity.global_position).normalized()
	movement_component.move_direction(direction * movement_component.base_speed)

func maintain_distance(delta: float):
	"""Maintain optimal distance from target"""
	if not current_target or not movement_component:
		return
	
	var direction = (entity.global_position - current_target.global_position).normalized()
	movement_component.move_direction(direction * movement_component.base_speed * 0.7)

func strafe_around_target(delta: float):
	"""Strafe around target while maintaining distance"""
	if not current_target or not movement_component:
		return
	
	var to_target = current_target.global_position - entity.global_position
	var strafe_direction = Vector2(-to_target.y, to_target.x).normalized()
	
	# Randomly choose strafe direction
	if randf() > 0.5:
		strafe_direction = -strafe_direction
	
	movement_component.move_direction(strafe_direction * movement_component.base_speed * 0.8)

func predict_player_position(time_ahead: float) -> Vector2:
	"""Predict where player will be in the future"""
	if not current_target or player_movement_history.size() < 10:
		return current_target.global_position if current_target else Vector2.ZERO
	
	# Calculate average velocity
	var velocity = Vector2.ZERO
	var samples = min(10, player_movement_history.size())
	
	for i in range(samples - 1):
		var current_pos = player_movement_history[player_movement_history.size() - 1 - i]
		var previous_pos = player_movement_history[player_movement_history.size() - 2 - i]
		velocity += (current_pos - previous_pos)
	
	velocity /= samples
	velocity *= Engine.get_frames_per_second()  # Convert to units per second
	
	# Predict future position
	var predicted_position = current_target.global_position + velocity * time_ahead
	
	# Clamp to arena bounds
	predicted_position.x = clamp(predicted_position.x, arena_bounds.position.x, arena_bounds.end.x)
	predicted_position.y = clamp(predicted_position.y, arena_bounds.position.y, arena_bounds.end.y)
	
	return predicted_position

func check_enrage_condition():
	"""Check if boss should enter enrage mode"""
	if not health_component:
		return
	
	var health_percentage = health_component.current_health / float(health_component.max_health)
	
	if health_percentage <= enrage_threshold and not has_meta("enraged"):
		enter_enrage_mode()

func enter_enrage_mode():
	"""Enter enrage mode"""
	set_meta("enraged", true)
	
	# Increase all behavior modifiers
	for phase in phase_behaviors.values():
		phase["aggression"] *= 1.5
		phase["ability_frequency"] *= 1.3
		phase["movement_speed"] *= 1.2
	
	boss_enraged.emit()
	print("[BossAI] Boss entered enrage mode!")

# Helper functions for boss abilities
func charge_toward_position(position: Vector2):
	"""Charge toward specific position"""
	if not movement_component:
		return
	
	var direction = (position - entity.global_position).normalized()
	movement_component.move_direction(direction * movement_component.base_speed * 2.0)

func create_area_damage(position: Vector2, radius: float, damage: int):
	"""Create area damage effect"""
	# This would integrate with effects/combat system
	print("[BossAI] Area damage at ", position, " radius: ", radius, " damage: ", damage)
	
	# Add to dangerous areas
	dangerous_areas.append({
		"area": Rect2(position - Vector2(radius, radius), Vector2(radius * 2, radius * 2)),
		"damage": damage,
		"created_time": Time.get_ticks_msec(),
		"duration": 2000  # 2 seconds
	})

func fire_projectile(direction: Vector2):
	"""Fire projectile in specific direction"""
	# This would integrate with projectile system
	print("[BossAI] Firing projectile in direction: ", direction)

func spawn_minion(position: Vector2):
	"""Spawn minion at specific position"""
	# This would integrate with spawning system
	print("[BossAI] Spawning minion at: ", position)

func create_environmental_hazard(position: Vector2, hazard_type: String):
	"""Create environmental hazard"""
	environmental_hazard_created.emit(hazard_type, position)
	
	# Add to dangerous areas
	var hazard_radius = 75.0
	dangerous_areas.append({
		"area": Rect2(position - Vector2(hazard_radius, hazard_radius), Vector2(hazard_radius * 2, hazard_radius * 2)),
		"type": hazard_type,
		"created_time": Time.get_ticks_msec(),
		"duration": 10000  # 10 seconds
	})

# Signal handlers
func _on_boss_phase_changed(phase: int):
	"""Handle boss phase change"""
	boss_phase_started.emit(phase)
	
	# Reset combo count and patterns
	combo_count = 0
	last_ability_used = ""
	
	# Clear some cooldowns for dramatic phase transitions
	var abilities_to_clear = ["charge_attack", "area_slam"]
	for ability in abilities_to_clear:
		abilities_on_cooldown.erase(ability)
	
	print("[BossAI] Boss entered phase ", phase)

func _on_boss_health_changed(current_health: int, max_health: int):
	"""Handle boss health changes for phase transitions"""
	var health_percentage = current_health / float(max_health)
	
	# Check for phase transitions
	for i in range(phase_health_thresholds.size()):
		var threshold = phase_health_thresholds[i]
		if health_percentage <= threshold and boss_phase == i + 1:
			trigger_boss_phase_transition()
			break

func _on_environmental_hazard_created(hazard_type: String, position: Vector2):
	"""Handle environmental hazard creation"""
	# Track hazards created by other systems
	pass

func _on_hazard_removed(hazard_id: String):
	"""Handle environmental hazard removal"""
	# Remove from dangerous areas tracking
	pass

func _on_damage_dealt_to_player(damage: int, target: Node):
	"""Handle damage dealt to player"""
	last_damage_time = Time.get_ticks_msec() / 1000.0

# Save/Load for boss state
func get_boss_save_data() -> Dictionary:
	"""Get boss-specific save data"""
	var base_data = get_save_data()
	base_data.merge({
		"boss_id": boss_id,
		"phase_data": phase_data,
		"abilities_on_cooldown": abilities_on_cooldown,
		"player_performance_score": player_performance_score,
		"difficulty_modifier": difficulty_modifier,
		"dangerous_areas": dangerous_areas,
		"combo_count": combo_count
	})
	return base_data

func load_boss_save_data(data: Dictionary):
	"""Load boss-specific save data"""
	load_save_data(data)
	
	if "boss_id" in data:
		boss_id = data.boss_id
	if "phase_data" in data:
		phase_data = data.phase_data
	if "abilities_on_cooldown" in data:
		abilities_on_cooldown = data.abilities_on_cooldown
	if "player_performance_score" in data:
		player_performance_score = data.player_performance_score
	if "difficulty_modifier" in data:
		difficulty_modifier = data.difficulty_modifier
	if "dangerous_areas" in data:
		dangerous_areas = data.dangerous_areas
	if "combo_count" in data:
		combo_count = data.combo_count