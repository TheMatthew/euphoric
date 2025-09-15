extends Node2D

var hero_entity:CharacterBody2D = null
var camera:FollowingCamera2D = null

func _ready() -> void:
	# Check if the hero node already exists in the parent
	if not Global.player_in_scene:
		# Load the hero scene and instantiate it
		var hero_scene = load("res://scenes/hero.tscn")
		var hero_node:Node2D = hero_scene.instantiate()
		hero_entity = hero_node.get_node("hero")
		if not hero_entity:
			push_error("No hero!")
		camera = hero_node.get_node("Camera2D")
		camera.target = hero_entity
		hero_entity.global_position = global_position
		call_deferred_thread_group("_setup_camera")
		call_deferred_thread_group("_setup_hero")
		Global.player_in_scene = true

func _setup_hero()->void:
	hero_entity.owner=null
	hero_entity.reparent(get_parent())
	# Set the position of the hero
	hero_entity.global_position = global_position
	
func _setup_camera()->void:
	camera.owner= null
	camera.reparent(get_parent())
	camera.make_current()
	camera.move_update()
	print ("Camera pos ", camera.global_position)
	
	
	
