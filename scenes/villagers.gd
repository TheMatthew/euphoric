extends Node

@export var spawn_name:String

func _ready() -> void:
	DialogManager.spawn_village_npcs(spawn_name, self)
