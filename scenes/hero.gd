extends CharacterBody2D

const inputs = {
	"move_right": Vector2.RIGHT,
	"move_left": Vector2.LEFT,
	"move_down": Vector2.DOWN,
	"move_up": Vector2.UP
}

const tile_sounds_inner = {
	"fast": preload("res://res/The Essential Retro Video Game Sound Effects Collection [512 sounds] By Juhani Junkala/Movement/Footsteps/sfx_movement_footstepsloop4_fast.wav"),
	"slow": preload("res://res/The Essential Retro Video Game Sound Effects Collection [512 sounds] By Juhani Junkala/Movement/Footsteps/sfx_movement_footstepsloop4_slow.wav")
}
const tile_sounds = {
	"3": tile_sounds_inner['fast'],
	"4": tile_sounds_inner['fast'],
	"5": tile_sounds_inner['fast'],
	"6": tile_sounds_inner['slow'],
	"7": tile_sounds_inner['slow'],
}

# Stores the grid size, which is 16 (same as one tile)
var grid_size = 32
var is_moving = false
var move_timer = null

# Reference to the RayCast2D node
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var sound_player = get_parent().get_node("SoundPlayer")
var tilemap:TileMapLayer

func _ready():
	tilemap = get_parent().get_node("TileMapLayer")

	# Convert hero's global position to TileMap-local coordinates
	var hero_local = tilemap.to_local(global_position)

	# Convert to cell
	var cell = tilemap.local_to_map(hero_local)

	# Get tile id
	var tile_id = tilemap.get_cell_source_id(cell)
	
	move_timer = Timer.new()
	move_timer.wait_time = 0.25  # Time between each step
	move_timer.connect("timeout", _on_move_timer_timeout)
	add_child(move_timer)

# Calls the move function with the appropriate input key
# if any input map action is triggered
func _unhandled_input(event):
	for action in inputs.keys():
		if event.is_action_pressed(action) and not is_moving:
			is_moving = true
			move(action)
			move_timer.start()  # Start the timer after the first press

# Called when the move timer times out
func _on_move_timer_timeout():
	for action in inputs.keys():
		if Input.is_action_pressed(action):
			move(action)
			

# Optional: Stop moving when the key is released
func _input(event):
	if event.is_action_released("move_right") or event.is_action_released("move_left") or event.is_action_released("move_up") or event.is_action_released("move_down"):
		is_moving = false
		move_timer.stop()  # Stop
# Updates the direction of the RayCast2D according to the input key
# and moves one grid if no collision is detected
func move(action):
	var destination = inputs[action] * grid_size
	ray_cast_2d.target_position = destination
	ray_cast_2d.force_raycast_update()
	
	var new_pos = global_position + destination
	if not ray_cast_2d.is_colliding():
		if  can_move_to(new_pos):
			
			global_position = new_pos
	play_step_sound()

func get_current_tile_type() -> String:
	var tilemap = get_parent().get_node("TileMapLayer")

	# target cell from hero position
	var target_cell = tilemap.local_to_map(position)
	# desired neighbor cell
	
	return str(tilemap.get_cell_source_id(target_cell)) # 0 = layer index

# Function to play the step sound based on the current tile type
func play_step_sound():
	var tile_type = get_current_tile_type()

	if tile_sounds.has(tile_type):
		sound_player.stream = tile_sounds[tile_type]  # Set the sound stream
		sound_player.play()  # Play the sound

var blocked_tiles = [
	"0","1","2","8"
]

func can_move_to(world_pos: Vector2) -> bool:
	var tilemap = get_parent().get_node("TileMapLayer")

	# target cell from hero position
	var target_cell = tilemap.local_to_map(tilemap.to_local(world_pos))
	# desired neighbor cell
	
	var tile_id = tilemap.get_cell_source_id(target_cell) # 0 = layer index
	if str(tile_id) in blocked_tiles: # <-- make sure both are strings
		return false
	return true
