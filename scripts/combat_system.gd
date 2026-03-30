extends Node2D
class_name CombatSystem

# Combat grid settings
const GRID_SIZE = 32
const GRID_WIDTH = 15
const GRID_HEIGHT = 11

# Combat states
enum CombatState {
	WAITING_FOR_ACTION,
	MOVING,
	SELECTING_ATTACK_TARGET,
	ANIMATING,
	COMBAT_WON,
	COMBAT_LOST
}

var current_state: CombatState = CombatState.WAITING_FOR_ACTION
var initiative_order: Array[CombatUnit] = []
var current_unit_index: int = 0
var current_unit: CombatUnit = null

# UI elements
var tilemap: TileMapLayer
var cursor: Sprite2D
var status_label: Label
var initiative_panel: Panel
var initiative_list: VBoxContainer
var cursor_position: Vector2i = Vector2i(7, 5)
var attack_cursor_position: Vector2i = Vector2i(0, 0)

# Audio
var battle_music: AudioStreamPlayer
var sword_sound: AudioStreamPlayer
var arrow_sound: AudioStreamPlayer
var hit_sound: AudioStreamPlayer

var enemies: Array[CombatUnit] = []
var player_units: Array[CombatUnit] = []

signal combat_ended(victory: bool)

func _ready():
	setup_audio()
	setup_tilemap()
	setup_ui()
	setup_cursor()
	spawn_combat_units()
	initialize_initiative()
	start_turn()

func setup_audio():
	# Battle music
	battle_music = AudioStreamPlayer.new()
	var battle_stream = load("res://res/music/battle.mp3")
	if battle_stream:
		battle_music.stream = battle_stream
		battle_music.autoplay = true
		if battle_stream.has_method("set_loop"):
			battle_stream.set_loop(true)
		add_child(battle_music)
	
	# Sound effects
	sword_sound = AudioStreamPlayer.new()
	var sword_stream = load("res://res/sfx/sword.mp3")
	if sword_stream:
		sword_sound.stream = sword_stream
		add_child(sword_sound)
	
	arrow_sound = AudioStreamPlayer.new()
	var arrow_stream = load("res://res/sfx/arrow.mp3")
	if arrow_stream:
		arrow_sound.stream = arrow_stream
		add_child(arrow_sound)
	
	hit_sound = AudioStreamPlayer.new()
	var hit_stream = load("res://res/sfx/hit.mp3")
	if hit_stream:
		hit_sound.stream = hit_stream
		add_child(hit_sound)

func setup_tilemap():
	tilemap = TileMapLayer.new()
	tilemap.name = "CombatGrid"
	tilemap.tile_set = create_combat_tileset()
	add_child(tilemap)
	
	# Create combat terrain
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var terrain_type = get_terrain_for_position(x, y)
			tilemap.set_cell(Vector2i(x, y), terrain_type, Vector2i(0, 0), 0)

func create_combat_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(GRID_SIZE, GRID_SIZE)
	
	# Add basic terrain sources
	for i in range(3):
		var source = TileSetAtlasSource.new()
		source.texture = create_terrain_texture(i)
		source.texture_region_size = Vector2i(GRID_SIZE, GRID_SIZE)
		ts.add_source(source, i)
	
	return ts

func create_terrain_texture(terrain_type: int) -> ImageTexture:
	var img = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGB8)
	var color: Color
	
	match terrain_type:
		0: color = Color(0.3, 0.6, 0.3)  # Grass
		1: color = Color(0.5, 0.5, 0.5)  # Stone
		2: color = Color(0.2, 0.4, 0.8)  # Water
		_: color = Color(0.3, 0.6, 0.3)
	
	img.fill(color)
	return ImageTexture.create_from_image(img)

func get_terrain_for_position(x: int, y: int) -> int:
	if (x < 2 or x > GRID_WIDTH - 3) and (y > 2 and y < GRID_HEIGHT - 3):
		return 2  # Water on sides
	elif (x + y) % 7 == 0:
		return 1  # Occasional stone
	return 0  # Mostly grass

func setup_cursor():
	print("--- Setting up cursor ---")
	
	cursor = Sprite2D.new()
	cursor.name = "Cursor"
	var cursor_img = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	cursor_img.fill(Color(0, 0, 0, 0))
	
	# Draw cursor border
	for i in range(GRID_SIZE):
		cursor_img.set_pixel(i, 0, Color.YELLOW)
		cursor_img.set_pixel(i, GRID_SIZE - 1, Color.YELLOW)
		cursor_img.set_pixel(0, i, Color.YELLOW)
		cursor_img.set_pixel(GRID_SIZE - 1, i, Color.YELLOW)
	
	cursor.texture = ImageTexture.create_from_image(cursor_img)
	cursor.centered = false
	cursor.visible = false
	add_child(cursor)
	
	print("Cursor created at: ", cursor.position)
	print("Cursor setup complete")

func setup_ui():
	# Status label
	status_label = Label.new()
	status_label.position = Vector2(20, GRID_HEIGHT * GRID_SIZE + 20)
	status_label.custom_minimum_size = Vector2(GRID_WIDTH * GRID_SIZE - 40, 60)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)
	
	# Initiative panel
	initiative_panel = Panel.new()
	initiative_panel.size = Vector2(200, 300)
	initiative_panel.position = Vector2(GRID_WIDTH * GRID_SIZE + 20, 20)
	
	# Add style to make panel visible
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 1)
	initiative_panel.add_theme_stylebox_override("panel", style)
	
	add_child(initiative_panel)
	
	var title = Label.new()
	title.text = "Turn Order"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	initiative_panel.add_child(title)
	
	initiative_list = VBoxContainer.new()
	initiative_list.position = Vector2(10, 40)
	initiative_list.custom_minimum_size = Vector2(180, 250)
	initiative_panel.add_child(initiative_list)

func spawn_combat_units():
	print("--- Spawning combat units ---")
	
	# Spawn player party
	var player_positions = [
		Vector2i(1, 5),
		Vector2i(2, 4),
		Vector2i(2, 6),
	]
	
	var player_weapons = ["sword", "bow", "sword"]
	
	for i in range(min(3, player_positions.size())):
		var unit = CombatUnit.new("Hero" + str(i + 1), true, player_weapons[i])
		unit.position = Vector2(player_positions[i].x * GRID_SIZE, player_positions[i].y * GRID_SIZE)
		unit.grid_pos = player_positions[i]
		add_child(unit)
		player_units.append(unit)
		print("Spawned player unit: ", unit.unit_name, " at ", unit.position)
	
	# Spawn enemies
	var enemy_positions = [
		Vector2i(12, 5),
		Vector2i(11, 3),
		Vector2i(11, 7),
		Vector2i(13, 5),
	]
	
	for i in range(4):
		var unit = CombatUnit.new("Enemy" + str(i + 1), false, "sword")
		unit.position = Vector2(enemy_positions[i].x * GRID_SIZE, enemy_positions[i].y * GRID_SIZE)
		unit.grid_pos = enemy_positions[i]
		add_child(unit)
		enemies.append(unit)
		print("Spawned enemy unit: ", unit.unit_name, " at ", unit.position)
	
	print("Total player units: ", player_units.size())
	print("Total enemy units: ", enemies.size())
	print("Unit spawning complete")

func initialize_initiative():
	# Combine all units
	var all_units = player_units + enemies
	
	# Roll initiative for each unit (d20 + dex modifier)
	for unit in all_units:
		unit.initiative = randi_range(1, 20) + unit.dex_modifier
	
	# Sort by initiative (highest first)
	all_units.sort_custom(func(a, b): return a.initiative > b.initiative)
	
	initiative_order = all_units
	current_unit_index = 0
	
	update_initiative_display()

func update_initiative_display():
	# Clear existing labels
	for child in initiative_list.get_children():
		child.queue_free()
	
	# Add labels for each unit in initiative order
	for i in range(initiative_order.size()):
		var unit = initiative_order[i]
		var label = Label.new()
		label.text = "%s (%d)" % [unit.unit_name, unit.initiative]
		
		# Highlight current unit
		if i == current_unit_index:
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.text = "► " + label.text
		else:
			label.add_theme_color_override("font_color", Color.WHITE if unit.is_player else Color.RED)
		
		initiative_list.add_child(label)

func start_turn():
	if current_unit_index >= initiative_order.size():
		# Round complete, start new round
		current_unit_index = 0
	
	current_unit = initiative_order[current_unit_index]
	
	# Skip dead units
	if current_unit.current_hp <= 0:
		next_turn()
		return
	
	current_unit.has_acted = false
	current_unit.has_moved = false
	
	update_initiative_display()
	
	if current_unit.is_player:
		start_player_turn()
	else:
		start_enemy_turn()

func start_player_turn():
	current_state = CombatState.WAITING_FOR_ACTION
	update_status("%s's turn! Move with arrows OR press 'A' to attack." % current_unit.unit_name)

func start_enemy_turn():
	current_state = CombatState.ANIMATING
	update_status("%s's turn..." % current_unit.unit_name)
	await get_tree().create_timer(0.5).timeout
	execute_enemy_ai()

func _input(event):
	if current_state == CombatState.COMBAT_WON or current_state == CombatState.COMBAT_LOST:
		if event.is_action_pressed("ui_accept"):
			combat_ended.emit(current_state == CombatState.COMBAT_WON)
		return
	
	if not current_unit or not current_unit.is_player:
		return
	
	match current_state:
		CombatState.WAITING_FOR_ACTION:
			handle_action_input(event)
		CombatState.SELECTING_ATTACK_TARGET:
			handle_attack_targeting(event)

func handle_action_input(event):
	# Can only move OR attack, not both
	
	# Movement (ends turn immediately)
	if event.is_action_pressed("move_up"):
		attempt_move(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		attempt_move(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):
		attempt_move(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		attempt_move(Vector2i(1, 0))
	# Attack
	elif event.is_action_pressed("ui_text_backspace"):  # 'A' key
		start_attack_targeting()
	# Skip turn
	elif event.is_action_pressed("ui_cancel"):
		end_turn()

func attempt_move(direction: Vector2i):
	var new_pos = current_unit.grid_pos + direction
	
	# Check bounds
	if new_pos.x < 0 or new_pos.x >= GRID_WIDTH or new_pos.y < 0 or new_pos.y >= GRID_HEIGHT:
		update_status("Can't move there!")
		return
	
	# Check if position is occupied
	if is_position_occupied(new_pos):
		update_status("Space occupied!")
		return
	
	# Move the unit
	current_unit.grid_pos = new_pos
	current_unit.position = Vector2(new_pos.x * GRID_SIZE, new_pos.y * GRID_SIZE)
	current_unit.has_moved = true
	current_unit.has_acted = true  # Moving ends the turn
	
	# Check for chest at new position
	if collect_chest_at_position(new_pos):
		await get_tree().create_timer(1.0).timeout
	
	update_status("%s moved. Turn ending..." % current_unit.unit_name)
	
	# End turn after moving
	await get_tree().create_timer(0.5).timeout
	end_turn()

func start_attack_targeting():
	current_state = CombatState.SELECTING_ATTACK_TARGET
	cursor.visible = true
	attack_cursor_position = current_unit.grid_pos
	update_cursor_position()
	update_status("Select target with arrows, Enter to confirm, ESC to cancel.")

func handle_attack_targeting(event):
	if event.is_action_pressed("move_up"):
		move_attack_cursor(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		move_attack_cursor(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):
		move_attack_cursor(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		move_attack_cursor(Vector2i(1, 0))
	elif event.is_action_pressed("ui_accept"):
		execute_attack()
	elif event.is_action_pressed("ui_cancel"):
		cancel_attack_targeting()

func move_attack_cursor(delta: Vector2i):
	var new_pos = attack_cursor_position + delta
	var distance = current_unit.grid_pos.distance_to(new_pos)
	
	# Check if within weapon range
	if distance <= current_unit.attack_range:
		attack_cursor_position = new_pos
		update_cursor_position()

func update_cursor_position():
	cursor.position = Vector2(attack_cursor_position.x * GRID_SIZE, attack_cursor_position.y * GRID_SIZE)

func execute_attack():
	var target = get_unit_at_position(attack_cursor_position)
	
	if not target:
		update_status("No target at that position!")
		return
	
	if target.is_player:
		update_status("Can't attack allies!")
		return
	
	var distance = current_unit.grid_pos.distance_to(attack_cursor_position)
	if distance > current_unit.attack_range:
		update_status("Out of range!")
		return
	
	# Perform attack
	current_state = CombatState.ANIMATING
	cursor.visible = false
	
	# Play weapon sound based on weapon type
	if current_unit.weapon_type == "bow":
		if arrow_sound:
			arrow_sound.play()
	else:  # sword, spear, etc.
		if sword_sound:
			sword_sound.play()
	
	# Wait for weapon sound
	await get_tree().create_timer(0.3).timeout
	
	var damage = current_unit.attack_power + randi_range(-2, 2)
	var target_name = target.unit_name  # Store name before potential death
	var target_pos = target.grid_pos  # Store position for loot drop
	target.take_damage(damage)
	
	# Play hit sound
	if hit_sound:
		hit_sound.play()
	
	update_status("%s attacks %s for %d damage!" % [current_unit.unit_name, target_name, damage])
	
	if target.current_hp <= 0:
		enemies.erase(target)
		update_status("%s defeated!" % target_name)
		
		# Drop loot chest before removing unit
		drop_loot_chest(target_pos)
		
		target.queue_free()
		check_victory()
	
	current_unit.has_acted = true
	
	await get_tree().create_timer(1.0).timeout
	
	# End turn after attacking
	end_turn()

func cancel_attack_targeting():
	current_state = CombatState.WAITING_FOR_ACTION
	cursor.visible = false
	update_status("%s's turn. Move with arrows or press 'A' to attack." % current_unit.unit_name)

func end_turn():
	current_unit.has_acted = true
	current_unit.has_moved = true
	next_turn()

func next_turn():
	current_unit_index += 1
	start_turn()

func execute_enemy_ai():
	# Simple AI: move toward nearest player and attack if in range
	var nearest_player = find_nearest_player(current_unit)
	if not nearest_player:
		end_turn()
		return
	
	var distance = current_unit.grid_pos.distance_to(nearest_player.grid_pos)
	
	if distance <= current_unit.attack_range:
		# Attack
		var damage = current_unit.attack_power + randi_range(-2, 2)
		var player_name = nearest_player.unit_name  # Store name before potential death
		var player_pos = nearest_player.grid_pos  # Store position for loot drop
		nearest_player.take_damage(damage)
		update_status("%s attacks %s for %d damage!" % [current_unit.unit_name, player_name, damage])
		
		if nearest_player.current_hp <= 0:
			player_units.erase(nearest_player)
			update_status("%s defeated!" % player_name)
			
			# Drop loot chest before removing unit
			drop_loot_chest(player_pos)
			
			nearest_player.queue_free()
			check_defeat()
	else:
		# Move toward player - convert to Vector2 for normalized(), then back to Vector2i
		var direction_vec2 = Vector2(nearest_player.grid_pos - current_unit.grid_pos).normalized()
		var new_pos = current_unit.grid_pos + Vector2i(round(direction_vec2.x), round(direction_vec2.y))
		
		if not is_position_occupied(new_pos) and new_pos.x >= 0 and new_pos.x < GRID_WIDTH and new_pos.y >= 0 and new_pos.y < GRID_HEIGHT:
			current_unit.grid_pos = new_pos
			current_unit.position = Vector2(new_pos.x * GRID_SIZE, new_pos.y * GRID_SIZE)
			update_status("%s moves closer." % current_unit.unit_name)
	
	await get_tree().create_timer(1.0).timeout
	next_turn()

func find_nearest_player(enemy: CombatUnit) -> CombatUnit:
	var nearest: CombatUnit = null
	var min_distance = INF
	
	for player in player_units:
		if player.current_hp <= 0:
			continue
		var distance = enemy.grid_pos.distance_to(player.grid_pos)
		if distance < min_distance:
			min_distance = distance
			nearest = player
	
	return nearest

func is_position_occupied(pos: Vector2i) -> bool:
	for unit in player_units + enemies:
		if unit.grid_pos == pos and unit.current_hp > 0:
			return true
	return false

func get_unit_at_position(pos: Vector2i) -> CombatUnit:
	for unit in player_units + enemies:
		if unit.grid_pos == pos and unit.current_hp > 0:
			return unit
	return null

func check_victory():
	if enemies.size() == 0:
		current_state = CombatState.COMBAT_WON
		update_status("Victory! Press Enter to continue.")

func check_defeat():
	if player_units.size() == 0:
		current_state = CombatState.COMBAT_LOST
		update_status("Defeat! Press Enter to continue.")

func drop_loot_chest(pos: Vector2i):
	"""Drop a chest with random loot at the given position"""
	var chest = LootChest.new()
	chest.position = Vector2(pos.x * GRID_SIZE, pos.y * GRID_SIZE)
	chest.grid_pos = pos
	add_child(chest)
	
	# Generate random loot
	var gold_amount = randi_range(1, 10)
	chest.gold = gold_amount
	
	# Random item (40% chance for each, 20% chance for nothing extra)
	var item_roll = randi_range(1, 100)
	if item_roll <= 20:
		chest.item = "dagger"
	elif item_roll <= 40:
		chest.item = "sword"
	elif item_roll <= 60:
		chest.item = "shield"
	elif item_roll <= 80:
		chest.item = "bow"
	elif item_roll <= 90:
		chest.item = "ring"
	# else: no item (just gold)
	
	update_status("A chest appeared! Move onto it to collect loot.")

func collect_chest_at_position(pos: Vector2i):
	"""Check if there's a chest at this position and collect it"""
	for child in get_children():
		if child is LootChest and child.grid_pos == pos:
			var loot_text = "%d gold" % child.gold
			if child.item:
				loot_text += " and a %s" % child.item
				# Add item to player inventory
				Global.inventory.add_item(child.item, 1)
			
			# Add gold to player inventory
			Global.inventory.gold += child.gold
			
			update_status("Collected: %s!" % loot_text)
			child.queue_free()
			return true
	return false

func update_status(text: String):
	status_label.text = text
	print("Combat: ", text)

static func start_combat(parent_scene: Node):
	var combat = CombatSystem.new()
	combat.name = "CombatScene"
	parent_scene.add_child(combat)
	combat.position = Vector2.ZERO
	combat.z_index = 100
	return combat

# Loot Chest Class
class LootChest extends Node2D:
	var grid_pos: Vector2i
	var gold: int = 0
	var item: String = ""
	
	var sprite: Sprite2D
	
	func _ready():
		# Create chest sprite
		sprite = Sprite2D.new()
		var img = Image.create(28, 28, false, Image.FORMAT_RGB8)
		
		# Draw a simple chest (brown with gold latch)
		for y in range(28):
			for x in range(28):
				if y < 14:
					img.set_pixel(x, y, Color(0.4, 0.25, 0.1))  # Brown top
				else:
					img.set_pixel(x, y, Color(0.35, 0.2, 0.05))  # Darker brown bottom
		
		# Gold latch
		for x in range(10, 18):
			for y in range(12, 16):
				img.set_pixel(x, y, Color(0.8, 0.7, 0.2))  # Gold
		
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(16, 16)
		add_child(sprite)
		
		# Label
		var label = Label.new()
		label.text = "💰"
		label.position = Vector2(8, -10)
		label.add_theme_font_size_override("font_size", 16)
		add_child(label)

# Combat Unit Class
class CombatUnit extends Node2D:
	var unit_name: String
	var is_player: bool
	var grid_pos: Vector2i
	var max_hp: int = 20
	var current_hp: int = 20
	var attack_power: int = 5
	var defense: int = 2
	var dex_modifier: int = 0
	var initiative: int = 0
	var has_acted: bool = false
	var has_moved: bool = false
	var weapon_type: String = "sword"
	var attack_range: int = 1
	
	var sprite: Sprite2D
	var hp_bar: ColorRect
	var name_label: Label
	
	func _init(name: String, player: bool, weapon: String = "sword"):
		unit_name = name
		is_player = player
		weapon_type = weapon
		
		# Set weapon range
		match weapon_type:
			"sword":
				attack_range = 1
			"bow":
				attack_range = 4
			"spear":
				attack_range = 2
		
		if is_player:
			max_hp = Global.stats.max_hp
			current_hp = Global.stats.current_hp
			attack_power = Global.stats.attack_power
			defense = Global.stats.defense
			dex_modifier = Global.stats.initiative_mod
		else:
			max_hp = 15
			current_hp = 15
			attack_power = 4
			dex_modifier = 0
	
	func _ready():
		print("--- CombatUnit _ready() called ---")
		print("Unit: ", unit_name, " at position: ", position)
		
		# Create sprite
		sprite = Sprite2D.new()
		var img = Image.create(24, 24, false, Image.FORMAT_RGB8)
		img.fill(Color.BLUE if is_player else Color.RED)
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(16, 16)
		add_child(sprite)
		print("Sprite created for ", unit_name)
		
		# Create HP bar
		hp_bar = ColorRect.new()
		hp_bar.size = Vector2(28, 4)
		hp_bar.position = Vector2(2, 2)
		hp_bar.color = Color.GREEN if is_player else Color.ORANGE_RED
		add_child(hp_bar)
		
		# Name label
		name_label = Label.new()
		name_label.text = unit_name
		name_label.position = Vector2(-10, -15)
		name_label.add_theme_font_size_override("font_size", 8)
		add_child(name_label)
		
		# Weapon indicator
		if weapon_type == "bow":
			var weapon_label = Label.new()
			weapon_label.text = "🏹"
			weapon_label.position = Vector2(20, -15)
			weapon_label.add_theme_font_size_override("font_size", 10)
			add_child(weapon_label)
		
		print("Unit ", unit_name, " fully initialized")
		print("  Position: ", position)
		print("  Visible: ", visible)
		print("  Modulate: ", modulate)
	
	func take_damage(damage: int):
		var actual_damage = max(1, damage - defense)
		current_hp -= actual_damage
		update_hp_bar()
	
	func update_hp_bar():
		var hp_ratio = float(current_hp) / float(max_hp)
		hp_bar.size.x = 28 * hp_ratio
		
		if hp_ratio > 0.6:
			hp_bar.color = Color.GREEN
		elif hp_ratio > 0.3:
			hp_bar.color = Color.YELLOW
		else:
			hp_bar.color = Color.RED
