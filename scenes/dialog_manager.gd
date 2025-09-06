extends Node

var npc_data: Dictionary

func _ready() -> void:
	# Load the JSON once at startup
	npc_data = load_json("res://npc_dialogs.json")


# --- JSON LOADING ---
func load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON file: %s" % path)
		return {}

	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data == null:
		push_error("Failed to parse JSON data")
		return {}

	return data


# --- NPC LOOKUP ---
func get_npc(village: String, index: int) -> Dictionary:
	if not npc_data.has(village):
		push_warning("Village not found: %s" % village)
		return {}
	if index < 0 or index >= npc_data[village].size():
		push_warning("NPC index out of range in %s" % village)
		return {}
	return npc_data[village][index]


func get_response(village: String, index: int, keyword: String) -> String:
	var npc = get_npc(village, index)
	if npc.is_empty():
		return "[No NPC]"
	if not npc.has(keyword):
		return "[No response]"
	return npc[keyword]


# --- Example Utility ---
func talk_to_npc(village: String, index: int) -> void:
	var npc = get_npc(village, index)
	if npc.is_empty():
		return

	print("You approach " + npc["DESCRIPTION"])
	print("Ask about NAME: ", get_response(village, index, "NAME"))
	print("Ask about JOB: ", get_response(village, index, "JOB"))
	print("Ask about HEALTH: ", get_response(village, index, "HEALTH"))
	print("Ask about GOLD: ", get_response(village, index, "GOLD"))
	print("Rumor: ", get_response(village, index, "HOOK"))
