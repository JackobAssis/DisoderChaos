extends Control
class_name QuickSlot

@export var slot_index: int = 0
var item_id: String = ""
var quantity: int = 0

func set_item(id: String, qty: int):
    item_id = id
    quantity = qty
    queue_redraw()
