extends Node

var items := {}
var gold := 100

func add_item(item_id, count=1):
	items[item_id] = items.get(item_id, 0) + count

func remove_item(item_id, count=1) -> bool:
	if not has_item(item_id, count):
		return false
	items[item_id] -= count
	if items[item_id] <= 0:
		items.erase(item_id)
	return true

func has_item(item_id, count=1) -> bool:
	return items.get(item_id, 0) >= count

func list_items():
	return items.duplicate()
