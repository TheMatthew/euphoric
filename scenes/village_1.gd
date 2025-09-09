#https://opengameart.org/content/town-theme
extends TileMapLayer

var bg_music := AudioStreamPlayer.new()

func _ready():
	bg_music.stream = load("res://res/valewind.ogg")
	bg_music.autoplay = true
	add_child(bg_music)
