class_name TouchLookZone
extends Control

var active_touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_DISABLED, NOTIFICATION_EXIT_TREE, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			reset_touch()


func reset_touch() -> void:
	active_touch_index = -1


func _is_excluded_position(screen_pos: Vector2) -> bool:
	var interact_btn := get_node_or_null("../InteractButton") as Control
	if is_instance_valid(interact_btn) and interact_btn.is_visible_in_tree():
		if interact_btn.get_global_rect().has_point(screen_pos):
			return true

	var pda_btn := get_node_or_null("../../PDAButton") as Control
	if is_instance_valid(pda_btn) and pda_btn.is_visible_in_tree():
		if pda_btn.get_global_rect().has_point(screen_pos):
			return true

	var pda_panel := get_node_or_null("../../PDAPanel") as Control
	if is_instance_valid(pda_panel) and pda_panel.is_visible_in_tree():
		if pda_panel.get_global_rect().has_point(screen_pos):
			return true

	var dialogue_panel := get_node_or_null("../../DialoguePanel") as Control
	if is_instance_valid(dialogue_panel) and dialogue_panel.is_visible_in_tree():
		if dialogue_panel.get_global_rect().has_point(screen_pos):
			return true

	return false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or process_mode == Node.PROCESS_MODE_DISABLED:
		if active_touch_index != -1:
			reset_touch()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var local_pos := get_global_transform_with_canvas().affine_inverse() * touch.position
			var rect := Rect2(Vector2.ZERO, size)
			if rect.has_point(local_pos) and not _is_excluded_position(touch.position):
				active_touch_index = touch.index
				get_viewport().set_input_as_handled()
		else:
			if touch.index == active_touch_index:
				reset_touch()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == active_touch_index:
			EventBus.virtual_look_input.emit(drag.relative)
			get_viewport().set_input_as_handled()
