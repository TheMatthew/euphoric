# MainMenu.gd
extends Control

# Menu states
enum MenuState {
	MAIN,
	SAVE_SLOTS,
	OPTIONS,
	EXIT_CONFIRM
}

var current_state = MenuState.MAIN
var selected_index = 0
var save_data = {}

# UI References
@onready var background = $Background
@onready var menu_container = $MenuContainer
@onready var main_menu = $MenuContainer/MainMenu
@onready var save_slots_menu = $MenuContainer/SaveSlotsMenu
@onready var options_menu = $MenuContainer/OptionsMenu
@onready var exit_confirm = $MenuContainer/ExitConfirm

# Main menu buttons - Updated for 2x2 grid layout
@onready var main_buttons = [
	$MenuContainer/MainMenu/VBoxContainer/TopRow/NewGameButton,
	$MenuContainer/MainMenu/VBoxContainer/TopRow/ContinueButton,
	$MenuContainer/MainMenu/VBoxContainer/BottomRow/OptionsButton,
	$MenuContainer/MainMenu/VBoxContainer/BottomRow/ExitButton
]

# Save slot buttons
@onready var save_slot_buttons = []

# Options controls
@onready var sound_volume_slider = $MenuContainer/OptionsMenu/Panel/MarginContainer/VBoxContainer/SoundVolumeContainer/SoundSlider
@onready var music_volume_slider = $MenuContainer/OptionsMenu/Panel/MarginContainer/VBoxContainer/MusicVolumeContainer/MusicSlider
@onready var options_back_button = $MenuContainer/OptionsMenu/Panel/MarginContainer/VBoxContainer/BackButton

# Exit confirm buttons
@onready var exit_yes_button = $MenuContainer/ExitConfirm/Panel/MarginContainer/VBoxContainer/ButtonContainer/YesButton
@onready var exit_no_button = $MenuContainer/ExitConfirm/Panel/MarginContainer/VBoxContainer/ButtonContainer/NoButton

# Audio
var tick_sound: AudioStreamPlayer

func _ready():
	# Setup audio
	tick_sound = AudioStreamPlayer.new()
	add_child(tick_sound)
	# You'll need to load your tick sound file here
	# tick_sound.stream = preload("res://audio/tick.ogg")
	
	# Initialize save slot buttons
	setup_save_slots()
	
	# Load save data
	load_save_data()
	
	# Connect signals
	connect_signals()
	
	# Show main menu
	show_main_menu()
	
	# Set initial selection
	update_selection()

func setup_save_slots():
	var save_slots_container = $MenuContainer/SaveSlotsMenu/Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
	
	for i in range(8):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(600, 80)
		slot_button.text = "Slot " + str(i + 1) + " - Empty"
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Style the button for 8-bit look
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.2, 0.4, 0.8)
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color.GOLD
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.3, 0.3, 0.5, 0.9)
		style_hover.border_width_left = 2
		style_hover.border_width_right = 2
		style_hover.border_width_top = 2
		style_hover.border_width_bottom = 2
		style_hover.border_color = Color.WHITE
		
		slot_button.add_theme_stylebox_override("normal", style_normal)
		slot_button.add_theme_stylebox_override("hover", style_hover)
		slot_button.add_theme_stylebox_override("focus", style_hover)
		slot_button.add_theme_color_override("font_color", Color.GOLD)
		slot_button.add_theme_color_override("font_hover_color", Color.WHITE)
		
		slot_button.pressed.connect(_on_save_slot_selected.bind(i))
		save_slots_container.add_child(slot_button)
		save_slot_buttons.append(slot_button)

func connect_signals():
	# Main menu buttons
	main_buttons[0].pressed.connect(_on_new_game_pressed)
	main_buttons[1].pressed.connect(_on_continue_pressed)
	main_buttons[2].pressed.connect(_on_options_pressed)
	main_buttons[3].pressed.connect(_on_exit_pressed)
	
	# Options
	sound_volume_slider.value_changed.connect(_on_sound_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	options_back_button.pressed.connect(_on_options_back_pressed)
	
	# Save slots back button
	$MenuContainer/SaveSlotsMenu/Panel/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_save_slots_back_pressed)
	
	# Exit confirm
	exit_yes_button.pressed.connect(_on_exit_yes_pressed)
	exit_no_button.pressed.connect(_on_exit_no_pressed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		match current_state:
			MenuState.MAIN:
				_on_exit_pressed()
			MenuState.SAVE_SLOTS, MenuState.OPTIONS:
				show_main_menu()
			MenuState.EXIT_CONFIRM:
				show_main_menu()
	
	elif event.is_action_pressed("ui_up"):
		navigate_up()
	elif event.is_action_pressed("ui_down"):
		navigate_down()
	elif event.is_action_pressed("ui_left"):
		navigate_left()
	elif event.is_action_pressed("ui_right"):
		navigate_right()
	elif event.is_action_pressed("ui_accept"):
		activate_current_selection()

func navigate_up():
	play_tick()
	match current_state:
		MenuState.MAIN:
			# Move up in the 2x2 grid
			if selected_index >= 2:
				selected_index -= 2
		MenuState.EXIT_CONFIRM:
			selected_index = (selected_index - 1) % 2
	update_selection()

func navigate_down():
	play_tick()
	match current_state:
		MenuState.MAIN:
			# Move down in the 2x2 grid
			if selected_index < 2:
				selected_index += 2
		MenuState.EXIT_CONFIRM:
			selected_index = (selected_index + 1) % 2
	update_selection()

func navigate_left():
	play_tick()
	match current_state:
		MenuState.MAIN:
			# Move left in the 2x2 grid
			if selected_index % 2 == 1:
				selected_index -= 1
	update_selection()

func navigate_right():
	play_tick()
	match current_state:
		MenuState.MAIN:
			# Move right in the 2x2 grid
			if selected_index % 2 == 0:
				selected_index += 1
	update_selection()

func update_selection():
	match current_state:
		MenuState.MAIN:
			for i in range(main_buttons.size()):
				if i == selected_index:
					main_buttons[i].grab_focus()
		MenuState.EXIT_CONFIRM:
			if selected_index == 0:
				exit_yes_button.grab_focus()
			else:
				exit_no_button.grab_focus()

func activate_current_selection():
	play_tick()
	match current_state:
		MenuState.MAIN:
			main_buttons[selected_index].pressed.emit()
		MenuState.EXIT_CONFIRM:
			if selected_index == 0:
				exit_yes_button.pressed.emit()
			else:
				exit_no_button.pressed.emit()

func play_tick():
	if tick_sound and tick_sound.stream:
		tick_sound.play()

# Menu state transitions
func show_main_menu():
	current_state = MenuState.MAIN
	selected_index = 0
	hide_all_menus()
	main_menu.show()
	animate_menu_in(main_menu)
	update_selection()

func show_save_slots():
	current_state = MenuState.SAVE_SLOTS
	hide_all_menus()
	save_slots_menu.show()
	animate_menu_in(save_slots_menu)
	update_save_slot_display()

func show_options():
	current_state = MenuState.OPTIONS
	hide_all_menus()
	options_menu.show()
	animate_menu_in(options_menu)
	load_settings()

func show_exit_confirm():
	current_state = MenuState.EXIT_CONFIRM
	selected_index = 1  # Default to "No"
	hide_all_menus()
	exit_confirm.show()
	animate_menu_in(exit_confirm)
	update_selection()

func hide_all_menus():
	main_menu.hide()
	save_slots_menu.hide()
	options_menu.hide()
	exit_confirm.hide()

func animate_menu_in(menu_node):
	menu_node.modulate.a = 0.0
	menu_node.position.x += 50
	
	var tween = create_tween()
	tween.parallel().tween_property(menu_node, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(menu_node, "position:x", menu_node.position.x - 50, 0.2)
	tween.set_ease(Tween.EASE_OUT)

# Button callbacks
func _on_new_game_pressed():
	play_tick()
	# Here you would typically show a save slot selection for new game
	# or go directly to character creation
	print("Starting new game...")
	get_tree().change_scene_to_file("res://scenes/char_gen/char_gen.tscn")

func _on_continue_pressed():
	play_tick()
	var data = Global.load_game()
	if data.is_empty():
		return
	Global.apply_save(data)
	get_tree().change_scene_to_file(data.get("scene", ""))

func _on_options_pressed():
	play_tick()
	show_options()

func _on_exit_pressed():
	play_tick()
	show_exit_confirm()

func _on_save_slot_selected(slot_index):
	play_tick()
	if has_save_data(slot_index):
		load_game(slot_index)
	else:
		# Empty slot, start new game in this slot
		start_new_game_in_slot(slot_index)

func _on_sound_volume_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	save_settings()

func _on_music_volume_changed(value):
	# Assuming you have a separate "Music" audio bus
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	save_settings()

func _on_options_back_pressed():
	play_tick()
	show_main_menu()

func _on_save_slots_back_pressed():
	play_tick()
	show_main_menu()

func _on_exit_yes_pressed():
	play_tick()
	get_tree().quit()

func _on_exit_no_pressed():
	play_tick()
	show_main_menu()

# Save/Load functionality
func load_save_data():
	save_data = {}
	for i in range(8):
		var save_file = FileAccess.open("user://save_slot_" + str(i) + ".save", FileAccess.READ)
		if save_file:
			var save_info = save_file.get_var()
			save_data[i] = save_info
			save_file.close()

func has_save_data(slot_index):
	return save_data.has(slot_index)

func update_save_slot_display():
	for i in range(8):
		if has_save_data(i):
			var data = save_data[i]
			var text = "Slot %d - %s\nLevel %d - %s\nPlaytime: %s" % [
				i + 1,
				data.get("player_name", "Unknown"),
				data.get("level", 1),
				data.get("location", "Unknown"),
				format_playtime(data.get("playtime", 0))
			]
			save_slot_buttons[i].text = text
		else:
			save_slot_buttons[i].text = "Slot " + str(i + 1) + " - Empty"

func format_playtime(seconds):
	var hours = int(seconds) / 3600
	var minutes = (int(seconds) % 3600) / 60
	return "%02d:%02d" % [hours, minutes]

func load_game(slot_index):
	# Load the game from the specified slot
	print("Loading game from slot ", slot_index)
	# get_tree().change_scene_to_file("res://scenes/Game.tscn")

func start_new_game_in_slot(slot_index):
	# Start a new game and save it to the specified slot
	print("Starting new game in slot ", slot_index)
	# get_tree().change_scene_to_file("res://scenes/CharacterCreation.tscn")

# Settings
func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		sound_volume_slider.value = config.get_value("audio", "sound_volume", 0.8)
		music_volume_slider.value = config.get_value("audio", "music_volume", 0.6)
	else:
		sound_volume_slider.value = 0.8
		music_volume_slider.value = 0.6

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "sound_volume", sound_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.save("user://settings.cfg")
