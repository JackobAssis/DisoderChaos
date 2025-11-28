extends RefCounted
class_name AICondition

var name: String
var predicate: Callable

func _init(n: String="condition", p: Callable=null):
    name = n
    predicate = p

func execute(delta: float):
    if predicate and predicate.is_valid():
        return predicate.call()
    return false

func reset():
    pass
