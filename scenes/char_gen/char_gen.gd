# char_gen.gd
# Interactive character generation with GUI text box and selectable options

extends Node2D

# --- 1. SYSTEM DEFINITIONS ---
const PRINCIPLES = {
	"Valor": "STR (Courage)",
	"Resolve": "END (Steadfastness)",
	"Adroitness": "DEX (Precision)",
	"Verity": "INT (Objective Truth)",
	"Clarity": "WIS (Discernment)",
	"Grace": "CHA (Harmony)"
}

const VIRTUES = {
	"Aegis": ["Valor", "Resolve", "Adroitness", "Grace"],
	"Erudition": ["Verity", "Clarity", "Resolve", "Adroitness"],
	"Sovereignty": ["Grace", "Verity", "Clarity", "Valor"]
}

# --- 2. QUIZ DATA ---
const QUIZ_QUESTIONS = [
	{
		"text": "You discover a thief about to cut the purse of a noble. How do you intercede?",
		"A": {"text": "Chase and tackle the thief directly", "scores": {"Valor": 2, "Resolve": 1}},
		"B": {"text": "Intercept with precise timing and sleight of hand", "scores": {"Adroitness": 2, "Clarity": 1}},
		"C": {"text": "Call out publicly and command them to stop", "scores": {"Grace": 2, "Verity": 1}}
	},
	{
		"text": "Your path is blocked by a complex, heavy mechanism. How do you proceed?",
		"A": {"text": "Force it open through persistent effort", "scores": {"Resolve": 2, "Valor": 1}},
		"B": {"text": "Carefully examine and manipulate the mechanism", "scores": {"Adroitness": 2, "Verity": 1}},
		"C": {"text": "Study it deeply to understand its design", "scores": {"Clarity": 2, "Grace": 1}}
	},
	{
		"text": "Your small company is on a long, arduous journey, and spirits are low.",
		"A": {"text": "Lead by tireless example, never showing weakness", "scores": {"Resolve": 2, "Valor": 1}},
		"B": {"text": "Analyze resources and plot the most efficient route", "scores": {"Clarity": 2, "Resolve": 1}},
		"C": {"text": "Deliver an inspiring, rousing speech", "scores": {"Grace": 2, "Valor": 1}}
	},
	{
		"text": "A village leader demands harsh punishment for a man who accidentally damaged a vital public well.",
		"A": {"text": "Demand the man serves penance through hard work", "scores": {"Valor": 2, "Resolve": 1}},
		"B": {"text": "Question thoroughly for an objective account", "scores": {"Verity": 2, "Clarity": 1}},
		"C": {"text": "Broker a diplomatic solution and fair compromise", "scores": {"Grace": 2, "Clarity": 1}}
	},
	{
		"text": "You are presented with historical accounts of a war that completely contradict each other.",
		"A": {"text": "Trust the most experienced veteran's account", "scores": {"Valor": 2, "Resolve": 1}},
		"B": {"text": "Cross-reference documents to prove the facts", "scores": {"Verity": 2, "Adroitness": 1}},
		"C": {"text": "Seek the deeper reason for the contradictions", "scores": {"Clarity": 2, "Grace": 1}}
	},
	{
		"text": "Your soldiers are paralyzed by fear of the enemy's gruesome new weapon.",
		"A": {"text": "Charge the enemy line first to demonstrate courage", "scores": {"Valor": 2, "Adroitness": 1}},
		"B": {"text": "Immediately sketch the weapon to find a weakness", "scores": {"Clarity": 2, "Verity": 1}},
		"C": {"text": "Move through ranks, speaking to calm fears", "scores": {"Grace": 2, "Resolve": 1}}
	},
	{
		"text": "You must cross a rickety bridge high above a canyon.",
		"A": {"text": "Use speed and precision to minimize contact", "scores": {"Adroitness": 2, "Resolve": 1}},
		"B": {"text": "Calculate weight distribution using physics", "scores": {"Verity": 2, "Clarity": 1}},
		"C": {"text": "Search for an alternative, unseen path", "scores": {"Resolve": 2, "Adroitness": 1}}
	},
	{
		"text": "You come across a fallen traveler in the woods and must choose how to assist them.",
		"A": {"text": "Immediately bind wounds and carry them to safety", "scores": {"Valor": 2, "Resolve": 1}},
		"B": {"text": "Perform a detailed diagnosis of injuries", "scores": {"Verity": 2, "Clarity": 1}},
		"C": {"text": "Command them to remain still and delegate help", "scores": {"Grace": 2, "Valor": 1}}
	},
	{
		"text": "You are tasked with leading negotiations between two groups that despise one another.",
		"A": {"text": "Demand a firm deadline with consequences", "scores": {"Resolve": 2, "Valor": 1}},
		"B": {"text": "Use logic and data to show the cost of failure", "scores": {"Verity": 2, "Clarity": 1}},
		"C": {"text": "Appeal to their shared humanity", "scores": {"Grace": 2, "Adroitness": 1}}
	},
	{
		"text": "You must learn a new, complex military skill or magical art quickly.",
		"A": {"text": "Practice relentlessly through repetition", "scores": {"Resolve": 2, "Adroitness": 1}},
		"B": {"text": "First study the complete theory and history", "scores": {"Verity": 2, "Clarity": 1}},
		"C": {"text": "Convince the master to train you personally", "scores": {"Grace": 2, "Verity": 1}}
	}
]

# --- 3. STATE VARIABLES ---
var principle_scores = {}
var current_question = 0
var quiz_started = false
var final_virtue_name = ""
var current_story_sequence = "intro"  # Track which story we're in
var story_index = 0
var selected_option = 0
var waiting_for_timer = false  # Track if we're in a timer wait

# Story sequences
var intro_story = [
	"You have heard tales of the truthseer, a wise woman said to give meaning to life.",
	"You seek her humble house and knock on her door.",
	"Surprisingly, a soft, old voice calls your name and asks you to enter.",
]

var fortune_story = [
	"The wise woman welcomes you with a weary smile and asks you to sit.",
	"Her eyes hold the light of a thousand years.",
	"'Child, you have a destiny. But first, we must discover the true nature of your soul.'"
]

# --- 4. NODE REFERENCES ---
@onready var text_box = $TextBox
@onready var option_a = $Options/OptionA
@onready var option_b = $Options/OptionB
@onready var option_c = $Options/OptionC
@onready var hut_sprite = $hut
@onready var fortune_sprite = $fortune
@onready var ship_sprite = $ship
@onready var wreck_sprite = $wreck

func _ready():
	# Initialize principle scores
	for name in PRINCIPLES:
		principle_scores[name] = 0
	
	# Hide all sprites initially
	hut_sprite.visible = false
	fortune_sprite.visible = false
	ship_sprite.visible = false
	wreck_sprite.visible = false
	
	# Hide options initially
	$Options.visible = false
	
	# Start the prologue
	show_sprite("hut")
	show_story(intro_story)

func _input(event):
	if waiting_for_timer:
		# If waiting for timer, clicking skips it
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
			skip_timer()
	elif not quiz_started and current_story_sequence != "confirmation":
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
			advance_story()
	elif current_story_sequence == "confirmation":
		# Handle confirmation input
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			selected_option = 0
			update_confirmation_highlight()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			selected_option = 1
			update_confirmation_highlight()
		elif event.is_action_pressed("ui_accept"):
			confirm_choice()
	else:
		# Handle keyboard selection during quiz
		if event.is_action_pressed("ui_up"):
			selected_option = max(0, selected_option - 1)
			update_option_highlight()
		elif event.is_action_pressed("ui_down"):
			selected_option = min(2, selected_option + 1)
			update_option_highlight()
		elif event.is_action_pressed("ui_accept"):
			select_current_option()

func show_sprite(sprite_name):
	# Hide all sprites
	hut_sprite.visible = false
	fortune_sprite.visible = false
	ship_sprite.visible = false
	wreck_sprite.visible = false
	
	# Show the requested sprite
	match sprite_name:
		"hut":
			hut_sprite.visible = true
		"fortune":
			fortune_sprite.visible = true
		"ship":
			ship_sprite.visible = true
		"wreck":
			wreck_sprite.visible = true

func show_story(story_lines):
	story_index = 0
	text_box.text = story_lines[0]

func advance_story():
	# Advance based on which story sequence we're currently in
	if current_story_sequence == "intro":
		story_index += 1
		if story_index < intro_story.size():
			text_box.text = intro_story[story_index]
		else:
			# Transition to fortune teller
			current_story_sequence = "fortune"
			show_sprite("fortune")
			show_story(fortune_story)
	elif current_story_sequence == "fortune":
		story_index += 1
		if story_index < fortune_story.size():
			text_box.text = fortune_story[story_index]
		else:
			# Start the quiz
			start_quiz()

func start_quiz():
	quiz_started = true
	current_question = 0
	$Options.visible = true
	selected_option = 0
	show_question()

func show_question():
	if current_question < QUIZ_QUESTIONS.size():
		var q = QUIZ_QUESTIONS[current_question]
		text_box.text = "Question %d:\n%s" % [current_question + 1, q.text]
		
		option_a.text = "A: " + q.A.text
		option_b.text = "B: " + q.B.text
		option_c.text = "C: " + q.C.text
		
		update_option_highlight()
	else:
		finish_quiz()

func update_option_highlight():
	# Reset all colors
	option_a.modulate = Color.WHITE
	option_b.modulate = Color.WHITE
	option_c.modulate = Color.WHITE
	
	# Highlight selected
	match selected_option:
		0:
			option_a.modulate = Color.YELLOW
		1:
			option_b.modulate = Color.YELLOW
		2:
			option_c.modulate = Color.YELLOW

func select_current_option():
	var choice = ["A", "B", "C"][selected_option]
	answer_question(choice)

func answer_question(choice):
	var q = QUIZ_QUESTIONS[current_question]
	var scores = q[choice].scores
	
	# Tally scores
	for principle in scores:
		if principle_scores.has(principle):
			principle_scores[principle] += scores[principle]
	
	current_question += 1
	selected_option = 0
	
	# Check if quiz is complete before showing next question
	if current_question >= QUIZ_QUESTIONS.size():
		finish_quiz()
	else:
		show_question()

var current_timer = null  # Reference to active timer

func skip_timer():
	# Skip the current timer by stopping it and proceeding
	if current_timer:
		current_timer.timeout.disconnect(Callable(self, "_on_timer_complete"))
		waiting_for_timer = false
		current_timer = null
		_on_timer_complete()

func _on_timer_complete():
	# This will be overridden by each timer's specific completion action
	pass

func finish_quiz():
	quiz_started = false
	$Options.visible = false
	
	# Determine virtue
	var virtue_data = determine_virtue()
	var dominant_virtues = virtue_data.dominant
	
	if dominant_virtues.size() == 1:
		final_virtue_name = dominant_virtues[0]
	else:
		final_virtue_name = dominant_virtues[0] + " & " + dominant_virtues[-1]
	
	# Show prophecy
	show_prophecy()

func show_prophecy():
	var description = ""
	if final_virtue_name.find("Aegis") != -1:
		description = "You are the Champion, destined to walk the path of direct action, courage, and relentless defense of the weak."
	elif final_virtue_name.find("Erudition") != -1:
		description = "You are the Scholar-Artisan, destined for the pursuit of truth, patient insight, and the precise application of skill."
	elif final_virtue_name.find("Sovereignty") != -1:
		description = "You are the Just Leader, destined for rightful authority, governing with wisdom, social grace, and logical integrity."
	else:
		description = "Your destiny is complex, blending the callings of your heart."
	
	text_box.text = "'Your Virtue is revealed! Your soul yearns for the path of %s.'\n\n%s\n\n'Now, you must depart. Take a ship from the harbor when the moon is new.'" % [final_virtue_name.to_upper(), description]
	
	# Wait then show confirmation
	await get_tree().create_timer(10.0).timeout
	show_confirmation()

func show_confirmation():
	current_story_sequence = "confirmation"
	text_box.text = "Are you sure about your choices?"
	
	# Show Yes/No options
	$Options.visible = true
	option_a.text = "Yes - Continue"
	option_b.text = "No - Retake the quiz"
	option_c.visible = false  # Hide third option
	selected_option = 0
	update_confirmation_highlight()

func update_confirmation_highlight():
	# Reset colors
	option_a.modulate = Color.WHITE
	option_b.modulate = Color.WHITE
	
	# Highlight selected
	if selected_option == 0:
		option_a.modulate = Color.YELLOW
	else:
		option_b.modulate = Color.YELLOW

func confirm_choice():
	if selected_option == 0:
		# Yes - Continue to ship
		$Options.visible = false
		option_c.visible = true  # Restore third option for future use
		show_shipwreck()
	else:
		# No - Retake quiz
		$Options.visible = false
		option_c.visible = true  # Restore third option
		restart_quiz()

func restart_quiz():
	# Reset all scores
	for name in PRINCIPLES:
		principle_scores[name] = 0
	
	# Reset state
	current_question = 0
	quiz_started = false
	final_virtue_name = ""
	current_story_sequence = "fortune"
	
	# Return to fortune teller and restart
	show_sprite("fortune")
	text_box.text = "'Very well, child. Let us discover your true nature once more.'"
	
	await get_tree().create_timer(3.0).timeout
	start_quiz()

func show_shipwreck():
	show_sprite("ship")
	text_box.text = "You secure passage on a sturdy vessel, the wind guiding you toward your destiny...\n\nA few days out, the sky turns the color of deep bruise. A brutal storm tears through your ship."
	
	await get_tree().create_timer(10.0).timeout
	
	show_sprite("wreck")
	text_box.text = "The world is chaos. You cling to wreckage, battered by the surf, until consciousness fails you.\n\nAll your life's possessions are lost. The prophecy slips from your memory like water..."
	
	await get_tree().create_timer(10.0).timeout
	
	# Fade to black and load the next scene
	text_box.text = "..."
	
	await get_tree().create_timer(10.0).timeout
	
	# Load the starting hut scene
	get_tree().change_scene_to_file("res://scenes/settlement/hut_alvo/alvo_hut_start.tscn")

func determine_virtue():
	var virtue_scores = {}
	var max_score = -1
	var dominant_virtues = []
	
	for virtue_name in VIRTUES:
		var total_score = 0
		for principle in VIRTUES[virtue_name]:
			total_score += principle_scores.get(principle, 0)
		virtue_scores[virtue_name] = total_score
		
		if total_score > max_score:
			max_score = total_score
			dominant_virtues = [virtue_name]
		elif total_score == max_score:
			dominant_virtues.append(virtue_name)
	
	return {"scores": virtue_scores, "dominant": dominant_virtues}

# Connect button signals
func _on_option_a_pressed():
	if quiz_started:
		answer_question("A")
	elif current_story_sequence == "confirmation":
		selected_option = 0
		confirm_choice()

func _on_option_b_pressed():
	if quiz_started:
		answer_question("B")
	elif current_story_sequence == "confirmation":
		selected_option = 1
		confirm_choice()

func _on_option_c_pressed():
	if quiz_started:
		answer_question("C")
