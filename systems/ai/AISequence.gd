extends RefCounted
class_name AISequence

var name: String
var children: Array = []
var current_child_index: int = 0

func _init(n: String="sequence"):
    name = n

func add_child(c):
    children.append(c)

func execute(delta: float):
    while current_child_index < children.size():
        var result = children[current_child_index].execute(delta)
        if result == false:
            reset()
            return false
        elif result == null:
            return null
        else:
            current_child_index += 1
    reset()
    return true

func reset():
    current_child_index = 0
    for c in children:
        if c.has_method("reset"):
            c.reset()
