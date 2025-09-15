extends Node2D
class_name npc_node

var npc_info:Dictionary={}
var sprite_2d:LocalAnimatedSprite = null
var shape: RectangleShape2D = null
var collision:CollisionShape2D = null

func _init(npc_dict):
	npc_info = npc_dict
	sprite_2d = LocalAnimatedSprite.new()
	collision = CollisionShape2D.new()

	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite_2d.centered = true
	collision.shape = RectangleShape2D.new()
	collision.shape.extents = Vector2(16, 16) # matches 32x32 sprite
	set_meta("collide", true)
	set_meta("dialog", true)
	var sprite = npc_info.get("SPRITE", "")
	if "mage" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/mage.png")
	elif "singing" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/singing_bard.png")
	elif "bard" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/bard.png")
	elif "fighter" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/fighter.png")
	elif "druid" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/druid.png")
	elif "tinker" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/tinker.png")
	elif "paladin" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/paladin.png")
	elif "ranger" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/ranger.png")
	elif "shepherd" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/shepherd.png")
	elif "guard" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/guard.png")
	elif "citizen" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/merchant.png")
	elif "merchant" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/merchant.png")
	elif "jester" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/jester.png")
	elif "beggar" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/beggar.png")
	elif "rogue" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/rogue.png")
	elif "child" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/child.png")
	elif "lord" in sprite:
		sprite_2d.cell_image = load("res://res/sprites/lord.png")
	else:
		sprite_2d.cell_image = load("res://res/sprites/citizen.png")
	
	add_child(sprite_2d)
	add_child(collision)
