extends Node2D

var hero:CharacterBody2D = null

func _ready() -> void:
	# Check if the hero node already exists in the parent
	if not get_parent().has_node("hero"):
		# Load the hero scene and instantiate it
		var hero_scene = load("res://scenes/hero.tscn")
		var hero_node:Node2D = hero_scene.instantiate()
		hero = hero_node.get_node("hero")
		call_deferred_thread_group("_setup_hero")

func _setup_hero()->void:
	hero.owner=null
	hero.reparent(get_parent())
	# Set the position of the hero
	hero.global_position = global_position
	
	var camera:Camera2D = hero.get_node("Camera2D")
	# Print the children of the parent to verify
	camera.make_current()
