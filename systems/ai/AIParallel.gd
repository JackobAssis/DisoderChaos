extends RefCounted
class_name AIParallel

var name: String
var children: Array = []

func _init(n: String="parallel"):
    name = n

func add_child(c):
    children.append(c)

func execute(delta: float):
    var any_running: bool = false
    var any_success: bool = false
    for c in children:
        var r = c.execute(delta)
        if r == null:
            any_running = true
        elif r == true:
            any_success = true
    if any_running:
        return null
    return any_success

func reset():
    for c in children:
        if c.has_method("reset"):
            c.reset()
