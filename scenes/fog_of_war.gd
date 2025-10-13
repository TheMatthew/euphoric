# camera_fog_overlay.gd
# Attach this to a Node2D under Camera2D
extends Node2D
class_name FogOfWar

const TILE_SIZE = 32
const SIGHT_RANGE = 6

# Tiles that block line of sight
const BLOCKING_TILES = {
	6: true,   # Forest
	8: true,   # Mountain
	73: true,  # Secret passage
	127: true  # Brick wall
}

var fog_grid: Dictionary = {}  # Grid of fog tiles
var tilemap: TileMapLayer = null
var hero: CharacterBody2D = null
var last_hero_grid_pos: Vector2i = Vector2i(-999, -999)
var revealed_tiles: Dictionary = {}  # Persistent revealed tiles across scenes

# Visual fog tile
var fog_sprite: Texture2D

# Singleton reference for persistence
static var instance: Node2D = null

func _ready():
	# Make this a persistent singleton
	if instance == null:
		instance = self
		# Don't free when changing scenes
		process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		# If another instance exists, destroy this one
		queue_free()
		return
	
	# Create fog texture
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.95))  # Almost black
	fog_sprite = ImageTexture.create_from_image(img)
	
	# Set z_index below UI but above world
	z_index = 50  # Below dialog (which should be z_index 100+)
	
	# Find references
	await get_tree().process_frame
	find_references()
	
	# Initial fog generation
	if hero and tilemap:
		generate_initial_fog()

func find_references():
	"""Find hero and tilemap in scene"""
	# Get hero from scene
	hero = get_tree().current_scene.get_node_or_null("hero")
	if not hero:
		# Try alternate paths
		hero = get_tree().current_scene.get_node_or_null("Hero/hero")
	
	# Get tilemap
	tilemap = get_tree().current_scene.get_node_or_null("TileMapLayer")
	
	if hero:
		print("Fog: Found hero at ", hero.position)
	else:
		print("Fog: ERROR - Could not find hero")
	
	if tilemap:
		print("Fog: Found tilemap at ", tilemap.position)
	else:
		print("Fog: ERROR - Could not find tilemap")

func _process(_delta):
	if not hero or not tilemap:
		return
	
	# Get hero's grid position
	var hero_world_pos = hero.global_position
	var hero_grid_pos = tilemap.local_to_map(tilemap.to_local(hero_world_pos))
	
	# Only update if hero moved to new tile
	if hero_grid_pos != last_hero_grid_pos:
		last_hero_grid_pos = hero_grid_pos
		update_fog_of_war(hero_grid_pos)

func generate_initial_fog():
	"""Create fog covering entire visible area"""
	print("Fog: Generating initial fog")
	
	# Clear existing fog sprites
	for fog_tile in fog_grid.values():
		if is_instance_valid(fog_tile):
			fog_tile.queue_free()
	fog_grid.clear()
	
	# Get map bounds from tilemap
	var cells = tilemap.get_used_cells()
	if cells.size() == 0:
		print("Fog: No cells found")
		return
	
	# Find bounds
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	
	for cell in cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	
	print("Fog: Map bounds: ", min_x, ",", min_y, " to ", max_x, ",", max_y)
	
	# Create fog sprites for entire map, but skip already revealed tiles
	for y in range(int(min_y), int(max_y) + 1):
		for x in range(int(min_x), int(max_x) + 1):
			var grid_pos = Vector2i(x, y)
			# Skip if already revealed in previous scenes
			if not revealed_tiles.has(grid_pos):
				create_fog_tile(grid_pos)
	
	print("Fog: Created ", fog_grid.size(), " fog tiles")

func create_fog_tile(grid_pos: Vector2i):
	"""Create a single fog tile sprite in world space"""
	var sprite = Sprite2D.new()
	sprite.texture = fog_sprite
	sprite.centered = false
	sprite.z_index = 50  # Below UI
	
	# Convert grid position to world position using tilemap's coordinate system
	var world_pos = tilemap.map_to_local(grid_pos)
	# Adjust for tile being centered - we want top-left corner
	world_pos.x -= TILE_SIZE / 2.0
	world_pos.y -= TILE_SIZE / 2.0
	# Convert to global position in world space
	sprite.global_position = tilemap.to_global(world_pos)
	
	# Add to scene root, not to camera, so it stays in world space
	get_tree().current_scene.add_child(sprite)
	fog_grid[grid_pos] = sprite

func update_fog_of_war(hero_grid_pos: Vector2i):
	"""Update fog visibility based on hero position using raycasting"""
	
	# Cast rays in all directions
	var angles = range(0, 360, 3)  # Every 3 degrees
	
	for angle_deg in angles:
		var angle_rad = deg_to_rad(angle_deg)
		var ray_dir = Vector2(cos(angle_rad), sin(angle_rad))
		cast_ray(hero_grid_pos, ray_dir, SIGHT_RANGE)
	
	# Always reveal hero's tile
	reveal_tile(hero_grid_pos)

func cast_ray(start: Vector2i, direction: Vector2, max_distance: int):
	"""Cast a ray and reveal tiles until hitting a blocker"""
	var distance = 0.0
	var step_size = 0.3
	
	while distance < max_distance:
		distance += step_size
		
		var current_pos = Vector2(start.x, start.y) + direction * distance
		var grid_pos = Vector2i(int(round(current_pos.x)), int(round(current_pos.y)))
		
		# Reveal this tile
		reveal_tile(grid_pos)
		
		# Check if tile blocks vision
		if tilemap:
			var tile_id = tilemap.get_cell_source_id(grid_pos)
			if BLOCKING_TILES.has(tile_id):
				break  # Stop ray

func reveal_tile(grid_pos: Vector2i):
	"""Remove fog from a tile and mark as permanently revealed"""
	# Mark as revealed for persistence
	revealed_tiles[grid_pos] = true
	
	# Remove fog sprite
	if fog_grid.has(grid_pos):
		var fog_tile = fog_grid[grid_pos]
		if is_instance_valid(fog_tile):
			fog_tile.queue_free()
		fog_grid.erase(grid_pos)

func _notification(what):
	"""Handle scene changes"""
	if what == NOTIFICATION_PREDELETE:
		# Clean up fog sprites before deletion
		for fog_tile in fog_grid.values():
			if is_instance_valid(fog_tile):
				fog_tile.queue_free()
		fog_grid.clear()

# Call this when entering a new scene
func refresh_for_new_scene():
	"""Refresh fog system for new scene"""
	await get_tree().process_frame
	find_references()
	if hero and tilemap:
		generate_initial_fog()
		# Update fog for current position
		var hero_world_pos = hero.global_position
		var hero_grid_pos = tilemap.local_to_map(tilemap.to_local(hero_world_pos))
		update_fog_of_war(hero_grid_pos)
