extends Node3D

class_name Focusable

@export var prompt: String = "Inspect"

signal focused()
signal defocused()

func get_interaction_prompt() -> String:
	return prompt

func interact(player: Node) -> void:
	# Default interact: request inspect
	var inspect_controller = get_tree().get_root().get_node_or_null("/root/InspectController")
	if inspect_controller:
		inspect_controller.request_inspect(self, player)

func on_focused() -> void:
	emit_signal("focused")

func on_defocused() -> void:
	emit_signal("defocused")
