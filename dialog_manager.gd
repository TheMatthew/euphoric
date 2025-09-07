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
	var min_x = 192
	var min_y = 192
	var num_x = 31
	var num_y = 17
	var max_x = 1216
	var max_y = 704
	if npc_spawn_area:
		var rect = npc_spawn_area.shape
		min_x = parent.position.x
		min_y = parent.position.y
		max_x = rect.size.x + min_x
		max_y = rect.size.y + min_y
		num_x = int(rect.size.x / 32)
		num_y = int(rect.size.y / 32)
	for npc_info in npc_data[village_name]:
		var x = randi() % num_x *32
		var y = randi() % num_y *32
		var npc = create_npc(npc_info)
		parent.add_child(npc)

		# Set position based on "location" or random
		if npc_info.has("location"):
			npc.position = Vector2(
				float(npc_info["location"].get("x", x)),
				float(npc_info["location"].get("y", y))
			)
		else:
			npc.position = Vector2(
				x,
				y
			)
		print("NPC created ", npc)


# --- NPC Scene (Sprite + Collision) ---
func create_npc(npc_info: Dictionary) -> Node2D:
	var npc_node = Node2D.new()

	var sprite = Sprite2D.new()
	sprite.texture = load("res://res/u4graphics-master/32x32x24/shapes-assets/082_citizen0.png")
	sprite.centered = true
	npc_node.add_child(sprite)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(16, 16) # matches 32x32 sprite
	collision.shape = shape
	npc_node.add_child(collision)

	npc_node.set_meta("npc_data", npc_info) # store the JSON info
	

	return npc_node
