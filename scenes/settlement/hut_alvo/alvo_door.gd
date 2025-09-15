extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.inventory.inventory_added.connect(unlock_door)
	set_meta("collide", true)

func unlock_door(item, _count):
	if item == 'Key-Alvo':
		Global.inventory.remove_item(item, 1)
		queue_free()
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
