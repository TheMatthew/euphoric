extends CharacterBody2D

const inputs = {
	"move_right": Vector2.RIGHT,
	"move_left": Vector2.LEFT,
	"move_down": Vector2.DOWN,
	"move_up": Vector2.UP
}
# Stores the grid size, which is 16 (same as one tile)
var grid_size = 32

# Reference to the RayCast2D node
@onready var ray_cast_2d: RayCast2D = $RayCast2D


func _ready():
	print("Hero global pos:", global_position)
	print("TileMap global pos:", get_parent().get_node("TileMapLayer").global_position)
	var tilemap = get_parent().get_node("TileMapLayer")

	# Convert hero's global position to TileMap-local coordinates
	var hero_local = tilemap.to_local(global_position)

	# Convert to cell
	var cell = tilemap.local_to_map(hero_local)

	# Get tile id
	var tile_id = tilemap.get_cell_source_id(cell)

	print("Hero is on cell:", cell, "tile id:", tile_id)
# Calls the move function with the appropriate input key
# if any input map action is triggered
func _unhandled_input(event):
	for action in inputs.keys():
		if event.is_action_pressed(action):
			move(action)

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


var blocked_tiles = [
	"0","1","2","8"
]

func can_move_to(world_pos: Vector2) -> bool:
	var tilemap = get_parent().get_node("TileMapLayer")

	# target cell from hero position
	var target_cell = tilemap.local_to_map(tilemap.to_local(world_pos))
	# desired neighbor cell
	
	var tile_id = tilemap.get_cell_source_id(target_cell) # 0 = layer index
	print("Hero global pos:", global_position)
	print("Hero tgt pos:", world_pos)
	if str(tile_id) in blocked_tiles: # <-- make sure both are strings
		return false
	return true
