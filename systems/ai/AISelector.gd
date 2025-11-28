extends RefCounted
class_name AISelector

var name: String
var children: Array = []
var current_child_index: int = 0

func _init(n: String="selector"):
    name = n

func add_child(c):
    children.append(c)

func execute(delta: float):
    while current_child_index < children.size():
        var result = children[current_child_index].execute(delta)
        if result == true:
            reset()
            return true
        elif result == null: # running
            return null
        else:
            current_child_index += 1
    reset()
    return false

func reset():
    current_child_index = 0
    for c in children:
        if c.has_method("reset"):
            c.reset()
