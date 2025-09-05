extends AreaAnnouncement

func _ready():
	var raw_name = name
	var clean = raw_name.split("_")
	area_name = clean[0].capitalize() + " of " + clean[1].capitalize()
	super._ready()
