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
@onready var quantum_diagnostic_label: Label = $Root/PDAPanel/Margin/VBox/QuantumDiagnostic
@onready var pda_button: Button = $Root/PDAButton
@onready var save_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/SaveButton
@onready var load_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/LoadButton
@onready var close_pda_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/CloseButton
@onready var hint_label: Label = $Root/PDAPanel/Margin/VBox/Hint
@onready var mobile_controls: Control = $Root/MobileControls
@onready var interact_button: Button = $Root/MobileControls/InteractButton

var dialogue_lines: Array = []
var dialogue_index: int = 0
var current_objective: String = "Find Keith and get safe containment gear."


func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("mobile") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _ready() -> void:
	prompt_label.visible = false
	dialogue_panel.visible = false
	pda_panel.visible = false
	notification_panel.visible = false
	mobile_controls.visible = is_mobile()

	_apply_platform_labels()

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


func _apply_platform_labels() -> void:
	if is_mobile():
		pda_button.text = "PDA"
		if is_instance_valid(hint_label):
			hint_label.text = "Touch: Left stick move • Drag to look • INTERACT button • Save/Load buttons"
	else:
		pda_button.text = "PDA [P]"
		if is_instance_valid(hint_label):
			hint_label.text = "Desktop: WASD move • Mouse look • E interact • Shift sprint • F5/F9 save/load"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_P:
			_toggle_pda()
		elif dialogue_panel.visible and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
			_advance_dialogue()


func _format_prompt(text: String) -> String:
	if text.is_empty():
		return ""
	if is_mobile():
		var cleaned := text
		cleaned = cleaned.replace("[E / A] ", "").replace("[E/A] ", "").replace("[E / A]", "")
		cleaned = cleaned.replace("[E] ", "").replace("[E]", "")
		cleaned = cleaned.replace("[P] ", "").replace("[P]", "")
		return cleaned.strip_edges()
	return text


func _update_prompt_visibility() -> void:
	if not is_instance_valid(prompt_label):
		return
	var modal_open := (is_instance_valid(dialogue_panel) and dialogue_panel.visible) or (is_instance_valid(pda_panel) and pda_panel.visible)
	prompt_label.visible = not modal_open and not prompt_label.text.is_empty()


func _on_prompt_changed(text: String) -> void:
	if is_instance_valid(prompt_label):
		prompt_label.text = _format_prompt(text)
	_update_prompt_visibility()


func _on_objective_changed(text: String) -> void:
	current_objective = text
	if is_instance_valid(objective_label):
		objective_label.text = text
	_refresh_pda()


func _on_dialogue_requested(speaker: String, lines: Array) -> void:
	dialogue_lines = lines.duplicate()
	dialogue_index = 0
	if is_instance_valid(speaker_label):
		speaker_label.text = speaker
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = true
	if is_instance_valid(pda_panel) and pda_panel.visible:
		pda_panel.visible = false
	_set_mobile_gameplay_controls_enabled(false)
	_update_prompt_visibility()
	EventBus.first_person_input_lock_changed.emit(true)
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	if dialogue_lines.is_empty():
		_close_dialogue()
		return
	if is_instance_valid(dialogue_label):
		dialogue_label.text = str(dialogue_lines[dialogue_index])
	if is_instance_valid(continue_button):
		continue_button.text = "Go on." if dialogue_index < dialogue_lines.size() - 1 else "Done."


func _advance_dialogue() -> void:
	if not is_instance_valid(dialogue_panel) or not dialogue_panel.visible:
		return
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		_close_dialogue()
	else:
		_show_dialogue_line()


func _close_dialogue() -> void:
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	dialogue_lines.clear()
	dialogue_index = 0
	_set_mobile_gameplay_controls_enabled(true)
	_update_prompt_visibility()
	EventBus.first_person_input_lock_changed.emit(false)
	EventBus.first_person_dialogue_closed.emit()


func _toggle_pda() -> void:
	if is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		return
	if is_instance_valid(pda_panel):
		pda_panel.visible = not pda_panel.visible
		_set_mobile_gameplay_controls_enabled(not pda_panel.visible)
		_update_prompt_visibility()
		EventBus.first_person_input_lock_changed.emit(pda_panel.visible)
		_refresh_pda()


func _set_mobile_gameplay_controls_enabled(enabled: bool) -> void:
	if not is_instance_valid(mobile_controls):
		return
	mobile_controls.visible = is_mobile() and enabled
	mobile_controls.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


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
	_refresh_quantum_diagnostic()


func _refresh_quantum_diagnostic() -> void:
	if not is_instance_valid(quantum_diagnostic_label):
		return
	var kevin := get_tree().root.find_child("FirstPersonKevin", true, false)
	if kevin == null or kevin.get("quantum_component") == null:
		quantum_diagnostic_label.text = "QUANTUM COHERENCE\nSubject: Kevin — status unavailable"
		return
	var q = kevin.get("quantum_component")
	if not q.has_method("get_status_summary"):
		quantum_diagnostic_label.text = "QUANTUM COHERENCE\nSubject: Kevin — component online"
		return
	var summary: Dictionary = q.get_status_summary()
	var observed := bool(summary.get("observed", false))
	quantum_diagnostic_label.text = "QUANTUM COHERENCE\nState: %s\nLast confirmed anchor: %s\nCoherence: %s%%\nWitnesses: %s" % ["OBSERVED" if observed else "UNCONFIRMED", str(summary.get("last_confirmed_location", "unknown")), str(summary.get("coherence_pct", 0)), str(summary.get("witness_count", 0))]


func _on_notification(message: String) -> void:
	notification_label.text = message
	notification_panel.visible = true
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(notification_panel):
			notification_panel.visible = false
	)
