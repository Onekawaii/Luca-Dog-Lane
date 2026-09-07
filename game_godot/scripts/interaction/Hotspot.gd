class_name Hotspot
extends Area2D

# Interactive world object / prop hotspot with local subtle highlight and approach logic.

@export var hotspot_id: String = ""
@export var display_name: String = ""
@export var scene_id: String = ""
@export var approach_position: Vector2 = Vector2.ZERO
@export var is_exit: bool = false
@export var target_room: String = ""

@export var target_entrance: String = "Entrance"

var is_hovered: bool = false
var is_selected: bool = false

var base_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var highlight_modulate: Color = Color(1.2, 1.25, 1.35, 1.0)


func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_update_presentation()


func _on_mouse_entered() -> void:
	is_hovered = true
	_update_presentation()
	_update_cursor()


func _on_mouse_exited() -> void:
	is_hovered = false
	_update_presentation()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _update_cursor() -> void:
	if GameRuntime.inventory_system.is_item_armed():
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		viewport.set_input_as_handled()
		_handle_activation()
	elif event is InputEventScreenTouch and event.pressed:
		viewport.set_input_as_handled()
		_handle_activation()


func _handle_activation() -> void:
	AudioManager.play_ui_click()

	if GameRuntime.inventory_system.is_item_armed():
		GameRuntime.use_armed_item_on(hotspot_id)
		return

	var app_pos = approach_position if approach_position != Vector2.ZERO else global_position + Vector2(0, 40)
	EventBus.action_requested.emit({
		"type": "approach_and_interact_hotspot",
		"hotspot": self,
		"hotspot_id": hotspot_id,
		"scene_id": scene_id,
		"is_exit": is_exit,
		"target_room": target_room,
		"target_entrance": target_entrance,
		"approach_pos": app_pos
	})


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_presentation()


func _update_presentation() -> void:
	for child in get_children():
		if child is Sprite2D and child.name != "Reticle":
			if is_selected or is_hovered:
				child.modulate = highlight_modulate
			else:
				child.modulate = base_modulate


func _draw() -> void:
	if GameRuntime.debug_mode:
		draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.7, 0.1, 0.8)) # Hotspot center
		var app_rel = to_local(approach_position) if approach_position != Vector2.ZERO else Vector2(0, 40)
		draw_circle(app_rel, 4.0, Color(0.2, 0.6, 1.0, 0.8)) # Approach anchor
		draw_line(Vector2.ZERO, app_rel, Color(0.2, 0.6, 1.0, 0.5), 1.0)
