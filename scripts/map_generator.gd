@tool
extends EditorScript

const MAP_WIDTH = 256
const MAP_HEIGHT = 256
# Fixed: Set actual values for island generation
const N_ISLANDS = 8  # Number of islands
const N_MOUNTAIN_CENTROIDS = 12  # Total mountain centroids (distributed across islands)
const N_SWAMP_CENTROIDS = 5  # M swampy areas per island
const N_FOREST_CENTROIDS = 7  # O forests per island

# Island generation parameters
const MIN_ISLAND_DISTANCE = 25  # Minimum distance between island centers
const ISLAND_RADIUS_MIN = 15
const ISLAND_RADIUS_MAX = 25
const ISLAND_BORDER_MARGIN = 20  # Keep islands away from map borders
const MIN_CENTROID_DISTANCE = 8  # Minimum distance between centroids in same island
const MAX_CENTROID_DISTANCE = 18  # Maximum distance between centroids in same island

# Terrain distribution constraints
const MAX_MOUNTAIN_PERCENT = 10.0
const MIN_OCEAN_PERCENT = 30.0  # Increased for island separation
const TARGET_WATER_PERCENT = 40.0  # Ocean + Water + Shallow combined

# Tiles - these must match your TileSet source IDs
enum TileType {
	OCEAN = 0,
	WATER = 1,
	SHALLOW = 2,
	SWAMP = 3,
	GRASS = 4,
	SHRUB = 5,
	FOREST = 6,
	HILL = 7,
	MOUNTAIN = 8
}

var tileset_resource: TileSet
var islands: Array = []  # Array of island data structures
var mountain_centroids: Array = []  # Global mountain centroids

# Island structure: 
# {
#   "centroids": [Vector2i, ...],  # 1-2 centroids per island
#   "center": Vector2i,            # Average center for distance calculations
#   "radius": float,               # Base radius
#   "mountain_centroids": [Vector2i, ...] # Mountains for this island
# }

func _run():
	print("=== Godot Island Map Generator (Editor Script) ===")
	
	# Load the tileset resource
	tileset_resource = load("res://res/euphoric.tres") as TileSet
	if not tileset_resource:
		print("ERROR: Could not load tileset resource at res://res/euphoric.tres")
		print("Make sure the file exists and is a valid TileSet resource.")
		return
	
	print("Loaded tileset: ", tileset_resource.resource_path)
	print("Tileset has ", tileset_resource.get_source_count(), " sources")
	
	# Validate tileset sources
	validate_tileset()
	
	print("Starting island map generation...")
	print("  Islands: %d" % N_ISLANDS)
	print("  Mountains: %d" % N_MOUNTAIN_CENTROIDS)
	print("  Swamps per island: %d" % N_SWAMP_CENTROIDS)
	print("  Forests per island: %d" % N_FOREST_CENTROIDS)
	
	generate_and_save_map()
	generate_test_maps()
	print("=== Map generation complete! ===")
	print("Generated files:")
	print("  - res://map.tscn (full map with camera)")
	print("  - res://minimal_test.tscn (single tile test)")
	print("  - res://simple_test.tscn (5x5 pattern test)")

func validate_tileset():
	print("Validating tileset sources...")
	var missing_sources = []
	
	for tile_id in range(9):  # 0-8
		var source = tileset_resource.get_source(tile_id)
		if source:
			print("  Source %d: OK (%s)" % [tile_id, source.get_class()])
		else:
			missing_sources.append(tile_id)
			print("  Source %d: MISSING!" % tile_id)
	
	if missing_sources.size() > 0:
		print("WARNING: Missing tileset sources: ", missing_sources)
		print("Your map may not display correctly.")
	else:
		print("All tileset sources validated successfully!")

func generate_islands() -> Array:
	"""Generate islands with varied shapes (1-2 centroids each)"""
	var islands_data = []
	var attempts = 0
	var max_attempts = 100
	
	while islands_data.size() < N_ISLANDS and attempts < max_attempts:
		attempts += 1
		
		# Generate first centroid with border margin
		var x1 = randi_range(ISLAND_BORDER_MARGIN, MAP_WIDTH - ISLAND_BORDER_MARGIN)
		var y1 = randi_range(ISLAND_BORDER_MARGIN, MAP_HEIGHT - ISLAND_BORDER_MARGIN)
		var centroid1 = Vector2i(x1, y1)
		
		# Decide if this island should have 2 centroids (40% chance)
		var island_centroids = [centroid1]
		var island_center = centroid1
		var max_hops = 4
		while randf() < 0.6 and max_hops > 0:  # 40% chance for elongated island
			# Generate second centroid
			max_hops -= 1
			var angle = randf() * 2.0 * PI
			var distance = randf_range(MIN_CENTROID_DISTANCE, MAX_CENTROID_DISTANCE)
			var x2 = int(x1 + cos(angle) * distance)
			var y2 = int(y1 + sin(angle) * distance)
			
			# Ensure second centroid is within bounds
			x2 = clamp(x2, ISLAND_BORDER_MARGIN, MAP_WIDTH - ISLAND_BORDER_MARGIN)
			y2 = clamp(y2, ISLAND_BORDER_MARGIN, MAP_HEIGHT - ISLAND_BORDER_MARGIN)
			
			var centroid2 = Vector2i(x2, y2)
			island_centroids.append(centroid2)
			# Island center is average of centroids
			island_center = Vector2i((x1 + x2) / 2, (y1 + y2) / 2)
		
		# Check distance from existing island centers
		var valid = true
		for existing_island in islands_data:
			var distance = island_center.distance_to(existing_island.center)
			if distance < MIN_ISLAND_DISTANCE:
				valid = false
				break
		
		if valid:
			var island_data = {
				"centroids": island_centroids,
				"center": island_center,
				"radius": randf_range(ISLAND_RADIUS_MIN, ISLAND_RADIUS_MAX),
				"mountain_centroids": []
			}
			islands_data.append(island_data)
			print("  Island %d: %d centroid(s) at center (%d, %d)" % [
				islands_data.size(), 
				island_centroids.size(), 
				island_center.x, 
				island_center.y
			])
	
	if islands_data.size() < N_ISLANDS:
		print("Warning: Only generated %d islands out of %d requested" % [islands_data.size(), N_ISLANDS])
	
	return islands_data

func distribute_mountains_to_islands(islands_data: Array) -> Array:
	"""Distribute mountain centroids across islands"""
	if islands_data.size() == 0:
		return islands_data
	
	# Distribute mountains across islands
	for i in range(N_MOUNTAIN_CENTROIDS):
		var island_idx = i % islands_data.size()  # Round-robin distribution
		var island = islands_data[island_idx]
		
		# Place mountain centroid within island
		var attempts = 0
		var max_attempts = 20
		var placed = false
		
		while attempts < max_attempts and not placed:
			attempts += 1
			
			# Choose a random centroid from this island as base
			var base_centroid = island.centroids[randi() % island.centroids.size()]
			
			# Place mountain near the island centroid
			var angle = randf() * 2.0 * PI
			var distance = randf_range(2, island.radius * 0.6)
			var x = int(base_centroid.x + cos(angle) * distance)
			var y = int(base_centroid.y + sin(angle) * distance)
			
			# Ensure within bounds
			if x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT:
				var mountain_pos = Vector2i(x, y)
				island.mountain_centroids.append(mountain_pos)
				mountain_centroids.append(mountain_pos)
				placed = true
				print("    Mountain centroid %d placed on island %d at (%d, %d)" % [
					mountain_centroids.size(), island_idx + 1, x, y
				])
	
	return islands_data

func island_height(x: int, y: int, islands_data: Array) -> float:
	"""Calculate height based on distance to nearest island centroids"""
	var max_height = 0.0
	
	# Check distance to each island
	for island in islands_data:
		var island_height = 0.0
		
		# For multi-centroid islands, use combined influence
		for centroid in island.centroids:
			var distance = Vector2(x, y).distance_to(Vector2(centroid.x, centroid.y))
			var distance_ratio = distance / island.radius
			
			if distance_ratio <= 1.0:
				# Inside island radius - quadratic falloff
				var centroid_height = (1.0 - distance_ratio) * (1.0 - distance_ratio)
				island_height = max(island_height, centroid_height)
		
		# Add mountain influence for this island
		for mountain_centroid in island.mountain_centroids:
			var distance = Vector2(x, y).distance_to(Vector2(mountain_centroid.x, mountain_centroid.y))
			var mountain_influence = max(0.0, (10.0 - distance) / 10.0)  # 10-unit radius influence
			if mountain_influence > 0:
				island_height += mountain_influence * 0.4  # Mountain boost
		
		max_height = max(max_height, island_height)
	
	# Add some noise and ensure ocean areas stay low
	var final_height = max_height + randf_range(-0.05, 0.05)
	
	# Ensure areas far from islands are ocean
	if max_height < 0.1:
		final_height = max_height * 0.5  # Reduce to ensure ocean
	
	return clamp(final_height, 0.0, 1.5)

func place_island_features(islands_data: Array, feature_count_per_island: int, min_height: float = 0.2) -> Array:
	"""Place features (swamps/forests) on islands"""
	var all_features = []
	
	for i in range(islands_data.size()):
		var island = islands_data[i]
		var island_features = []
		var attempts = 0
		var max_attempts = 50
		
		while island_features.size() < feature_count_per_island and attempts < max_attempts:
			attempts += 1
			
			# Choose a random centroid from this island
			var base_centroid = island.centroids[randi() % island.centroids.size()]
			
			# Place feature within island radius
			var angle = randf() * 2.0 * PI
			var distance = randf_range(3, island.radius * 0.8)
			
			var x = int(base_centroid.x + cos(angle) * distance)
			var y = int(base_centroid.y + sin(angle) * distance)
			
			# Check bounds
			if x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT:
				# Check if this position would have sufficient height
				var height = island_height(x, y, islands_data)
				if height >= min_height:
					island_features.append(Vector2i(x, y))
		
		all_features.append_array(island_features)
		print("  Island %d: placed %d features" % [i + 1, island_features.size()])
	
	return all_features

func influence(x: int, y: int, centroids: Array, power: float = 2.0) -> float:
	"""Calculate influence from centroids with stronger falloff"""
	var max_influence = 0.0
	for centroid in centroids:
		var cx = centroid.x
		var cy = centroid.y
		var d = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) + 1.0
		var inf = power / (d * d)  # Quadratic falloff for more localized influence
		max_influence = max(max_influence, inf)
	return max_influence

func choose_tile_from_height(h: float, swamp_inf: float, forest_inf: float, x: int, y: int) -> TileType:
	"""Choose tile type based on height and influences"""
	
	# Base terrain from height (fixed the inversion issue)
	var base_tile: TileType
	if h < 0.02:  # Very low - Ocean
		base_tile = TileType.OCEAN
	elif h < 0.1:  # Low - Water
		base_tile = TileType.WATER  
	elif h < 0.6:  # Low land - Grass
		base_tile = TileType.GRASS
	elif h < 0.8:  # Medium - Shrub
		base_tile = TileType.SHRUB
	elif h < 0.99:  # High - Hill
		base_tile = TileType.HILL
	else:  # Very high - Mountain
		base_tile = TileType.MOUNTAIN
	
	# Apply biome influences only on land
	if h >= 0.25:  # Only on land areas
		if swamp_inf > 0.15 and h >= 0.25 and h <= 0.4:  # Swamps in low areas
			return TileType.SWAMP
		elif forest_inf > 0.12 and h >= 0.3 and h <= 0.7:  # Forests on medium elevations
			if randf() < 0.8:
				return TileType.FOREST
			else:
				return TileType.SHRUB
	
	return base_tile

func generate_map_data() -> Dictionary:
	print("Generating islands...")
	islands = generate_islands()
	
	if islands.size() == 0:
		print("ERROR: No islands generated!")
		return {}
	
	print("Distributing mountains to islands...")
	islands = distribute_mountains_to_islands(islands)
	
	print("Placing terrain features...")
	var swamp_centroids = place_island_features(islands, N_SWAMP_CENTROIDS, 0.25)
	var forest_centroids = place_island_features(islands, N_FOREST_CENTROIDS, 0.3)
	
	print("Generating height map...")
	var tile_data = {}
	
	# Generate tile data
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var h = island_height(x, y, islands)
			var s = influence(x, y, swamp_centroids, 3.0)
			var f = influence(x, y, forest_centroids, 2.5)
			var tile_type = choose_tile_from_height(h, s, f, x, y)
			tile_data[Vector2i(x, y)] = tile_type
	
	# Apply coherence filtering
	tile_data = apply_coherence_pass(tile_data)
	
	# Print distribution
	print_distribution(tile_data)
	
	return tile_data

func apply_coherence_pass(tile_data: Dictionary) -> Dictionary:
	"""Apply coherence pass to reduce noise"""
	var improved_data = tile_data.duplicate()
	
	for y in range(1, MAP_HEIGHT - 1):  # Skip borders
		for x in range(1, MAP_WIDTH - 1):
			var pos = Vector2i(x, y)
			var current_tile = tile_data[pos]
			
			# Count neighbor types
			var neighbor_counts = {}
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var neighbor_pos = Vector2i(x + dx, y + dy)
					if tile_data.has(neighbor_pos):
						var neighbor_tile = tile_data[neighbor_pos]
						neighbor_counts[neighbor_tile] = neighbor_counts.get(neighbor_tile, 0) + 1
			
			# Find most common neighbor
			var max_count = 0
			var most_common_tile = current_tile
			for tile_type in neighbor_counts:
				if neighbor_counts[tile_type] > max_count:
					max_count = neighbor_counts[tile_type]
					most_common_tile = tile_type
			
			# If current tile is very isolated, consider changing it
			var current_neighbors = neighbor_counts.get(current_tile, 0)
			if current_neighbors <= 1 and max_count >= 4:  # Very isolated
				if are_tiles_compatible(current_tile, most_common_tile):
					if randf() < 0.7:  # 70% chance to change
						improved_data[pos] = most_common_tile
	
	return improved_data

func are_tiles_compatible(tile_a: TileType, tile_b: TileType) -> bool:
	"""Check if two tile types can reasonably be neighbors"""
	# Water tiles are compatible with each other
	var water_tiles = [TileType.OCEAN, TileType.WATER, TileType.SHALLOW]
	if tile_a in water_tiles and tile_b in water_tiles:
		return true
	
	# Land tiles are compatible with each other
	var land_tiles = [TileType.GRASS, TileType.SHRUB, TileType.FOREST, TileType.HILL, TileType.MOUNTAIN]
	if tile_a in land_tiles and tile_b in land_tiles:
		return true
	
	# Swamp is compatible with water and some land
	if tile_a == TileType.SWAMP:
		return tile_b in [TileType.WATER, TileType.SHALLOW, TileType.GRASS, TileType.SHRUB]
	if tile_b == TileType.SWAMP:
		return tile_a in [TileType.WATER, TileType.SHALLOW, TileType.GRASS, TileType.SHRUB]
	
	# Shallow water can border land
	if tile_a == TileType.SHALLOW and tile_b in land_tiles:
		return true
	if tile_b == TileType.SHALLOW and tile_a in land_tiles:
		return true
	
	return false

func print_distribution(tile_data: Dictionary):
	"""Print terrain distribution"""
	var counts = {}
	var total = MAP_WIDTH * MAP_HEIGHT
	
	# Initialize counts
	for tile_type in TileType.values():
		counts[tile_type] = 0
	
	# Count tiles
	for pos in tile_data.keys():
		var tile_type = tile_data[pos]
		counts[tile_type] += 1
	
	print("\nTerrain distribution:")
	for tile_type in TileType.values():
		var count = counts[tile_type]
		var percentage = (count * 100.0) / total
		print("  %s: %d (%.1f%%)" % [get_tile_name(tile_type), count, percentage])

func get_tile_name(tile_type: TileType) -> String:
	"""Get human-readable name for tile type"""
	match tile_type:
		TileType.OCEAN: return "Ocean"
		TileType.WATER: return "Water"
		TileType.SHALLOW: return "Shallow"
		TileType.SWAMP: return "Swamp"
		TileType.GRASS: return "Grass"
		TileType.SHRUB: return "Shrub"
		TileType.FOREST: return "Forest"
		TileType.HILL: return "Hill"
		TileType.MOUNTAIN: return "Mountain"
		_: return "Unknown"

func create_tilemap_scene(tile_data: Dictionary, scene_name: String, add_camera: bool = false) -> PackedScene:
	var scene = PackedScene.new()
	var root = Node2D.new()
	root.name = "MapRoot"
	
	# Add camera if requested
	if add_camera:
		var camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.position = Vector2(MAP_WIDTH * 16, MAP_HEIGHT * 16)  # Center of map
		camera.zoom = Vector2(0.3, 0.3)  # Zoom out more to see islands
		root.add_child(camera)
		camera.owner = root
	
	# Create TileMapLayer
	var tilemap_layer = TileMapLayer.new()
	tilemap_layer.name = "TileMapLayer"
	tilemap_layer.tile_set = tileset_resource
	
	# Set tile data
	for pos in tile_data.keys():
		var tile_type = tile_data[pos]
		tilemap_layer.set_cell(pos, tile_type, Vector2i(0, 0), 0)
	
	root.add_child(tilemap_layer)
	tilemap_layer.owner = root
	
	# Pack the scene
	scene.pack(root)
	return scene

func generate_and_save_map():
	print("Generating full island map (%dx%d)..." % [MAP_WIDTH, MAP_HEIGHT])
	var tile_data = generate_map_data()
	if tile_data.size() > 0:
		var scene = create_tilemap_scene(tile_data, "IslandMap", true)
		save_scene_to_file(scene, "res://map.tscn")
	else:
		print("ERROR: Failed to generate map data")

func generate_test_maps():
	# Generate minimal test (single tile)
	print("Generating minimal test...")
	var minimal_data = {Vector2i(0, 0): TileType.GRASS}
	var minimal_scene = create_tilemap_scene(minimal_data, "MinimalTest", true)
	save_scene_to_file(minimal_scene, "res://minimal_test.tscn")
	
	# Generate simple test (5x5 pattern)
	print("Generating simple test...")
	var simple_data = {}
	for y in range(5):
		for x in range(5):
			var tile_type: TileType
			if x == 0 or y == 0 or x == 4 or y == 4:
				tile_type = TileType.MOUNTAIN  # Border
			elif (x + y) % 2 == 0:
				tile_type = TileType.GRASS
			else:
				tile_type = TileType.WATER
			simple_data[Vector2i(x, y)] = tile_type
	
	var simple_scene = create_tilemap_scene(simple_data, "SimpleTest", true)
	save_scene_to_file(simple_scene, "res://simple_test.tscn")

# Save scenes using EditorInterface
func save_scene_to_file(scene: PackedScene, path: String) -> bool:
	var result = ResourceSaver.save(scene, path)
	if result == OK:
		print("✓ Saved: ", path)
		# Refresh the FileSystem dock
		EditorInterface.get_resource_filesystem().scan()
		return true
	else:
		print("✗ Failed to save: ", path, " (Error: ", result, ")")
		return false
