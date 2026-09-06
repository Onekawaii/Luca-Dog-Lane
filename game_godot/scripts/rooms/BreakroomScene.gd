class_name BreakroomScene
extends Node2D

# Breakroom Scene Controller for Native Hive-Lattice Vertical Slice.

@onready var camera: Camera2D = $Camera2D
@onready var ysort_container: Node2D = $YSortContainer
@onready var player: PlayerActor = $YSortContainer/Player
@onready var keith: KeithActor = $YSortContainer/Keith
@onready var darla: DarlaActor = $YSortContainer/Darla
@onready var tammy: TammyActor = $YSortContainer/Tammy
@onready var wetberry_prop: Sprite2D = $YSortContainer/CentralTableHotspot/WetberrySprite
@onready var wetberry_pulse: AnimationPlayer = $YSortContainer/CentralTableHotspot/PulseAnimation
@onready var debug_draw: Node2D = $DebugDraw

var is_in_dialogue: bool = false
var default_camera_pos: Vector2 = Vector2(640, 360)
var target_camera_pos: Vector2 = Vector2(640, 360)
var default_camera_zoom: Vector2 = Vector2(1.0, 1.0)
var target_camera_zoom: Vector2 = Vector2(1.0, 1.0)


func _ready() -> void:
	EventBus.action_requested.connect(_on_action_requested)
	EventBus.world_state_changed.connect(_on_world_state_changed)
	EventBus.dialogue_closed.connect(_on_dialogue_closed)
	EventBus.debug_toggled.connect(_on_debug_toggled)
	EventBus.camera_focus_requested.connect(_on_camera_focus_requested)
	EventBus.camera_reset_requested.connect(_on_camera_reset_requested)

	default_camera_pos = camera.global_position
	target_camera_pos = default_camera_pos
	default_camera_zoom = camera.zoom
	target_camera_zoom = default_camera_zoom

	_update_room_visuals()


func _process(delta: float) -> void:
	# Smooth camera easing
	camera.global_position = camera.global_position.lerp(target_camera_pos, delta * 4.0)
	camera.zoom = camera.zoom.lerp(target_camera_zoom, delta * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_in_dialogue:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_world = get_global_mouse_position()
		# Only move if clicked in walkable floor region (approx y between 380 and 680)
		if click_world.y >= 360.0 and click_world.y <= 680.0 and click_world.x >= 100.0 and click_world.x <= 1180.0:
			player.walk_to(click_world)
	elif event is InputEventScreenTouch and event.pressed:
		var touch_world = get_global_mouse_position()
		if touch_world.y >= 360.0 and touch_world.y <= 680.0 and touch_world.x >= 100.0 and touch_world.x <= 1180.0:
			player.walk_to(touch_world)


func _on_action_requested(act_data: Dictionary) -> void:
	var act_type = act_data.get("type", "")

	if act_type == "approach_and_interact_actor":
		var app_pos = act_data.get("approach_pos", Vector2.ZERO)
		var actor = act_data.get("actor")
		var scene_id = act_data.get("scene_id", "")
		if actor:
			actor.set_focus(true)

		player.walk_to(app_pos, func():
			_trigger_actor_dialogue(actor, scene_id)
		)

	elif act_type == "approach_and_interact_hotspot":
		var app_pos = act_data.get("approach_pos", Vector2.ZERO)
		var hotspot = act_data.get("hotspot")
		var hotspot_id = act_data.get("hotspot_id", "")
		var scene_id = act_data.get("scene_id", "")
		var is_exit = act_data.get("is_exit", false)
		if hotspot:
			hotspot.set_selected(true)

		player.walk_to(app_pos, func():
			if is_exit:
				EventBus.notification_posted.emit("The hallway lights flicker ominously. You remain in the Breakroom.")
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

	# Focus camera subtly between player and actor
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
	if keith:
		keith.set_focus(false)
	if darla:
		darla.set_focus(false)
	if tammy:
		tammy.set_focus(false)


func _on_world_state_changed(_delta: Dictionary) -> void:
	_update_room_visuals()


func _update_room_visuals() -> void:
	var state = GameRuntime.world_state
	# If Wetberry is contained, hide the pulsing carton on table
	var is_contained = state.get_flag("wetberry_contained", false) == true or state.room_memory().get("wetberry_status") == "contained"
	if wetberry_prop:
		wetberry_prop.visible = not is_contained


func _on_debug_toggled(is_enabled: bool) -> void:
	if debug_draw:
		debug_draw.visible = is_enabled


func _on_camera_focus_requested(target_pos: Vector2, zoom_level: float) -> void:
	target_camera_pos = target_pos
	target_camera_zoom = Vector2(zoom_level, zoom_level)


func _on_camera_reset_requested() -> void:
	target_camera_pos = default_camera_pos
	target_camera_zoom = default_camera_zoom
