class_name LucaObjectTether
extends Node

@export var hold_distance := 3.0
@export var follow_speed := 12.0

var anchor: Node3D
var held_body: RigidBody3D
var _previous_freeze := false

func configure(anchor_node: Node3D) -> void:
	anchor = anchor_node

func can_hold(body: Node) -> bool:
	return body is RigidBody3D and not bool(body.get_meta("luca_tether_locked", false))

func hold(body: RigidBody3D) -> bool:
	if not can_hold(body):
		return false
	release()
	held_body = body
	_previous_freeze = held_body.freeze
	held_body.freeze = true
	return true

func release() -> void:
	if is_instance_valid(held_body):
		held_body.freeze = _previous_freeze
	held_body = null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(held_body) or not is_instance_valid(anchor):
		return
	var target := anchor.global_position - anchor.global_transform.basis.z.normalized() * hold_distance
	held_body.global_position = held_body.global_position.lerp(target, clampf(delta * follow_speed, 0.0, 1.0))
