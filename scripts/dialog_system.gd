extends Node

class_name dialog_system
# Dialog State Machine
enum DialogState {
	READY,
	DIRECTION,
	DIALOG
}
signal dialog_finished(person:String)
# Dialog UI nodes
var dialog_panel: Panel
var npc_name_label: Label
var dialog_text_label: RichTextLabel
var input_field: LineEdit
var response_buttons: VBoxContainer
var current_npc:npc_node = null

# State machine variables
var dialog_state: DialogState = DialogState.READY
var talk_timer: Timer
var talk_prompt_label: Label
var hero_node: CharacterEntity

var dynamic_font:Font = load("res://res/blackchancery.regular.ttf")
# Signals
signal dialog_closed
signal state_changed(new_state: DialogState)

func _ready():
	setup_state_machine()

func setup_state_machine():
	# Create talk timer for DIRECTION state timeout
	talk_timer = Timer.new()
	talk_timer.wait_time = 3.0  # 3 seconds to press direction after T
	talk_timer.one_shot = true
	talk_timer.connect("timeout", _on_talk_timer_timeout)
	add_child(talk_timer)
	
	# Get reference to hero
	hero_node = get_tree().current_scene.get_node('hero')

func create_dialog_ui():
	var camera:FollowingCamera2D = get_tree().current_scene.get_node("Camera2D")
	# Create main dialog panel
	dialog_panel = Panel.new()
	dialog_panel.size = Vector2(600, 300)
	
	
	dialog_panel.position = camera.position - (dialog_panel.size / 2)
	dialog_panel.visible = false
	dialog_panel.z_index = 10
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.6, 0.8, 1.0)
	dialog_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create VBox container
	var vbox = VBoxContainer.new()
	vbox.size = dialog_panel.size - Vector2(20,20)
	vbox.position = Vector2(10, 10)
	dialog_panel.add_child(vbox)
	
	# NPC name label
	npc_name_label = Label.new()
	npc_name_label.text = "NPC Name"
	npc_name_label.add_theme_font_size_override("font_size", 18)
	npc_name_label.add_theme_font_override("",dynamic_font)
	npc_name_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(npc_name_label)
	
	# Separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Dialog text area
	dialog_text_label = RichTextLabel.new()
	dialog_text_label.custom_minimum_size = Vector2(560, 180)
	dialog_text_label.bbcode_enabled = true
	dialog_text_label.scroll_active = false
	dialog_text_label.add_theme_font_override("", dynamic_font)
	dialog_text_label.add_theme_color_override("default_color", Color.WHITE)
	vbox.add_child(dialog_text_label)
	
	# Another separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)

	# Input field
	input_field = LineEdit.new()
	input_field.placeholder_text = "You say..."
	input_field.custom_minimum_size = Vector2(560, 30)
	vbox.add_child(input_field)

	# Connect input field
	input_field.connect("text_submitted", _on_text_submitted)
	dialog_panel.visible = true
	get_tree().current_scene.add_child(dialog_panel)


func is_dialog_active() -> bool:
	return dialog_panel and dialog_panel.visible 
	
func _unhandled_input(event: InputEvent) -> void:
	match dialog_state:
		DialogState.READY:
			_handle_ready_state(event)
		DialogState.DIRECTION:
			_handle_direction_state(event)
		DialogState.DIALOG:
			_handle_dialog_state(event)
	

# Main input handler - called by hero
func handle_input(event):
	match dialog_state:
		DialogState.READY:
			_handle_ready_state(event)
		DialogState.DIRECTION:
			_handle_direction_state(event)
		DialogState.DIALOG:
			_handle_dialog_state(event)

# READY State: Check for T key to start talking
func _handle_ready_state(event):
	if event.is_action_pressed("ui_talk"):
		transition_to_direction_state()
		return true  # Consumed event
	return false  # Let hero handle other inputs

# DIRECTION State: Wait for direction or cancel/timeout
func _handle_direction_state(event):
	# Handle direction keys
	var inputs = {
		"move_right": Vector2.RIGHT,
		"move_left": Vector2.LEFT,
		"move_down": Vector2.DOWN,
		"move_up": Vector2.UP
	}
	
	for action in inputs.keys():
		if event.is_action_pressed(action):
			attempt_talk_in_direction(inputs[action])
			return true  # Consumed event
	
	# Handle cancel (Escape key)
	if event.is_action_pressed("ui_cancel"):
		transition_to_ready_state_cancelled()
		return true  # Consumed event
	
	return true  # Always consume input in DIRECTION state

# DIALOG State: Dialog UI handles input
func _handle_dialog_state(event):
	if event.is_action_pressed("ui_cancel"):
		close_dialog()
		return true  # Consumed event
	return true  # Always consume input in DIALOG state

# State Transitions
func transition_to_direction_state():
	dialog_state = DialogState.DIRECTION
	talk_timer.start()
	show_talk_prompt()
	state_changed.emit(dialog_state)
	print("Dialog State: READY -> DIRECTION")

func transition_to_dialog_state(npc: Node2D):
	dialog_state = DialogState.DIALOG
	talk_timer.stop()
	hide_talk_prompt()
	open_dialog(npc)
	state_changed.emit(dialog_state)
	print("Dialog State: DIRECTION -> DIALOG")

func transition_to_ready_state():
	dialog_state = DialogState.READY
	talk_timer.stop()
	hide_talk_prompt()
	state_changed.emit(dialog_state)
	print("Dialog State: -> READY")

func transition_to_ready_state_cancelled():
	transition_to_ready_state()
	show_cancelled_message()
	print("Dialog State: DIRECTION -> READY (cancelled)")

# Timer timeout handler
func _on_talk_timer_timeout():
	if dialog_state == DialogState.DIRECTION:
		transition_to_ready_state_cancelled()
		print("Dialog State: DIRECTION -> READY (timeout)")

# UI Management
func show_talk_prompt():
	if not hero_node:
		return
		
	talk_prompt_label = Label.new()
	talk_prompt_label.add_theme_font_override("", dynamic_font)
	talk_prompt_label.text = "Choose direction to talk, or ESC to cancel..."
	talk_prompt_label.position = hero_node.global_position + Vector2(-80, -50)
	talk_prompt_label.add_theme_color_override("font_color", Color.YELLOW)
	talk_prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	talk_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	talk_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	talk_prompt_label.add_theme_font_size_override("font_size", 12)
	hero_node.get_parent().add_child(talk_prompt_label)

func hide_talk_prompt():
	if is_instance_valid(talk_prompt_label):
		talk_prompt_label.queue_free()
		talk_prompt_label = null

func show_cancelled_message():
	if not hero_node:
		return
		
	var label = Label.new()
	label.text = "Cancelled."
	label.position = hero_node.global_position + Vector2(-20, -40)
	label.add_theme_color_override("font_color", Color.GRAY)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	hero_node.get_parent().add_child(label)
	
	# Remove after 1 second
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(label):
		label.queue_free()

# NPC Interaction Logic
func attempt_talk_in_direction(direction: Vector2):
	if not hero_node:
		transition_to_ready_state()
		return
	
	var grid_size = hero_node.grid_size if hero_node.has_method("get") else 32
	var target_pos = hero_node.global_position + (direction * grid_size)
	
	# Check for NPC at target position
	var npc = find_npc_at_position(target_pos)
	if npc:
		# Transition to DIALOG state
		transition_to_dialog_state(npc)
	else:
		# No NPC found, back to READY
		transition_to_ready_state()
		show_no_one_message()

func find_npc_at_position(world_pos: Vector2) -> Node2D:
	if not hero_node:
		return null
		
	# Get the village node
	var village_node = hero_node.get_parent().get_node_or_null("villagers")
	if not village_node:
		return null
	
	var grid_size = hero_node.grid_size if hero_node.has_method("get") else 32
	
	# Check all children of village for NPCs
	for child in village_node.get_children():
		if child.has_meta("dialog"):
			var distance = world_pos.distance_to(child.global_position)
			if distance < grid_size * 0.7:
				return child
	
	return null

func show_no_one_message():
	if not hero_node:
		return
		
	var label = Label.new()
	label.text = "No one there."
	label.position = hero_node.global_position + Vector2(-30, -40)
	label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	hero_node.get_parent().add_child(label)
	
	# Remove after 1 second
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(label):
		label.queue_free()

func open_dialog(npc: npc_node):
	current_npc = npc
	if dialog_panel:
		dialog_panel.queue_free()
		dialog_panel = null
	create_dialog_ui()
	
	
	
	var npc_data = npc.npc_info
	npc_name_label.text = get_npc_name(npc_data)
	dialog_text_label.text = "[color=cyan]%s approaches...[/color]\n\n%s" % [get_npc_name(npc_data), npc_data.get("DESCRIPTION", "A mysterious figure.")]
	
	input_field.text = ""
	input_field.grab_focus()
	input_field.keep_editing_on_text_submit=true
	input_field.edit()

func close_dialog():
	current_npc = null
	dialog_panel.queue_free()
	# Transition back to READY state
	transition_to_ready_state()
	# Emit signal for any listeners
	dialog_closed.emit("")

# Public getter for current state
func get_dialog_state() -> DialogState:
	return dialog_state

func is_dialog_open() -> bool:
	return dialog_state == DialogState.DIALOG

func get_npc_name(npc_data: Dictionary) -> String:
	var npc_name = npc_data.get("CLEAN_NAME", "")
	if npc_name:
		return npc_name
	npc_name = npc_data.get("NAME", "Unknown")
	# Extract just the name part after "I am" or "My name's" etc.
	if "I am " in npc_name:
		npc_name = npc_name.replace("I am ", "")
	elif "My name's " in npc_name:
		name = name.replace("My name's ", "")
	elif "Call me " in npc_name:
		name = name.replace("Call me ", "")
	elif "They call me " in npc_name:
		npc_name = npc_name.replace("They call me ", "")
	
	# Remove periods
	npc_name = npc_name.replace(".", "")
	return npc_name

func _on_quick_question(question: String):
	input_field.text = question
	_on_text_submitted(question)

func _on_text_submitted(text: String):
	if text.is_empty() or not current_npc:
		close_dialog()
		dialog_finished.emit("")
		return ""
	
	var npc_data = current_npc.npc_info
	var response = get_npc_response(npc_data, text.to_upper().strip_edges())
	
	# Update dialog text
	var question_color = "yellow"
	var response_color = "white"
	if text.to_upper() in ["FAREWELL", "BYE"]:
		close_dialog()
		dialog_finished.emit("")
		return ""
	dialog_text_label.text += "\n\n[color=%s]You: %s[/color]\n[color=%s]%s: %s[/color]" % [
		question_color, text,
		response_color, get_npc_name(npc_data), response
	]
	
	# Scroll to bottom
	dialog_text_label.scroll_to_line(dialog_text_label.get_line_count())
	
	# Clear input
	input_field.text = ""
	input_field.grab_focus()

func get_npc_response(npc_data: Dictionary, question: String) -> String:
	# Direct key matches
	var block_list = ['OPEN', 'LOCATION', 'CLEAN_NAME', 'AGE', 'SPRITE']
	if npc_data.has(question) and question not in block_list:
		return npc_data[question]
	question = question.to_upper()
	# Handle common variations and synonyms-
	var responses = {
		"NAME": npc_data.get("NAME", "I prefer not to say."),
		"JOB": npc_data.get("JOB", "I work as I must."),
		"WORK": npc_data.get("JOB", "I work as I must."),
		"HEALTH": npc_data.get("HEALTH", "I am well enough."),
		"GOLD": npc_data.get("GOLD", "I have little coin."),
		"MONEY": npc_data.get("GOLD", "I have little coin."),
		"COIN": npc_data.get("GOLD", "I have little coin."),
		"DESCRIPTION": npc_data.get("DESCRIPTION", "Nothing special about me."),
		"LOOK": npc_data.get("DESCRIPTION", "Nothing special about me."),
		"AGE": "I am %d years old." % npc_data.get("AGE", 30),
		"GENDER": "I am %s." % npc_data.get("GENDER", "a person"),
		"HOOK": npc_data.get("HOOK", "I know nothing of interest."),
		"RUMOR": npc_data.get("HOOK", "I know nothing of interest."),
		"NEWS": npc_data.get("HOOK", "I know nothing of interest."),
		"SECRET": npc_data.get("HOOK", "I know nothing of interest.")
	}
			
	if npc_data.has(question) and "OPEN" in question or "UNLOCK" in question or "KEY" in question:
		var key_name = "Key-"+npc_data.get('CLEAN_NAME')
		if Global.inventory.has_item(key_name):
			return "I already gave you the key"
		Global.inventory.add_item(key_name)
		return "It is done!"
		
	if not block_list.has(question) and responses.has(question):
		return responses[question]
	
	# Location-based responses
	if "VILLAGE" in question or "TOWN" in question or "CITY" in question:
		return "This is a fine place to live."
	
	if "KING" in question or "RULER" in question:
		return "King Aldren rules from Castle Moonfel."
	
	if "CASTLE" in question:
		return "Castle Moonfel stands proud in our realm."
	
	# Topic-based responses using keywords
	var location_keywords = {
		"VALEWIND": "A peaceful village to the south.",
		"ELDERIA": "The great port city by the sea.",
		"MAPLEGROVE": "Where the druids dwell among ancient trees.",
		"WILLOWBEND": "A fishing village by the coast.",
		"BRIGHTWATCH": "The great library and keep of knowledge.",
		"BLACKWATER": "The mining town in the mountains.",
		"MOONFEL": "The royal castle where our king resides."
	}
	
	for keyword in location_keywords:
		if keyword in question:
			return location_keywords[keyword]
	
	# Magic/adventure keywords
	if "MAGIC" in question or "SPELL" in question:
		return "Magic is powerful and dangerous. Best left to the learned."
	
	if "ADVENTURE" in question or "QUEST" in question:
		return "Adventure calls to brave souls. Are you one such?"
	
	if "DANGER" in question or "MONSTER" in question:
		return "Dark things stir in the wilderness. Be cautious."
	
	# Default responses based on question length/type
	if len(question) < 3:
		return "Could you speak more clearly?"
	
	if "?" in question:
		return "I'm not sure I understand your question."
	
	# Random default responses
	var default_responses = [
		"I don't know much about that.",
		"Perhaps you should ask someone more knowledgeable.",
		"That's not something I concern myself with.",
		"Interesting question, but I have no answer.",
		"You might find answers elsewhere."
	]
	
	return default_responses[randi() % default_responses.size()]

func show_message(text: String):
	# Create a simple message popup
	var popup = AcceptDialog.new()
	popup.dialog_text = text
	popup.title = "Talk"
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	popup.connect("confirmed", popup.queue_free)
	
	# Auto close after 2 seconds
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(popup):
		popup.queue_free()
