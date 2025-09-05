extends MarginContainer

const CHAR_READ_RATE = 0.05

@onready var tween = Tween.new()
@onready var textbox_container = self
@onready var start_symbol = textbox_container.get_node("VBoxContainer").get_node("header")
@onready var end_symbol = textbox_container.get_node("VBoxContainer").get_node("footer")
@onready var label = textbox_container.get_node("VBoxContainer").get_node("body")

enum State {
	READY,
	READING,
	FINISHED
}

var current_state = State.READY
var text_queue = []

func _ready():
	print("Starting state: State.READY")
	hide_textbox()
	tween.connect("finished",_on_Tween_tween_completed)

func _process(delta):
	match current_state:
		State.READY:
			if !text_queue.is_empty():
				display_text()
			else:
				# Hide textbox when there's no text to display
				if textbox_container.visible:
					hide_textbox()
		State.READING:
			if Input.is_action_just_pressed("ui_accept"):
				label.visible_ratio = 1.0
				tween.stop()
				end_symbol.text = "<enter>"
				change_state(State.FINISHED)
		State.FINISHED:
			if Input.is_action_just_pressed("ui_accept"):
				change_state(State.READY)

func queue_text(next_text):
	text_queue.push_back(next_text)

func hide_textbox():
	start_symbol.text = ""
	end_symbol.text = ""
	label.text = ""
	textbox_container.hide()

func show_textbox():
	print("Showing text: ", label.text)
	textbox_container.show()
	label.add_theme_color_override("default_color", Color.BLACK)
	label.show()

func display_text():
	var next_text = text_queue.pop_front()
	label.text = next_text
	label.visible_ratio = 1.0
	change_state(State.READING)
	show_textbox()
	# tween.tween_property(label, "visible_ratio", 1.0, len(next_text) * CHAR_READ_RATE)

func change_state(next_state):
	current_state = next_state
	match current_state:
		State.READY:
			print("Changing state to: State.READY")
		State.READING:
			print("Changing state to: State.READING")
		State.FINISHED:
			print("Changing state to: State.FINISHED")

func _on_Tween_tween_completed(object, key):
	end_symbol.text = "<enter>"
	change_state(State.FINISHED)
