extends AreaAnnouncement


func _ready():
	var raw_name = name
	var clean = raw_name.split("_")
	area_name = clean[0].capitalize() + " of " + clean[1].capitalize()
	destination_id="start"
	target_scene="res://scenes/village1.tscn"
	
	super._ready()
