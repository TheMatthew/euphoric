extends Camera2D
class_name FollowingCamera2D

const max_cam = 100000
const min_cam = -100000
@export var target:CharacterEntity = null
var tilemap : TileMapLayer = null
var bounding_box
var min_x:int = 0
var max_x:int = 1000
var min_y:int = 0
var max_y:int = 700
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not target:
		target = get_parent().get_node("hero")
	target.connect("moved", move_update)
	tilemap = get_tree().current_scene.get_node('TileMapLayer')
	bounding_box = get_bounding_box()
	min_x = bounding_box.position.x
	max_x = bounding_box.position.x + bounding_box.size.x
	min_y = bounding_box.position.y
	max_y = bounding_box.position.y + bounding_box.size.y
	make_current()
	
func get_bounding_box() -> Rect2:
	var min_x_cam = max_cam
	var min_y_cam = max_cam
	var max_x_cam = min_cam
	var max_y_cam = min_cam
	if not tilemap:
		return Rect2()
	var cells:Array[Vector2i] = tilemap.get_used_cells()
	var tile_size = tilemap.tile_set.tile_size
	for cell in cells:
		var x = cell.x
		var y = cell.y
		min_x_cam = min(min_x_cam, x)
		min_y_cam = min(min_y_cam, y)
		max_x_cam = max(max_x_cam, x)
		max_y_cam = max(max_y_cam, y)

	if min_x_cam == max_cam:  # No tiles found
		return Rect2()  # Return an empty Rect2

	# Calculate the bounding box
	return Rect2(Vector2(min_x_cam * tile_size.x+tilemap.position.x, min_y_cam * tile_size.y+tilemap.position.y), 
				  Vector2((max_x_cam - min_x_cam + 1) * tile_size.x, (max_y_cam - min_y_cam + 1) * tile_size.y))


func move_update():
	if bounding_box == Rect2():  # If the bounding box is empty, do nothing
		return

	var hero_position = target.position

	# Convert viewport size into world coordinates
	var viewport_size_gutter: Vector2 = Vector2(get_viewport().size) / zoom /2 

	var clamped_x: float = clamp(
		hero_position.x,
		bounding_box.position.x + viewport_size_gutter.x,
		bounding_box.position.x + bounding_box.size.x - viewport_size_gutter.x
	)

	var clamped_y: float = clamp(
		hero_position.y,
		bounding_box.position.y + viewport_size_gutter.y,
		bounding_box.position.y + bounding_box.size.y - viewport_size_gutter.y
	)
	print ("Camera " , clamped_x, clamped_y)
	position = Vector2(clamped_x, clamped_y)
