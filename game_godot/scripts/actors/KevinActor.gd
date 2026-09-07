class_name KevinActor
extends ActorBase

# Kevin from Marketing - Conditionally present at Coffee Counter/Breakroom.

func _ready() -> void:
	actor_id = "npc.kevin_marketing"
	display_name = "Kevin from Marketing"
	portrait_path = "res://assets/portraits/kevin_neutral.png"
	approach_offset = Vector2(0, 50)
	super._ready()

	EventBus.world_state_changed.connect(_on_world_state_changed)
	_check_presence()


func _on_world_state_changed(_delta: Dictionary) -> void:
	_check_presence()


func _check_presence() -> void:
	var state = GameRuntime.world_state
	var is_present = (
		state.get_flag("kevin_present", true) == true and
		not state.get_flag("kevin_departed", false)
	)
	visible = is_present
	process_mode = Node.PROCESS_MODE_INHERIT if is_present else Node.PROCESS_MODE_DISABLED


func _handle_interaction() -> void:
	if not visible:
		return
	if GameRuntime.inventory_system.is_item_armed():
		GameRuntime.use_armed_item_on(actor_id)
		return

	EventBus.action_requested.emit({
		"type": "approach_and_interact_actor",
		"actor": self,
		"actor_id": actor_id,
		"scene_id": "scene.act1.coffee_counter",
		"approach_pos": get_approach_position()
	})
