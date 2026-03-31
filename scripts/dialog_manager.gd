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
	const half_grid_size:int = int(grid_size / 2.0)
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
	
	# Valid tile IDs for NPC spawning (walkable tiles)
	var valid_tiles = [4, 5, 22, 24]
	
	# Track occupied tile positions
	var occupied_tiles: Array[Vector2i] = []
	var dims = get_viewport().get_visible_rect().size / grid_size
	if npc_spawn_area:
		dims = npc_spawn_area.shape.size / grid_size
	var num_x: int = int(dims.x)
	var num_y: int = int(dims.y)
	var offset_x: int = int(float(num_x) / 2)
	var offset_y: int = int(float(num_y) / 2)
	
	for npc_info in npc_data[village_name]:
		var npc = npc_node.new(npc_info)
		var target_tile := Vector2i.ZERO
		var valid := false
		
		if npc_info.has("location") and npc_info["location"].has("x") and npc_info["location"].has("y"):
			# Fixed position — convert grid coords to tile coords
			var gx: int = int(npc_info["location"]["x"])
			var gy: int = int(npc_info["location"]["y"])
			var world_pos = Vector2(
				(gx - offset_x) * grid_size - half_grid_size,
				(gy - offset_y) * grid_size - half_grid_size
			)
			var global_pos = npc_spawn_area.to_global(world_pos)
			target_tile = tilemap.local_to_map(tilemap.to_local(global_pos))
			
			# Validate, search nearby if invalid
			if is_valid_npc_tile(tilemap, target_tile, valid_tiles, occupied_tiles):
				valid = true
			else:
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var alt = target_tile + Vector2i(dx, dy)
						if is_valid_npc_tile(tilemap, alt, valid_tiles, occupied_tiles):
							target_tile = alt
							valid = true
							break
					if valid:
						break
		else:
			# Random position
			for attempt in range(100):
				var x = randi() % num_x
				var y = randi() % num_y
				var world_pos = Vector2(
					(x - offset_x) * grid_size - half_grid_size,
					(y - offset_y) * grid_size - half_grid_size
				)
				var global_pos = npc_spawn_area.to_global(world_pos)
				target_tile = tilemap.local_to_map(tilemap.to_local(global_pos))
				if is_valid_npc_tile(tilemap, target_tile, valid_tiles, occupied_tiles):
					valid = true
					break
		
		if valid:
			occupied_tiles.append(target_tile)
			# Convert tile back to spawn_area local position
			var tile_world = tilemap.to_global(tilemap.map_to_local(target_tile))
			npc.position = parent.to_local(tile_world)
			parent.add_child(npc)
		else:
			npc.queue_free()

# Check if a tile is valid for NPC placement
func is_valid_npc_tile(tm: TileMapLayer, tile_pos: Vector2i, valid_tiles: Array, occupied: Array[Vector2i]) -> bool:
	if tile_pos in occupied:
		return false
	var tile_id = tm.get_cell_source_id(tile_pos)
	if tile_id not in valid_tiles:
		return false
	# Must have at least 3 free cardinal neighbors (don't block passageways)
	var free = 0
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor = tile_pos + dir
		if tm.get_cell_source_id(neighbor) in valid_tiles and neighbor not in occupied:
			free += 1
	return free >= 3
