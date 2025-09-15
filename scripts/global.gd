extends Node


@export var player_in_scene: bool = false
@export var volume: float = 1.0
@export var music_volume: float = 1.0
@onready var inventory: player_inventory = player_inventory.new()

func set_volume(value: float) -> void:
	volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	

func set_sfx_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sfx"), linear_to_db(music_volume))
