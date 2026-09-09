class_name FirstPersonInspectable
extends RefCounted

# Reusable inspect target data and camera framing calculation.
# Used by FirstPersonInteractable nodes and FirstPersonBreakroom inspection system.

var target_node: Node3D
var inspect_distance: float = 1.2
var inspect_height_offset: float = 0.1
var inspect_prompt: String = "Inspect"
var inspect_title: String = ""
var inspect_description: String = ""


func _init(
	p_target: Node3D,
	p_distance: float = 1.2,
	p_height_offset: float = 0.1,
	p_prompt: String = "Inspect",
	p_title: String = "",
	p_desc: String = ""
) -> void:
	target_node = p_target
	inspect_distance = p_distance
	inspect_height_offset = p_height_offset
	inspect_prompt = p_prompt
	inspect_title = p_title
	inspect_description = p_desc


func compute_inspect_transform(from_position: Vector3) -> Transform3D:
	if not is_instance_valid(target_node):
		return Transform3D()

	var target_center := target_node.global_position + Vector3(0.0, inspect_height_offset, 0.0)
	var dir_to_cam := (from_position - target_center)
	dir_to_cam.y = 0.0
	if dir_to_cam.length_squared() < 0.001:
		dir_to_cam = -target_node.global_transform.basis.z
		dir_to_cam.y = 0.0
	if dir_to_cam.length_squared() < 0.001:
		dir_to_cam = Vector3(0, 0, 1)
	dir_to_cam = dir_to_cam.normalized()

	var cam_pos := target_center + dir_to_cam * inspect_distance + Vector3(0.0, 0.15, 0.0)
	var t := Transform3D().looking_at(target_center - cam_pos, Vector3.UP)
	t.origin = cam_pos
	return t
