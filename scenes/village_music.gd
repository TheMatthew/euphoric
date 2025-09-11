extends TileMapLayer

var bg_music := AudioStreamPlayer.new()
@export var source:AudioStream = null
@export var source_comment:String = ""
func _ready():
	if source:
		bg_music.stream = source
		bg_music.autoplay = true
		add_child(bg_music)
