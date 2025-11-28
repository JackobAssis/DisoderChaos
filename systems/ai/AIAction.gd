extends RefCounted
class_name AIAction

var name: String
var action: Callable
var continuous: bool = false

func _init(n: String="action", a: Callable=null, cont: bool=false):
    name = n
    action = a
    continuous = cont

func execute(delta: float):
    if not action or not action.is_valid():
        return false
    if continuous:
        return action.call(delta)
    return action.call()

func reset():
    pass
