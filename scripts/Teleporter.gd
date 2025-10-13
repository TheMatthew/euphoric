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
# Update your Teleporter.gd teleport_player function

func teleport_player(player_node):
	# stop any children activities before changing the scene
	_on_body_exited(player_node)
	
	var camera:FollowingCamera2D = get_tree().current_scene.get_node("Camera2D")
		
	var return_destination = destination_id
	var parent_node = player_node.get_parent()
	var destination = null
	# try local first
	if parent_node.has_node(return_destination):
		destination = parent_node.get_node(destination_id)
	# another map is specified
	if target_scene:
		var old_scene = get_tree().current_scene
		var new_scene = load(target_scene).instantiate()
		get_tree().root.add_child(new_scene)
		get_tree().current_scene = new_scene
		get_tree().root.remove_child(old_scene)
		parent_node = new_scene
		destination = new_scene.get_node(return_destination)
		
		camera.reparent(new_scene)
		player_node.reparent(new_scene)
		old_scene.queue_free()
		
		# Refresh fog of war for new scene using the singleton instance
		var fog = camera.get_node_or_null("FogOfWar")
		if fog and fog.has_method("refresh_for_new_scene"):
			fog.call_deferred("refresh_for_new_scene")
			print("Teleporter: Refreshing fog of war")
		
		if not destination:
			var nodes = []
			for node in new_scene.get_children():
				nodes.append(node.name)
			push_error("Could not find : " , destination_id, " visible areas ", nodes)
	if destination:
		player_node.global_position = destination.global_position
		camera._ready()
		camera.move_update()
		# Add teleport effects here
		player_node.has_moved = false
		print("parent_nodes ", parent_node.get_children())
