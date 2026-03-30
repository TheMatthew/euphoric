# village_music.gd - Extended with fog of war support
extends TileMapLayer

var bg_music := AudioStreamPlayer.new()
@export var source: AudioStream = null
@export var source_comment: String = ""
@export var enable_fog_of_war: bool = true
@export var fog_sight_range: int = 6

func _ready():
	if source:
		bg_music.stream = source
		bg_music.autoplay = true
		source.loop = true
		add_child(bg_music)
	
	# FogOfWar is managed as a singleton on Camera2D — see scenes/fog_of_war.gd
	if enable_fog_of_war and FogOfWar.instance:
		FogOfWar.instance.call_deferred("refresh_for_new_scene")
