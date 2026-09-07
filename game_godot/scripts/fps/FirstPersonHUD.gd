class_name FirstPersonHUD
extends CanvasLayer

@onready var prompt_label: Label = $Root/PromptLabel
@onready var objective_label: Label = $Root/ObjectivePanel/Margin/VBox/ObjectiveLabel
@onready var notification_label: Label = $Root/NotificationPanel/Margin/NotificationLabel
@onready var notification_panel: PanelContainer = $Root/NotificationPanel
@onready var dialogue_panel: PanelContainer = $Root/DialoguePanel
@onready var speaker_label: Label = $Root/DialoguePanel/Margin/VBox/SpeakerLabel
@onready var dialogue_label: Label = $Root/DialoguePanel/Margin/VBox/DialogueLabel
@onready var continue_button: Button = $Root/DialoguePanel/Margin/VBox/ContinueButton
@onready var pda_panel: PanelContainer = $Root/PDAPanel
@onready var pda_objective_label: Label = $Root/PDAPanel/Margin/VBox/PDAObjective
@onready var inventory_label: Label = $Root/PDAPanel/Margin/VBox/InventoryLabel
@onready var pda_button: Button = $Root/PDAButton
@onready var save_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/SaveButton
@onready var load_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/LoadButton
@onready var close_pda_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/CloseButton
@onready var mobile_controls: Control = $Root/MobileControls
@onready var interact_button: Button = $Root/MobileControls/InteractButton

var dialogue_lines: Array = []
var dialogue_index: int = 0
var current_objective: String = "Find Keith and get safe containment gear."


func _ready() -> void:
	dialogue_panel.visible = false
	pda_panel.visible = false
	notification_panel.visible = false
	mobile_controls.visible = DisplayServer.is_touchscreen_available()

	EventBus.first_person_prompt_changed.connect(_on_prompt_changed)
	EventBus.first_person_dialogue_requested.connect(_on_dialogue_requested)
	EventBus.first_person_objective_changed.connect(_on_objective_changed)
	EventBus.notification_posted.connect(_on_notification)
	EventBus.inventory_changed.connect(_refresh_pda)
	EventBus.world_state_changed.connect(func(_delta): _refresh_pda())

	continue_button.pressed.connect(_advance_dialogue)
	pda_button.pressed.connect(_toggle_pda)
	save_button.pressed.connect(func(): GameRuntime.save_slot("slot_1"))
	load_button.pressed.connect(func(): GameRuntime.load_slot("slot_1"))
	close_pda_button.pressed.connect(_toggle_pda)
	interact_button.pressed.connect(func(): EventBus.first_person_interact_pressed.emit())

	_refresh_pda()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_P:
			_toggle_pda()
		elif dialogue_panel.visible and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
			_advance_dialogue()


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text


func _on_objective_changed(text: String) -> void:
	current_objective = text
	objective_label.text = text
	_refresh_pda()


func _on_dialogue_requested(speaker: String, lines: Array) -> void:
	dialogue_lines = lines.duplicate()
	dialogue_index = 0
	speaker_label.text = speaker
	dialogue_panel.visible = true
	if pda_panel.visible:
		pda_panel.visible = false
	_set_mobile_gameplay_controls_enabled(false)
	EventBus.first_person_input_lock_changed.emit(true)
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	if dialogue_lines.is_empty():
		_close_dialogue()
		return
	dialogue_label.text = str(dialogue_lines[dialogue_index])
	continue_button.text = "Go on." if dialogue_index < dialogue_lines.size() - 1 else "Done."


func _advance_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		_close_dialogue()
	else:
		_show_dialogue_line()


func _close_dialogue() -> void:
	dialogue_panel.visible = false
	dialogue_lines.clear()
	dialogue_index = 0
	_set_mobile_gameplay_controls_enabled(true)
	EventBus.first_person_input_lock_changed.emit(false)
	EventBus.first_person_dialogue_closed.emit()


func _toggle_pda() -> void:
	if dialogue_panel.visible:
		return
	pda_panel.visible = not pda_panel.visible
	_set_mobile_gameplay_controls_enabled(not pda_panel.visible)
	EventBus.first_person_input_lock_changed.emit(pda_panel.visible)
	_refresh_pda()


func _set_mobile_gameplay_controls_enabled(enabled: bool) -> void:
	if not is_instance_valid(mobile_controls):
		return
	mobile_controls.visible = DisplayServer.is_touchscreen_available() and enabled


func _refresh_pda() -> void:
	if not is_instance_valid(inventory_label):
		return
	pda_objective_label.text = "OBJECTIVE\n" + current_objective
	var lines: Array[String] = ["INVENTORY"]
	if GameRuntime.world_state != null and GameRuntime.inventory_system != null:
		var items := GameRuntime.inventory_system.get_items()
		if items.is_empty():
			lines.append("• Empty")
		else:
			for item in items:
				lines.append("• " + str(item.get("name", item.get("id", "Unknown item"))))
	inventory_label.text = "\n".join(lines)


func _on_notification(message: String) -> void:
	notification_label.text = message
	notification_panel.visible = true
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(notification_panel):
			notification_panel.visible = false
	)
