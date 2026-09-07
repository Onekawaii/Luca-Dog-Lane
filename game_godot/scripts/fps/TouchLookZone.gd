class_name TouchLookZone
extends Control

var active_touch_index: int = -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and active_touch_index == -1:
			active_touch_index = touch.index
			accept_event()
		elif not touch.pressed and touch.index == active_touch_index:
			active_touch_index = -1
			accept_event()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == active_touch_index:
			EventBus.virtual_look_input.emit(drag.relative)
			accept_event()
