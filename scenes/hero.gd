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
var tilemap: TileMapLayer

func get_tilemap() -> TileMapLayer:
	if not is_instance_valid(tilemap):
		tilemap = get_parent().get_node_or_null("TileMapLayer")
	return tilemap


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
	if inventory_panel:
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
func _on_dialog_closed(_arg = null):
	pass

func _on_dialog_state_changed(new_state):
	match new_state:
		dialog_system.DialogState.READY:
			print("Hero: Ready for normal movement")
		dialog_system.DialogState.DIRECTION:
			print("Hero: Waiting for direction input")
		dialog_system.DialogState.DIALOG:
			print("Hero: In dialog mode")

# --- Inventory/Stats Panel ---
var inventory_panel: Panel = null
var inv_selected: int = 0
var inv_item_keys: Array = []

func open_inventory():
	if inventory_panel and inventory_panel.visible:
		close_inventory()
		return
	if inventory_panel:
		inventory_panel.queue_free()

	inv_item_keys = Global.inventory.list_items().keys()
	inv_selected = 0
	build_inventory_panel()

func build_inventory_panel():
	if inventory_panel:
		inventory_panel.queue_free()

	var s = Global.stats
	var inv = Global.inventory

	inventory_panel = Panel.new()
	inventory_panel.z_index = 100
	inventory_panel.size = Vector2(420, 400)
	inventory_panel.position = camera.position - inventory_panel.size / 2

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.6, 0.8)
	inventory_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(12, 8)
	vbox.custom_minimum_size = Vector2(396, 380)
	inventory_panel.add_child(vbox)

	# Name + stats header
	var header = Label.new()
	header.text = "%s  Lv %d  XP %d  (%s)" % [s.player_name, s.level, s.xp, s.virtue if s.virtue else "—"]
	header.add_theme_color_override("font_color", Color.YELLOW)
	header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	# Base stats
	_add_label(vbox, "STR %d  DEX %d  INT %d  END %d  WIS %d  CHA %d" % [
		s.str_base, s.dex_base, s.int_base, s.end_base, s.wis_base, s.cha_base], 12, Color.WHITE)

	# Derived stats
	_add_label(vbox, "HP %d/%d  MP %d/%d  ATK %d  DEF %d  HIT %d%%  DODGE %d%%" % [
		s.current_hp, s.max_hp, s.current_mp, s.max_mp,
		s.attack_power, s.defense, s.hit_pct, s.dodge_pct], 12, Color.LIGHT_BLUE)

	vbox.add_child(HSeparator.new())

	# Equipment
	_add_label(vbox, "Equipment", 14, Color.YELLOW)
	for slot in inv.equipped:
		var item = inv.equipped[slot]
		var display = Global.get_item_name(item) if item else "—"
		_add_label(vbox, "  %s: %s" % [slot.capitalize(), display], 12, Color.WHITE)

	vbox.add_child(HSeparator.new())

	# Inventory with selection
	_add_label(vbox, "Inventory  (Gold: %d)" % inv.gold, 14, Color.YELLOW)
	inv_item_keys = inv.list_items().keys()
	if inv_item_keys.is_empty():
		_add_label(vbox, "  (empty)", 12, Color.GRAY)
	else:
		for i in range(inv_item_keys.size()):
			var item_id = inv_item_keys[i]
			var count = inv.items[item_id]
			var display = Global.get_item_name(item_id)
			var prefix = "► " if i == inv_selected else "  "
			var color = Color.YELLOW if i == inv_selected else Color.WHITE
			_add_label(vbox, "%s%s x%d" % [prefix, display, count], 12, color)

	# Footer
	_add_label(vbox, "↑↓ select  Enter=equip  I/ESC=close", 10, Color.GRAY)

	get_parent().add_child(inventory_panel)

func _add_label(parent: Node, text: String, size: int, color: Color):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)

func handle_inventory_input(event: InputEvent):
	if event.is_action_pressed("ui_inventory") or event.is_action_pressed("ui_cancel"):
		close_inventory()
		return
	if inv_item_keys.is_empty():
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		inv_selected = (inv_selected - 1) % inv_item_keys.size()
		build_inventory_panel()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		inv_selected = (inv_selected + 1) % inv_item_keys.size()
		build_inventory_panel()
	elif event.is_action_pressed("ui_accept"):
		equip_selected_item()

func equip_selected_item():
	if inv_selected >= inv_item_keys.size():
		return
	var item_id = inv_item_keys[inv_selected]
	# Determine slot based on item type
	var slot = guess_equip_slot(item_id)
	if slot != "":
		Global.inventory.equip(slot, item_id)
		inv_item_keys = Global.inventory.list_items().keys()
		inv_selected = mini(inv_selected, inv_item_keys.size() - 1)
		build_inventory_panel()

func guess_equip_slot(item_id: String) -> String:
	# Look up item in items.json categories
	if not Global.item_db.is_empty():
		for category in Global.item_db:
			if Global.item_db[category].has(item_id):
				return Global.item_db[category][item_id].get("slot", "")
	# Fallback
	if item_id in ["sword", "dagger", "bow", "spear", "staff", "short_sword", "long_sword", "mace", "crossbow", "halberd", "sling", "club"]:
		return "weapon"
	if item_id in ["small_shield", "large_shield", "magic_shield", "spiked_shield", "shield"]:
		return "shield"
	if item_id in ["cloth_armour", "leather_armour", "chain_mail", "plate_mail", "ring_mail", "scale_mail", "armor"]:
		return "armor"
	if item_id in ["ring_of_protection", "amulet_of_turning", "ring", "amulet"]:
		return "accessory"
	return ""

func close_inventory():
	if inventory_panel:
		inventory_panel.queue_free()
		inventory_panel = null

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
	if inventory_panel and inventory_panel.visible:
		handle_inventory_input(event)
		return
	if dialog_tree and dialog_tree.is_dialog_active():
		return
	
	# Test combat trigger - press 'C' key
	if event.is_action_pressed("ui_combat"):
		trigger_combat()
		return
	if event.is_action_pressed("ui_inventory"):
		open_inventory()
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
	
	# Check for random encounters on overworld only
	if not in_combat and "overworld" in get_tree().current_scene.scene_file_path:
		var tile_type = get_current_tile_type()
		var zone_id = "plains" if tile_type in ["4", "5", "3"] else "mountains" if tile_type in ["7", "8"] else ""
		if zone_id != "":
			var em = get_node_or_null("/root/EncounterManager")
			if em:
				em.on_hero_moved(zone_id)

func get_current_tile_type() -> String:
	var tm = get_tilemap()
	if not tm:
		return ""
	var target_cell = tm.local_to_map(position)
	return str(tm.get_cell_source_id(target_cell))

# Function to play the step sound based on the current tile type
func play_step_sound():
	var tile_type = get_current_tile_type()

	if tile_sounds.has(tile_type):
		sound_player.stream = tile_sounds[tile_type]  # Set the sound stream
		sound_player.play()  # Play the sound

func can_move_to(world_pos: Vector2) -> bool:
	var tm = get_tilemap()
	if not tm:
		return false
	var target_cell = tm.local_to_map(tm.to_local(world_pos))
	if is_npc_at_position(world_pos):
		return false
	var tile_id = tm.get_cell_source_id(target_cell)
	if str(tile_id) in tile_sounds:
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

func start_combat_encounter(enemy_list: Array[String]):
	if in_combat:
		return
	in_combat = true
	is_moving = false
	move_timer.stop()

	stored_overworld_scene = get_tree().current_scene
	stop_overworld_music(stored_overworld_scene)

	var combat_scene = load("res://scenes/combat.tscn")
	if not combat_scene:
		in_combat = false
		return
	var combat_instance = combat_scene.instantiate()

	var combat_system = combat_instance.get_node_or_null("CombatSystem")
	if combat_system:
		combat_system.encounter_enemies.assign(enemy_list)
		combat_system.overworld_tile = get_current_tile_type()
		combat_system.combat_ended.connect(_on_combat_ended)

	get_tree().root.add_child(combat_instance)
	get_tree().current_scene = combat_instance
	stored_overworld_scene.visible = false

func trigger_combat():
	# Manual combat trigger (A key) — default encounter
	start_combat_encounter(["goblin", "goblin"])

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
	in_combat = false
	var combat_scene = get_tree().current_scene

	if victory and stored_overworld_scene:
		stored_overworld_scene.visible = true
		get_tree().current_scene = stored_overworld_scene
		if stored_music_player and is_instance_valid(stored_music_player):
			stored_music_player.play()
		camera.make_current()
	elif not victory:
		# Defeat: return to menu
		if stored_overworld_scene:
			stored_overworld_scene.queue_free()
		stored_overworld_scene = null
		stored_music_player = null
		if combat_scene:
			combat_scene.queue_free()
		get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
		return

	if combat_scene:
		combat_scene.queue_free()
	stored_music_player = null
