class_name KeithActor
extends ActorBase

# Keith the Janitor - Fixed identity in Utility Corner.

func _ready() -> void:
	actor_id = "npc.keith_janitor"
	display_name = "Keith the Janitor"
	portrait_path = "res://assets/portraits/keith_neutral.png"
	approach_offset = Vector2(-70, 0)
	super._ready()


func _handle_interaction() -> void:
	if GameRuntime.inventory_system.is_item_armed():
		GameRuntime.use_armed_item_on(actor_id)
		return

	# Start Keith's interaction encounter
	EventBus.action_requested.emit({
		"type": "approach_and_interact_actor",
		"actor": self,
		"actor_id": actor_id,
		"scene_id": "scene.act1.keith_corner",
		"approach_pos": get_approach_position()
	})
