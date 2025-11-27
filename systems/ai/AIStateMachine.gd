extends Node
class_name AIStateMachine
# AIStateMachine.gd - Finite State Machine for AI behavior
# Manages state transitions and state-specific behavior

# State management
var states: Dictionary = {}
var current_state: AIState = null
var previous_state: AIState = null
var global_transitions: Dictionary = {}

# Execution
var is_active: bool = true
var state_timer: float = 0.0

signal state_changed(from_state: AIState, to_state: AIState)
signal state_entered(state: AIState)
signal state_exited(state: AIState)

func _ready():
	print("[AIStateMachine] State machine initialized")

func add_state(state: AIState):
# Add a state to the state machine
	states[state.state_name] = state
	state.set_state_machine(self)
	print("[AIStateMachine] Added state: ", state.state_name)

func set_initial_state(state_name: String):
# Set the initial state
	if state_name in states:
		current_state = states[state_name]
		current_state.enter()
		state_entered.emit(current_state)
		print("[AIStateMachine] Initial state set: ", state_name)

func add_transition(from_state: String, to_state: String, condition: Callable):
# Add a state transition
	if not from_state in states:
		push_error("From state '" + from_state + "' not found")
		return
	
	if not to_state in states:
		push_error("To state '" + to_state + "' not found")
		return
	
	states[from_state].add_transition(to_state, condition)
	print("[AIStateMachine] Added transition: ", from_state, " -> ", to_state)

func add_global_transition(to_state: String, condition: Callable):
# Add a global transition that can trigger from any state
	global_transitions[to_state] = condition
	print("[AIStateMachine] Added global transition to: ", to_state)

func update(delta: float):
# Update the state machine
	if not is_active or not current_state:
		return
	
	state_timer += delta
	
	# Check global transitions first
	for state_name in global_transitions:
		var condition = global_transitions[state_name]
		if condition.is_valid() and condition.call():
			transition_to(state_name)
			return
	
	# Check current state transitions
	var next_state = current_state.check_transitions()
	if next_state:
		transition_to(next_state)
		return
	
	# Update current state
	current_state.update(delta)

func transition_to(state_name: String):
# Transition to a specific state
	if not state_name in states:
		push_error("State '" + state_name + "' not found")
		return
	
	if current_state and current_state.state_name == state_name:
		return  # Already in this state
	
	# Exit current state
	if current_state:
		current_state.exit()
		state_exited.emit(current_state)
		previous_state = current_state
	
	# Enter new state
	current_state = states[state_name]
	current_state.enter()
	state_timer = 0.0
	
	state_entered.emit(current_state)
	state_changed.emit(previous_state, current_state)
	
	print("[AIStateMachine] Transitioned to state: ", state_name)

func force_state(state_name: String):
# Force transition to state without checking conditions
	transition_to(state_name)

func get_current_state_name() -> String:
# Get current state name
	return current_state.state_name if current_state else ""

func get_state_time() -> float:
# Get time spent in current state
	return state_timer

func pause():
# Pause the state machine
	is_active = false

func resume():
# Resume the state machine
	is_active = true

# Base AIState class
class_name AIState
extends RefCounted

var state_name: String = ""
var state_machine: AIStateMachine = null
var transitions: Dictionary = {}
var entry_time: float = 0.0

func _init(name: String):
	state_name = name

func set_state_machine(sm: AIStateMachine):
# Set reference to the state machine
	state_machine = sm

func add_transition(to_state: String, condition: Callable):
# Add a transition from this state
	transitions[to_state] = condition

func check_transitions() -> String:
# Check if any transitions should trigger
	for state_name in transitions:
		var condition = transitions[state_name]
		if condition.is_valid() and condition.call():
			return state_name
	return ""

func enter():
# Called when entering this state
	entry_time = Time.get_ticks_msec() / 1000.0
	print("[AIState] Entered state: ", state_name)

func update(delta: float):
# Called each frame while in this state
	pass

func exit():
# Called when exiting this state
	print("[AIState] Exited state: ", state_name)

func get_time_in_state() -> float:
# Get time spent in this state
	return (Time.get_ticks_msec() / 1000.0) - entry_time

# Specific AI State implementations

class_name AIIdleState
extends AIState

var idle_behavior: Callable
var max_idle_time: float = 5.0

func _init(name: String = "idle", behavior: Callable = Callable(), max_time: float = 5.0):
	super._init(name)
	idle_behavior = behavior
	max_idle_time = max_time

func update(delta: float):
	# Execute idle behavior if provided
	if idle_behavior.is_valid():
		idle_behavior.call(delta)
	
	# Auto-transition after max idle time
	if get_time_in_state() > max_idle_time:
		# This would trigger a transition to patrol or alert state
		pass

class_name AIPatrolState
extends AIState

var patrol_behavior: Callable
var patrol_points: Array = []
var current_patrol_index: int = 0

func _init(name: String = "patrol", behavior: Callable = Callable(), points: Array = []):
	super._init(name)
	patrol_behavior = behavior
	patrol_points = points

func enter():
	super.enter()
	if patrol_points.is_empty():
		# Generate random patrol points around current position
		generate_random_patrol_points()

func update(delta: float):
	if patrol_behavior.is_valid():
		var reached_point = patrol_behavior.call(delta, get_current_patrol_point())
		if reached_point:
			advance_patrol_point()

func get_current_patrol_point() -> Vector2:
	if patrol_points.is_empty():
		return Vector2.ZERO
	return patrol_points[current_patrol_index]

func advance_patrol_point():
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func generate_random_patrol_points():
	# This would be implemented based on the entity's starting position
	pass

class_name AIAlertState
extends AIState

var search_behavior: Callable
var alert_duration: float = 10.0
var investigation_points: Array = []

func _init(name: String = "alert", behavior: Callable = Callable(), duration: float = 10.0):
	super._init(name)
	search_behavior = behavior
	alert_duration = duration

func update(delta: float):
	if search_behavior.is_valid():
		search_behavior.call(delta)
	
	# Return to patrol after alert duration
	if get_time_in_state() > alert_duration:
		# Transition back to patrol
		pass

func add_investigation_point(point: Vector2):
# Add a point to investigate
	investigation_points.append(point)

class_name AIPursuitState
extends AIState

var pursue_behavior: Callable
var target: Node2D = null
var max_pursuit_time: float = 30.0
var last_known_position: Vector2

func _init(name: String = "pursuit", behavior: Callable = Callable(), max_time: float = 30.0):
	super._init(name)
	pursue_behavior = behavior
	max_pursuit_time = max_time

func set_target(new_target: Node2D):
# Set the target to pursue
	target = new_target
	if target:
		last_known_position = target.global_position

func update(delta: float):
	if target:
		last_known_position = target.global_position
	
	if pursue_behavior.is_valid():
		pursue_behavior.call(delta, target, last_known_position)
	
	# Give up pursuit after max time
	if get_time_in_state() > max_pursuit_time:
		target = null
		# Transition to alert or patrol

class_name AIAttackState
extends AIState

var attack_behavior: Callable
var target: Node2D = null
var attack_cooldown: float = 1.0
var last_attack_time: float = 0.0

func _init(name: String = "attack", behavior: Callable = Callable(), cooldown: float = 1.0):
	super._init(name)
	attack_behavior = behavior
	attack_cooldown = cooldown

func set_target(new_target: Node2D):
# Set the target to attack
	target = new_target

func update(delta: float):
	if not target:
		return
	
	var current_time = get_time_in_state()
	if current_time - last_attack_time >= attack_cooldown:
		if attack_behavior.is_valid():
			var attack_successful = attack_behavior.call(target)
			if attack_successful:
				last_attack_time = current_time

class_name AIFleeState
extends AIState

var flee_behavior: Callable
var flee_speed_multiplier: float = 1.5
var safe_distance: float = 200.0
var threat: Node2D = null

func _init(name: String = "flee", behavior: Callable = Callable(), speed_mult: float = 1.5):
	super._init(name)
	flee_behavior = behavior
	flee_speed_multiplier = speed_mult

func set_threat(threat_source: Node2D):
# Set the threat to flee from
	threat = threat_source

func update(delta: float):
	if flee_behavior.is_valid():
		flee_behavior.call(delta, threat, safe_distance, flee_speed_multiplier)

class_name AIStunnedState
extends AIState

var stun_duration: float = 2.0

func _init(name: String = "stunned", duration: float = 2.0):
	super._init(name)
	stun_duration = duration

func update(delta: float):
	# Do nothing while stunned
	if get_time_in_state() > stun_duration:
		# Transition back to previous state or alert
		pass

class_name AIBossPhaseState
extends AIState

var phase_number: int = 1
var phase_behavior: Callable
var phase_transition_behavior: Callable

func _init(name: String = "boss_phase", phase: int = 1, behavior: Callable = Callable()):
	super._init(name)
	phase_number = phase
	phase_behavior = behavior

func enter():
	super.enter()
	# Execute phase transition effects
	if phase_transition_behavior.is_valid():
		phase_transition_behavior.call(phase_number)

func update(delta: float):
	if phase_behavior.is_valid():
		phase_behavior.call(delta, phase_number)

func set_phase_transition_behavior(behavior: Callable):
# Set behavior to execute when transitioning to this phase
	phase_transition_behavior = behavior

# Utility functions for common state machine setups

static func create_basic_enemy_fsm(entity: Node2D) -> AIStateMachine:
# Create a basic enemy state machine
	var fsm = AIStateMachine.new()
	
	# Create states
	var idle_state = AIIdleState.new("idle")
	var patrol_state = AIPatrolState.new("patrol")
	var alert_state = AIAlertState.new("alert")
	var pursuit_state = AIPursuitState.new("pursuit")
	var attack_state = AIAttackState.new("attack")
	var flee_state = AIFleeState.new("flee")
	var stunned_state = AIStunnedState.new("stunned")
	
	# Add states to FSM
	fsm.add_state(idle_state)
	fsm.add_state(patrol_state)
	fsm.add_state(alert_state)
	fsm.add_state(pursuit_state)
	fsm.add_state(attack_state)
	fsm.add_state(flee_state)
	fsm.add_state(stunned_state)
	
	# Set up transitions (these would use actual condition functions)
	# idle -> patrol (after idle time)
	# patrol -> alert (on suspicious sound)
	# alert -> pursuit (on target spotted)
	# pursuit -> attack (when in range)
	# attack -> flee (when low health)
	# any -> stunned (when stunned effect applied)
	
	fsm.set_initial_state("idle")
	return fsm

static func create_boss_fsm(entity: Node2D, num_phases: int = 3) -> AIStateMachine:
# Create a boss state machine with phases
	var fsm = AIStateMachine.new()
	
	# Create phase states
	for i in range(num_phases):
		var phase_state = AIBossPhaseState.new("phase_" + str(i + 1), i + 1)
		fsm.add_state(phase_state)
	
	# Add utility states
	var stunned_state = AIStunnedState.new("stunned")
	fsm.add_state(stunned_state)
	
	# Set up phase transitions based on health
	# This would be configured based on specific boss behavior
	
	fsm.set_initial_state("phase_1")
	return fsm

static func create_coward_fsm(entity: Node2D) -> AIStateMachine:
# Create a coward enemy state machine (flees more easily)
	var fsm = AIStateMachine.new()
	
	# Create states
	var idle_state = AIIdleState.new("idle")
	var patrol_state = AIPatrolState.new("patrol")
	var alert_state = AIAlertState.new("alert", Callable(), 5.0)  # Shorter alert time
	var flee_state = AIFleeState.new("flee", Callable(), 2.0)  # Faster flee speed
	var attack_state = AIAttackState.new("attack", Callable(), 2.0)  # Longer attack cooldown
	
	fsm.add_state(idle_state)
	fsm.add_state(patrol_state)
	fsm.add_state(alert_state)
	fsm.add_state(flee_state)
	fsm.add_state(attack_state)
	
	# Cowards prioritize fleeing over fighting
	fsm.add_global_transition("flee", func(): return should_coward_flee(entity))
	
	fsm.set_initial_state("idle")
	return fsm

static func should_coward_flee(entity: Node2D) -> bool:
# Check if coward should flee (higher health threshold)
	if not entity or not entity.has_method("get_health_percentage"):
		return false
	return entity.get_health_percentage() < 0.5  # Flee at 50% health

class_name AITargetSelector
extends Node
# AITargetSelector.gd - Intelligent target selection for AI

var entity: Node2D
var senses: AISenses
var current_target: Node2D = null
var target_priorities: Dictionary = {}

# Target selection criteria
var prefer_player: bool = true
var prefer_wounded: bool = false
var prefer_close: bool = true
var aggro_memory: Dictionary = {}

func setup(parent_entity: Node2D, perception_system: AISenses):
# Setup target selector
	entity = parent_entity
	senses = perception_system

func select_best_target() -> Node2D:
# Select the best target from available options
	if not senses:
		return null
	
	var detected_targets = senses.get_detected_targets()
	if detected_targets.is_empty():
		return null
	
	var best_target = null
	var best_score = -1.0
	
	for target in detected_targets:
		var score = calculate_target_score(target)
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target

func calculate_target_score(target: Node2D) -> float:
# Calculate priority score for a potential target
	var score = 0.0
	
	if not target or not entity:
		return score
	
	# Distance factor (closer = higher score if prefer_close)
	var distance = entity.global_position.distance_to(target.global_position)
	var distance_score = 1.0 - (distance / senses.vision_range)
	if prefer_close:
		score += distance_score * 30.0
	else:
		score += (1.0 - distance_score) * 30.0
	
	# Target type priority
	if target.is_in_group("player") and prefer_player:
		score += 50.0
	elif target.is_in_group("enemy"):
		score += 20.0
	
	# Health factor (lower health = higher score if prefer_wounded)
	if target.has_method("get_health_percentage") and prefer_wounded:
		var health_pct = target.get_health_percentage()
		score += (1.0 - health_pct) * 25.0
	
	# Aggro memory (targets that attacked us recently)
	var target_id = target.get_instance_id()
	if target_id in aggro_memory:
		score += 40.0
	
	# Line of sight bonus
	if senses.has_line_of_sight_to(target):
		score += 15.0
	
	return score

func add_aggro(target: Node2D, amount: float = 1.0):
# Add aggro for a target
	if not target:
		return
	
	var target_id = target.get_instance_id()
	aggro_memory[target_id] = aggro_memory.get(target_id, 0.0) + amount

func clear_aggro(target: Node2D):
# Clear aggro for a target
	if not target:
		return
	
	var target_id = target.get_instance_id()
	aggro_memory.erase(target_id)
