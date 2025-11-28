extends Node
class_name EconomySystem

var gold: int = 0

func add_gold(amount: int):
    gold += max(0, amount)

func spend_gold(amount: int) -> bool:
    if amount <= gold:
        gold -= amount
        return true
    return false
