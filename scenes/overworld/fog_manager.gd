# fog_manager.gd - Delegates to the FogOfWar singleton on Camera2D
extends Node2D
class_name FogManager

@export var tilemap_path: NodePath
@export var sight_range: int = 6

func _ready():
	# FogOfWar is managed as a singleton — see scenes/fog_of_war.gd
	if FogOfWar.instance:
		FogOfWar.instance.call_deferred("refresh_for_new_scene")
