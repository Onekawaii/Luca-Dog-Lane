class_name FirstPersonHoldable
extends RefCounted

# Reusable holdable / carry system helper for 3D first person props.

var item_id: String = ""
var prop_node: Node3D = null
var is_held: bool = false
var original_transform: Transform3D


func _init(p_item_id: String, p_prop: Node3D) -> void:
	item_id = p_item_id
	prop_node = p_prop
	if is_instance_valid(prop_node):
		original_transform = prop_node.global_transform


func can_pick_up() -> bool:
	return not is_held and is_instance_valid(prop_node) and prop_node.visible


func pick_up() -> bool:
	if not can_pick_up():
		return false
	is_held = true
	if is_instance_valid(prop_node):
		prop_node.visible = false
		prop_node.process_mode = Node.PROCESS_MODE_DISABLED
	return true


func place(target_transform: Transform3D) -> bool:
	if not is_held:
		return false
	is_held = false
	if is_instance_valid(prop_node):
		prop_node.global_transform = target_transform
		prop_node.visible = true
		prop_node.process_mode = Node.PROCESS_MODE_INHERIT
	return true
