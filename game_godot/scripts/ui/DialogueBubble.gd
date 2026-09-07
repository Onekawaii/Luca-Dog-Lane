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


func _get_portrait_for_actor(actor_id: String) -> String:
	var clean = actor_id.replace("npc.", "")
	if clean.begins_with("keith"):
		return "res://assets/portraits/keith_neutral.png"
	elif clean.begins_with("darla"):
		return "res://assets/portraits/darla_neutral.png"
	elif clean.begins_with("tammy"):
		return "res://assets/portraits/tammy_procedural.png"
	elif clean.begins_with("kevin"):
		return "res://assets/portraits/kevin_neutral.png"
	return ""


func _update_anchor_position() -> void:
	var vp_size = get_viewport_rect().size
	var target_screen: Vector2 = vp_size * 0.5
	var actor_screen_center: Vector2 = target_screen

	if is_instance_valid(target_actor):
		var canvas_transform = get_viewport().get_canvas_transform()
		if target_actor is ActorBase:
			target_screen = target_actor.get_head_screen_position()
			actor_screen_center = canvas_transform * (target_actor.global_position + Vector2(0, -90))
		else:
			target_screen = canvas_transform * target_actor.global_position
			actor_screen_center = target_screen

	var panel_size = panel_container.size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(400, 220)

	# Candidate placement offsets (relative to actor_screen_center)
	var candidates: Array[Vector2] = [
		# 1. Right of actor
		Vector2(actor_screen_center.x + 60, actor_screen_center.y - panel_size.y * 0.5),
		# 2. Left of actor
		Vector2(actor_screen_center.x - panel_size.x - 60, actor_screen_center.y - panel_size.y * 0.5),
		# 3. Above-Right
		Vector2(actor_screen_center.x + 30, actor_screen_center.y - panel_size.y - 40),
		# 4. Above-Left
		Vector2(actor_screen_center.x - panel_size.x - 30, actor_screen_center.y - panel_size.y - 40),
		# 5. Above-Center
		Vector2(actor_screen_center.x - panel_size.x * 0.5, actor_screen_center.y - panel_size.y - 40),
		# 6. Below-Right
		Vector2(actor_screen_center.x + 30, actor_screen_center.y + 40),
		# 7. Below-Left
		Vector2(actor_screen_center.x - panel_size.x - 30, actor_screen_center.y + 40)
	]

	var best_pos: Vector2 = candidates[0]
	var best_score: float = -999999.0

	var margin: float = 20.0
	var safe_rect = Rect2(margin, margin + 48.0, vp_size.x - margin * 2.0, vp_size.y - margin * 2.0 - 100.0)

	for cand in candidates:
		var cand_rect = Rect2(cand, panel_size)
		var score: float = 100.0

		# Check if entirely inside viewport safe region
		if safe_rect.encloses(cand_rect):
			score += 500.0
		else:
			# Penalize for overflowing bounds
			var left_pen = max(0.0, safe_rect.position.x - cand_rect.position.x)
			var right_pen = max(0.0, (cand_rect.position.x + cand_rect.size.x) - (safe_rect.position.x + safe_rect.size.x))
			var top_pen = max(0.0, safe_rect.position.y - cand_rect.position.y)
			var bot_pen = max(0.0, (cand_rect.position.y + cand_rect.size.y) - (safe_rect.position.y + safe_rect.size.y))
			score -= (left_pen + right_pen + top_pen + bot_pen) * 5.0

		# Do not overlap the speaker face / center
		var actor_box = Rect2(actor_screen_center - Vector2(40, 60), Vector2(80, 120))
		if cand_rect.intersects(actor_box):
			score -= 800.0

		if score > best_score:
			best_score = score
			best_pos = cand

	# Final safe clamp
	best_pos.x = clampf(best_pos.x, margin, max(margin, vp_size.x - panel_size.x - margin))
	best_pos.y = clampf(best_pos.y, margin + 48.0, max(margin + 48.0, vp_size.y - panel_size.y - 90.0))

	panel_container.global_position = best_pos
