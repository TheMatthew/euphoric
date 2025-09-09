extends TileMapLayer
# https://opengameart.org/content/old-city-theme

var bg_music := AudioStreamPlayer.new()

func _ready():
	bg_music.stream = load("res://res/eldoria.ogg")

	bg_music.autoplay = true
	add_child(bg_music)
