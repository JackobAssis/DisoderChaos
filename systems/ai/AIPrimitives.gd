extends Node
## Minimal stub AI primitive classes to satisfy parser

class_name AIPrimitivesRoot

class AISelector extends RefCounted:
	var name: String
	var children: Array = []
	func _init(n: String="selector"):
		name = n
	func add_child(c):
		children.append(c)

class AISequence extends RefCounted:
	var name: String
	var children: Array = []
	func _init(n: String="sequence"):
		name = n
	func add_child(c):
		children.append(c)

class AICondition extends RefCounted:
	var name: String
	var predicate: Callable
	func _init(n: String="condition", p: Callable=null):
		name = n
		predicate = p

class AIAction extends RefCounted:
	var name: String
	var action: Callable
	var continuous: bool = false
	func _init(n: String="action", a: Callable=null, cont: bool=false):
		name = n
		action = a
		continuous = cont

class AIStateMachine extends RefCounted:
	var states: Dictionary = {}
	static func create_basic_enemy_fsm(entity):
		var fsm = AIStateMachine.new()
		fsm.states = {"idle": {}, "pursuit": {"max_pursuit_time": 30.0}}
		return fsm
