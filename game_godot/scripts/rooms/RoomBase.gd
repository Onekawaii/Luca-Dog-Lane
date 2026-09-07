class_name RoomBase
extends Node2D

# Base Room Controller for Native Multi-Room Adventure World.

@export var room_id: String = ""
@export var location_id: String = ""
@export var default_camera_pos: Vector2 = Vector2(640, 360)
@export var default_camera_zoom: Vector2 = Vector2(1.0, 1.0)

@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var ysort_container: Node2D = get_node_or_null("YSortContainer")
@onready var player: PlayerActor = get_node_or_null("YSortContainer/Player")
@onready var nav_region: NavigationRegion2D = get_node_or_null("NavigationRegion2D")
@onready var debug_draw: Node2D = get_node_or_null("DebugDraw")

var is_in_dialogue: bool = false
var target_camera_pos: Vector2 = Vector2(640, 360)
var target_camera_zoom: Vector2 = Vector2(1.0, 1.0)


func _ready() -> void:
	EventBus.action_requested.connect(_on_action_requested)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	EventBus.dialogue_closed.connect(_on_dialogue_closed)
	EventBus.debug_toggled.connect(_on_debug_toggled)
	EventBus.camera_focus_requested.connect(_on_camera_focus_requested)
	EventBus.camera_reset_requested.connect(_on_camera_reset_requested)

	if camera:
		target_camera_pos = camera.global_position
		target_camera_zoom = camera.zoom

	_update_room_visuals()


func _process(delta: float) -> void:
	if camera:
		camera.global_position = camera.global_position.lerp(target_camera_pos, delta * 4.0)
		camera.zoom = camera.zoom.lerp(target_camera_zoom, delta * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_in_dialogue or not player or not player.can_move:
		return

	var target_world = Vector2.ZERO
	var has_target = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		target_world = get_global_mouse_position()
		has_target = true
	elif event is InputEventScreenTouch and event.pressed:
		target_world = get_viewport().get_canvas_transform().affine_inverse() * event.position
		has_target = true

	if has_target:
		var nav_map = get_world_2d().navigation_map
		var closest = NavigationServer2D.map_get_closest_point(nav_map, target_world)
		if closest != Vector2.ZERO:
			player.walk_to(closest)
		elif _is_point_walkable(target_world):
			player.walk_to(target_world)


func _is_point_walkable(pos: Vector2) -> bool:
	return pos.y >= 350.0 and pos.y <= 680.0 and pos.x >= 80.0 and pos.x <= 1200.0


func set_player_spawn(entrance_name: String) -> void:
	var marker = find_child("Entrance_" + entrance_name, true, false)
	if not marker:
		marker = find_child("Entrance_Default", true, false)
	if marker and player:
		player.global_position = marker.global_position
		player.velocity = Vector2.ZERO
		player.stop()


func _on_action_requested(act_data: Dictionary) -> void:
	var act_type = act_data.get("type", "")

	if act_type == "approach_and_interact_actor":
		var app_pos = act_data.get("approach_pos", Vector2.ZERO)
		var actor = act_data.get("actor")
		var scene_id = act_data.get("scene_id", "")
		if actor:
			actor.set_focus(true)

		if player:
			player.walk_to(app_pos, func():
				_trigger_actor_dialogue(actor, scene_id)
			)

	elif act_type == "approach_and_interact_hotspot":
		var app_pos = act_data.get("approach_pos", Vector2.ZERO)
		var hotspot = act_data.get("hotspot")
		var hotspot_id = act_data.get("hotspot_id", "")
		var scene_id = act_data.get("scene_id", "")
		var is_exit = act_data.get("is_exit", false)
		var target_room = act_data.get("target_room", "")
		var target_entrance = act_data.get("target_entrance", "Default")
		if hotspot:
			hotspot.set_selected(true)

		if player:
			player.walk_to(app_pos, func():
				if is_exit and target_room != "":
					EventBus.room_change_requested.emit(target_room, target_entrance)
					if hotspot:
						hotspot.set_selected(false)
				else:
					_trigger_hotspot_dialogue(hotspot, hotspot_id, scene_id)
			)


func _trigger_actor_dialogue(actor: ActorBase, scene_id: String) -> void:
	is_in_dialogue = true
	var state = GameRuntime.world_state
	if scene_id != "":
		GameRuntime.action_resolver.enter_scene(state, scene_id)

	var scene_meta = GameRuntime.loader.get_encounter(state.current_scene)
	var choices = GameRuntime.action_resolver.choice_views(state)

	if player:
		var mid_point = (player.global_position + actor.global_position) * 0.5 + Vector2(0, -60)
		target_camera_pos = mid_point
		target_camera_zoom = Vector2(1.15, 1.15)

	var bubble = get_tree().root.find_child("DialogueBubble", true, false)
	if bubble:
		bubble.target_actor = actor

	EventBus.dialogue_started.emit(
		actor.actor_id,
		actor.display_name,
		scene_meta.get("read_aloud", "..."),
		choices
	)


func _trigger_hotspot_dialogue(hotspot: Hotspot, hotspot_id: String, scene_id: String) -> void:
	is_in_dialogue = true
	var state = GameRuntime.world_state
	if scene_id != "":
		GameRuntime.action_resolver.enter_scene(state, scene_id)

	var scene_meta = GameRuntime.loader.get_encounter(state.current_scene)
	var choices = GameRuntime.action_resolver.choice_views(state)

	var bubble = get_tree().root.find_child("DialogueBubble", true, false)
	if bubble:
		bubble.target_actor = hotspot

	EventBus.dialogue_started.emit(
		hotspot_id,
		hotspot.display_name,
		scene_meta.get("read_aloud", "..."),
		choices
	)


func _on_dialogue_closed() -> void:
	is_in_dialogue = false
	target_camera_pos = default_camera_pos
	target_camera_zoom = default_camera_zoom
	if ysort_container:
		for child in ysort_container.get_children():
			if child is ActorBase:
				child.set_focus(false)
			elif child is Hotspot:
				child.set_selected(false)


func _on_world_state_changed(_delta: Dictionary) -> void:
	_update_room_visuals()


func _update_room_visuals() -> void:
	pass


func _on_debug_toggled(is_enabled: bool) -> void:
	if debug_draw:
		debug_draw.visible = is_enabled


func _on_camera_focus_requested(target_pos: Vector2, zoom_level: float) -> void:
	target_camera_pos = target_pos
	target_camera_zoom = Vector2(zoom_level, zoom_level)


func _on_camera_reset_requested() -> void:
	target_camera_pos = default_camera_pos
	target_camera_zoom = default_camera_zoom
