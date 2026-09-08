class_name FirstPersonInteractable
extends StaticBody3D

@export var interaction_id: String = ""
@export var target_id: String = ""
@export var prompt: String = "Interact"
@export var speaker_name: String = ""
@export_multiline var description: String = ""


func get_interaction_prompt() -> String:
	var is_mobile := OS.has_feature("android") or OS.has_feature("mobile") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	if is_mobile:
		var cleaned := prompt
		cleaned = cleaned.replace("[E / A] ", "").replace("[E/A] ", "").replace("[E / A]", "")
		cleaned = cleaned.replace("[E] ", "").replace("[E]", "")
		cleaned = cleaned.replace("[P] ", "").replace("[P]", "")
		return cleaned.strip_edges()
	return prompt


func interact(_player: Node) -> void:
	EventBus.first_person_interaction_requested.emit({
		"interaction_id": interaction_id,
		"target_id": target_id,
		"prompt": prompt,
		"speaker_name": speaker_name,
		"description": description,
	})
