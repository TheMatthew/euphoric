extends CharacterBody2D

@export var speed := 120
var inventory = null

func _ready():
    inventory = preload("res://scripts/Inventory.gd").new()

func _physics_process(delta):
    var dir = Vector2.ZERO
    if Input.is_action_pressed("ui_right"): dir.x += 1
    if Input.is_action_pressed("ui_left"): dir.x -= 1
    if Input.is_action_pressed("ui_down"): dir.y += 1
    if Input.is_action_pressed("ui_up"): dir.y -= 1
    if dir != Vector2.ZERO:
        dir = dir.normalized()
        velocity = dir * speed
        move_and_slide()
    else:
        velocity = Vector2.ZERO
