extends Node2D
class_name CombatSystem

const GRID_SIZE = 32
const GRID_WIDTH = 15
const GRID_HEIGHT = 11

enum CombatState {
	WAITING_FOR_ACTION,
	SELECTING_ATTACK_TARGET,
	ANIMATING,
	COMBAT_WON,
	COMBAT_LOST
}

var current_state: CombatState = CombatState.WAITING_FOR_ACTION
var initiative_order: Array[CombatUnit] = []
var current_unit_index: int = 0
var current_unit: CombatUnit = null

var tilemap: TileMapLayer
var cursor: Sprite2D
var status_label: Label
var initiative_panel: Panel
var initiative_list: VBoxContainer
var attack_cursor_position: Vector2i = Vector2i(0, 0)

var enemies: Array[CombatUnit] = []
var player_units: Array[CombatUnit] = []

# Enemy data loaded from JSON
static var enemy_db: Dictionary = {}
# Which enemies to spawn (set before adding to tree)
var encounter_enemies: Array[String] = []
# Overworld tile type string where encounter happened (set before adding to tree)
var overworld_tile: String = "4"

signal combat_ended(victory: bool)

func _ready():
	if enemy_db.is_empty():
		load_enemy_db()
	setup_tilemap()
	setup_ui()
	setup_cursor()
	spawn_combat_units()
	initialize_initiative()
	start_turn()

static func load_enemy_db():
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if file:
		enemy_db = JSON.parse_string(file.get_as_text())
		file.close()

# --- Setup ---

func setup_tilemap():
	tilemap = TileMapLayer.new()
	tilemap.name = "CombatGrid"
	tilemap.tile_set = create_combat_tileset()
	add_child(tilemap)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			tilemap.set_cell(Vector2i(x, y), get_terrain_for_position(x, y), Vector2i(0, 0), 0)

func create_combat_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(GRID_SIZE, GRID_SIZE)
	for i in range(4):
		var source = TileSetAtlasSource.new()
		source.texture = create_terrain_texture(i)
		source.texture_region_size = Vector2i(GRID_SIZE, GRID_SIZE)
		ts.add_source(source, i)
	return ts

func create_terrain_texture(terrain_type: int) -> ImageTexture:
	var img = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGB8)
	match terrain_type:
		0: img.fill(Color(0.3, 0.6, 0.3))  # Grass
		1: img.fill(Color(0.5, 0.5, 0.5))  # Stone/rock
		2: img.fill(Color(0.2, 0.4, 0.8))  # Water
		3: img.fill(Color(0.2, 0.35, 0.15)) # Dark grass/forest floor
		_: img.fill(Color(0.3, 0.6, 0.3))
	return ImageTexture.create_from_image(img)

func get_terrain_for_position(x: int, y: int) -> int:
	# Generate terrain based on overworld tile where encounter happened
	# 0=grass, 1=stone, 2=water, 3=dark grass
	match overworld_tile:
		"3":  # Swamp
			if randi() % 5 == 0: return 2  # Puddles
			if randi() % 3 == 0: return 3  # Muck
			return 0
		"4":  # Grass
			if (x + y) % 9 == 0: return 1  # Occasional rock
			return 0
		"5":  # Scrub
			if randi() % 4 == 0: return 1  # Rocky scrub
			if randi() % 6 == 0: return 3
			return 0
		"6":  # Forest
			if randi() % 3 == 0: return 3  # Dense undergrowth
			if randi() % 7 == 0: return 1  # Fallen log/rock
			return 0
		"7":  # Hill
			if randi() % 3 == 0: return 1  # Lots of rocks
			return 0
		"8":  # Mountain
			if randi() % 2 == 0: return 1  # Mostly stone
			if randi() % 5 == 0: return 0  # Patches of grass
			return 1
		_:  # Default (grass-like)
			if (x + y) % 7 == 0: return 1
			return 0

func setup_cursor():
	cursor = Sprite2D.new()
	cursor.name = "Cursor"
	var cursor_img = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	cursor_img.fill(Color(0, 0, 0, 0))
	for i in range(GRID_SIZE):
		cursor_img.set_pixel(i, 0, Color.YELLOW)
		cursor_img.set_pixel(i, GRID_SIZE - 1, Color.YELLOW)
		cursor_img.set_pixel(0, i, Color.YELLOW)
		cursor_img.set_pixel(GRID_SIZE - 1, i, Color.YELLOW)
	cursor.texture = ImageTexture.create_from_image(cursor_img)
	cursor.centered = false
	cursor.visible = false
	add_child(cursor)

func setup_ui():
	status_label = Label.new()
	status_label.position = Vector2(20, GRID_HEIGHT * GRID_SIZE + 5)
	status_label.custom_minimum_size = Vector2(GRID_WIDTH * GRID_SIZE - 40, 40)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)

	initiative_panel = Panel.new()
	initiative_panel.size = Vector2(200, 300)
	initiative_panel.position = Vector2(GRID_WIDTH * GRID_SIZE + 20, 20)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
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

# --- Spawning ---

func spawn_combat_units():
	# Single hero unit
	var hero_unit = CombatUnit.new("Hero", true, Global.inventory.equipped.get("weapon", "sword"))
	hero_unit.max_hp = Global.stats.max_hp
	hero_unit.current_hp = Global.stats.current_hp
	hero_unit.attack_power = Global.stats.attack_power
	hero_unit.defense = Global.stats.defense
	hero_unit.dex_modifier = Global.stats.initiative_mod
	hero_unit.hit_pct = Global.stats.hit_pct
	hero_unit.dodge_pct = Global.stats.dodge_pct
	hero_unit.grid_pos = Vector2i(3, 5)
	hero_unit.position = Vector2(3 * GRID_SIZE, 5 * GRID_SIZE)
	add_child(hero_unit)
	player_units.append(hero_unit)

	# Enemies from encounter data or defaults
	if encounter_enemies.is_empty():
		encounter_enemies = ["goblin"]

	var enemy_positions = [
		Vector2i(11, 5), Vector2i(12, 3), Vector2i(12, 7), Vector2i(13, 5)
	]
	for i in range(encounter_enemies.size()):
		var enemy_id = encounter_enemies[i]
		var data = enemy_db.get(enemy_id, {})
		if data.is_empty():
			continue
		var pos = enemy_positions[i % enemy_positions.size()]
		var unit = CombatUnit.new(data.get("name", enemy_id), false, data.get("weapon", "sword"))
		unit.max_hp = data.get("hp", 15)
		unit.current_hp = unit.max_hp
		unit.attack_power = data.get("attack", 4)
		unit.defense = data.get("defense", 0)
		unit.dex_modifier = data.get("dex", 0)
		unit.xp_value = data.get("xp", 5)
		unit.grid_pos = pos
		unit.position = Vector2(pos.x * GRID_SIZE, pos.y * GRID_SIZE)
		add_child(unit)
		enemies.append(unit)

# --- Initiative ---

func initialize_initiative():
	var all_units = player_units + enemies
	for unit in all_units:
		unit.initiative = randi_range(1, 20) + unit.dex_modifier
	all_units.sort_custom(func(a, b): return a.initiative > b.initiative)
	initiative_order = all_units
	current_unit_index = 0
	update_initiative_display()

func update_initiative_display():
	for child in initiative_list.get_children():
		child.queue_free()
	for i in range(initiative_order.size()):
		var unit = initiative_order[i]
		if unit.current_hp <= 0:
			continue
		var label = Label.new()
		label.text = "%s (%d)" % [unit.unit_name, unit.initiative]
		if i == current_unit_index:
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.text = "► " + label.text
		else:
			label.add_theme_color_override("font_color", Color.WHITE if unit.is_player else Color.RED)
		initiative_list.add_child(label)

# --- Turn flow ---

func start_turn():
	if current_unit_index >= initiative_order.size():
		current_unit_index = 0
	current_unit = initiative_order[current_unit_index]
	if current_unit.current_hp <= 0:
		next_turn()
		return
	current_unit.has_acted = false
	update_initiative_display()
	if current_unit.is_player:
		current_state = CombatState.WAITING_FOR_ACTION
		update_status("%s's turn! Arrows to move, A to attack, ESC to skip." % current_unit.unit_name)
	else:
		current_state = CombatState.ANIMATING
		update_status("%s's turn..." % current_unit.unit_name)
		await get_tree().create_timer(0.5).timeout
		execute_enemy_ai()

func next_turn():
	current_unit_index += 1
	start_turn()

func end_turn():
	current_unit.has_acted = true
	next_turn()

# --- Input ---

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
	if event.is_action_pressed("move_up"):
		attempt_move(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		attempt_move(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):
		attempt_move(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		attempt_move(Vector2i(1, 0))
	elif event.is_action_pressed("ui_combat"):
		start_attack_targeting()
	elif event.is_action_pressed("ui_cancel"):
		end_turn()

# --- Movement ---

func attempt_move(direction: Vector2i):
	var new_pos = current_unit.grid_pos + direction
	if new_pos.x < 0 or new_pos.x >= GRID_WIDTH or new_pos.y < 0 or new_pos.y >= GRID_HEIGHT:
		update_status("Can't move there!")
		return
	if is_position_occupied(new_pos):
		update_status("Space occupied!")
		return
	current_unit.grid_pos = new_pos
	current_unit.position = Vector2(new_pos.x * GRID_SIZE, new_pos.y * GRID_SIZE)
	if collect_chest_at_position(new_pos):
		await get_tree().create_timer(0.8).timeout
	await get_tree().create_timer(0.3).timeout
	end_turn()

# --- Attack targeting ---

func start_attack_targeting():
	current_state = CombatState.SELECTING_ATTACK_TARGET
	cursor.visible = true
	attack_cursor_position = current_unit.grid_pos
	update_cursor_position()
	update_status("Select target (arrows), Enter to attack, ESC to cancel.")

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
		current_state = CombatState.WAITING_FOR_ACTION
		cursor.visible = false
		update_status("%s's turn! Arrows to move, A to attack." % current_unit.unit_name)

func move_attack_cursor(delta: Vector2i):
	var new_pos = attack_cursor_position + delta
	if current_unit.grid_pos.distance_to(new_pos) <= current_unit.attack_range:
		attack_cursor_position = new_pos
		update_cursor_position()

func update_cursor_position():
	cursor.position = Vector2(attack_cursor_position.x * GRID_SIZE, attack_cursor_position.y * GRID_SIZE)

# --- Attack resolution with hit/miss ---

func resolve_attack(attacker: CombatUnit, defender: CombatUnit) -> Dictionary:
	# Hit roll: attacker.hit_pct vs defender.dodge_pct
	var hit_roll = randi_range(1, 100)
	var hit_chance = attacker.hit_pct - defender.dodge_pct
	if hit_roll > hit_chance:
		return {"hit": false, "damage": 0}
	var damage = maxi(1, attacker.attack_power + randi_range(-2, 2) - defender.defense)
	defender.take_damage(damage)
	return {"hit": true, "damage": damage}

func execute_attack():
	var target = get_unit_at_position(attack_cursor_position)
	if not target:
		update_status("No target there!")
		return
	if target.is_player:
		update_status("Can't attack allies!")
		return
	if current_unit.grid_pos.distance_to(attack_cursor_position) > current_unit.attack_range:
		update_status("Out of range!")
		return

	current_state = CombatState.ANIMATING
	cursor.visible = false
	await get_tree().create_timer(0.3).timeout

	var result = resolve_attack(current_unit, target)
	if not result.hit:
		update_status("%s attacks %s — Miss!" % [current_unit.unit_name, target.unit_name])
	else:
		update_status("%s hits %s for %d damage!" % [current_unit.unit_name, target.unit_name, result.damage])
		if target.current_hp <= 0:
			var target_name = target.unit_name
			var target_pos = target.grid_pos
			var target_xp = target.xp_value
			enemies.erase(target)
			target.queue_free()
			drop_loot_chest(target_pos)
			update_status("%s defeated! (+%d XP)" % [target_name, target_xp])
			Global.stats.xp += target_xp
			check_victory()

	await get_tree().create_timer(0.8).timeout
	if current_state != CombatState.COMBAT_WON:
		end_turn()

# --- Enemy AI ---

func execute_enemy_ai():
	var nearest = find_nearest_player(current_unit)
	if not nearest:
		end_turn()
		return

	var distance = current_unit.grid_pos.distance_to(nearest.grid_pos)
	if distance <= current_unit.attack_range:
		var result = resolve_attack(current_unit, nearest)
		if not result.hit:
			update_status("%s attacks %s — Miss!" % [current_unit.unit_name, nearest.unit_name])
		else:
			update_status("%s hits %s for %d!" % [current_unit.unit_name, nearest.unit_name, result.damage])
			if nearest.current_hp <= 0:
				player_units.erase(nearest)
				nearest.queue_free()
				check_defeat()
	else:
		var dir = Vector2(nearest.grid_pos - current_unit.grid_pos).normalized()
		var new_pos = current_unit.grid_pos + Vector2i(round(dir.x), round(dir.y))
		if not is_position_occupied(new_pos) and new_pos.x >= 0 and new_pos.x < GRID_WIDTH and new_pos.y >= 0 and new_pos.y < GRID_HEIGHT:
			current_unit.grid_pos = new_pos
			current_unit.position = Vector2(new_pos.x * GRID_SIZE, new_pos.y * GRID_SIZE)
			update_status("%s moves closer." % current_unit.unit_name)

	await get_tree().create_timer(0.8).timeout
	next_turn()

func find_nearest_player(enemy: CombatUnit) -> CombatUnit:
	var nearest: CombatUnit = null
	var min_dist = INF
	for p in player_units:
		if p.current_hp <= 0:
			continue
		var d = enemy.grid_pos.distance_to(p.grid_pos)
		if d < min_dist:
			min_dist = d
			nearest = p
	return nearest

# --- Utility ---

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
		# Sync HP back to Global
		if player_units.size() > 0:
			Global.stats.current_hp = player_units[0].current_hp
		current_state = CombatState.COMBAT_WON
		update_status("Victory! Press Enter to continue.")

func check_defeat():
	if player_units.size() == 0:
		current_state = CombatState.COMBAT_LOST
		update_status("Defeat! Press Enter to continue.")

func drop_loot_chest(pos: Vector2i):
	var chest = LootChest.new()
	chest.position = Vector2(pos.x * GRID_SIZE, pos.y * GRID_SIZE)
	chest.grid_pos = pos
	chest.gold = randi_range(1, 10)
	var roll = randi_range(1, 100)
	if roll <= 20: chest.item = "dagger"
	elif roll <= 40: chest.item = "sword"
	elif roll <= 60: chest.item = "shield"
	elif roll <= 80: chest.item = "bow"
	elif roll <= 90: chest.item = "ring"
	add_child(chest)

func collect_chest_at_position(pos: Vector2i) -> bool:
	for child in get_children():
		if child is LootChest and child.grid_pos == pos:
			var loot_text = "%d gold" % child.gold
			if child.item:
				loot_text += " and a %s" % child.item
				Global.inventory.add_item(child.item, 1)
			Global.inventory.gold += child.gold
			update_status("Collected: %s!" % loot_text)
			child.queue_free()
			return true
	return false

func update_status(text: String):
	status_label.text = text

# --- Loot Chest ---

class LootChest extends Node2D:
	var grid_pos: Vector2i
	var gold: int = 0
	var item: String = ""

	func _ready():
		var sprite = Sprite2D.new()
		var img = Image.create(28, 28, false, Image.FORMAT_RGB8)
		for y in range(28):
			for x in range(28):
				img.set_pixel(x, y, Color(0.4, 0.25, 0.1) if y < 14 else Color(0.35, 0.2, 0.05))
		for x in range(10, 18):
			for y in range(12, 16):
				img.set_pixel(x, y, Color(0.8, 0.7, 0.2))
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(16, 16)
		add_child(sprite)

# --- Combat Unit ---

class CombatUnit extends Node2D:
	var unit_name: String
	var is_player: bool
	var grid_pos: Vector2i
	var max_hp: int = 20
	var current_hp: int = 20
	var attack_power: int = 5
	var defense: int = 2
	var dex_modifier: int = 0
	var hit_pct: int = 70
	var dodge_pct: int = 5
	var initiative: int = 0
	var has_acted: bool = false
	var weapon_type: String = "sword"
	var attack_range: int = 1
	var xp_value: int = 0

	var hp_bar: ColorRect

	func _init(p_name: String, player: bool, weapon: String = "sword"):
		unit_name = p_name
		is_player = player
		weapon_type = weapon
		match weapon_type:
			"bow": attack_range = 4
			"spear": attack_range = 2
			_: attack_range = 1

	func _ready():
		var sprite = Sprite2D.new()
		var img = Image.create(24, 24, false, Image.FORMAT_RGB8)
		img.fill(Color.BLUE if is_player else Color.RED)
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(16, 16)
		add_child(sprite)

		hp_bar = ColorRect.new()
		hp_bar.size = Vector2(28, 4)
		hp_bar.position = Vector2(2, 2)
		hp_bar.color = Color.GREEN if is_player else Color.ORANGE_RED
		add_child(hp_bar)

		var label = Label.new()
		label.text = unit_name
		label.position = Vector2(-10, -15)
		label.add_theme_font_size_override("font_size", 8)
		add_child(label)

	func take_damage(damage: int):
		current_hp -= damage
		update_hp_bar()

	func update_hp_bar():
		var ratio = float(current_hp) / float(max_hp)
		hp_bar.size.x = 28 * ratio
		if ratio > 0.6: hp_bar.color = Color.GREEN
		elif ratio > 0.3: hp_bar.color = Color.YELLOW
		else: hp_bar.color = Color.RED
