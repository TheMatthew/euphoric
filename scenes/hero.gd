extends CharacterBody2D
class_name CharacterEntity
# can be an NPC or a PC

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
var blocked_tiles = []
var has_moved = false
signal moved

# Reference to the RayCast2D node
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var sound_player = get_node("SoundPlayer")
@onready var camera:FollowingCamera2D = get_parent().get_node("Camera2D")
@onready var tilemap:TileMapLayer = get_parent().get_node("TileMapLayer")


@onready var dialog_tree: Node= dialog_system.new()

func _ready():
	blocked_tiles = ["0", "1", "2", "8", "20", "19", "18", "25"]
	# Add numbers from 27 to 60
	for i in range(27, 61):
		blocked_tiles.append(str(i))
	
	move_timer = Timer.new()
	move_timer.wait_time = 0.25  # Time between each step
	move_timer.connect("timeout", _on_move_timer_timeout)
	add_child(move_timer)
	
	camera.target=self
	setup_dialog_system()
	
	# Restore saved position if loading a save
	if Global.pending_hero_pos != Vector2.ZERO:
		global_position = Global.pending_hero_pos
		Global.pending_hero_pos = Vector2.ZERO

func setup_dialog_system():
	# Create dialog system - it manages its own state
	camera.add_child(dialog_tree)
	
	# Optional: Connect to dialog system signals for additional behavior
	dialog_tree.connect("dialog_closed", _on_dialog_closed)
	dialog_tree.connect("state_changed", _on_dialog_state_changed)


# Calls the move function with the appropriate input key
# if any input map action is triggered
func _unhandled_input(event):
	if dialog_tree and dialog_tree.is_dialog_active():
		return
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
			
# Optional callback handlers
func _on_dialog_closed():
	print("Hero: Dialog closed, back to normal gameplay")

func _on_dialog_state_changed(new_state):
	match new_state:
		dialog_system.DialogState.READY:
			print("Hero: Ready for normal movement")
		dialog_system.DialogState.DIRECTION:
			print("Hero: Waiting for direction input")
		dialog_system.DialogState.DIALOG:
			print("Hero: In dialog mode")

# Optional: Stop moving when the key is released
func _input(event):
	# Ctrl+S to save anywhere
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		var scene_path = get_tree().current_scene.scene_file_path
		Global.save_game(scene_path, global_position)
		get_viewport().set_input_as_handled()
		return

	if in_combat:
		return
	if dialog_tree and dialog_tree.is_dialog_active():
		return
	
	# Test combat trigger - press 'C' key
	if event.is_action_pressed("ui_combat"):
		trigger_combat()
		return
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
		if can_move_to(new_pos):
			has_moved = true
			global_position = new_pos
	play_step_sound()
	moved.emit()

func get_current_tile_type() -> String:
	tilemap = get_parent().get_node("TileMapLayer")

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

func can_move_to(world_pos: Vector2) -> bool:
	tilemap = get_parent().get_node("TileMapLayer")

	# target cell from hero position
	var target_cell = tilemap.local_to_map(tilemap.to_local(world_pos))
	# desired neighbor cell

	if is_npc_at_position(world_pos):
			return false  # Can't move here, NPC is blocking
	var tile_id = tilemap.get_cell_source_id(target_cell) # 0 = layer index
	if str(tile_id) in tile_sounds: # <-- make sure both are strings
		# Now check for NPC collision at the target position
		
		return true
	
	return str(tile_id) not in blocked_tiles

# Check if there's an NPC at the given world position
func is_npc_at_position(world_pos: Vector2) -> bool:
	# Get the village node (assuming it's a sibling of the hero's parent)
	var village_node = get_parent().get_node_or_null("villagers")
	if not village_node:
		return false
	
	# Check all children of village for NPCs
	for child in village_node.get_children():
		# Check if this child has NPC data (created by dialog_manager)
		if child.has_meta("collide"):
			# Calculate distance between target position and NPC position
			var distance = world_pos.distance_to(child.global_position)
			# If they're close enough (within one grid cell), consider it blocked
			if distance < grid_size * 0.7:  # 0.7 gives some tolerance
				return true
	
	return false
# Add this to your hero.gd file - near the _input function

var in_combat: bool = false
var stored_overworld_scene: Node = null
var stored_music_player: AudioStreamPlayer = null

func trigger_combat():
	"""Start a combat encounter by loading combat scene"""
	if in_combat:
		return
	
	in_combat = true
	is_moving = false
	move_timer.stop()
	
	print("=== HERO: Starting Combat ===")
	
	# Store reference to current overworld scene
	stored_overworld_scene = get_tree().current_scene
	print("Stored overworld scene: ", stored_overworld_scene.name)
	
	# Find and stop any overworld music
	stop_overworld_music(stored_overworld_scene)
	
	print("Loading combat scene...")
	# Load the combat scene
	var combat_scene = load("res://scenes/combat.tscn")
	if not combat_scene:
		print("ERROR: Could not load combat scene!")
		in_combat = false
		return
	
	print("Combat scene loaded, instantiating...")
	var combat_instance = combat_scene.instantiate()
	print("Combat instance created: ", combat_instance.name)
	
	# Connect to combat end signal
	var combat_system = combat_instance.get_node_or_null("CombatSystem")
	if combat_system:
		print("Found CombatSystem node")
		combat_system.combat_ended.connect(_on_combat_ended)
	else:
		print("ERROR: Could not find CombatSystem node!")
		print("Combat instance children: ", combat_instance.get_children())
	
	# Switch to combat scene
	print("Adding combat to scene tree...")
	get_tree().root.add_child(combat_instance)
	print("Setting combat as current scene...")
	get_tree().current_scene = combat_instance
	
	# Hide overworld (but don't remove it)
	print("Hiding overworld...")
	stored_overworld_scene.visible = false
	
	print("=== HERO: Combat transition complete ===")
	print("Current scene: ", get_tree().current_scene.name)
	print("Current scene children: ", get_tree().current_scene.get_children())

func stop_overworld_music(scene: Node):
	"""Find and stop any AudioStreamPlayer in the overworld scene"""
	if not scene:
		return
	
	# Check for AudioStreamPlayer as direct child
	for child in scene.get_children():
		if child is AudioStreamPlayer:
			stored_music_player = child
			child.stop()
			return
		# Also check TileMapLayer children (where music often is)
		if child is TileMapLayer or child is Node2D:
			for subchild in child.get_children():
				if subchild is AudioStreamPlayer:
					stored_music_player = subchild
					subchild.stop()
					return

func _on_combat_ended(victory: bool):
	"""Handle end of combat and return to overworld"""
	print("=== Combat Ended: ", "Victory" if victory else "Defeat", " ===")
	
	in_combat = false
	
	# Get the combat scene
	var combat_scene = get_tree().current_scene
	
	# Restore overworld scene
	if stored_overworld_scene:
		stored_overworld_scene.visible = true
		get_tree().current_scene = stored_overworld_scene
		
		# Restart overworld music
		if stored_music_player and is_instance_valid(stored_music_player):
			stored_music_player.play()
	
	# Remove combat scene
	if combat_scene:
		combat_scene.queue_free()
	
	stored_music_player = null
	
	if victory:
		print("You won the battle!")
		# Combat system already added loot to Global.inventory
	else:
		print("You lost the battle!")
		# Handle defeat (game over, retreat, etc.)
