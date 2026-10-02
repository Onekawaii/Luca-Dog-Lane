class_name FirstPersonHUD
extends CanvasLayer

@onready var crosshair: Label = $Root/Crosshair
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
@onready var inventory_button: Button = $Root/InventoryButton
@onready var inventory_panel: PanelContainer = $Root/InventoryPanel
@onready var inventory_items: VBoxContainer = $Root/InventoryPanel/Margin/VBox/Scroll/Items
@onready var inventory_detail: Label = $Root/InventoryPanel/Margin/VBox/Detail
@onready var close_inventory_button: Button = $Root/InventoryPanel/Margin/VBox/CloseInventoryButton
@onready var save_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/SaveButton
@onready var load_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/LoadButton
@onready var close_pda_button: Button = $Root/PDAPanel/Margin/VBox/Buttons/CloseButton
@onready var hint_label: Label = $Root/PDAPanel/Margin/VBox/Hint
@onready var mobile_controls: Control = $Root/MobileControls
@onready var interact_button: Button = $Root/MobileControls/InteractButton
@onready var fly_button: Button = $Root/MobileControls/FlyButton
@onready var fly_up_button: Button = $Root/MobileControls/FlyUpButton
@onready var fly_down_button: Button = $Root/MobileControls/FlyDownButton

var dialogue_lines: Array = []
var dialogue_index: int = 0
var current_objective: String = "Find Keith and get safe containment gear."
var current_interaction_prompt: String = ""
var pre_inspect_prompt: String = ""
var gameplay_input_locked: bool = false
var fly_enabled: bool = false
var force_mobile_controls: bool = false

const CROSSHAIR_IDLE := Color(0.82, 1.0, 0.83, 0.62)
const CROSSHAIR_ACTIVE := Color(0.38, 1.0, 0.52, 1.0)


func is_mobile() -> bool:
	return force_mobile_controls or OS.has_feature("android") or OS.has_feature("mobile") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


func _ready() -> void:
	prompt_label.visible = false
	dialogue_panel.visible = false
	pda_panel.visible = false
	inventory_panel.visible = false
	notification_panel.visible = false
	mobile_controls.visible = is_mobile()

	_apply_platform_labels()

	EventBus.first_person_prompt_changed.connect(_on_prompt_changed)
	EventBus.first_person_dialogue_requested.connect(_on_dialogue_requested)
	EventBus.first_person_objective_changed.connect(_on_objective_changed)
	EventBus.notification_posted.connect(_on_notification)
	EventBus.inventory_changed.connect(_refresh_pda)
	EventBus.inventory_changed.connect(_refresh_inventory_panel)
	EventBus.world_state_changed.connect(func(_delta): _refresh_pda())

	EventBus.first_person_inspect_started.connect(_on_inspect_started)
	EventBus.first_person_inspect_ended.connect(_on_inspect_ended)
	EventBus.first_person_input_lock_changed.connect(_on_first_person_input_lock_changed)
	EventBus.first_person_fly_state_changed.connect(_on_fly_state_changed)

	continue_button.pressed.connect(_advance_dialogue)
	pda_button.pressed.connect(_toggle_pda)
	inventory_button.pressed.connect(_toggle_inventory)
	close_inventory_button.pressed.connect(_toggle_inventory)
	save_button.pressed.connect(func(): GameRuntime.save_slot(GameRuntime.current_save_slot()))
	load_button.pressed.connect(func(): GameRuntime.load_slot(GameRuntime.current_save_slot()))
	close_pda_button.pressed.connect(_toggle_pda)
	interact_button.pressed.connect(_on_interact_pressed)
	fly_button.pressed.connect(_on_fly_pressed)
	fly_up_button.button_down.connect(func(): EventBus.first_person_fly_vertical_input.emit(1.0))
	fly_up_button.button_up.connect(func(): EventBus.first_person_fly_vertical_input.emit(0.0))
	fly_down_button.button_down.connect(func(): EventBus.first_person_fly_vertical_input.emit(-1.0))
	fly_down_button.button_up.connect(func(): EventBus.first_person_fly_vertical_input.emit(0.0))

	_refresh_pda()
	_refresh_inventory_panel()
	_update_interaction_feedback()
	_update_fly_controls()


func _apply_platform_labels() -> void:
	if is_mobile():
		pda_button.text = "PDA"
		inventory_button.text = "INV"
		fly_button.text = "LAND" if fly_enabled else "FLY"
		if is_instance_valid(hint_label):
			hint_label.text = "Touch: Left stick move • Drag to look • INTERACT button • Save/Load buttons"
	else:
		pda_button.text = "PDA [P]"
		inventory_button.text = "INVENTORY [I]"
		fly_button.text = "LAND [F]" if fly_enabled else "FLY [F]"
		if is_instance_valid(hint_label):
			hint_label.text = "Desktop: WASD move • Mouse look • E interact • F fly/noclip • Space up • C down • Shift boost • R unstuck • F5/F9 save/load"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_P:
			_toggle_pda()
		elif key.keycode == KEY_I:
			_toggle_inventory()
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
	var modal_open := _modal_open()
	prompt_label.visible = not modal_open and not prompt_label.text.is_empty()


func _action_label_for_prompt(text: String) -> String:
	var action := _format_prompt(text).strip_edges().to_lower()
	if action.begins_with("open "):
		return "OPEN"
	if action.begins_with("close "):
		return "CLOSE"
	if action.begins_with("talk "):
		return "TALK"
	if action.begins_with("inspect "):
		return "INSPECT"
	if action.begins_with("pick up ") or action.begins_with("pickup "):
		return "PICK UP"
	if action.begins_with("place ") or action.begins_with("put down "):
		return "PLACE"
	if action.begins_with("turn on "):
		return "TURN ON"
	if action.begins_with("turn off "):
		return "TURN OFF"
	return "INTERACT"


func _update_interaction_feedback() -> void:
	var modal_open := _modal_open()
	var actionable := not current_interaction_prompt.is_empty() and not gameplay_input_locked and not modal_open
	if is_instance_valid(interact_button):
		interact_button.disabled = not actionable
		interact_button.text = _action_label_for_prompt(current_interaction_prompt) if actionable else "INTERACT"
	if is_instance_valid(crosshair):
		crosshair.modulate = CROSSHAIR_ACTIVE if actionable else CROSSHAIR_IDLE


func _modal_open() -> bool:
	return (is_instance_valid(dialogue_panel) and dialogue_panel.visible) or (is_instance_valid(pda_panel) and pda_panel.visible) or (is_instance_valid(inventory_panel) and inventory_panel.visible)


func _on_interact_pressed() -> void:
	if gameplay_input_locked or not is_instance_valid(interact_button) or interact_button.disabled:
		return
	EventBus.first_person_interact_pressed.emit()


func _on_prompt_changed(text: String) -> void:
	current_interaction_prompt = _format_prompt(text)
	if is_instance_valid(prompt_label):
		prompt_label.text = current_interaction_prompt
	_update_prompt_visibility()
	_update_interaction_feedback()


func _on_inspect_started(target_name: String) -> void:
	pre_inspect_prompt = current_interaction_prompt
	var exit_hint := "Tap anywhere to exit inspect" if is_mobile() else "[ESC / E] Exit Inspect (" + target_name + ")"
	_on_prompt_changed(exit_hint)


func _on_inspect_ended() -> void:
	var restored_prompt := pre_inspect_prompt
	pre_inspect_prompt = ""
	_on_prompt_changed(restored_prompt)


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
	if is_instance_valid(inventory_panel) and inventory_panel.visible:
		inventory_panel.visible = false
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
	if is_instance_valid(inventory_panel) and inventory_panel.visible:
		inventory_panel.visible = false
	if is_instance_valid(pda_panel):
		pda_panel.visible = not pda_panel.visible
		_set_mobile_gameplay_controls_enabled(not pda_panel.visible)
		_update_prompt_visibility()
		EventBus.first_person_input_lock_changed.emit(pda_panel.visible)
		_refresh_pda()


func _toggle_inventory() -> void:
	if is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		return
	if is_instance_valid(pda_panel) and pda_panel.visible:
		pda_panel.visible = false
	if not is_instance_valid(inventory_panel):
		return
	inventory_panel.visible = not inventory_panel.visible
	_set_mobile_gameplay_controls_enabled(not inventory_panel.visible)
	_update_prompt_visibility()
	EventBus.first_person_input_lock_changed.emit(inventory_panel.visible)
	_refresh_inventory_panel()


func _on_fly_pressed() -> void:
	if gameplay_input_locked or _modal_open():
		return
	EventBus.first_person_fly_toggle_requested.emit()


func _on_fly_state_changed(enabled: bool) -> void:
	fly_enabled = enabled
	_apply_platform_labels()
	_update_fly_controls()


func _update_fly_controls() -> void:
	var modal_open := _modal_open()
	if is_instance_valid(fly_button):
		fly_button.disabled = gameplay_input_locked or modal_open
	if is_instance_valid(fly_up_button):
		fly_up_button.visible = is_mobile() and fly_enabled
		fly_up_button.disabled = gameplay_input_locked or modal_open or not fly_enabled
	if is_instance_valid(fly_down_button):
		fly_down_button.visible = is_mobile() and fly_enabled
		fly_down_button.disabled = gameplay_input_locked or modal_open or not fly_enabled
	if gameplay_input_locked or modal_open or not fly_enabled:
		EventBus.first_person_fly_vertical_input.emit(0.0)


func _on_first_person_input_lock_changed(locked: bool) -> void:
	gameplay_input_locked = locked
	_update_interaction_feedback()
	_update_fly_controls()
	if not locked or not is_instance_valid(mobile_controls):
		return
	var look_zone := mobile_controls.find_child("TouchLookZone", true, false)
	if is_instance_valid(look_zone) and look_zone.has_method("reset_touch"):
		look_zone.reset_touch()
	var stick := mobile_controls.find_child("MobileStick", true, false)
	if is_instance_valid(stick) and stick.has_method("_reset_stick"):
		stick._reset_stick()


func _set_mobile_gameplay_controls_enabled(enabled: bool) -> void:
	if not is_instance_valid(mobile_controls):
		return
	mobile_controls.visible = is_mobile() and enabled
	mobile_controls.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if not enabled:
		EventBus.first_person_fly_vertical_input.emit(0.0)
	_update_fly_controls()
	if not enabled:
		var look_zone := mobile_controls.find_child("TouchLookZone", true, false)
		if is_instance_valid(look_zone) and look_zone.has_method("reset_touch"):
			look_zone.reset_touch()
		var stick := mobile_controls.find_child("MobileStick", true, false)
		if is_instance_valid(stick) and stick.has_method("_reset_stick"):
			stick._reset_stick()


func _refresh_inventory_panel() -> void:
	if not is_instance_valid(inventory_items) or GameRuntime.inventory_system == null:
		return
	for child in inventory_items.get_children():
		child.queue_free()
	var items := GameRuntime.inventory_system.get_items()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nothing carried."
		inventory_items.add_child(empty)
		inventory_detail.text = "Items you pick up or are handed will stay here."
		return
	for item in items:
		var btn := Button.new()
		var item_id := str(item.get("id", ""))
		var item_name := str(item.get("name", item_id))
		btn.text = item_name
		btn.custom_minimum_size = Vector2(0, 72)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var icon_path := str(item.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path) as Texture2D
			btn.expand_icon = true
			btn.icon_max_width = 52
		var captured: Dictionary = item.duplicate(true) as Dictionary
		btn.pressed.connect(func(): _select_inventory_item(captured))
		inventory_items.add_child(btn)
	inventory_detail.text = "Select an item to inspect or ready it for use."


func _select_inventory_item(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var item_name := str(item.get("name", item_id))
	var description := str(item.get("description", "No description available."))
	if GameRuntime.inventory_system.get_armed_item() == item_id:
		GameRuntime.inventory_system.disarm_item()
		inventory_detail.text = item_name + "
" + description + "

Not readied."
	else:
		GameRuntime.inventory_system.arm_item(item_id)
		inventory_detail.text = item_name + "
" + description + "

READY FOR USE"


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
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var kevin := tree.root.find_child("FirstPersonKevin", true, false)
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
	if not is_instance_valid(notification_label) or not is_instance_valid(notification_panel):
		return
	notification_label.text = message
	notification_panel.visible = true
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(3.0)
		timer.timeout.connect(func():
			if is_instance_valid(notification_panel):
				notification_panel.visible = false
		)
