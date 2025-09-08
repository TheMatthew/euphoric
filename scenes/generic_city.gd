extends AreaAnnouncement

func _ready():
	if not area_name or area_name == "Village":
		var raw_name = name
		var clean = raw_name.split("_")
		area_name = clean[0].capitalize() + " of " + clean[1].capitalize()
	DialogManager._ready()
	super._ready()
