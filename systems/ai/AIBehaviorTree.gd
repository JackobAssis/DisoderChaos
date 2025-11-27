extends Node
class_name AIBehaviorTree
# AIBehaviorTree.gd - Behavior tree system for AI
# Implements behavior tree nodes and execution logic

# Node execution results
enum BehaviorResult {
	SUCCESS,
	FAILURE,
	RUNNING
}

# Root behavior node
var root_node: AINode = null
var blackboard: Dictionary = {}

# Execution state
var is_running: bool = false
var current_execution_path: Array = []

signal behavior_completed(result: BehaviorResult)
signal behavior_started(node_name: String)

func _ready():
	print("[AIBehaviorTree] Behavior tree system initialized")

func set_root(node: AINode):
# Set the root node of the behavior tree
	root_node = node
	if root_node:
		root_node.set_blackboard(blackboard)
	print("[AIBehaviorTree] Root node set: ", root_node.get_name() if root_node else "None")

func update(delta: float) -> BehaviorResult:
# Update the behavior tree
	if not root_node:
		return BehaviorResult.FAILURE
	
	is_running = true
	var result = root_node.execute(delta)
	
	if result != BehaviorResult.RUNNING:
		is_running = false
		behavior_completed.emit(result)
	
	return result

func get_blackboard_value(key: String, default_value = null):
# Get value from blackboard
	return blackboard.get(key, default_value)

func set_blackboard_value(key: String, value):
# Set value in blackboard
	blackboard[key] = value

func reset():
# Reset the behavior tree
	if root_node:
		root_node.reset()
	current_execution_path.clear()
	is_running = false

# Base AINode class
class_name AINode
extends RefCounted

var name: String = ""
var parent: AINode = null
var children: Array = []
var blackboard: Dictionary = {}

func _init(node_name: String = ""):
	name = node_name

func set_blackboard(bb: Dictionary):
# Set the blackboard for this node and children
	blackboard = bb
	for child in children:
		child.set_blackboard(bb)

func add_child(child: AINode):
# Add a child node
	child.parent = self
	child.set_blackboard(blackboard)
	children.append(child)

func execute(delta: float) -> BehaviorResult:
# Execute this node - override in subclasses
	return BehaviorResult.FAILURE

func reset():
# Reset this node - override in subclasses
	for child in children:
		child.reset()

func get_name() -> String:
	return name

# Composite nodes
class_name AISelector
extends AINode
# Executes children in order until one succeeds

var current_child_index: int = 0

func execute(delta: float) -> BehaviorResult:
	while current_child_index < children.size():
		var result = children[current_child_index].execute(delta)
		
		if result == BehaviorResult.SUCCESS:
			reset()
			return BehaviorResult.SUCCESS
		elif result == BehaviorResult.RUNNING:
			return BehaviorResult.RUNNING
		else:
			# Child failed, try next one
			current_child_index += 1
	
	# All children failed
	reset()
	return BehaviorResult.FAILURE

func reset():
	current_child_index = 0
	super.reset()

class_name AISequence
extends AINode
# Executes children in order, all must succeed

var current_child_index: int = 0

func execute(delta: float) -> BehaviorResult:
	while current_child_index < children.size():
		var result = children[current_child_index].execute(delta)
		
		if result == BehaviorResult.FAILURE:
			reset()
			return BehaviorResult.FAILURE
		elif result == BehaviorResult.RUNNING:
			return BehaviorResult.RUNNING
		else:
			# Child succeeded, move to next one
			current_child_index += 1
	
	# All children succeeded
	reset()
	return BehaviorResult.SUCCESS

func reset():
	current_child_index = 0
	super.reset()

class_name AIParallel
extends AINode
# Executes all children simultaneously

var child_results: Array = []

func execute(delta: float) -> BehaviorResult:
	if child_results.is_empty():
		child_results.resize(children.size())
		child_results.fill(BehaviorResult.RUNNING)
	
	var running_count = 0
	var success_count = 0
	var failure_count = 0
	
	for i in range(children.size()):
		if child_results[i] == BehaviorResult.RUNNING:
			child_results[i] = children[i].execute(delta)
		
		match child_results[i]:
			BehaviorResult.RUNNING:
				running_count += 1
			BehaviorResult.SUCCESS:
				success_count += 1
			BehaviorResult.FAILURE:
				failure_count += 1
	
	# If any child is still running, parallel is still running
	if running_count > 0:
		return BehaviorResult.RUNNING
	
	# All children completed - determine result based on policy
	# For now, succeed if any child succeeded
	reset()
	return BehaviorResult.SUCCESS if success_count > 0 else BehaviorResult.FAILURE

func reset():
	child_results.clear()
	super.reset()

# Decorator nodes
class_name AIInverter
extends AINode
# Inverts the result of its child

func execute(delta: float) -> BehaviorResult:
	if children.is_empty():
		return BehaviorResult.FAILURE
	
	var result = children[0].execute(delta)
	
	match result:
		BehaviorResult.SUCCESS:
			return BehaviorResult.FAILURE
		BehaviorResult.FAILURE:
			return BehaviorResult.SUCCESS
		BehaviorResult.RUNNING:
			return BehaviorResult.RUNNING

class_name AIRepeater
extends AINode
# Repeats its child a specified number of times

var repetitions: int = 1
var current_repetition: int = 0

func _init(node_name: String = "", reps: int = 1):
	super._init(node_name)
	repetitions = reps

func execute(delta: float) -> BehaviorResult:
	if children.is_empty():
		return BehaviorResult.FAILURE
	
	while current_repetition < repetitions:
		var result = children[0].execute(delta)
		
		if result == BehaviorResult.RUNNING:
			return BehaviorResult.RUNNING
		elif result == BehaviorResult.FAILURE:
			reset()
			return BehaviorResult.FAILURE
		else:
			# Success, increment repetition
			current_repetition += 1
			children[0].reset()
	
	# All repetitions completed successfully
	reset()
	return BehaviorResult.SUCCESS

func reset():
	current_repetition = 0
	super.reset()

class_name AITimer
extends AINode
# Runs child for a specified duration

var duration: float = 1.0
var elapsed_time: float = 0.0

func _init(node_name: String = "", time: float = 1.0):
	super._init(node_name)
	duration = time

func execute(delta: float) -> BehaviorResult:
	if children.is_empty():
		return BehaviorResult.FAILURE
	
	elapsed_time += delta
	
	if elapsed_time >= duration:
		reset()
		return BehaviorResult.SUCCESS
	
	# Continue executing child
	var result = children[0].execute(delta)
	
	if result == BehaviorResult.FAILURE:
		reset()
		return BehaviorResult.FAILURE
	
	return BehaviorResult.RUNNING

func reset():
	elapsed_time = 0.0
	super.reset()

# Leaf nodes
class_name AICondition
extends AINode
# Checks a condition

var condition_func: Callable

func _init(node_name: String = "", condition: Callable = Callable()):
	super._init(node_name)
	condition_func = condition

func execute(delta: float) -> BehaviorResult:
	if condition_func.is_valid() and condition_func.call():
		return BehaviorResult.SUCCESS
	else:
		return BehaviorResult.FAILURE

class_name AIAction
extends AINode
# Executes an action

var action_func: Callable
var is_continuous: bool = false
var action_state: String = "idle"

func _init(node_name: String = "", action: Callable = Callable(), continuous: bool = false):
	super._init(node_name)
	action_func = action
	is_continuous = continuous

func execute(delta: float) -> BehaviorResult:
	if not action_func.is_valid():
		return BehaviorResult.FAILURE
	
	if is_continuous:
		# Continuous action - call every frame
		var result = action_func.call(delta)
		if result is bool:
			return BehaviorResult.SUCCESS if result else BehaviorResult.FAILURE
		else:
			return result
	else:
		# Single execution action
		if action_state == "idle":
			action_state = "executing"
			var result = action_func.call()
			action_state = "completed"
			
			if result is bool:
				return BehaviorResult.SUCCESS if result else BehaviorResult.FAILURE
			else:
				return result
		else:
			return BehaviorResult.SUCCESS

func reset():
	action_state = "idle"
	super.reset()

class_name AIWait
extends AINode
# Waits for a specified duration

var wait_time: float = 1.0
var elapsed_time: float = 0.0

func _init(node_name: String = "", time: float = 1.0):
	super._init(node_name)
	wait_time = time

func execute(delta: float) -> BehaviorResult:
	elapsed_time += delta
	
	if elapsed_time >= wait_time:
		reset()
		return BehaviorResult.SUCCESS
	
	return BehaviorResult.RUNNING

func reset():
	elapsed_time = 0.0
	super.reset()

# Utility functions for creating common behavior patterns
static func create_patrol_behavior(move_action: Callable, wait_time: float = 2.0) -> AINode:
# Create a simple patrol behavior
	var patrol_sequence = AISequence.new("patrol_sequence")
	patrol_sequence.add_child(AIAction.new("move_to_patrol_point", move_action))
	patrol_sequence.add_child(AIWait.new("wait_at_patrol_point", wait_time))
	
	var patrol_repeater = AIRepeater.new("patrol_repeater", -1)  # Infinite repetition
	patrol_repeater.add_child(patrol_sequence)
	
	return patrol_repeater

static func create_combat_behavior(has_target: Callable, in_range: Callable, attack: Callable, move: Callable) -> AINode:
# Create a combat behavior tree
	var combat_selector = AISelector.new("combat_selector")
	
	# Attack sequence
	var attack_sequence = AISequence.new("attack_sequence")
	attack_sequence.add_child(AICondition.new("has_target", has_target))
	attack_sequence.add_child(AICondition.new("in_attack_range", in_range))
	attack_sequence.add_child(AIAction.new("attack_target", attack))
	
	# Move to target sequence
	var move_sequence = AISequence.new("move_sequence")
	move_sequence.add_child(AICondition.new("has_target", has_target))
	move_sequence.add_child(AIAction.new("move_to_target", move, true))
	
	combat_selector.add_child(attack_sequence)
	combat_selector.add_child(move_sequence)
	
	return combat_selector

static func create_flee_behavior(should_flee: Callable, flee_action: Callable) -> AINode:
# Create a flee behavior
	var flee_sequence = AISequence.new("flee_sequence")
	flee_sequence.add_child(AICondition.new("should_flee", should_flee))
	flee_sequence.add_child(AIAction.new("flee", flee_action, true))
	
	return flee_sequence

static func create_boss_behavior(phase_check: Callable, phase_actions: Array) -> AINode:
# Create a boss behavior tree with phase management
	var boss_selector = AISelector.new("boss_selector")
	
	for i in range(phase_actions.size()):
		var phase_sequence = AISequence.new("phase_" + str(i + 1))
		phase_sequence.add_child(AICondition.new("check_phase_" + str(i + 1), 
			func(): return phase_check.call() == i + 1))
		phase_sequence.add_child(phase_actions[i])
		boss_selector.add_child(phase_sequence)
	
	return boss_selector
