extends Node

class_name player_inventory

signal inventory_added(item_id, count)
signal inventory_removed(item_id, count)

var items := {}
var gold := 100

# Equipment slots
var equipped := {
	"weapon": "",
	"armor": "",
	"helm": "",
	"shield": "",
	"accessory": "",
}

func add_item(item_id, count=1):
	items[item_id] = items.get(item_id, 0) + count
	inventory_added.emit(item_id, count)

func remove_item(item_id, count=1) -> bool:
	if not has_item(item_id, count):
		return false
	items[item_id] -= count
	if items[item_id] <= 0:
		items.erase(item_id)
	inventory_removed.emit(item_id, count)
	return true

func has_item(item_id, count=1) -> bool:
	return items.get(item_id, 0) >= count

func list_items():
	return items.duplicate()

func equip(slot: String, item_id: String) -> String:
	var prev = equipped.get(slot, "")
	if prev != "":
		add_item(prev)
	equipped[slot] = item_id
	remove_item(item_id)
	return prev

func unequip(slot: String):
	var item_id = equipped.get(slot, "")
	if item_id != "":
		add_item(item_id)
		equipped[slot] = ""
