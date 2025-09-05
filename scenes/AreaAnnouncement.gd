extends Area2D
class_name AreaAnnouncement

@export var area_name: String = "Village"
@export var display_duration: float = 3.0
@export var offset_y: float = -50.0

var announcement_control: Control
var announcement_label: RichTextLabel
var textbox_script : Node
var player_in_area: bool = false
var tween:Tween 

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	tween = create_tween()
	create_announcement_ui()


func create_announcement_ui():
	# Create a Control container
	announcement_control = get_parent().get_node("hero").get_node("Camera2D").get_node("MarginContainer")
	textbox_script = announcement_control  # The script is attached to the MarginContainer
	# Create the label
	announcement_label = get_parent().get_node("hero").get_node("Camera2D").get_node("MarginContainer").get_node("VBoxContainer").get_node("body")
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	announcement_control.visible = false

func _on_body_entered(body):
	if body.name == "hero" and not player_in_area:
		player_in_area = true
		show_announcement()

func _on_body_exited(body):
	if body.name == "hero":
		player_in_area = false
		textbox_script.change_state(textbox_script.State.READY)

func show_announcement():
	if announcement_label and announcement_control and textbox_script:
		# Get camera for screen positioning
		var camera = get_viewport().get_camera_2d()
		var screen_center = get_viewport().size / 2
		var world_offset = Vector2.ZERO
		
		if camera:
			world_offset = global_position - camera.global_position
# Queue the text first
		textbox_script.queue_text(area_name)
		
		# Set up UI visibility
		announcement_control.visible = true
		announcement_label.visible = true
		announcement_label.get_parent().get_node("header").visible = false
		announcement_label.get_parent().get_node("footer").visible = false
		
		# Start with black text that's invisible (alpha = 0)
		announcement_label.modulate = Color(0, 0, 0, 1.0)
		
		# Slower fade in (2 seconds), then wait, then fade out
		#tween.tween_property(announcement_label, "modulate:a", 1.0, 2.0)  # fade in over 2 seconds
		tween.tween_interval(display_duration)  # wait for display_duration
		#tween.tween_property(announcement_label, "modulate:a", 0.0, 0.5)  # fade out
