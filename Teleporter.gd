extends Area2D
class_name Teleporter

@export var destination_id: String = ""
@export var teleporter_id: Node = self
# The scene we want to teleport to
@export_file("*.tscn") var target_scene : String = ""
@export var auto_teleport: bool = false



var player_in_range: bool = false
var player: Node = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print ("Teleporter ", teleporter_id, " -> ", destination_id)

func _input(event):
	if player_in_range and player and destination_id and (auto_teleport or event.is_action_pressed("interact")):
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
	# stop any children activities before changing the scene
	_on_body_exited(player_node)
	
	
	var return_destination = destination_id
	var parent_node = player_node.get_parent()
	var destination = null
	# try local first
	if parent_node.has_node(return_destination):
		destination = parent_node.get_node(destination_id)
	# another map is specified
	if target_scene:
		var old_scene = get_tree().current_scene
		var new_scene:Node = load(target_scene).instantiate()
		get_tree().root.add_child(new_scene)
		get_tree().current_scene = new_scene
		get_tree().root.remove_child(old_scene)
		parent_node = new_scene
		destination = new_scene.get_node(return_destination)
		
		player_node.owner = null
		player_node.reparent(new_scene)
		old_scene.queue_free()
		if not destination:
			var nodes = []
			for node in new_scene.get_children():
				nodes.append(node.name)
			print ("Could not find : " , destination_id, " visible areas ", nodes)
		

	if destination:
		player_node.global_position = destination.global_position
		# Add teleport effects here
		print("parent_nodes ", parent_node.get_children())
