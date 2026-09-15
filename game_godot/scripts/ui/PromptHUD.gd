extends CanvasLayer

class_name PromptHUD

@onready var prompt_label: Label = $MarginContainer/PromptLabel

func _ready() -> void:
	set_process(true)
	EventBus.first_person_prompt_changed.connect(_on_prompt_changed)

func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""
