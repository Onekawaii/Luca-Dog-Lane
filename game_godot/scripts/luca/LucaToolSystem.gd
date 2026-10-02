class_name LucaToolSystem
extends Node

signal tool_changed(tool_id: String)
signal tool_action(tool_id: String, action: String, target: Variant)

const TOOLS := ["object_tether", "builder", "remover", "inspector"]

var selected_index := 0
var object_tether: Node

func configure(tether_node: Node) -> void:
	object_tether = tether_node

func selected_tool() -> String:
	return TOOLS[selected_index]

func select_tool(tool_id: String) -> bool:
	var index := TOOLS.find(tool_id)
	if index < 0:
		return false
	selected_index = index
	emit_signal("tool_changed", selected_tool())
	return true

func cycle(step: int = 1) -> String:
	selected_index = posmod(selected_index + step, TOOLS.size())
	emit_signal("tool_changed", selected_tool())
	return selected_tool()

func primary(target: Node = null) -> bool:
	var tool := selected_tool()
	if tool == "object_tether":
		if is_instance_valid(object_tether) and target is RigidBody3D:
			var ok: bool = object_tether.call("hold", target)
			if ok:
				emit_signal("tool_action", tool, "hold", target)
			return ok
		return false
	emit_signal("tool_action", tool, "primary", target)
	return true

func secondary(target: Node = null) -> bool:
	var tool := selected_tool()
	if tool == "object_tether" and is_instance_valid(object_tether):
		object_tether.call("release")
		emit_signal("tool_action", tool, "release", target)
		return true
	emit_signal("tool_action", tool, "secondary", target)
	return true
