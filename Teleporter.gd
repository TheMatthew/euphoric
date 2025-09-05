extends Area2D
class_name Teleporter

@export var destination_id: String = ""
@export var teleporter_id: String = ""

var player_in_range: bool = false
var player: Node = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _input(event):
	if player_in_range and player and event.is_action_pressed("interact"):
		teleport_player(player)

func _on_body_entered(body):
	if body.name == "hero":
		player_in_range = true
		player = body

func _on_body_exited(body):
	if body.name == "hero":
		player_in_range = false
		player = null

func teleport_player(player_node):
	var destination = find_destination()
	if destination:
		player_node.global_position = destination.global_position + Vector2(0,-6)
		# Add teleport effects here

func find_destination():
	return get_parent().find_child(destination_id)
