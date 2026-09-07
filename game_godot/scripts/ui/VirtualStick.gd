class_name VirtualStick
extends Control

# Touch / Drag virtual thumbstick for mobile devices.
# Dispatches normalized movement vectors to EventBus.virtual_move_input.

@export var max_radius: float = 60.0
@export var deadzone: float = 0.12

@onready var stick_base: Control = get_node_or_null("StickBase")
@onready var stick_knob: Control = get_node_or_null("StickBase/StickKnob")

var active_touch_index: int = -1
var stick_center_global: Vector2 = Vector2.ZERO
var current_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	if stick_knob and stick_base:
		stick_knob.position = (stick_base.size * 0.5) - (stick_knob.size * 0.5)
	call_deferred("_update_center")


func _update_center() -> void:
	if stick_base:
		stick_center_global = stick_base.global_position + stick_base.size * 0.5
	else:
		stick_center_global = global_position + size * 0.5


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if active_touch_index != -1:
			_reset_stick()
		return

	if event is InputEventScreenTouch:
		var touch = event as InputEventScreenTouch
		if touch.pressed:
			if active_touch_index == -1:
				var local_pos = get_global_transform_with_canvas().affine_inverse() * touch.position
				var rect = Rect2(Vector2.ZERO, size)
				if rect.has_point(local_pos):
					active_touch_index = touch.index
					_update_center()
					_handle_touch_pos(touch.position)
					get_viewport().set_input_as_handled()
		else:
			if touch.index == active_touch_index:
				_reset_stick()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag = event as InputEventScreenDrag
		if drag.index == active_touch_index:
			_handle_touch_pos(drag.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var local_pos = get_global_transform_with_canvas().affine_inverse() * mb.position
				var rect = Rect2(Vector2.ZERO, size)
				if rect.has_point(local_pos):
					active_touch_index = 999
					_update_center()
					_handle_touch_pos(mb.position)
					get_viewport().set_input_as_handled()
			elif active_touch_index == 999:
				_reset_stick()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if active_touch_index == 999:
			var mm = event as InputEventMouseMotion
			_handle_touch_pos(mm.position)
			get_viewport().set_input_as_handled()


func _handle_touch_pos(screen_pos: Vector2) -> void:
	_update_center()
	var offset = screen_pos - stick_center_global
	var dist = offset.length()
	var dir = offset.normalized() if dist > 0.0 else Vector2.ZERO
	
	var clamped_dist = min(dist, max_radius)
	var norm_dist = clamped_dist / max_radius
	
	if norm_dist < deadzone:
		current_vector = Vector2.ZERO
	else:
		var scaled = (norm_dist - deadzone) / (1.0 - deadzone)
		current_vector = dir * scaled

	if stick_knob and stick_base:
		var knob_offset = dir * clamped_dist
		stick_knob.position = (stick_base.size * 0.5) - (stick_knob.size * 0.5) + knob_offset

	EventBus.virtual_move_input.emit(current_vector)


func _reset_stick() -> void:
	active_touch_index = -1
	current_vector = Vector2.ZERO
	if stick_knob and stick_base:
		stick_knob.position = (stick_base.size * 0.5) - (stick_knob.size * 0.5)
	EventBus.virtual_move_input.emit(Vector2.ZERO)
