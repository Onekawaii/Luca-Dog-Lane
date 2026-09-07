class_name ActorBase
extends CharacterBody2D

# Base Actor class with strictly grounded Foot Anchor at (0, 0).

@export var actor_id: String = ""
@export var display_name: String = ""
@export var approach_offset: Vector2 = Vector2(0, 40)
@export var portrait_path: String = ""

var is_hovered: bool = false
var is_focused: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var base_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var highlight_modulate: Color = Color(1.2, 1.25, 1.35, 1.0)


func _ready() -> void:
	y_sort_enabled = true
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_presentation()


func _get_runtime() -> Node:
	if has_node("/root/GameRuntime"):
		return get_node("/root/GameRuntime")
	return null


func _get_bus() -> Node:
	if has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null


func _get_audio() -> Node:
	if has_node("/root/AudioManager"):
		return get_node("/root/AudioManager")
	return null


func _on_mouse_entered() -> void:
	is_hovered = true
	_update_presentation()
	_update_cursor()


func _on_mouse_exited() -> void:
	is_hovered = false
	_update_presentation()
	_reset_cursor()


func _update_cursor() -> void:
	var runtime = _get_runtime()
	if runtime and runtime.inventory_system and runtime.inventory_system.is_item_armed():
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _reset_cursor() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func set_focus(focused: bool) -> void:
	is_focused = focused
	_update_presentation()


func get_foot_position() -> Vector2:
	return global_position


func get_approach_position() -> Vector2:
	return global_position + approach_offset


func get_head_screen_position(_camera: Camera2D = null) -> Vector2:
	var head_world = global_position + Vector2(0, -180)
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * head_world


func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		viewport.set_input_as_handled()
		_handle_interaction()
	elif event is InputEventScreenTouch and event.pressed:
		viewport.set_input_as_handled()
		_handle_interaction()


func _handle_interaction() -> void:
	var audio = _get_audio()
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()

	var runtime = _get_runtime()
	if runtime and runtime.inventory_system and runtime.inventory_system.is_item_armed():
		runtime.use_armed_item_on(actor_id)
		return

	var bus = _get_bus()
	if bus and bus.has_signal("action_requested"):
		bus.action_requested.emit({
			"type": "approach_and_interact_actor",
			"actor": self,
			"actor_id": actor_id,
			"approach_pos": get_approach_position()
		})


func _update_presentation() -> void:
	if sprite:
		if is_focused or is_hovered:
			sprite.modulate = highlight_modulate
		else:
			sprite.modulate = base_modulate


func _draw() -> void:
	var runtime = _get_runtime()
	if runtime and runtime.get("debug_mode"):
		draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.9, 0.3, 0.8)) # Foot anchor at origin
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.2, 0.9, 0.3, 1.0), 2.0)
		draw_line(Vector2(0, -12), Vector2(0, 12), Color(0.2, 0.9, 0.3, 1.0), 2.0)
