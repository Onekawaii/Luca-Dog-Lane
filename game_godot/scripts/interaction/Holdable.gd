extends Node3D

class_name Holdable

var is_held: bool = false
var holder: Node = null
var _world_root: Node3D = null

@export var held_offset: Vector3 = Vector3(0.4, -0.2, -0.6)

var _collision_shapes: Array = []

func _ready() -> void:
	_world_root = get_parent() as Node3D
	_collision_shapes = []
	if _world_root:
		_collision_shapes.append_array(_world_root.find_children("*", "CollisionShape3D", true, false))
		_collision_shapes.append_array(_world_root.find_children("*", "CollisionPolygon3D", true, false))

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
	if _world_root:
		_world_root.visible = false
	else:
		visible = false
	# notify holder to show held representation
	if holder and holder.has_method("_on_holdable_picked"):
		holder._on_holdable_picked(self)
	return true

func get_half_height() -> float:
	for s in _collision_shapes:
		if s is CollisionShape3D and is_instance_valid(s.shape):
			var shape: Shape3D = s.shape
			if shape is BoxShape3D:
				return shape.size.y * 0.5
			if shape is CapsuleShape3D:
				return shape.height * 0.5
	return 0.25


func can_place_at(target: Transform3D, space_state: PhysicsDirectSpaceState3D, ignored_colliders: Array = []) -> bool:
	for s in _collision_shapes:
		if not (s is CollisionShape3D) or not is_instance_valid(s.shape):
			continue
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = s.shape
		params.transform = target * s.transform
		params.collision_mask = 1
		var overlaps := space_state.intersect_shape(params, 8)
		for overlap in overlaps:
			var collider = overlap.get("collider")
			if collider in ignored_colliders:
				continue
			return false
	return true


func place(target: Transform3D) -> bool:
	if not is_held:
		return false
	is_held = false
	if _world_root:
		_world_root.global_transform = target
		_world_root.visible = true
	else:
		global_transform = target
		visible = true
	for s in _collision_shapes:
		if is_instance_valid(s):
			s.disabled = false
	if holder and holder.has_method("_on_holdable_dropped"):
		holder._on_holdable_dropped(self)
	holder = null
	return true


func drop_at(global_pos: Vector3) -> bool:
	return place(Transform3D(Basis.IDENTITY, global_pos))
