class_name DarlaActor
extends ActorBase

# Darla of the Microwave - Fixed identity at Coffee Counter.

func _ready() -> void:
	actor_id = "npc.darla_microwave"
	display_name = "Darla of the Microwave"
	portrait_path = "res://assets/portraits/darla_neutral.png"
	approach_offset = Vector2(0, 50)
	super._ready()


func _handle_interaction() -> void:
	if GameRuntime.inventory_system.is_item_armed():
		GameRuntime.use_armed_item_on(actor_id)
		return

	# Start Darla's interaction encounter
	EventBus.action_requested.emit({
		"type": "approach_and_interact_actor",
		"actor": self,
		"actor_id": actor_id,
		"scene_id": "scene.act1.coffee_counter",
		"approach_pos": get_approach_position()
	})
