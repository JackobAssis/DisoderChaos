extends Node
class_name InventorySystem

var items: Dictionary = {}

func add_item(id: String, qty: int = 1):
    items[id] = items.get(id, 0) + qty

func remove_item(id: String, qty: int = 1):
    if not items.has(id):
        return false
    items[id] -= qty
    if items[id] <= 0:
        items.erase(id)
    return true
