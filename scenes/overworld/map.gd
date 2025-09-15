extends TileMapLayer

var bg_music := AudioStreamPlayer.new()
@export var music:AudioStream = null


func _ready():
	bg_music.stream = music
# https://opengameart.org/content/woodland-fantasy
# LOOPED VERSIONS ARE AVAILABLE UPON REQUEST VIA MY WEBSITE HERE:
# http://www.matthewpablo.com/contact
	bg_music.autoplay = true
	add_child(bg_music)
