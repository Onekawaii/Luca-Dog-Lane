class_name TammyActor
extends ActorBase

# Tammy from HR - Conditionally spawned when HR is alerted.

func _ready() -> void:
	actor_id = "npc.tammy_hr"
	display_name = "Tammy from HR"
	portrait_path = "res://assets/portraits/tammy_procedural.png"
	approach_offset = Vector2(50, 0)
	super._ready()

	EventBus.world_state_changed.connect(_on_world_state_changed)
	_check_spawn_condition()


func _on_world_state_changed(_delta: Dictionary) -> void:
	_check_spawn_condition()


func _check_spawn_condition() -> void:
	var state = GameRuntime.world_state
	var should_spawn = (
		state.get_flag("tammy_alerted", false) == true or
		state.get_flag("npc.tammy_hr_spawned", false) == true or
		state.room_memory().get("tammy_present", false) == true or
		state.npc_memory.get("npc.tammy_hr", 0) > 0
	)
	visible = should_spawn
	process_mode = Node.PROCESS_MODE_INHERIT if should_spawn else Node.PROCESS_MODE_DISABLED


func _handle_interaction() -> void:
	if not visible:
		return
	if GameRuntime.inventory_system.is_item_armed():
		GameRuntime.use_armed_item_on(actor_id)
		return

	# Start Tammy's interaction encounter
	EventBus.action_requested.emit({
		"type": "approach_and_interact_actor",
		"actor": self,
		"actor_id": actor_id,
		"scene_id": "scene.act1.first_sighting",
		"approach_pos": get_approach_position()
	})
