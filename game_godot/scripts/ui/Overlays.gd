class_name Overlays
extends Control

# Modal game screens (Status, Journal, Pause/Save) inside the native game client.

@onready var status_modal: PanelContainer = $StatusModal
@onready var status_content: Label = $StatusModal/MarginContainer/VBoxContainer/ScrollContainer/StatusContent
@onready var status_close_btn: Button = $StatusModal/MarginContainer/VBoxContainer/CloseButton

@onready var journal_modal: PanelContainer = $JournalModal
@onready var journal_content: Label = $JournalModal/MarginContainer/VBoxContainer/ScrollContainer/JournalContent
@onready var journal_close_btn: Button = $JournalModal/MarginContainer/VBoxContainer/CloseButton

@onready var pause_modal: PanelContainer = $PauseModal
@onready var save_btn: Button = $PauseModal/MarginContainer/VBoxContainer/SaveButton
@onready var load_btn: Button = $PauseModal/MarginContainer/VBoxContainer/LoadButton
@onready var new_game_btn: Button = $PauseModal/MarginContainer/VBoxContainer/NewGameButton
@onready var resume_btn: Button = $PauseModal/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_btn: Button = $PauseModal/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	hide_all()

	status_close_btn.pressed.connect(hide_all)
	journal_close_btn.pressed.connect(hide_all)
	resume_btn.pressed.connect(hide_all)

	save_btn.pressed.connect(func():
		GameRuntime.save_slot("slot_1")
		hide_all()
	)
	load_btn.pressed.connect(func():
		GameRuntime.load_slot("slot_1")
		hide_all()
	)
	new_game_btn.pressed.connect(func():
		GameRuntime.new_game()
		hide_all()
	)
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)

	EventBus.overlay_opened.connect(_on_overlay_opened)
	EventBus.overlay_closed.connect(_on_overlay_closed)


func hide_all() -> void:
	visible = false
	status_modal.visible = false
	journal_modal.visible = false
	pause_modal.visible = false


func _on_overlay_opened(overlay_id: String) -> void:
	hide_all()
	visible = true

	if overlay_id == "status":
		_populate_status()
		status_modal.visible = true
	elif overlay_id == "journal":
		_populate_journal()
		journal_modal.visible = true
	elif overlay_id == "pause":
		pause_modal.visible = true


func _on_overlay_closed(_overlay_id: String) -> void:
	hide_all()


func _populate_status() -> void:
	var state = GameRuntime.world_state
	var text = "=== PROFESSIONAL ATTRIBUTES ===\n"
	for stat in state.stats:
		text += "• " + stat.replace("_", " ").capitalize() + ": " + str(state.stats[stat]) + "\n"

	text += "\n=== ACTIVE CONDITIONS ===\n"
	if state.conditions.is_empty():
		text += "(None active)\n"
	else:
		for cond in state.conditions:
			var turns = state.conditions[cond]
			var t_str = "Permanent" if turns < 0 else (str(turns) + " turns")
			text += "• " + cond.replace("condition.", "").replace("_", " ").capitalize() + " (" + t_str + ")\n"

	text += "\n=== INTERPERSONAL STANDING ===\n"
	if state.npc_memory.is_empty():
		text += "(Neutral with all colleagues)\n"
	else:
		for npc in state.npc_memory:
			var name_str = npc.replace("npc.", "").replace("_", " ").capitalize()
			text += "• " + name_str + ": Standing " + str(state.npc_memory[npc]) + "\n"

	status_content.text = text


func _populate_journal() -> void:
	var state = GameRuntime.world_state
	var text = "=== INCIDENT CHRONICLE ===\n"
	text += "Location: " + state.current_location + "\n"
	text += "Turn: " + str(state.turn_count) + "\n\n"

	text += "=== RECENT OBSERVATIONS ===\n"
	if state.log.is_empty():
		text += "(No entries recorded yet)\n"
	else:
		var start_idx = max(0, state.log.size() - 8)
		for i in range(start_idx, state.log.size()):
			text += "• " + state.log[i] + "\n\n"

	journal_content.text = text
