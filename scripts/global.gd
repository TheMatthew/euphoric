extends Node


@export var player_in_scene: bool = false
@onready var inventory: player_inventory = player_inventory.new()
@onready var stats: CharacterStats = CharacterStats.new()


class CharacterStats:
	# Base attributes (set by char gen quiz)
	var str_base: int = 10
	var dex_base: int = 10
	var int_base: int = 10
	var end_base: int = 10
	var wis_base: int = 10
	var cha_base: int = 10

	var level: int = 1
	var xp: int = 0
	var virtue: String = ""

	# Derived stats — call recalculate() after changing base stats
	var max_hp: int = 0
	var current_hp: int = 0
	var max_mp: int = 0
	var current_mp: int = 0
	var attack_power: int = 0
	var defense: int = 0
	var hit_pct: int = 0       # 0-100
	var dodge_pct: int = 0     # 0-100
	var initiative_mod: int = 0

	func _init():
		recalculate()

	func recalculate():
		max_hp = 20 + (end_base * 2) + (str_base) + (level * 5)
		max_mp = 5 + (int_base * 2) + (wis_base) + (level * 3)
		attack_power = 2 + int(str_base / 2.0)
		defense = 1 + int(end_base / 3.0)
		hit_pct = clampi(50 + dex_base + int(wis_base / 2.0), 0, 99)
		dodge_pct = clampi(5 + int(dex_base / 2.0), 0, 50)
		initiative_mod = int(dex_base / 2.0)
		# Heal to full on recalculate (level up / char gen)
		current_hp = max_hp
		current_mp = max_mp

	func set_from_principles(principle_scores: Dictionary):
		# Map quiz principles to base attributes
		str_base = 8 + principle_scores.get("Valor", 0)
		end_base = 8 + principle_scores.get("Resolve", 0)
		dex_base = 8 + principle_scores.get("Adroitness", 0)
		int_base = 8 + principle_scores.get("Verity", 0)
		wis_base = 8 + principle_scores.get("Clarity", 0)
		cha_base = 8 + principle_scores.get("Grace", 0)
		recalculate()
