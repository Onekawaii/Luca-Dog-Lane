extends Node

# Offline audio manager for Hive-Lattice Godot client.

var hum_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var pulse_player: AudioStreamPlayer

var sound_streams: Dictionary = {}


func _ready() -> void:
	hum_player = AudioStreamPlayer.new()
	hum_player.bus = "Master"
	add_child(hum_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)

	pulse_player = AudioStreamPlayer.new()
	pulse_player.bus = "Master"
	add_child(pulse_player)

	_load_sounds()
	start_ambience()


func _load_sounds() -> void:
	var files = {
		"hum": "res://assets/audio/fluorescent_hum.wav",
		"click": "res://assets/audio/ui_click.wav",
		"pickup": "res://assets/audio/item_pickup.wav",
		"pulse": "res://assets/audio/wetberry_pulse.wav",
		"footstep": "res://assets/audio/footstep.wav",
	}
	for k in files:
		if ResourceLoader.exists(files[k]):
			sound_streams[k] = load(files[k])


func start_ambience() -> void:
	if sound_streams.has("hum") and hum_player:
		hum_player.stream = sound_streams["hum"]
		hum_player.volume_db = -12.0
		# If available, play looping ambience
		if not hum_player.playing:
			hum_player.play()


func play_ui_click() -> void:
	if sound_streams.has("click") and sfx_player:
		sfx_player.stream = sound_streams["click"]
		sfx_player.volume_db = -4.0
		sfx_player.play()


func play_item_pickup() -> void:
	if sound_streams.has("pickup") and sfx_player:
		sfx_player.stream = sound_streams["pickup"]
		sfx_player.volume_db = -2.0
		sfx_player.play()


func play_wetberry_pulse() -> void:
	if sound_streams.has("pulse") and pulse_player:
		pulse_player.stream = sound_streams["pulse"]
		pulse_player.volume_db = -6.0
		pulse_player.play()


func play_footstep() -> void:
	if sound_streams.has("footstep") and sfx_player:
		sfx_player.stream = sound_streams["footstep"]
		sfx_player.volume_db = -10.0
		sfx_player.play()
