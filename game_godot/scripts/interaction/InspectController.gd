extends Node

class_name InspectController

@export var inspect_distance: float = 1.2
@export var inspect_transition_time: float = 0.28

onready var player: Node = null
onready var camera: Camera3D = null

var _orig_transform: Transform3D
var _orig_fov: float = 0.0
var _target: Node = null
var _tween: Tween = null
const INSPECT_FOV: float = 42.0

func _ready() -> void:
	# register singleton-like at root for easy lookup
	get_tree().get_root().set("InspectController", self)
	_tween = Tween.new()
	add_child(_tween)
	# Ensure EventBus is available
	# No-op: other systems will listen to EventBus.first_person_inspect_started/ended

func request_inspect(target: Node, from_player: Node) -> void:
	if _target != null:
		return
	_target = target
	player = from_player
	camera = player.camera
	if not camera:
		return
	# Save exact starting transform and FOV
	_orig_transform = camera.global_transform
	_orig_fov = camera.fov
	# emit global input lock via EventBus
	EventBus.first_person_input_lock_changed.emit(true)
	EventBus.first_person_inspect_started.emit(str(target.name))
	# compute target camera transform: place camera inspect_distance in front of target
	var target_global := target.global_transform
	var forward := -target_global.basis.z.normalized()
	var inspect_pos := target_global.origin + forward * inspect_distance + Vector3(0, 0.2, 0)
	var look_at_transform := Transform3D().looking_at(target_global.origin, Vector3.UP)
	look_at_transform.origin = inspect_pos

	# smooth transition: cancel any active tween and begin
	if _tween.is_valid():
		_tween.kill()
	camera.fov = INSPECT_FOV
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(camera, "global_transform", camera.global_transform, look_at_transform, inspect_transition_time)
	_tween.play()

	# ensure we listen for exit requests from input layer via EventBus
	# (other systems should call InspectController.exit_inspect() to end)

func exit_inspect() -> void:
	if _target == null:
		return
	if not camera:
		camera = player.camera
	if _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(camera, "global_transform", camera.global_transform, _orig_transform, inspect_transition_time)
	_tween.tween_callback(Callable(self, "_restore_fov_and_finish"))
	_tween.play()

	# Also emit input unlock immediately if no tween (defensive)
	if inspect_transition_time <= 0.0:
		EventBus.first_person_input_lock_changed.emit(false)

func _restore_fov_and_finish() -> void:
	# restore FOV and unlock input
	if is_instance_valid(camera):
		camera.fov = _orig_fov
		camera.global_transform = _orig_transform if _orig_transform != null else camera.global_transform
	EventBus.first_person_input_lock_changed.emit(false)
	EventBus.first_person_inspect_ended.emit()
	_target = null
