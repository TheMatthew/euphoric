extends Node2D
class_name CombatSystem

# Combat grid settings
const GRID_SIZE = 32
const GRID_WIDTH = 15
const GRID_HEIGHT = 11

# Combat states
enum CombatState {
	PLAYER_TURN,
	PLAYER_SELECTING_TARGET,
	ENEMY_TURN,
	COMBAT_WON,
	COMBAT_LOST
}

# Turn phases
enum TurnPhase {
	SELECT_ACTION,
	MOVE,
	ATTACK,
	END_TURN
}

var current_state: CombatState = CombatState.PLAYER_TURN
var current_phase: TurnPhase = TurnPhase.SELECT_ACTION
var selected_unit: CombatUnit = null
var target_position: Vector2i = Vector2i.ZERO
var enemies: Array[CombatUnit] = []
var player_units: Array[CombatUnit] = []
var current_enemy_index: int = 0

# UI elements
var tilemap: TileMapLayer
var cursor: Sprite2D
var action_panel: Panel
var status_label: Label
var unit_info_panel: Panel
var cursor_position: Vector2i = Vector2i(7, 5)

# Action buttons
var move_button: Button
var attack_button: Button
var wait_button: Button
var flee_button: Button

signal combat_ended(victory: bool)

func _ready():
	setup_tilemap()
	setup_ui()
	setup_cursor()
	spawn_combat_units()
	update_status("Your turn! Select a unit.")

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
	# Create a simple tileset for combat terrain
	var ts = TileSet.new()
	ts.tile_size = Vector2i(GRID_SIZE, GRID_SIZE)
	
	# Add basic terrain sources (grass, stone, water)
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
	# Create some varied terrain
	if (x < 2 or x > GRID_WIDTH - 3) and (y > 2 and y < GRID_HEIGHT - 3):
		return 2  # Water on sides
	elif (x + y) % 7 == 0:
		return 1  # Occasional stone
	return 0  # Mostly grass

func setup_cursor():
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
	add_child(cursor)
	update_cursor_position()

func setup_ui():
	# Action panel
	action_panel = Panel.new()
	action_panel.size = Vector2(200, 200)
	action_panel.position = Vector2(GRID_WIDTH * GRID_SIZE + 20, 20)
	action_panel.visible = false
	add_child(action_panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.custom_minimum_size = Vector2(180, 180)
	action_panel.add_child(vbox)
	
	# Action buttons
	move_button = Button.new()
	move_button.text = "Move"
	move_button.pressed.connect(_on_move_pressed)
	vbox.add_child(move_button)
	
	attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.pressed.connect(_on_attack_pressed)
	vbox.add_child(attack_button)
	
	wait_button = Button.new()
	wait_button.text = "Wait"
	wait_button.pressed.connect(_on_wait_pressed)
	vbox.add_child(wait_button)
	
	flee_button = Button.new()
	flee_button.text = "Flee"
	flee_button.pressed.connect(_on_flee_pressed)
	vbox.add_child(flee_button)
	
	# Status label
	status_label = Label.new()
	status_label.position = Vector2(20, GRID_HEIGHT * GRID_SIZE + 20)
	status_label.custom_minimum_size = Vector2(GRID_WIDTH * GRID_SIZE - 40, 60)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(status_label)
	
	# Unit info panel
	unit_info_panel = Panel.new()
	unit_info_panel.size = Vector2(200, 150)
	unit_info_panel.position = Vector2(GRID_WIDTH * GRID_SIZE + 20, 240)
	add_child(unit_info_panel)

func spawn_combat_units():
	# Spawn player party
	var player_positions = [
		Vector2i(1, 5),
		Vector2i(2, 4),
		Vector2i(2, 6),
	]
	
	for i in range(min(3, player_positions.size())):
		var unit = CombatUnit.new("Hero" + str(i + 1), true)
		unit.position = Vector2(player_positions[i].x * GRID_SIZE, player_positions[i].y * GRID_SIZE)
		unit.grid_pos = player_positions[i]
		add_child(unit)
		player_units.append(unit)
	
	# Spawn enemies
	var enemy_positions = [
		Vector2i(12, 5),
		Vector2i(11, 3),
		Vector2i(11, 7),
		Vector2i(13, 5),
	]
	
	for i in range(4):
		var unit = CombatUnit.new("Enemy" + str(i + 1), false)
		unit.position = Vector2(enemy_positions[i].x * GRID_SIZE, enemy_positions[i].y * GRID_SIZE)
		unit.grid_pos = enemy_positions[i]
		add_child(unit)
		enemies.append(unit)

func _input(event):
	if current_state == CombatState.COMBAT_WON or current_state == CombatState.COMBAT_LOST:
		if event.is_action_pressed("ui_accept"):
			combat_ended.emit(current_state == CombatState.COMBAT_WON)
		return
	
	if current_state == CombatState.PLAYER_TURN:
		handle_player_input(event)
	elif current_state == CombatState.PLAYER_SELECTING_TARGET:
		handle_target_selection(event)

func handle_player_input(event):
	if current_phase == TurnPhase.SELECT_ACTION:
		if event.is_action_pressed("move_up"):
			move_cursor(Vector2i(0, -1))
		elif event.is_action_pressed("move_down"):
			move_cursor(Vector2i(0, 1))
		elif event.is_action_pressed("move_left"):
			move_cursor(Vector2i(-1, 0))
		elif event.is_action_pressed("move_right"):
			move_cursor(Vector2i(1, 0))
		elif event.is_action_pressed("ui_accept"):
			select_unit_at_cursor()

func handle_target_selection(event):
	if event.is_action_pressed("move_up"):
		move_cursor(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		move_cursor(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):
		move_cursor(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		move_cursor(Vector2i(1, 0))
	elif event.is_action_pressed("ui_accept"):
		if current_phase == TurnPhase.MOVE:
			execute_move()
		elif current_phase == TurnPhase.ATTACK:
			execute_attack()
	elif event.is_action_pressed("ui_cancel"):
		cancel_target_selection()

func move_cursor(delta: Vector2i):
	cursor_position += delta
	cursor_position.x = clamp(cursor_position.x, 0, GRID_WIDTH - 1)
	cursor_position.y = clamp(cursor_position.y, 0, GRID_HEIGHT - 1)
	update_cursor_position()

func update_cursor_position():
	cursor.position = Vector2(cursor_position.x * GRID_SIZE, cursor_position.y * GRID_SIZE)

func select_unit_at_cursor():
	for unit in player_units:
		if unit.grid_pos == cursor_position and not unit.has_acted:
			selected_unit = unit
			action_panel.visible = true
			update_status("Selected " + unit.unit_name + ". Choose action.")
			return
	
	update_status("No unit at cursor or unit already acted.")

func _on_move_pressed():
	if not selected_unit:
		return
	
	current_phase = TurnPhase.MOVE
	current_state = CombatState.PLAYER_SELECTING_TARGET
	action_panel.visible = false
	update_status("Select destination (range: " + str(selected_unit.move_range) + " tiles)")

func _on_attack_pressed():
	if not selected_unit:
		return
	
	current_phase = TurnPhase.ATTACK
	current_state = CombatState.PLAYER_SELECTING_TARGET
	action_panel.visible = false
	update_status("Select target to attack (range: " + str(selected_unit.attack_range) + " tiles)")

func _on_wait_pressed():
	if selected_unit:
		selected_unit.has_acted = true
		end_unit_turn()

func _on_flee_pressed():
	if randf() < 0.5:
		update_status("Fled from combat!")
		await get_tree().create_timer(1.0).timeout
		combat_ended.emit(false)
	else:
		update_status("Failed to flee!")
		end_turn()

func execute_move():
	if not selected_unit:
		return
	
	var distance = cursor_position.distance_to(selected_unit.grid_pos)
	
	if distance <= selected_unit.move_range and not is_position_occupied(cursor_position):
		selected_unit.grid_pos = cursor_position
		selected_unit.position = Vector2(cursor_position.x * GRID_SIZE, cursor_position.y * GRID_SIZE)
		update_status(selected_unit.unit_name + " moved.")
		end_unit_turn()
	else:
		update_status("Cannot move there!")
		cancel_target_selection()

func execute_attack():
	if not selected_unit:
		return
	
	var target = get_unit_at_position(cursor_position)
	var distance = cursor_position.distance_to(selected_unit.grid_pos)
	
	if target and not target.is_player and distance <= selected_unit.attack_range:
		var damage = selected_unit.attack_power + randi_range(-2, 2)
		target.take_damage(damage)
		update_status(selected_unit.unit_name + " attacks " + target.unit_name + " for " + str(damage) + " damage!")
		
		if target.current_hp <= 0:
			enemies.erase(target)
			target.queue_free()
			update_status(target.unit_name + " defeated!")
		
		selected_unit.has_acted = true
		await get_tree().create_timer(1.0).timeout
		end_unit_turn()
		check_victory()
	else:
		update_status("Invalid target!")
		cancel_target_selection()

func cancel_target_selection():
	current_state = CombatState.PLAYER_TURN
	current_phase = TurnPhase.SELECT_ACTION
	action_panel.visible = true
	update_status("Action cancelled. Choose another action.")

func end_unit_turn():
	selected_unit = null
	action_panel.visible = false
	current_state = CombatState.PLAYER_TURN
	current_phase = TurnPhase.SELECT_ACTION
	
	# Check if all player units have acted
	var all_acted = true
	for unit in player_units:
		if not unit.has_acted:
			all_acted = false
			break
	
	if all_acted:
		end_turn()
	else:
		update_status("Select next unit.")

func end_turn():
	# Reset player units
	for unit in player_units:
		unit.has_acted = false
	
	# Enemy turn
	current_state = CombatState.ENEMY_TURN
	update_status("Enemy turn...")
	await get_tree().create_timer(0.5).timeout
	execute_enemy_turn()

func execute_enemy_turn():
	for enemy in enemies:
		if enemy.current_hp <= 0:
			continue
		
		# Simple AI: move toward nearest player and attack if in range
		var nearest_player = find_nearest_player(enemy)
		if nearest_player:
			var distance = enemy.grid_pos.distance_to(nearest_player.grid_pos)
			
			if distance <= enemy.attack_range:
				# Attack
				var damage = enemy.attack_power + randi_range(-2, 2)
				nearest_player.take_damage(damage)
				update_status(enemy.unit_name + " attacks " + nearest_player.unit_name + " for " + str(damage) + " damage!")
				
				if nearest_player.current_hp <= 0:
					player_units.erase(nearest_player)
					nearest_player.queue_free()
					update_status(nearest_player.unit_name + " defeated!")
			else:
				# Move toward player
				var direction = (nearest_player.grid_pos - enemy.grid_pos).normalized()
				var new_pos = enemy.grid_pos + Vector2i(round(direction.x), round(direction.y))
				
				if not is_position_occupied(new_pos) and new_pos.x >= 0 and new_pos.x < GRID_WIDTH and new_pos.y >= 0 and new_pos.y < GRID_HEIGHT:
					enemy.grid_pos = new_pos
					enemy.position = Vector2(new_pos.x * GRID_SIZE, new_pos.y * GRID_SIZE)
			
			await get_tree().create_timer(0.5).timeout
	
	check_defeat()
	
	# Back to player turn
	current_state = CombatState.PLAYER_TURN
	update_status("Your turn!")

func find_nearest_player(enemy: CombatUnit) -> CombatUnit:
	var nearest: CombatUnit = null
	var min_distance = INF
	
	for player in player_units:
		var distance = enemy.grid_pos.distance_to(player.grid_pos)
		if distance < min_distance:
			min_distance = distance
			nearest = player
	
	return nearest

func is_position_occupied(pos: Vector2i) -> bool:
	for unit in player_units + enemies:
		if unit.grid_pos == pos:
			return true
	return false

func get_unit_at_position(pos: Vector2i) -> CombatUnit:
	for unit in player_units + enemies:
		if unit.grid_pos == pos:
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

func update_status(text: String):
	status_label.text = text
	print("Combat: ", text)

# Combat Unit Class
class CombatUnit extends Node2D:
	var unit_name: String
	var is_player: bool
	var grid_pos: Vector2i
	var max_hp: int = 20
	var current_hp: int = 20
	var attack_power: int = 5
	var defense: int = 2
	var move_range: int = 3
	var attack_range: int = 1
	var has_acted: bool = false
	
	var sprite: Sprite2D
	var hp_bar: ColorRect
	var name_label: Label
	
	func _init(name: String, player: bool):
		unit_name = name
		is_player = player
		
		if is_player:
			max_hp = 25
			current_hp = 25
			attack_power = 6
		else:
			max_hp = 15
			current_hp = 15
			attack_power = 4
	
	func _ready():
		# Create sprite
		sprite = Sprite2D.new()
		var img = Image.create(24, 24, false, Image.FORMAT_RGB8)
		img.fill(Color.BLUE if is_player else Color.RED)
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(16, 16)
		add_child(sprite)
		
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
