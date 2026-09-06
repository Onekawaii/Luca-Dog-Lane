class_name ActorBase
extends CharacterBody2D

# Base Actor class with strictly grounded Foot Anchor at (0, 0).

@export var actor_id: String = ""
@export var display_name: String = ""
@export var approach_offset: Vector2 = Vector2(0, 40)
@export var portrait_path: String = ""

var is_hovered: bool = false
var is_focused: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var highlight: Sprite2D = get_node_or_null("Highlight")
@onready var reticle: Sprite2D = get_node_or_null("Reticle")


func _ready() -> void:
	# Enable YSort on parent container
	y_sort_enabled = true
	# Ensure input pickable
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if highlight:
		highlight.visible = false
	if reticle:
		reticle.visible = false

	_update_presentation()


func _on_mouse_entered() -> void:
	is_hovered = true
	if highlight:
		highlight.visible = true
	_update_cursor()


func _on_mouse_exited() -> void:
	is_hovered = false
	if highlight and not is_focused:
		highlight.visible = false
	_reset_cursor()


func _update_cursor() -> void:
	if GameRuntime.inventory_system.is_item_armed():
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _reset_cursor() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func set_focus(focused: bool) -> void:
	is_focused = focused
	if highlight:
		highlight.visible = focused or is_hovered
	if reticle:
		reticle.visible = focused


func get_foot_position() -> Vector2:
	return global_position


func get_approach_position() -> Vector2:
	return global_position + approach_offset


func get_head_screen_position(camera: Camera2D = null) -> Vector2:
	# Return approximate head position in screen coordinates for anchoring dialogue bubbles
	var head_world = global_position + Vector2(0, -180)
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * head_world


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_interaction()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_interaction()


func _handle_interaction() -> void:
	AudioManager.play_ui_click()
	if GameRuntime.inventory_system.is_item_armed():
		# Use armed item on this actor
		GameRuntime.use_armed_item_on(actor_id)
		return

	# Normal click: notify room / player to approach this actor and trigger interaction
	EventBus.action_requested.emit({
		"type": "approach_and_interact_actor",
		"actor": self,
		"actor_id": actor_id,
		"approach_pos": get_approach_position()
	})


func _update_presentation() -> void:
	pass
