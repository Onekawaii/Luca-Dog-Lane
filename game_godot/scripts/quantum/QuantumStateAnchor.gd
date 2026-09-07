class_name QuantumStateAnchor
extends RefCounted

# Reusable Quantum State Anchor.
# Defines an authored valid spatial, physical, or absent state for a QuantumEntity.
# Completely generic and portable to 2D, 3D, and Chernobyl systems.

var anchor_id: String = "anchor_default"
var display_name: String = "Default Anchor"
var position_2d: Vector2 = Vector2.ZERO
var position_3d: Vector3 = Vector3.ZERO
var rotation_deg: float = 0.0
var is_absent: bool = false
var weight: float = 1.0
var dialogue_state_hint: String = "default"
var metadata: Dictionary = {}
var require_nav_mesh: bool = false


func _init(
	p_id: String = "anchor_default",
	p_pos_2d: Vector2 = Vector2.ZERO,
	p_weight: float = 1.0,
	p_absent: bool = false,
	p_dialogue_hint: String = "default",
	p_name: String = ""
) -> void:
	anchor_id = p_id
	position_2d = p_pos_2d
	weight = p_weight
	is_absent = p_absent
	dialogue_state_hint = p_dialogue_hint
	display_name = p_name if p_name != "" else p_id.capitalize()


func matches_position(pos: Vector2, tolerance: float = 2.0) -> bool:
	if is_absent:
		return false
	return position_2d.distance_to(pos) <= tolerance


func to_dict() -> Dictionary:
	return {
		"anchor_id": anchor_id,
		"display_name": display_name,
		"position_2d": [position_2d.x, position_2d.y],
		"is_absent": is_absent,
		"weight": weight,
		"dialogue_state_hint": dialogue_state_hint
	}
