extends Node

func _ready() -> void:
	DialogManager.spawn_village_npcs("Eldoria", self)
