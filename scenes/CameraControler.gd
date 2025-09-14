# CameraController.gd
# Attach this script to the Camera2D node
extends Camera2D

@export var follow_target: Node2D  # The hero to follow
@export var border_margin: float = 5.0  # Distance in tiles from border before camera follows
@export var follow_speed: float = 2.0  # How fast the camera catches up

var grid_size: float = 32.0  # Same as your hero's grid size
var screen_size: Vector2
var margin_pixels: float

func _ready():
	# Calculate screen size in world units
	screen_size = get_viewport().get_visible_rect().size / zoom
	margin_pixels = border_margin * grid_size
	
	# If no target is set, try to find the hero
	if not follow_target:
		follow_target = get_parent().get_node("Hero")  # Find Hero node as sibling

func _process(delta):
	if not follow_target:
		return
	
	var target_pos = follow_target.global_position
	var camera_pos = global_position
	
	# Calculate the bounds of the current camera view
	var half_screen = screen_size * 0.5
	var left_bound = camera_pos.x - half_screen.x + margin_pixels
	var right_bound = camera_pos.x + half_screen.x - margin_pixels
	var top_bound = camera_pos.y - half_screen.y + margin_pixels
	var bottom_bound = camera_pos.y + half_screen.y - margin_pixels
	
	# Check if hero is near any border
	var new_camera_pos = camera_pos
	var should_follow = false
	
	# Check horizontal bounds
	if target_pos.x < left_bound:
		new_camera_pos.x = target_pos.x + half_screen.x - margin_pixels
		should_follow = true
	elif target_pos.x > right_bound:
		new_camera_pos.x = target_pos.x - half_screen.x + margin_pixels
		should_follow = true
	
	# Check vertical bounds
	if target_pos.y < top_bound:
		new_camera_pos.y = target_pos.y + half_screen.y - margin_pixels
		should_follow = true
	elif target_pos.y > bottom_bound:
		new_camera_pos.y = target_pos.y - half_screen.y + margin_pixels
		should_follow = true
	
	# Smoothly move camera to new position if needed
	if should_follow:
		global_position = global_position.lerp(new_camera_pos, follow_speed * delta)
