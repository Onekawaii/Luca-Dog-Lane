class_name Hotspot
extends Area2D

# Interactive world object / prop hotspot with local subtle highlight and approach logic.

@export var hotspot_id: String = ""
@export var display_name: String = ""
@export var scene_id: String = ""
@export var approach_position: Vector2 = Vector2.ZERO
@export var is_exit: bool = false
@export var target_room: String = ""

var is_hovered: bool = false
var is_selected: bool = false

@onready var reticle: Sprite2D = get_node_or_null("Reticle")


func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	if reticle:
		reticle.visible = false


func _on_mouse_entered() -> void:
	is_hovered = true
	if reticle:
		reticle.visible = true
	_update_cursor()


func _on_mouse_exited() -> void:
	is_hovered = false
	if reticle and not is_selected:
		reticle.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _update_cursor() -> void:
	if GameRuntime.inventory_system.is_item_armed():
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_activation()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_activation()


func _handle_activation() -> void:
	AudioManager.play_ui_click()

	if GameRuntime.inventory_system.is_item_armed():
		# Use armed item on this hotspot / object (e.g. Evidence Bag on Wetberry)
		GameRuntime.use_armed_item_on(hotspot_id)
		return

	# Normal click: approach hotspot and open interaction
	var app_pos = approach_position if approach_position != Vector2.ZERO else global_position + Vector2(0, 40)
	EventBus.action_requested.emit({
		"type": "approach_and_interact_hotspot",
		"hotspot": self,
		"hotspot_id": hotspot_id,
		"scene_id": scene_id,
		"is_exit": is_exit,
		"target_room": target_room,
		"approach_pos": app_pos
	})


func set_selected(selected: bool) -> void:
	is_selected = selected
	if reticle:
		reticle.visible = selected or is_hovered
