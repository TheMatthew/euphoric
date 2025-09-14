extends AnimatedSprite2D
class_name LocalAnimatedSprite

# Exported variable to load the image file
@export var cell_image: Texture2D
# Number of cells in the image
@export var num_cells: int  = -1

@export var size_x: int = -1
@export var size_y: int = -1

var anim_name = "default"

func _init() -> void:
	sprite_frames = SpriteFrames.new()

func _ready() -> void:
	if not cell_image:
		push_error("cell_image not set")
	setup()
	play(anim_name)

# Function to create an animated texture from the cell image
func setup():
	# Load the image from the texture
	var image = cell_image.get_image()
	
	# Calculate the number of rows and columns
	if anim_name not in sprite_frames.get_animation_names():
		sprite_frames.add_animation(anim_name)
	var size = image.get_size()
	if size_y == -1:
		size_y = size[1]
	if size_x == -1:
		size_x = size[1] # assume square
	if num_cells == -1:
		num_cells = int(float(size[0])/ size_x)
	# Create frames from the image
	for i in range(num_cells):
		var current_frame = Image.create(size_x, size_y, false, Image.FORMAT_RGBA8)
		
		# Use blit_rect to copy the cell from the original image
		var rect = Rect2(i * size_x, 0, size_x, size_y)
		current_frame.blit_rect(image, rect, Vector2i(0, 0))
		sprite_frames.add_frame(anim_name, ImageTexture.create_from_image(current_frame), randf() * .5 + .5, -1)
	sprite_frames.set_animation_loop(anim_name, true)
	print("Sprite Frames ", sprite_frames, " anims " , sprite_frames.get_animation_names())
