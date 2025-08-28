extends Node

var zones = {}
@export var steps_per_encounter := 6

func _ready():
	var f = FileAccess.open("res://data/zones.json", FileAccess.READ)
	if f:
		zones = JSON.parse_string(f.get_as_text()).result
		f.close()

func maybe_trigger_encounter(zone_id: String) -> void:
	if not zones.has(zone_id):
		return
	var zone = zones[zone_id]
	var chance = zone.get("encounter_chance", 0.08)
	if randi() % 100 < int(chance * 100):
		_start_encounter(zone)

func _start_encounter(zone):
	var pool = zone.get("monsters", [])
	if pool.size() == 0:
		return
	var total = 0
	for entry in pool:
		total += entry.get("weight", 1)
	var pick = randi() % total
	var cum = 0
	for entry in pool:
		cum += entry.get("weight", 1)
		if pick < cum:
			_dispatch_encounter(entry.get("id"))
			return

func _dispatch_encounter(encounter_id):
	print("Encounter start: ", encounter_id)
