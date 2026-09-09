class_name FirstPersonInteractable
extends StaticBody3D

@export var interaction_id: String = ""
@export var target_id: String = ""
@export var prompt: String = "Interact"
@export var speaker_name: String = ""
@export_multiline var description: String = ""


@export var can_inspect: bool = false
@export var inspect_distance: float = 1.4
@export var inspect_height_offset: float = 0.0
@export var dynamic_prompt: String = ""


func get_interaction_prompt() -> String:
	var active_prompt := dynamic_prompt if not dynamic_prompt.is_empty() else prompt
	var is_mobile := OS.has_feature("android") or OS.has_feature("mobile") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	if is_mobile:
		var cleaned := active_prompt
		cleaned = cleaned.replace("[E / A] ", "").replace("[E/A] ", "").replace("[E / A]", "")
		cleaned = cleaned.replace("[E] ", "").replace("[E]", "")
		cleaned = cleaned.replace("[P] ", "").replace("[P]", "")
		return cleaned.strip_edges()
	return active_prompt


func interact(player: Node = null) -> void:
	EventBus.first_person_interaction_requested.emit({
		"interaction_id": interaction_id,
		"target_id": target_id,
		"prompt": get_interaction_prompt(),
		"speaker_name": speaker_name,
		"description": description,
		"node": self,
		"player": player
	})
