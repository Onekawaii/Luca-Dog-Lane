extends Node

# Central GameRuntime Autoload for Native Hive-Lattice Game.

var loader: CampaignLoader
var world_state: WorldState
var action_resolver: ActionResolver
var inventory_system: InventorySystem
var save_system: SaveSystem

var debug_mode: bool = false


func _ready() -> void:
	loader = CampaignLoader.new()
	loader.load_all()

	world_state = WorldState.new()
	world_state.init_from_campaign(loader.campaign)

	action_resolver = ActionResolver.new(loader)
	inventory_system = InventorySystem.new(loader, world_state)
	save_system = SaveSystem.new()

	# Start entry scene
	action_resolver.enter_scene(world_state, loader.campaign.get("entry_scene", "scene.act1.first_sighting"))


func new_game() -> void:
	world_state.init_from_campaign(loader.campaign)
	action_resolver.enter_scene(world_state, loader.campaign.get("entry_scene", "scene.act1.first_sighting"))
	EventBus.world_state_changed.emit({})
	EventBus.inventory_changed.emit()


func execute_choice(choice_id: String) -> Dictionary:
	var outcome = action_resolver.choose(world_state, choice_id)
	EventBus.world_state_changed.emit(outcome)
	EventBus.inventory_changed.emit()
	if outcome.has("result"):
		EventBus.notification_posted.emit(outcome["result"])
	return outcome


func use_armed_item_on(target_id: String) -> Dictionary:
	if not inventory_system.is_item_armed():
		return {"error": "No item armed."}
	var armed_id = inventory_system.get_armed_item()
	var res = action_resolver.use_item_on_target(world_state, armed_id, target_id)
	inventory_system.disarm_item()
	EventBus.world_state_changed.emit(res)
	EventBus.inventory_changed.emit()
	if res.has("result"):
		AudioManager.play_item_pickup()
		EventBus.notification_posted.emit(res["result"])
	return res


func save_slot(slot: String = "slot_1") -> bool:
	var ok = save_system.save_game(world_state, slot)
	if ok:
		EventBus.notification_posted.emit("Game saved to " + slot + ".")
	return ok


func load_slot(slot: String = "slot_1") -> bool:
	var ok = save_system.load_game(world_state, slot)
	if ok:
		EventBus.world_state_changed.emit({})
		EventBus.inventory_changed.emit()
		EventBus.notification_posted.emit("Game loaded from " + slot + ".")
	return ok


func toggle_debug() -> void:
	debug_mode = not debug_mode
	EventBus.debug_toggled.emit(debug_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_debug()
		elif event.keycode == KEY_F5:
			save_slot("slot_1")
		elif event.keycode == KEY_F9:
			load_slot("slot_1")
		elif event.keycode == KEY_I:
			EventBus.overlay_opened.emit("inventory")
		elif event.keycode == KEY_J:
			EventBus.overlay_opened.emit("journal")
		elif event.keycode == KEY_S:
			EventBus.overlay_opened.emit("status")
		elif event.keycode == KEY_ESCAPE:
			EventBus.dialogue_closed.emit()
			EventBus.overlay_closed.emit("all")
