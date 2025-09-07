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
	if not npc_data.has(village_name):
		push_warning("Village not found in JSON: %s" % village_name)
		return
	var npc_spawn_area:CollisionShape2D = parent.get_node("spawn_area")
	
	# Get the TileMapLayer sibling node
	var tilemap = parent.get_parent().get_node("TileMapLayer")
	if not tilemap:
		push_error("TileMapLayer not found as sibling of parent")
		return
	
	# Valid tile IDs for NPC spawning
	var valid_tiles = [4, 5, 22,24]
	
	# Track occupied positions to avoid overlapping NPCs
	var occupied_positions = []
	var num_x:int = (1216 - 192)/32
	var num_y:int = (704 - 192)/32
	if npc_spawn_area:
		var rect = npc_spawn_area.shape
		num_x = rect.size.x / 32
		num_y = rect.size.y / 32
	var offset_x:int = num_x / 2
	var offset_y:int = num_y / 2
	
	for npc_info in npc_data[village_name]:
		var npc = create_npc(npc_info)
		var spawn_pos: Vector2
		var attempts = 0
		var max_attempts = 100  # Prevent infinite loops
		
		# Try to find a valid spawn position
		if npc_info.has("location") and npc_info["location"].has("x") and npc_info["location"].has("y"):
			npc.position = Vector2i(int(npc_info["location"]["x"]),int(npc_info["location"]["y"]))
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
					(x - offset_x) * 32 - 16,
					(y - offset_y) * 32 - 16
				)
				
				# Convert world position to tile coordinates
				var tile_pos:Vector2i = tilemap.local_to_map(tilemap.to_local(spawn_pos))+Vector2i(offset_x, offset_y)
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



# --- NPC Scene (Sprite + Collision) ---
func create_npc(npc_info: Dictionary) -> Node2D:
	var npc_node = Node2D.new()

	var sprite = Sprite2D.new()
	sprite.centered = true
	npc_node.add_child(sprite)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(16, 16) # matches 32x32 sprite
	collision.shape = shape
	npc_node.add_child(collision)

	npc_node.set_meta("npc_data", npc_info) # store the JSON info

	# Store NPC data and animation info
	npc_node.set_meta("npc_data", npc_info)
	npc_node.set_meta("sprite", sprite)
	npc_node.set_meta("current_frame", 0)
	
	# Load both textures
	var texture1 = load("res://res/u4graphics-master/32x32x24/shapes-assets/082_citizen0.png")
	var texture2 = load("res://res/u4graphics-master/32x32x24/shapes-assets/083_citizen1.png")
	npc_node.set_meta("textures", [texture1, texture2])
	
	# Set initial texture
	sprite.texture = texture1
	
	# Create and configure animation timer
	var anim_timer = Timer.new()
	anim_timer.wait_time = randf()*.5 + .5  # 1 second
	anim_timer.autostart = true
	anim_timer.connect("timeout", _on_npc_anim_timeout.bind(npc_node))
	npc_node.add_child(anim_timer)

	return npc_node

# Animation callback for NPCs
func _on_npc_anim_timeout(npc_node: Node2D) -> void:
	var sprite = npc_node.get_meta("sprite")
	var textures = npc_node.get_meta("textures")
	var current_frame = npc_node.get_meta("current_frame")
	
	# Switch to next frame
	current_frame = (current_frame + 1) % textures.size()
	sprite.texture = textures[current_frame]
	npc_node.set_meta("current_frame", current_frame)
