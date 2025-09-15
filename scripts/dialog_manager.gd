extends Node

var npc_data: Dictionary

func _ready() -> void:
	npc_data = load_json("res://res/npcs.json")


# --- Load JSON file ---
func load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON file: %s" % path)
		return {}

	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data == null:
		push_error("Failed to parse JSON data")
		return {}

	return data


# --- Spawn NPCs in a village scene ---
func spawn_village_npcs(village_name: String, parent: Node) -> void:
	const grid_size = 32
	const half_grid_size = 16
	if not npc_data.has(village_name):
		push_warning("Village not found in JSON: %s" % village_name)
		return
	var npc_spawn_area:CollisionShape2D = parent.get_node("spawn_area")
	if not npc_spawn_area:
		push_warning("Spawn area not found as child of ",name )
	# Get the TileMapLayer sibling node
	var tilemap = parent.get_parent().get_node("TileMapLayer")
	if not tilemap:
		push_error("TileMapLayer not found as sibling of parent")
		return
	
	# Valid tile IDs for NPC spawning
	var valid_tiles = [4, 5, 22, 24]
	
	# Track occupied positions to avoid overlapping NPCs
	var occupied_positions = []
	var num_x:int = int(1280.0 / grid_size)
	var num_y:int = int(720.0 / grid_size)
	if npc_spawn_area:
		var rect = npc_spawn_area.shape
		num_x = rect.size.x / grid_size
		num_y = rect.size.y / grid_size
	var offset_x:int = int(float(num_x) / 2)
	var offset_y:int = int(float(num_y) / 2)
	
	for npc_info in npc_data[village_name]:
		var npc = npc_node.new(npc_info)
		var spawn_pos: Vector2
		var attempts = 0
		var max_attempts = 100  # Prevent infinite loops
		
		# Try to find a valid spawn position
		if npc_info.has("location") and npc_info["location"].has("x") and npc_info["location"].has("y"):
			spawn_pos = Vector2(
					(npc_info["location"]["x"] - offset_x) * grid_size - half_grid_size,
					(npc_info["location"]["y"] - offset_y) * grid_size - half_grid_size
				)
		else:
			while attempts < max_attempts:
				var x: int
				var y: int
				
				# Set position based on "location" or random
				if npc_info.has("location"):
					x = int(npc_info["location"].get("x", randi() % num_x))
					y = int(npc_info["location"].get("y", randi() % num_y))
				else:
					x = randi() % num_x
					y = randi() % num_y
				
				# Calculate world position
				spawn_pos = Vector2(
					(x - offset_x) * grid_size - half_grid_size,
					(y - offset_y) * grid_size - half_grid_size
				)
				
				# Convert world position to tile coordinates
				var tile_pos:Vector2i = tilemap.local_to_map(npc_spawn_area.to_global(spawn_pos))
				var tile_id = tilemap.get_cell_source_id(tile_pos)
				
				# Check if tile is valid and position is not occupied
				if tile_id in valid_tiles and not is_position_occupied(spawn_pos, occupied_positions):
					occupied_positions.append(spawn_pos)
					break
				
				attempts += 1
			
		# Only add NPC if we found a valid position
		if attempts < max_attempts:
			parent.add_child(npc)
			npc.position = spawn_pos
			
			print("NPC created ", npc, " at ", npc.position, " on tile ID: ", tilemap.get_cell_source_id(tilemap.local_to_map(tilemap.to_local(spawn_pos))))
		else:
			print("Could not find valid spawn position for NPC, skipping")
			npc.queue_free()

# Check if a position is already occupied by another NPC
func is_position_occupied(pos: Vector2, occupied_list: Array) -> bool:
	for occupied_pos in occupied_list:
		if pos.distance_to(occupied_pos) < 16:  # Within half a tile
			return true
	return false
