# fog_of_war.gd
# Dither-based fog of war with raycasted lighting, emissive tiles, and time-of-day support.
# Only creates fog sprites in a window around the hero for performance.
extends Node2D
class_name FogOfWar

const TILE_SIZE = 32
const SIGHT_RANGE = 8
# How many tiles beyond sight range to render fog (covers viewport)
const FOG_PADDING = 14
const FOG_RADIUS = SIGHT_RANGE + FOG_PADDING

const DITHER_LEVELS = 8
const REMEMBERED_LEVEL = 1

# Tiles that block light rays
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

# Emissive tiles: tile_source_id -> { "range": int, "strength": float }
var emissive_tiles: Dictionary = {
	28: { "range": 5, "strength": 0.8 },  # Spit (campfire)
}

# Time of day: 0.0 = noon (no fog), 1.0 = midnight (full falloff)
var time_falloff: float = 1.0

# --- Internal state ---
var tilemap: TileMapLayer = null
var hero: CharacterBody2D = null
var last_hero_grid_pos: Vector2i = Vector2i(-999, -999)

var dither_textures: Array[ImageTexture] = []
# grid_pos -> Sprite2D (only for tiles in the active window)
var fog_sprites: Dictionary = {}
# grid_pos -> true (ever seen, persists across moves and scene changes)
var revealed_tiles: Dictionary = {}
# Pool of reusable sprite nodes
var sprite_pool: Array[Sprite2D] = []

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
		rebuild_fog_window()

func find_references():
	hero = get_tree().current_scene.get_node_or_null("hero")
	if not hero:
		hero = get_tree().current_scene.get_node_or_null("Hero/hero")
	tilemap = get_tree().current_scene.get_node_or_null("TileMapLayer")

func cache_map_bounds():
	var cells = tilemap.get_used_cells()
	if cells.size() == 0:
		return
	var mn_x: float = INF
	var mn_y: float = INF
	var mx_x: float = -INF
	var mx_y: float = -INF
	for cell in cells:
		mn_x = min(mn_x, cell.x)
		mn_y = min(mn_y, cell.y)
		mx_x = max(mx_x, cell.x)
		mx_y = max(mx_y, cell.y)
	map_min = Vector2i(int(mn_x), int(mn_y))
	map_max = Vector2i(int(mx_x), int(mx_y))

# --- Bayer dither texture generation ---

func generate_dither_textures():
	var bayer := [
		[ 0,  8,  2, 10],
		[12,  4, 14,  6],
		[ 3, 11,  1,  9],
		[15,  7, 13,  5],
	]
	dither_textures.clear()
	for level in range(DITHER_LEVELS):
		var threshold: float = float(level) / float(DITHER_LEVELS - 1) * 16.0
		var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				var bayer_val = bayer[y % 4][x % 4]
				if float(bayer_val) < threshold:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0.95))
		dither_textures.append(ImageTexture.create_from_image(img))

# --- Sprite pool ---

func acquire_sprite() -> Sprite2D:
	while sprite_pool.size() > 0:
		var spr = sprite_pool.pop_back()
		if is_instance_valid(spr):
			spr.visible = true
			return spr
	var spr = Sprite2D.new()
	spr.centered = false
	spr.z_index = 40
	get_tree().current_scene.add_child(spr)
	return spr

func release_sprite(spr: Sprite2D):
	if is_instance_valid(spr):
		spr.visible = false
		sprite_pool.append(spr)
	

# --- Fog window management ---

func rebuild_fog_window():
	if not is_instance_valid(hero) or not is_instance_valid(tilemap):
		return
	var center = tilemap.local_to_map(tilemap.to_local(hero.global_position))
	last_hero_grid_pos = center

	# Determine new window bounds
	var win_min_x = maxi(center.x - FOG_RADIUS, map_min.x)
	var win_max_x = mini(center.x + FOG_RADIUS, map_max.x)
	var win_min_y = maxi(center.y - FOG_RADIUS, map_min.y)
	var win_max_y = mini(center.y + FOG_RADIUS, map_max.y)

	# Collect tiles that should be in the window
	var needed: Dictionary = {}
	for y in range(win_min_y, win_max_y + 1):
		for x in range(win_min_x, win_max_x + 1):
			needed[Vector2i(x, y)] = true

	# Release sprites outside the new window
	var to_remove: Array = []
	for gp in fog_sprites:
		if not needed.has(gp):
			to_remove.append(gp)
	for gp in to_remove:
		release_sprite(fog_sprites[gp])
		fog_sprites.erase(gp)

	# Create sprites for new tiles in the window
	for gp in needed:
		if not fog_sprites.has(gp):
			var spr = acquire_sprite()
			var level = REMEMBERED_LEVEL if revealed_tiles.has(gp) else 0
			spr.texture = dither_textures[level]
			var world_pos = tilemap.map_to_local(gp)
			world_pos.x -= TILE_SIZE / 2.0
			world_pos.y -= TILE_SIZE / 2.0
			spr.global_position = tilemap.to_global(world_pos)
			spr.visible = true
			fog_sprites[gp] = spr

	# Now compute lighting
	update_lighting(center)

# --- Main update loop ---

func _process(_delta):
	if not is_instance_valid(hero) or not is_instance_valid(tilemap):
		return
	var hero_grid_pos = tilemap.local_to_map(tilemap.to_local(hero.global_position))
	if hero_grid_pos != last_hero_grid_pos:
		rebuild_fog_window()

func update_lighting(hero_grid_pos: Vector2i):
	var light_map: Dictionary = {}

	# Hero light
	cast_light_from(hero_grid_pos, SIGHT_RANGE, 1.0, light_map)

	# Emissive tiles (only check tiles in our window)
	for gp in fog_sprites:
		var tile_id = tilemap.get_cell_source_id(gp)
		if emissive_tiles.has(tile_id):
			var info = emissive_tiles[tile_id]
			cast_light_from(gp, info.get("range", 4), info.get("strength", 0.6), light_map)

	# Apply to sprites
	for gp in fog_sprites:
		var raw_brightness: float = light_map.get(gp, 0.0)
		var effective: float = lerpf(1.0, raw_brightness, time_falloff)
		var level = int(round(effective * float(DITHER_LEVELS - 1)))

		if effective > 0.05:
			revealed_tiles[gp] = true

		if level <= 0 and revealed_tiles.has(gp):
			level = REMEMBERED_LEVEL

		level = clampi(level, 0, DITHER_LEVELS - 1)
		var spr = fog_sprites[gp]
		if not is_instance_valid(spr):
			fog_sprites.erase(gp)
			continue 
		if level >= DITHER_LEVELS - 1:
			spr.visible = false
		else:
			spr.visible = true
			spr.texture = dither_textures[level]

# --- Raycasting light ---

func cast_light_from(origin: Vector2i, max_range: int, strength: float, light_map: Dictionary):
	var current = light_map.get(origin, 0.0)
	light_map[origin] = maxf(current, strength)

	for angle_deg in range(0, 360, 3):
		var angle_rad = deg_to_rad(angle_deg)
		var ray_dir = Vector2(cos(angle_rad), sin(angle_rad))
		var distance = 0.0

		while distance < max_range:
			distance += 0.4
			var pos = Vector2(origin.x, origin.y) + ray_dir * distance
			var gp = Vector2i(int(round(pos.x)), int(round(pos.y)))

			if gp.x < map_min.x or gp.x > map_max.x or gp.y < map_min.y or gp.y > map_max.y:
				break

			var falloff_val = 1.0 - (distance / float(max_range))
			var brightness = strength * maxf(falloff_val, 0.0)

			var prev = light_map.get(gp, 0.0)
			if brightness > prev:
				light_map[gp] = brightness

			var tile_id = tilemap.get_cell_source_id(gp)
			if light_blocking_tiles.has(tile_id):
				break

# --- Scene transition support ---

func refresh_for_new_scene():
	# Return all sprites to pool — they're children of the old scene and now invalid
	for spr in fog_sprites.values():
		if is_instance_valid(spr):
			spr.queue_free()
	fog_sprites.clear()
	# Also clear the pool — those sprites are from the old scene too
	for spr in sprite_pool:
		if is_instance_valid(spr):
			spr.queue_free()
	sprite_pool.clear()
	last_hero_grid_pos = Vector2i(-999, -999)
	hero = null
	tilemap = null

	await get_tree().process_frame
	find_references()
	if hero and tilemap:
		cache_map_bounds()
		rebuild_fog_window()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for spr in fog_sprites.values():
			if is_instance_valid(spr):
				spr.queue_free()
		fog_sprites.clear()
		for spr in sprite_pool:
			if is_instance_valid(spr):
				spr.queue_free()
		sprite_pool.clear()
		if instance == self:
			instance = null
