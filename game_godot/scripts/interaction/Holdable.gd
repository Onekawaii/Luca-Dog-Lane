extends Node3D

class_name Holdable

var is_held: bool = false
var holder: Node = null

@export var held_offset: Vector3 = Vector3(0.4, -0.2, -0.6)

var _collision_shapes: Array = []

func _ready() -> void:
	# gather collision shapes for easy enable/disable
	_collision_shapes = []
	for child in get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			_collision_shapes.append(child)

func can_pick_up() -> bool:
	return not is_held

func pick_up(by_player: Node) -> bool:
	if not can_pick_up():
		return false
	is_held = true
	holder = by_player
	# disable collisions and hide the world collider while held
	for s in _collision_shapes:
		if is_instance_valid(s):
			s.disabled = true
	visible = false if has_method("set_visible") else null
	# notify holder to show held representation
	if holder and holder.has_method("_on_holdable_picked"):
		holder._on_holdable_picked(self)
	return true

func drop_at(global_pos: Vector3) -> bool:
	if not is_held:
		return false
	is_held = false
	# place in world
	global_transform.origin = global_pos
	visible = true if has_method("set_visible") else null
	# re-enable collisions
	for s in _collision_shapes:
		if is_instance_valid(s):
			s.disabled = false
	if holder and holder.has_method("_on_holdable_dropped"):
		holder._on_holdable_dropped(self)
	holder = null
	return true
