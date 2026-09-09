extends Node

class_name InspectController

@export var inspect_distance: float = 1.2
@export var inspect_transition_time: float = 0.28

onready var player: Node = null
onready var camera: Camera3D = null

var _orig_transform: Transform3D
var _target: Node = null
var _tween: Tween = null

func _ready() -> void:
	# register singleton-like at root for easy lookup
	get_tree().get_root().set("InspectController", self)
	_tween = Tween.new()
	add_child(_tween)

func request_inspect(target: Node, from_player: Node) -> void:
	if _target != null:
		return
	_target = target
	player = from_player
	camera = player.camera
	_orig_transform = camera.global_transform
	# compute target camera transform: place camera inspect_distance in front of target
	var target_global := target.global_transform
	var forward := -target_global.basis.z.normalized()
	var inspect_pos := target_global.origin + forward * inspect_distance + Vector3(0, 0.2, 0)
	var look_at_transform := Transform3D().looking_at(target_global.origin, Vector3.UP)
	look_at_transform.origin = inspect_pos

	# lock player input
	player.emit_signal("_input_lock_changed", true) if player.has_method("_on_input_lock_requested") else player._on_input_lock_changed(true) if player.has_method("_on_input_lock_changed") else null
	# smooth transition
	_tween.interpolate_property(camera, "global_transform", camera.global_transform, look_at_transform, inspect_transition_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween.play()

func exit_inspect() -> void:
	if _target == null:
		return
	if not camera:
		camera = player.camera
	_tween.interpolate_property(camera, "global_transform", camera.global_transform, _orig_transform, inspect_transition_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween.play()
	_tween.connect("finished", Callable(self, "_on_exit_tween_finished"))

func _on_exit_tween_finished() -> void:
	if player:
		player.emit_signal("_input_lock_changed", false) if player.has_method("_on_input_lock_requested") else player._on_input_lock_changed(false) if player.has_method("_on_input_lock_changed") else null
	_target = null
