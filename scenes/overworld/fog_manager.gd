# fog_manager.gd - Standalone fog of war manager
extends Node2D
class_name FogManager

@export var tilemap_path: NodePath
@export var sight_range: int = 6

var fog_of_war: Node = null
var tilemap: TileMapLayer = null
var map_width: int = 0
var map_height: int = 0

func _ready():
	# Get the tilemap reference
	if tilemap_path:
		tilemap = get_node(tilemap_path)
	else:
		tilemap = get_parent() as TileMapLayer
	
	if not tilemap:
		print("ERROR: FogManager could not find TileMapLayer")
		return
	
	setup_fog_of_war()

func setup_fog_of_war():
	"""Initialize fog of war system"""
	# Calculate map dimensions from used cells
	var cells = tilemap.get_used_cells()
	if cells.size() == 0:
		print("No cells found, skipping fog of war")
		return
	
	# Find map bounds
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	
	for cell in cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	
	map_width = int(max_x - min_x + 1)
	map_height = int(max_y - min_y + 1)
	
	print("FogManager map dimensions: ", map_width, "x", map_height)
	
	# Load fog of war script
	var FogOfWarScript = load("res://scripts/fog_of_war.gd")
	if not FogOfWarScript:
		print("ERROR: Could not load fog_of_war.gd")
		return
	
	fog_of_war = FogOfWarScript.new(tilemap, map_width, map_height)
	add_child(fog_of_war)
	
	print("Fog of War initialized")

func update_fog_for_hero(hero_pos: Vector2i):
	"""Update fog of war based on hero position"""
	if fog_of_war and fog_of_war.has_method("update_visibility"):
		fog_of_war.update_visibility(hero_pos, sight_range)
