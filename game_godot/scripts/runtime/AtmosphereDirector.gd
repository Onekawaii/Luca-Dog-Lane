extends Node

# Persistent sensory spine. It survives menu/game transitions so Hive-Lattice
# never drops back to sterile silence between rooms or levels.
const ROOMTONE_PATH := "res://assets/audio/hive_roomtone.wav"
const WATERDROP_PATH := "res://assets/audio/hive_waterdrop.wav"

var roomtone: AudioStreamPlayer
var waterdrop: AudioStreamPlayer
var overlay: ColorRect
var rng := RandomNumberGenerator.new()
var next_drop_msec: int = 0
var current_level: int = -1
var current_title: String = ""

const LEVEL_TINTS := [
	Color(0.03, 0.09, 0.07, 0.075),
	Color(0.06, 0.08, 0.04, 0.070),
	Color(0.03, 0.06, 0.10, 0.080),
	Color(0.09, 0.04, 0.03, 0.065),
	Color(0.05, 0.04, 0.09, 0.080),
	Color(0.02, 0.08, 0.09, 0.070),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 6060
	_build_audio()
	_build_overlay()
	_schedule_next_drop()

func _build_audio() -> void:
	roomtone = AudioStreamPlayer.new()
	roomtone.name = "PersistentRoomtone"
	roomtone.stream = ResourceLoader.load(ROOMTONE_PATH) as AudioStream
	roomtone.volume_db = -24.0
	roomtone.finished.connect(func(): roomtone.play())
	add_child(roomtone)
	roomtone.play()

	waterdrop = AudioStreamPlayer.new()
	waterdrop.name = "PersistentWaterdrop"
	waterdrop.stream = ResourceLoader.load(WATERDROP_PATH) as AudioStream
	waterdrop.volume_db = -17.0
	add_child(waterdrop)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AtmosphereOverlay"
	layer.layer = 80
	add_child(layer)
	overlay = ColorRect.new()
	overlay.name = "PersistentTint"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = LEVEL_TINTS[0]
	layer.add_child(overlay)


func _process(_delta: float) -> void:
	if is_instance_valid(roomtone) and not roomtone.playing:
		roomtone.play()
	if Time.get_ticks_msec() >= next_drop_msec:
		play_waterdrop(-19.0)
		_schedule_next_drop()

func _schedule_next_drop() -> void:
	next_drop_msec = Time.get_ticks_msec() + rng.randi_range(4200, 9800)


func play_waterdrop(volume_db: float = -14.0) -> void:
	if not is_instance_valid(waterdrop):
		return
	waterdrop.volume_db = volume_db
	waterdrop.pitch_scale = rng.randf_range(0.88, 1.14)
	waterdrop.play()


func play_containment_drop() -> void:
	play_waterdrop(-20.0)
	var tree := get_tree()
	if tree != null:
		tree.create_timer(0.42).timeout.connect(func(): play_waterdrop(-24.0))


func set_level(level_index: int, title: String = "") -> void:
	if level_index == current_level and title == current_title:
		return
	current_level = level_index
	current_title = title
	if is_instance_valid(overlay):
		overlay.color = LEVEL_TINTS[posmod(level_index, LEVEL_TINTS.size())]
	if is_instance_valid(roomtone):
		roomtone.pitch_scale = 0.96 + float(posmod(level_index, 5)) * 0.015
		roomtone.volume_db = -24.0 + float(posmod(level_index, 3))


func enter_menu() -> void:
	set_level(0, "LUCA DOG WORLD")
	if is_instance_valid(roomtone):
		roomtone.volume_db = -27.0


func enter_gameplay() -> void:
	if is_instance_valid(roomtone):
		roomtone.volume_db = -23.0
