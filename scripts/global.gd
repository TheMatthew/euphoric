extends Node


@export var player_in_scene: bool = false
@onready var inventory: player_inventory = player_inventory.new()
@onready var stats: CharacterStats = CharacterStats.new()

const SAVE_PATH = "user://savegame.dat"

func save_game(scene_path: String, hero_pos: Vector2):
	var data = {
		"scene": scene_path,
		"hero_x": hero_pos.x,
		"hero_y": hero_pos.y,
		"stats": stats.to_dict(),
		"inventory": inventory.items.duplicate(),
		"equipped": inventory.equipped.duplicate(),
		"gold": inventory.gold,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(data)
	file.close()
	print("Game saved.")

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = file.get_var()
	file.close()
	return data if data is Dictionary else {}

var pending_hero_pos: Vector2 = Vector2.ZERO

func apply_save(data: Dictionary):
	if data.is_empty():
		return
	stats.from_dict(data.get("stats", {}))
	inventory.items = data.get("inventory", {})
	inventory.equipped = data.get("equipped", {"weapon":"","armor":"","shield":"","accessory":""})
	inventory.gold = data.get("gold", 100)
	pending_hero_pos = Vector2(data.get("hero_x", 0), data.get("hero_y", 0))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


class CharacterStats:
	var str_base: int = 10
	var dex_base: int = 10
	var int_base: int = 10
	var end_base: int = 10
	var wis_base: int = 10
	var cha_base: int = 10

	var level: int = 1
	var xp: int = 0
	var virtue: String = ""
	var player_name: String = "Hero"

	var max_hp: int = 0
	var current_hp: int = 0
	var max_mp: int = 0
	var current_mp: int = 0
	var attack_power: int = 0
	var defense: int = 0
	var hit_pct: int = 0
	var dodge_pct: int = 0
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
		current_hp = max_hp
		current_mp = max_mp

	func set_from_principles(principle_scores: Dictionary):
		str_base = 8 + principle_scores.get("Valor", 0)
		end_base = 8 + principle_scores.get("Resolve", 0)
		dex_base = 8 + principle_scores.get("Adroitness", 0)
		int_base = 8 + principle_scores.get("Verity", 0)
		wis_base = 8 + principle_scores.get("Clarity", 0)
		cha_base = 8 + principle_scores.get("Grace", 0)
		recalculate()

	func to_dict() -> Dictionary:
		return {
			"player_name": player_name,
			"str": str_base, "dex": dex_base, "int": int_base,
			"end": end_base, "wis": wis_base, "cha": cha_base,
			"level": level, "xp": xp, "virtue": virtue,
			"current_hp": current_hp, "current_mp": current_mp,
		}

	func from_dict(d: Dictionary):
		player_name = d.get("player_name", "Hero")
		str_base = d.get("str", 10)
		dex_base = d.get("dex", 10)
		int_base = d.get("int", 10)
		end_base = d.get("end", 10)
		wis_base = d.get("wis", 10)
		cha_base = d.get("cha", 10)
		level = d.get("level", 1)
		xp = d.get("xp", 0)
		virtue = d.get("virtue", "")
		recalculate()
		current_hp = d.get("current_hp", max_hp)
		current_mp = d.get("current_mp", max_mp)
