extends Node

var zones = {}
@export var steps_per_encounter := 6
var step_count: int = 0

func _ready():
	var f = FileAccess.open("res://data/zones.json", FileAccess.READ)
	if f:
		zones = JSON.parse_string(f.get_as_text())
		f.close()

func on_hero_moved(zone_id: String):
	if not zones.has(zone_id):
		return
	step_count += 1
	if step_count < steps_per_encounter:
		return
	step_count = 0
	var zone = zones[zone_id]
	var chance = zone.get("encounter_chance", 0.08)
	if randf() < chance:
		var enemy_id = pick_enemy(zone)
		if enemy_id != "":
			start_encounter(enemy_id)

func pick_enemy(zone: Dictionary) -> String:
	var pool = zone.get("monsters", [])
	if pool.size() == 0:
		return ""
	var total = 0
	for entry in pool:
		total += entry.get("weight", 1)
	var pick = randi() % int(total)
	var cum = 0
	for entry in pool:
		cum += entry.get("weight", 1)
		if pick < cum:
			return entry.get("id", "")
	return ""

func start_encounter(enemy_id: String):
	# Determine enemy count: 1-3 based on randomness
	var count = randi_range(1, 3)
	var enemy_list: Array[String] = []
	for i in range(count):
		enemy_list.append(enemy_id)

	# Get hero node to trigger combat
	var hero = get_tree().current_scene.get_node_or_null("hero")
	if hero and hero.has_method("start_combat_encounter"):
		hero.start_combat_encounter(enemy_list)
