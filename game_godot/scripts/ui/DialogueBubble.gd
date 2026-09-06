class_name DialogueBubble
extends Control

# Anchored Dialogue and Choice UI.
# Positions itself adjacent to the active character on screen, clamped to safe viewport bounds.

@onready var panel_container: PanelContainer = $PanelContainer
@onready var speaker_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/SpeakerLabel
@onready var text_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TextLabel
@onready var portrait_rect: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/Header/PortraitRect
@onready var choices_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ChoicesScroll/ChoicesContainer
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton

var target_world_pos: Vector2 = Vector2.ZERO
var target_actor: Node2D = null
var is_open: bool = false


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_dialogue)
	EventBus.dialogue_started.connect(display_dialogue)
	EventBus.dialogue_closed.connect(close_dialogue)


func _process(_delta: float) -> void:
	if is_open and is_instance_valid(target_actor):
		_update_anchor_position()


func display_dialogue(actor_id: String, speaker_name: String, text: String, choices: Array) -> void:
	is_open = true
	visible = true

	speaker_label.text = speaker_name
	text_label.text = text

	# Set portrait
	var portrait_path = _get_portrait_for_actor(actor_id)
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false

	# Clear previous choices
	for child in choices_container.get_children():
		child.queue_free()

	# Populate choice buttons
	if choices.is_empty():
		var dismiss_btn = Button.new()
		dismiss_btn.text = "Continue..."
		dismiss_btn.custom_minimum_size = Vector2(0, 38)
		dismiss_btn.pressed.connect(close_dialogue)
		choices_container.add_child(dismiss_btn)
	else:
		for ch in choices:
			var btn = Button.new()
			var label_text = ch.get("label", ch.get("id"))
			if not ch.get("available", true):
				label_text += " [LOCKED: " + ch.get("locked_reason", "Unavailable") + "]"
				btn.disabled = true
			btn.text = label_text
			btn.custom_minimum_size = Vector2(0, 38)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var choice_id = ch.get("id")
			btn.pressed.connect(func(): _on_choice_selected(choice_id))
			choices_container.add_child(btn)

	_update_anchor_position()


func _on_choice_selected(choice_id: String) -> void:
	AudioManager.play_ui_click()
	var outcome = GameRuntime.execute_choice(choice_id)
	if outcome.has("result"):
		text_label.text = outcome["result"]

	# Refresh choice list after state change
	var views = GameRuntime.action_resolver.choice_views(GameRuntime.world_state)
	for child in choices_container.get_children():
		child.queue_free()

	if views.is_empty() or outcome.has("next_scene"):
		var done_btn = Button.new()
		done_btn.text = "Step away."
		done_btn.custom_minimum_size = Vector2(0, 38)
		done_btn.pressed.connect(close_dialogue)
		choices_container.add_child(done_btn)
	else:
		for ch in views:
			var btn = Button.new()
			var label_text = ch.get("label", ch.get("id"))
			if not ch.get("available", true):
				label_text += " [LOCKED: " + ch.get("locked_reason", "Unavailable") + "]"
				btn.disabled = true
			btn.text = label_text
			btn.custom_minimum_size = Vector2(0, 38)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var ch_id = ch.get("id")
			btn.pressed.connect(func(): _on_choice_selected(ch_id))
			choices_container.add_child(btn)


func close_dialogue() -> void:
	is_open = false
	visible = false
	target_actor = null
	EventBus.camera_reset_requested.emit()


func _update_anchor_position() -> void:
	var vp_size = get_viewport_rect().size
	var target_screen: Vector2 = vp_size * 0.5

	if is_instance_valid(target_actor):
		if target_actor is ActorBase:
			target_screen = target_actor.get_head_screen_position()
		else:
			var canvas_transform = get_viewport().get_canvas_transform()
			target_screen = canvas_transform * target_actor.global_position

	var panel_size = panel_container.size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(420, 240)

	# Try positioning above actor
	var ideal_pos = target_screen - Vector2(panel_size.x * 0.5, panel_size.y + 20)

	# If too close to top edge, flip to below or side
	if ideal_pos.y < 40:
		ideal_pos.y = target_screen.y + 30

	# Clamp to safe viewport margins
	ideal_pos.x = clampf(ideal_pos.x, 20.0, max(20.0, vp_size.x - panel_size.x - 20.0))
	ideal_pos.y = clampf(ideal_pos.y, 20.0, max(20.0, vp_size.y - panel_size.y - 100.0))

	panel_container.global_position = ideal_pos


func _get_portrait_for_actor(actor_id: String) -> String:
	var clean = actor_id.replace("npc.", "")
	if clean.begins_with("keith"):
		return "res://assets/portraits/keith_neutral.png"
	elif clean.begins_with("darla"):
		return "res://assets/portraits/darla_neutral.png"
	elif clean.begins_with("tammy"):
		return "res://assets/portraits/tammy_procedural.png"
	return ""
