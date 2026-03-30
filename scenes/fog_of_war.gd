# fog_of_war.gd
# Dither-based fog of war with raycasted lighting, emissive tiles, and time-of-day support.
# Attach to a Node2D under Camera2D (or anywhere in the scene tree).
extends Node2D
class_name FogOfWar

const TILE_SIZE = 32
const SIGHT_RANGE = 8

# 8 dither levels: 0 = fully dark, 7 = fully lit (invisible overlay)
const DITHER_LEVELS = 8
# Remembered (previously seen but out of range) tiles show at this level
const REMEMBERED_LEVEL = 1

# --- Configurable blocking and emissive tile sets ---
# Tiles that block light rays. Edit as needed.
# Village tileset source IDs:
#   19=stone_wall, 20=door_locked, 25=white_solid, 59=blank, 60=brick_wall, 61=secret_passage
# Overworld tileset source IDs:
#   6=forest, 8=mountain
var light_blocking_tiles: Dictionary = {
	6: true,    # Forest
	8: true,    # Mountain
	19: true,   # Stone wall
	20: true,   # Door (locked)
	25: true,   # White solid (wall)
	59: true,   # Blank (wall)
	60: true,   # Brick wall
	61: true,   # Secret passage
}

# Emissive tiles: tile_source_id -> { "range": int, "strength": float (0-1) }
# Village tileset: 28=spit (campfire/fireplace)
# When lava (076) or field_fire (070) are added to a tileset, add their source IDs here.
var emissive_tiles: Dictionary = {
	28: { "range": 5, "strength": 0.8 },  # Spit (campfire)
}

# --- Time of day ---
# 0.0 = no falloff (noon, everything lit), 1.0 = max falloff (midnight)
var time_falloff: float = 1.0  # TODO: wire to time-of-day system. 0.0=noon, 1.0=midnight

# --- Internal state ---
var tilemap: TileMapLayer = null
var hero: CharacterBody2D = null
var last_hero_grid_pos: Vector2i = Vector2i(-999, -999)

var dither_textures: Array[ImageTexture] = []
# grid_pos -> Sprite2D
var fog_sprites: Dictionary = {}
# grid_pos -> current dither level (int 0-7)
var tile_light_level: Dictionary = {}
# grid_pos -> true (ever seen)
var revealed_tiles: Dictionary = {}

# Map bounds cache
var map_min: Vector2i
var map_max: Vector2i

static var instance: FogOfWar = null

func _ready():
	if instance == null:
		instance = self
		process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		queue_free()
		return

	z_index = 40
	generate_dither_textures()

	await get_tree().process_frame
	find_references()
	if hero and tilemap:
		cache_map_bounds()
		generate_initial_fog()

func find_references():
	hero = get_tree().current_scene.get_node_or_null("hero")
	if not hero:
		hero = get_tree().current_scene.get_node_or_null("Hero/hero")
	tilemap = get_tree().current_scene.get_node_or_null("TileMapLayer")

func cache_map_bounds():
	var cells = tilemap.get_used_cells()
	if cells.size() == 0:
		return
	var mn_x = INF
	var mn_y = INF
	var mx_x = -INF
	var mx_y = -INF
	for cell in cells:
		mn_x = min(mn_x, cell.x)
		mn_y = min(mn_y, cell.y)
		mx_x = max(mx_x, cell.x)
		mx_y = max(mx_y, cell.y)
	map_min = Vector2i(int(mn_x), int(mn_y))
	map_max = Vector2i(int(mx_x), int(mx_y))

# --- Bayer dither texture generation ---

func generate_dither_textures():
	# 4x4 Bayer matrix (normalized 0-15)
	var bayer := [
		[ 0,  8,  2, 10],
		[12,  4, 14,  6],
		[ 3, 11,  1,  9],
		[15,  7, 13,  5],
	]

	dither_textures.clear()
	for level in range(DITHER_LEVELS):
		# level 0 = fully dark, level 7 = fully transparent
		# threshold: how many of the 16 bayer cells should be transparent
		var threshold: float = float(level) / float(DITHER_LEVELS - 1) * 16.0
		var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)

		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				var bayer_val = bayer[y % 4][x % 4]
				if float(bayer_val) < threshold:
					img.set_pixel(x, y, Color(0, 0, 0, 0))  # transparent
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0.95))  # dark
		dither_textures.append(ImageTexture.create_from_image(img))

# --- Fog sprite management ---

func generate_initial_fog():
	# Clear existing fog sprites
	for spr in fog_sprites.values():
		if is_instance_valid(spr):
			spr.queue_free()
	fog_sprites.clear()
	tile_light_level.clear()

	for y in range(map_min.y, map_max.y + 1):
		for x in range(map_min.x, map_max.x + 1):
			var gp = Vector2i(x, y)
			if revealed_tiles.has(gp):
				# Previously seen: show at remembered level
				create_fog_sprite(gp, REMEMBERED_LEVEL)
			else:
				create_fog_sprite(gp, 0)

func create_fog_sprite(grid_pos: Vector2i, level: int):
	var spr = Sprite2D.new()
	spr.centered = false
	spr.z_index = 40
	spr.texture = dither_textures[level]
	var world_pos = tilemap.map_to_local(grid_pos)
	world_pos.x -= TILE_SIZE / 2.0
	world_pos.y -= TILE_SIZE / 2.0
	spr.global_position = tilemap.to_global(world_pos)
	get_tree().current_scene.add_child(spr)
	fog_sprites[grid_pos] = spr
	tile_light_level[grid_pos] = level

func set_tile_level(grid_pos: Vector2i, level: int):
	level = clampi(level, 0, DITHER_LEVELS - 1)
	if not fog_sprites.has(grid_pos):
		return
	if tile_light_level.get(grid_pos, -1) == level:
		return
	tile_light_level[grid_pos] = level
	var spr = fog_sprites[grid_pos]
	if is_instance_valid(spr):
		if level >= DITHER_LEVELS - 1:
			spr.visible = false
		else:
			spr.visible = true
			spr.texture = dither_textures[level]

# --- Main update loop ---

func _process(_delta):
	if not is_instance_valid(hero) or not is_instance_valid(tilemap):
		return
	var hero_world_pos = hero.global_position
	var hero_grid_pos = tilemap.local_to_map(tilemap.to_local(hero_world_pos))
	if hero_grid_pos != last_hero_grid_pos:
		last_hero_grid_pos = hero_grid_pos
		update_lighting(hero_grid_pos)

func update_lighting(hero_grid_pos: Vector2i):
	# Build a light map: grid_pos -> float brightness (0.0 to 1.0)
	var light_map: Dictionary = {}

	# 1) Hero light source
	cast_light_from(hero_grid_pos, SIGHT_RANGE, 1.0, light_map)

	# 2) Emissive tile light sources
	for gp in fog_sprites.keys():
		var tile_id = tilemap.get_cell_source_id(gp)
		if emissive_tiles.has(tile_id):
			var info = emissive_tiles[tile_id]
			cast_light_from(gp, info.get("range", 4), info.get("strength", 0.6), light_map)

	# 3) Apply time-of-day: at falloff=0 everything is fully lit
	# At falloff=1 only light_map matters. Blend: effective = lerp(1.0, light_val, time_falloff)
	# So at noon (falloff=0) every tile = 1.0 brightness

	# 4) Set dither levels on all fog tiles
	for gp in fog_sprites.keys():
		var raw_brightness: float = light_map.get(gp, 0.0)
		var effective: float = lerpf(1.0, raw_brightness, time_falloff)

		# Convert brightness (0-1) to dither level (0 to DITHER_LEVELS-1)
		var level = int(round(effective * float(DITHER_LEVELS - 1)))

		if effective > 0.05:
			revealed_tiles[gp] = true

		# If tile was revealed but now out of light, show remembered level
		if level <= 0 and revealed_tiles.has(gp):
			level = REMEMBERED_LEVEL

		set_tile_level(gp, level)

# --- Raycasting light ---

func cast_light_from(origin: Vector2i, max_range: int, strength: float, light_map: Dictionary):
	# Always light the origin tile
	var current = light_map.get(origin, 0.0)
	light_map[origin] = maxf(current, strength)

	# Cast rays every 3 degrees
	for angle_deg in range(0, 360, 3):
		var angle_rad = deg_to_rad(angle_deg)
		var ray_dir = Vector2(cos(angle_rad), sin(angle_rad))
		var step_size = 0.4
		var distance = 0.0

		while distance < max_range:
			distance += step_size
			var pos = Vector2(origin.x, origin.y) + ray_dir * distance
			var gp = Vector2i(int(round(pos.x)), int(round(pos.y)))

			# Out of map bounds
			if gp.x < map_min.x or gp.x > map_max.x or gp.y < map_min.y or gp.y > map_max.y:
				break

			# Brightness falls off linearly with distance
			var falloff = 1.0 - (distance / float(max_range))
			var brightness = strength * maxf(falloff, 0.0)

			var prev = light_map.get(gp, 0.0)
			if brightness > prev:
				light_map[gp] = brightness

			# Stop ray if tile blocks light
			var tile_id = tilemap.get_cell_source_id(gp)
			if light_blocking_tiles.has(tile_id):
				break

# --- Scene transition support ---

func refresh_for_new_scene():
	# Clear stale sprite references — they were children of the old scene and are now freed
	fog_sprites.clear()
	tile_light_level.clear()
	last_hero_grid_pos = Vector2i(-999, -999)
	hero = null
	tilemap = null

	await get_tree().process_frame
	find_references()
	if hero and tilemap:
		cache_map_bounds()
		generate_initial_fog()
		var hero_world_pos = hero.global_position
		var hero_grid_pos = tilemap.local_to_map(tilemap.to_local(hero_world_pos))
		update_lighting(hero_grid_pos)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for spr in fog_sprites.values():
			if is_instance_valid(spr):
				spr.queue_free()
		fog_sprites.clear()
		if instance == self:
			instance = null
