extends TileMapLayer

var bg_music := AudioStreamPlayer.new()

func _ready():
	bg_music.stream = load("res://res/Woodland Fantasy.mp3")
# https://opengameart.org/content/woodland-fantasy
# LOOPED VERSIONS ARE AVAILABLE UPON REQUEST VIA MY WEBSITE HERE:
# http://www.matthewpablo.com/contact
	bg_music.autoplay = true
	add_child(bg_music)
