extends Node
class_name AIController
# AIController.gd - Advanced AI system for mobs and bosses
# Supports behavior trees, state machines, perception, and dynamic priorities

# AI Types
enum AIType {
	MELEE,
	RANGED,
	COWARD,
	ELITE,
	MINION,
	BOSS
}

# AI States
enum AIState {
	IDLE,
	PATROL,
	ALERT,
	PURSUE,
	ATTACK,
	FLEE,
	PROTECT,
	STUNNED,
	DEAD,
	BOSS_PHASE_TRANSITION
}

# Behavior Priorities
enum Priority {
	CRITICAL = 100,  # Death, boss mechanics
	HIGH = 80,       # Combat, fleeing
	MEDIUM = 50,     # Pursuit, protection
	LOW = 20,        # Patrol, idle
	MINIMAL = 5      # Ambient behaviors
}

# Core properties
@export var ai_type: AIType = AIType.MELEE
@export var detection_range: float = 150.0
@export var attack_range: float = 50.0
@export var flee_threshold: float = 0.2  # Flee when HP < 20%
@export var aggro_timeout: float = 10.0
@export var patrol_radius: float = 200.0

# AI Components
var senses: AISenses
var behavior_tree: AIBehaviorTree
var state_machine: AIStateMachine
var target_selector: AITargetSelector

# References
var entity: CharacterBody2D
var health_component: Node
var combat_component: Node
var movement_component: Node

# Current state
var current_state: AIState = AIState.IDLE
var previous_state: AIState = AIState.IDLE
var current_target: Node = null
var last_known_target_position: Vector2
var aggro_timer: float = 0.0
var state_timer: float = 0.0

# Boss specific
var boss_phase: int = 1
var boss_max_phases: int = 3
var phase_transition_triggered: bool = false

# Behavior tree nodes
var behavior_nodes: Dictionary = {}
var active_behaviors: Array = []

# Dynamic priorities
var behavior_priorities: Dictionary = {}
var priority_modifiers: Dictionary = {}

# Integration with other systems
var climate_manager: Node
var event_manager: Node
var save_data: Dictionary = {}

signal state_changed(from_state: AIState, to_state: AIState)
signal target_acquired(target: Node)
signal target_lost()
signal boss_phase_changed(phase: int)
signal behavior_executed(behavior_name: String)

func _ready():
	print("[AIController] Initializing AI system for: ", get_parent().name)
	
	# Get entity reference
	entity = get_parent()
	
	# Initialize components
	setup_components()
	setup_senses()
	setup_behavior_tree()
	setup_state_machine()
	setup_target_selector()
	
	# Connect to other systems
	connect_to_systems()
	
	# Initialize based on AI type
	configure_ai_type()
	
	print("[AIController] AI system ready for: ", entity.name)

func setup_components():
	"""Initialize AI components"""
	# Find required components
	health_component = entity.get_node_or_null("HealthComponent")
	combat_component = entity.get_node_or_null("CombatComponent")
	movement_component = entity.get_node_or_null("MovementComponent")
	
	if not health_component:
		push_error("AI entity requires HealthComponent")
	if not combat_component:
		push_error("AI entity requires CombatComponent")
	if not movement_component:
		push_error("AI entity requires MovementComponent")

func setup_senses():
	"""Initialize AI senses"""
	senses = preload("res://systems/ai/AISenses.gd").new()
	add_child(senses)
	senses.setup(entity, detection_range)
	
	# Connect sense signals
	senses.target_detected.connect(_on_target_detected)
	senses.target_lost.connect(_on_target_lost)
	senses.sound_heard.connect(_on_sound_heard)

func setup_behavior_tree():
	"""Initialize behavior tree system"""
	behavior_tree = AIBehaviorTree.new()
	add_child(behavior_tree)
	
	# Create behavior nodes based on AI type
	create_behavior_nodes()
	
	# Build behavior tree structure
	build_behavior_tree()

func setup_state_machine():
	"""Initialize state machine"""
	state_machine = AIStateMachine.new()
	add_child(state_machine)
	
	# Define state transitions
	setup_state_transitions()
	
	# Connect state machine signals
	state_machine.state_changed.connect(_on_state_changed)

func setup_target_selector():
	"""Initialize target selection system"""
	target_selector = AITargetSelector.new()
	add_child(target_selector)
	
	target_selector.setup(entity, senses)

func connect_to_systems():
	"""Connect to external game systems"""
	# Climate integration
	climate_manager = get_node_or_null("/root/ClimateManager")
	if climate_manager:
		climate_manager.weather_changed.connect(_on_weather_changed)
	
	# Event system integration
	event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		event_manager.dynamic_event_triggered.connect(_on_dynamic_event)
	
	# Combat system integration
	if combat_component:
		combat_component.damage_taken.connect(_on_damage_taken)
		combat_component.attack_executed.connect(_on_attack_executed)
	
	# Health system integration
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_entity_died)

func configure_ai_type():
	"""Configure AI behavior based on type"""
	match ai_type:
		AIType.MELEE:
			configure_melee_ai()
		AIType.RANGED:
			configure_ranged_ai()
		AIType.COWARD:
			configure_coward_ai()
		AIType.ELITE:
			configure_elite_ai()
		AIType.MINION:
			configure_minion_ai()
		AIType.BOSS:
			configure_boss_ai()

func configure_melee_ai():
	"""Configure melee fighter AI"""
	attack_range = 60.0
	detection_range = 120.0
	flee_threshold = 0.1  # Fight almost to death
	
	# Aggressive behavior priorities
	set_behavior_priority("aggressive_pursuit", Priority.HIGH)
	set_behavior_priority("melee_attack", Priority.HIGH)
	set_behavior_priority("defensive_position", Priority.MEDIUM)

func configure_ranged_ai():
	"""Configure ranged attacker AI"""
	attack_range = 150.0
	detection_range = 200.0
	flee_threshold = 0.15
	
	# Ranged behavior priorities
	set_behavior_priority("maintain_distance", Priority.HIGH)
	set_behavior_priority("ranged_attack", Priority.HIGH)
	set_behavior_priority("kiting", Priority.MEDIUM)

func configure_coward_ai():
	"""Configure coward mob AI"""
	attack_range = 40.0
	detection_range = 100.0
	flee_threshold = 0.5  # Flee when half health
	
	# Coward behavior priorities
	set_behavior_priority("flee_behavior", Priority.CRITICAL)
	set_behavior_priority("call_for_help", Priority.HIGH)
	set_behavior_priority("cautious_attack", Priority.LOW)

func configure_elite_ai():
	"""Configure elite mob AI"""
	attack_range = 80.0
	detection_range = 180.0
	flee_threshold = 0.0  # Never flee
	
	# Elite behavior priorities
	set_behavior_priority("tactical_positioning", Priority.HIGH)
	set_behavior_priority("combo_attacks", Priority.HIGH)
	set_behavior_priority("area_control", Priority.MEDIUM)

func configure_minion_ai():
	"""Configure minion AI"""
	attack_range = 50.0
	detection_range = 100.0
	flee_threshold = 0.3
	
	# Minion behavior priorities
	set_behavior_priority("swarm_tactics", Priority.HIGH)
	set_behavior_priority("protect_master", Priority.CRITICAL)
	set_behavior_priority("simple_attack", Priority.MEDIUM)

func configure_boss_ai():
	"""Configure boss AI"""
	attack_range = 100.0
	detection_range = 300.0
	flee_threshold = 0.0  # Bosses never flee
	
	# Boss behavior priorities
	set_behavior_priority("phase_management", Priority.CRITICAL)
	set_behavior_priority("boss_mechanics", Priority.CRITICAL)
	set_behavior_priority("player_prediction", Priority.HIGH)
	set_behavior_priority("environmental_awareness", Priority.HIGH)

func _process(delta):
	"""Main AI update loop"""
	if current_state == AIState.DEAD:
		return
	
	# Update timers
	update_timers(delta)
	
	# Update senses
	senses.update_perception(delta)
	
	# Update behavior tree
	behavior_tree.update(delta)
	
	# Update state machine
	state_machine.update(delta)
	
	# Boss specific updates
	if ai_type == AIType.BOSS:
		update_boss_behavior(delta)
	
	# Apply climate effects
	apply_climate_effects(delta)

func update_timers(delta):
	"""Update various AI timers"""
	state_timer += delta
	
	if aggro_timer > 0:
		aggro_timer -= delta
		if aggro_timer <= 0:
			_on_aggro_timeout()

func update_boss_behavior(delta):
	"""Update boss-specific behavior"""
	if not phase_transition_triggered:
		check_phase_transition()
	
	# Boss environmental awareness
	if current_target:
		update_boss_tactics(delta)

func check_phase_transition():
	"""Check if boss should transition to next phase"""
	if not health_component:
		return
	
	var health_percentage = health_component.current_health / float(health_component.max_health)
	var phase_threshold = 1.0 - (boss_phase / float(boss_max_phases))
	
	if health_percentage <= phase_threshold and boss_phase < boss_max_phases:
		trigger_boss_phase_transition()

func trigger_boss_phase_transition():
	"""Trigger boss phase transition"""
	phase_transition_triggered = true
	boss_phase += 1
	
	change_state(AIState.BOSS_PHASE_TRANSITION)
	boss_phase_changed.emit(boss_phase)
	
	print("[AIController] Boss entering phase ", boss_phase)
	
	# Reconfigure AI for new phase
	configure_boss_phase(boss_phase)

func configure_boss_phase(phase: int):
	"""Configure boss behavior for specific phase"""
	match phase:
		1:
			# Basic attacks, learning player patterns
			set_behavior_priority("basic_attacks", Priority.HIGH)
			set_behavior_priority("pattern_learning", Priority.MEDIUM)
		2:
			# More aggressive, special abilities
			set_behavior_priority("special_abilities", Priority.CRITICAL)
			set_behavior_priority("aggressive_tactics", Priority.HIGH)
		3:
			# Desperate phase, all abilities
			set_behavior_priority("desperate_attacks", Priority.CRITICAL)
			set_behavior_priority("environmental_damage", Priority.HIGH)

func update_boss_tactics(delta):
	"""Update boss tactical behavior"""
	# Predict player movement
	var predicted_position = predict_player_movement()
	
	# Check for dangerous areas
	var safe_positions = get_safe_positions()
	
	# Update targeting based on predictions
	update_boss_targeting(predicted_position, safe_positions)

func predict_player_movement() -> Vector2:
	"""Predict where player will be"""
	if not current_target:
		return Vector2.ZERO
	
	var target_velocity = Vector2.ZERO
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.get_velocity()
	
	# Predict position 0.5 seconds ahead
	var prediction_time = 0.5
	return current_target.global_position + (target_velocity * prediction_time)

func get_safe_positions() -> Array:
	"""Get positions safe from environmental hazards"""
	var safe_positions = []
	var grid_size = 50.0
	
	# Check grid around boss for safe spots
	for x in range(-5, 6):
		for y in range(-5, 6):
			var test_position = entity.global_position + Vector2(x * grid_size, y * grid_size)
			if is_position_safe(test_position):
				safe_positions.append(test_position)
	
	return safe_positions

func is_position_safe(position: Vector2) -> bool:
	"""Check if position is safe from hazards"""
	# TODO: Check for environmental hazards, spell effects, etc.
	# This would integrate with spell/hazard systems
	return true

func update_boss_targeting(predicted_pos: Vector2, safe_positions: Array):
	"""Update boss targeting based on predictions and safety"""
	# Choose attack based on predicted player position
	# Prefer safe positions for boss positioning
	pass

# State Management
func change_state(new_state: AIState):
	"""Change AI state with proper transition"""
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	state_timer = 0.0
	
	# Execute state exit/enter logic
	exit_state(previous_state)
	enter_state(current_state)
	
	state_changed.emit(previous_state, current_state)
	print("[AIController] State changed: ", AIState.keys()[previous_state], " -> ", AIState.keys()[current_state])

func enter_state(state: AIState):
	"""Execute logic when entering a state"""
	match state:
		AIState.IDLE:
			# Reset aggro, start idle behavior
			current_target = null
			aggro_timer = 0.0
		AIState.PATROL:
			# Start patrol route
			start_patrol_behavior()
		AIState.ALERT:
			# Increase perception, look for threats
			senses.increase_alertness()
		AIState.PURSUE:
			# Start pursuit behavior
			aggro_timer = aggro_timeout
		AIState.ATTACK:
			# Initiate attack behavior
			start_attack_behavior()
		AIState.FLEE:
			# Find escape route
			start_flee_behavior()
		AIState.PROTECT:
			# Defensive positioning
			start_protect_behavior()
		AIState.STUNNED:
			# Disable AI temporarily
			disable_ai_temporarily()
		AIState.BOSS_PHASE_TRANSITION:
			# Boss phase transition
			start_phase_transition()

func exit_state(state: AIState):
	"""Execute logic when exiting a state"""
	match state:
		AIState.ALERT:
			senses.reset_alertness()
		AIState.ATTACK:
			stop_attack_behavior()
		AIState.FLEE:
			stop_flee_behavior()
		AIState.STUNNED:
			enable_ai()

# Behavior Tree System
func create_behavior_nodes():
	"""Create behavior tree nodes"""
	behavior_nodes["selector"] = AISelector.new()
	behavior_nodes["sequence"] = AISequence.new()
	behavior_nodes["parallel"] = AIParallel.new()
	
	# Condition nodes
	behavior_nodes["has_target"] = AICondition.new("has_target", func(): return current_target != null)
	behavior_nodes["in_range"] = AICondition.new("in_range", check_target_in_range)
	behavior_nodes["low_health"] = AICondition.new("low_health", check_low_health)
	behavior_nodes["is_boss"] = AICondition.new("is_boss", func(): return ai_type == AIType.BOSS)
	
	# Action nodes
	behavior_nodes["move_to_target"] = AIAction.new("move_to_target", move_to_target)
	behavior_nodes["attack_target"] = AIAction.new("attack_target", attack_target)
	behavior_nodes["flee_from_target"] = AIAction.new("flee_from_target", flee_from_target)
	behavior_nodes["patrol_area"] = AIAction.new("patrol_area", patrol_area)
	behavior_nodes["call_for_help"] = AIAction.new("call_for_help", call_for_help)

func build_behavior_tree():
	"""Build the main behavior tree structure"""
	var root = behavior_nodes["selector"]
	
	# High priority behaviors (flee, boss mechanics)
	var high_priority = behavior_nodes["selector"]
	high_priority.add_child(create_flee_branch())
	high_priority.add_child(create_boss_branch())
	
	# Combat behaviors
	var combat_branch = behavior_nodes["selector"]
	combat_branch.add_child(create_attack_branch())
	combat_branch.add_child(create_pursuit_branch())
	
	# Idle behaviors
	var idle_branch = behavior_nodes["selector"]
	idle_branch.add_child(create_patrol_branch())
	
	# Assemble main tree
	root.add_child(high_priority)
	root.add_child(combat_branch)
	root.add_child(idle_branch)
	
	behavior_tree.set_root(root)

func create_flee_branch() -> AINode:
	"""Create flee behavior branch"""
	var flee_sequence = behavior_nodes["sequence"]
	flee_sequence.add_child(behavior_nodes["low_health"])
	flee_sequence.add_child(behavior_nodes["flee_from_target"])
	return flee_sequence

func create_boss_branch() -> AINode:
	"""Create boss-specific behavior branch"""
	var boss_sequence = behavior_nodes["sequence"]
	boss_sequence.add_child(behavior_nodes["is_boss"])
	boss_sequence.add_child(AIAction.new("boss_behavior", execute_boss_behavior))
	return boss_sequence

func create_attack_branch() -> AINode:
	"""Create attack behavior branch"""
	var attack_sequence = behavior_nodes["sequence"]
	attack_sequence.add_child(behavior_nodes["has_target"])
	attack_sequence.add_child(behavior_nodes["in_range"])
	attack_sequence.add_child(behavior_nodes["attack_target"])
	return attack_sequence

func create_pursuit_branch() -> AINode:
	"""Create pursuit behavior branch"""
	var pursuit_sequence = behavior_nodes["sequence"]
	pursuit_sequence.add_child(behavior_nodes["has_target"])
	pursuit_sequence.add_child(behavior_nodes["move_to_target"])
	return pursuit_sequence

func create_patrol_branch() -> AINode:
	"""Create patrol behavior branch"""
	return behavior_nodes["patrol_area"]

# Behavior Actions
func move_to_target() -> bool:
	"""Move towards current target"""
	if not current_target or not movement_component:
		return false
	
	var target_pos = current_target.global_position
	movement_component.move_towards(target_pos)
	return true

func attack_target() -> bool:
	"""Attack current target"""
	if not current_target or not combat_component:
		return false
	
	if ai_type == AIType.RANGED:
		return combat_component.ranged_attack(current_target)
	else:
		return combat_component.melee_attack(current_target)

func flee_from_target() -> bool:
	"""Flee from current target"""
	if not current_target or not movement_component:
		return false
	
	var flee_direction = (entity.global_position - current_target.global_position).normalized()
	var flee_destination = entity.global_position + flee_direction * 200.0
	movement_component.move_towards(flee_destination)
	return true

func patrol_area() -> bool:
	"""Patrol assigned area"""
	if not movement_component:
		return false
	
	# Simple patrol logic - move to random point within patrol radius
	var random_offset = Vector2(randf_range(-patrol_radius, patrol_radius), randf_range(-patrol_radius, patrol_radius))
	var patrol_destination = entity.global_position + random_offset
	movement_component.move_towards(patrol_destination)
	return true

func call_for_help() -> bool:
	"""Call nearby allies for help"""
	if ai_type != AIType.COWARD:
		return false
	
	# Find nearby allies and alert them
	var nearby_allies = get_nearby_allies(100.0)
	for ally in nearby_allies:
		if ally.has_method("receive_help_call"):
			ally.receive_help_call(current_target)
	
	return true

func execute_boss_behavior() -> bool:
	"""Execute boss-specific behavior"""
	if ai_type != AIType.BOSS:
		return false
	
	# Execute current boss phase behavior
	match boss_phase:
		1:
			return execute_boss_phase_1()
		2:
			return execute_boss_phase_2()
		3:
			return execute_boss_phase_3()
	
	return false

func execute_boss_phase_1() -> bool:
	"""Execute boss phase 1 behavior"""
	# Basic attacks with pattern learning
	if current_target:
		learn_player_patterns()
		return attack_target()
	return false

func execute_boss_phase_2() -> bool:
	"""Execute boss phase 2 behavior"""
	# Special abilities and aggressive tactics
	if current_target:
		use_special_abilities()
		return true
	return false

func execute_boss_phase_3() -> bool:
	"""Execute boss phase 3 behavior"""
	# Desperate attacks with environmental damage
	if current_target:
		use_environmental_attacks()
		return true
	return false

# Condition Checks
func check_target_in_range() -> bool:
	"""Check if target is in attack range"""
	if not current_target:
		return false
	
	var distance = entity.global_position.distance_to(current_target.global_position)
	return distance <= attack_range

func check_low_health() -> bool:
	"""Check if entity has low health"""
	if not health_component:
		return false
	
	var health_percentage = health_component.current_health / float(health_component.max_health)
	return health_percentage <= flee_threshold

# Priority System
func set_behavior_priority(behavior_name: String, priority: int):
	"""Set priority for a behavior"""
	behavior_priorities[behavior_name] = priority

func get_behavior_priority(behavior_name: String) -> int:
	"""Get priority for a behavior"""
	return behavior_priorities.get(behavior_name, Priority.LOW)

func add_priority_modifier(modifier_name: String, value: int, duration: float = -1):
	"""Add temporary priority modifier"""
	priority_modifiers[modifier_name] = {
		"value": value,
		"duration": duration,
		"timer": duration
	}

func update_priority_modifiers(delta: float):
	"""Update temporary priority modifiers"""
	for modifier_name in priority_modifiers.keys():
		var modifier = priority_modifiers[modifier_name]
		if modifier.duration > 0:
			modifier.timer -= delta
			if modifier.timer <= 0:
				priority_modifiers.erase(modifier_name)

# Helper Functions
func get_nearby_allies(radius: float) -> Array:
	"""Get nearby allied entities"""
	var allies = []
	var space_state = entity.get_world_2d().direct_space_state
	
	# This would need proper faction/team system
	# For now, return empty array
	return allies

func learn_player_patterns():
	"""Learn and adapt to player behavior patterns"""
	if not current_target:
		return
	
	# Track player movement patterns, attack timing, etc.
	# This would be expanded with machine learning or pattern recognition
	pass

func use_special_abilities():
	"""Use boss special abilities"""
	# Implementation depends on boss type and available abilities
	pass

func use_environmental_attacks():
	"""Use environmental attacks"""
	# Implementation depends on environment and boss abilities
	pass

# State Behavior Functions
func start_patrol_behavior():
	"""Start patrol behavior"""
	pass

func start_attack_behavior():
	"""Start attack behavior"""
	pass

func stop_attack_behavior():
	"""Stop attack behavior"""
	pass

func start_flee_behavior():
	"""Start flee behavior"""
	change_state(AIState.FLEE)

func stop_flee_behavior():
	"""Stop flee behavior"""
	pass

func start_protect_behavior():
	"""Start protect behavior"""
	pass

func disable_ai_temporarily():
	"""Temporarily disable AI"""
	set_process(false)

func enable_ai():
	"""Re-enable AI"""
	set_process(true)

func start_phase_transition():
	"""Start boss phase transition"""
	# Play transition effects, disable normal behavior temporarily
	pass

func setup_state_transitions():
	"""Setup state machine transitions"""
	# This would be expanded with proper state machine implementation
	pass

# Apply external effects
func apply_climate_effects(delta: float):
	"""Apply climate effects to AI behavior"""
	if not climate_manager:
		return
	
	var current_weather = climate_manager.get_current_weather()
	match current_weather:
		"rain":
			# Reduced vision range in rain
			senses.vision_range_modifier = 0.7
		"fog":
			# Greatly reduced vision in fog
			senses.vision_range_modifier = 0.3
		"storm":
			# Erratic behavior in storms
			add_priority_modifier("storm_confusion", -20, 1.0)
		_:
			# Clear weather
			senses.vision_range_modifier = 1.0

# Signal Handlers
func _on_target_detected(target: Node):
	"""Handle target detection"""
	current_target = target
	last_known_target_position = target.global_position
	
	if current_state == AIState.IDLE or current_state == AIState.PATROL:
		change_state(AIState.ALERT)
	
	target_acquired.emit(target)

func _on_target_lost():
	"""Handle target loss"""
	if current_target:
		change_state(AIState.PATROL)
	
	current_target = null
	target_lost.emit()

func _on_sound_heard(sound_position: Vector2, sound_type: String):
	"""Handle sound detection"""
	if current_state == AIState.IDLE:
		change_state(AIState.ALERT)
		# Move towards sound
		last_known_target_position = sound_position

func _on_state_changed(from_state: AIState, to_state: AIState):
	"""Handle state change"""
	print("[AIController] State transition: ", AIState.keys()[from_state], " -> ", AIState.keys()[to_state])

func _on_damage_taken(damage: int, attacker: Node):
	"""Handle taking damage"""
	if attacker and not current_target:
		current_target = attacker
		change_state(AIState.ALERT)
	
	# Increase aggression or flee based on AI type
	if ai_type == AIType.COWARD:
		var health_percentage = health_component.current_health / float(health_component.max_health)
		if health_percentage <= flee_threshold:
			change_state(AIState.FLEE)

func _on_attack_executed():
	"""Handle attack execution"""
	behavior_executed.emit("attack")

func _on_health_changed(current_health: int, max_health: int):
	"""Handle health change"""
	var health_percentage = current_health / float(max_health)
	
	# Check for phase transitions (bosses)
	if ai_type == AIType.BOSS and not phase_transition_triggered:
		check_phase_transition()
	
	# Check for flee threshold
	if health_percentage <= flee_threshold and ai_type == AIType.COWARD:
		change_state(AIState.FLEE)

func _on_entity_died():
	"""Handle entity death"""
	change_state(AIState.DEAD)
	set_process(false)

func _on_aggro_timeout():
	"""Handle aggro timeout"""
	if current_state == AIState.PURSUE and not senses.can_see_target(current_target):
		change_state(AIState.PATROL)

func _on_weather_changed(weather_type: String):
	"""Handle weather changes"""
	print("[AIController] Weather changed to: ", weather_type)
	# Apply weather effects to AI behavior

func _on_dynamic_event(event_type: String, event_data: Dictionary):
	"""Handle dynamic events"""
	match event_type:
		"reinforcements_called":
			# Increase aggression
			add_priority_modifier("reinforcements", 30, 60.0)
		"alarm_triggered":
			# Enter alert state
			if current_state == AIState.IDLE:
				change_state(AIState.ALERT)

# Save/Load Integration
func get_save_data() -> Dictionary:
	"""Get AI data for saving"""
	return {
		"current_state": current_state,
		"boss_phase": boss_phase,
		"behavior_priorities": behavior_priorities,
		"last_known_target_position": last_known_target_position,
		"aggro_timer": aggro_timer
	}

func load_save_data(data: Dictionary):
	"""Load AI data from save"""
	if "current_state" in data:
		current_state = data.current_state
	if "boss_phase" in data:
		boss_phase = data.boss_phase
	if "behavior_priorities" in data:
		behavior_priorities = data.behavior_priorities
	if "last_known_target_position" in data:
		last_known_target_position = data.last_known_target_position
	if "aggro_timer" in data:
		aggro_timer = data.aggro_timer

# Debug Functions
func debug_print_state():
	"""Print current AI state for debugging"""
	print("[AIController DEBUG] Entity: ", entity.name)
	print("  State: ", AIState.keys()[current_state])
	print("  Target: ", current_target.name if current_target else "None")
	print("  Boss Phase: ", boss_phase if ai_type == AIType.BOSS else "N/A")
	print("  Active Behaviors: ", active_behaviors)

# Cleanup
func _exit_tree():
	"""Cleanup when AI controller is removed"""
	if senses:
		senses.queue_free()
	if behavior_tree:
		behavior_tree.queue_free()
	if state_machine:
		state_machine.queue_free()
	if target_selector:
		target_selector.queue_free()
	
	print("[AIController] AI controller cleaned up for: ", entity.name if entity else "unknown")