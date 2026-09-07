class_name QuantumStateAnchor
extends RefCounted

# Reusable Quantum State Anchor (2D and 3D portable).
# Defines an authored valid spatial, physical, or absent state for a QuantumEntity.
# Used by Hive-Lattice First-Person and portable to Chernobyl Witness Anomalies.

var anchor_id: String = "anchor_default"
var display_name: String = "Default Anchor"
var position_2d: Vector2 = Vector2.ZERO
var position_3d: Vector3 = Vector3.ZERO
var rotation_3d: Vector3 = Vector3.ZERO
var rotation_deg: float = 0.0
var is_absent: bool = false
var relative_weight: float = 1.0 # Relative weight in resolution pool
var dialogue_state_hint: String = "default"
var metadata: Dictionary = {}
var require_nav_mesh: bool = false


func _init(
	p_id: String = "anchor_default",
	p_pos: Variant = Vector3.ZERO,
	p_weight: float = 1.0,
	p_absent: bool = false,
	p_dialogue_hint: String = "default",
	p_name: String = ""
) -> void:
	anchor_id = p_id
	relative_weight = p_weight
	is_absent = p_absent
	dialogue_state_hint = p_dialogue_hint
	display_name = p_name if p_name != "" else p_id.capitalize()

	if typeof(p_pos) == TYPE_VECTOR3:
		position_3d = p_pos
		position_2d = Vector2(p_pos.x, p_pos.z)
	elif typeof(p_pos) == TYPE_VECTOR2:
		position_2d = p_pos
		position_3d = Vector3(p_pos.x, 0.0, p_pos.y)


func matches_position_3d(pos: Vector3, tolerance: float = 0.1) -> bool:
	if is_absent:
		return false
	return position_3d.distance_to(pos) <= tolerance


func matches_position_2d(pos: Vector2, tolerance: float = 2.0) -> bool:
	if is_absent:
		return false
	return position_2d.distance_to(pos) <= tolerance


func to_dict() -> Dictionary:
	return {
		"anchor_id": anchor_id,
		"display_name": display_name,
		"position_3d": [position_3d.x, position_3d.y, position_3d.z],
		"position_2d": [position_2d.x, position_2d.y],
		"is_absent": is_absent,
		"relative_weight": relative_weight,
		"dialogue_state_hint": dialogue_state_hint
	}
