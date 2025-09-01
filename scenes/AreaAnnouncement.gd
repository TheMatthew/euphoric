extends Area2D
class_name AreaAnnouncement

@export var area_name: String = "Village"
@export var display_duration: float = 3.0
@export var offset_y: float = -50.0

var announcement_control: Control
var announcement_label: Label
var player_in_area: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	create_announcement_ui()

func create_announcement_ui():
	# Create a Control container
	announcement_control = Control.new()
	announcement_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create the label
	announcement_label = Label.new()
	announcement_label.text = area_name
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_label.size = Vector2(300, 60)
	
	# Style the label
	announcement_label.add_theme_font_size_override("font_size", 24)
	announcement_label.add_theme_color_override("font_color", Color.WHITE)
	announcement_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	announcement_label.add_theme_constant_override("shadow_offset_x", 2)
	announcement_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Add label to control
	announcement_control.add_child(announcement_label)
	
	# Add to scene tree
	get_tree().current_scene.add_child(announcement_control)
	announcement_control.visible = false

func _on_body_entered(body):
	if body.name == "hero" and not player_in_area:
		player_in_area = true
		show_announcement()

func _on_body_exited(body):
	if body.name == "hero":
		player_in_area = false

func show_announcement():
	if announcement_label and announcement_control:
		# Get camera for screen positioning
		var camera = get_viewport().get_camera_2d()
		var screen_center = get_viewport().size / 2
		var world_offset = Vector2.ZERO
		
		if camera:
			world_offset = global_position - camera.global_position
		
		var final_pos = Vector2i(screen_center) + Vector2i(world_offset) + Vector2i(0, offset_y)
		
		# Position the label within the control
		announcement_label.position = Vector2(
			final_pos.x - announcement_label.size.x / 2,
			final_pos.y - announcement_label.size.y / 2
		)
		print("Positioning at: ", announcement_label.position)
		announcement_control.visible = true

		announcement_label.modulate = Color.RED 
