class_name FirstPersonBreakroom
extends Node3D

var pending_dialogue_action: String = ""


func _ready() -> void:
	EventBus.first_person_interaction_requested.connect(_on_interaction_requested)
	EventBus.first_person_dialogue_closed.connect(_on_dialogue_closed)
	EventBus.world_state_changed.connect(func(_delta): _refresh_world())
	EventBus.inventory_changed.connect(_refresh_world)

	if GameRuntime.world_state != null:
		GameRuntime.action_resolver.enter_scene(GameRuntime.world_state, "scene.act1.first_sighting", false)
		EventBus.world_state_changed.emit({})

	_refresh_world()


func _on_interaction_requested(data: Dictionary) -> void:
	match str(data.get("interaction_id", "")):
		"keith":
			_interact_keith()
		"wetberry":
			_interact_wetberry()
		"coffee":
			_start_dialogue("Breakroom Coffee", [
				"The coffee maker clicks once without being touched.",
				"A handwritten warning says: THE WATER INLET IS CONNECTED TO THE DEEPER CHANNELS."
			])
		"fridge":
			_start_dialogue("Breakroom Fridge", [
				"The compressor hums behind the door.",
				"Something on the other side answers one beat too late."
			])
		_:
			var speaker := str(data.get("speaker_name", "Hive-Lattice"))
			var description := str(data.get("description", "Nothing happens."))
			_start_dialogue(speaker, [description])


func _interact_keith() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return

	if state.has_item("item.evidence_bag_not_my_business") or state.get_flag("wetberry_contained", false):
		_start_dialogue("Keith the Janitor", [
			"You already have the bag.",
			"Keith points toward the central table. “Contain the problem before it becomes a meeting.”"
		])
		return

	GameRuntime.action_resolver.enter_scene(state, "scene.act1.keith_corner", false)
	pending_dialogue_action = "grant_evidence_bag"
	_start_dialogue("Keith the Janitor", [
		"Nope. We bag it. We label it. We do not make bare-handed history.",
		"Keith holds up a sealable evidence bag. “Use this on Wetberry. Then we can all pretend this was procedural.”"
	])


func _interact_wetberry() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return

	if state.get_flag("wetberry_contained", false):
		_start_dialogue("Bagged Wetberry", [
			"The plastic is fogged from the inside.",
			"The carton has stopped pulsing. This is probably good."
		])
		return

	if state.has_item("item.evidence_bag_not_my_business"):
		GameRuntime.action_resolver.enter_scene(state, "scene.act1.first_sighting", false)
		GameRuntime.inventory_system.arm_item("item.evidence_bag_not_my_business")
		var outcome := GameRuntime.use_armed_item_on("relic.wetberry")
		if outcome.has("error"):
			EventBus.notification_posted.emit(str(outcome["error"]))
		else:
			_start_dialogue("Wetberry", [
				"The evidence bag seals with a disappointed zipper sound.",
				"Wetberry stops pulsing. The room becomes measurably less damp."
			])
		_refresh_world()
		return

	_start_dialogue("Wetberry", [
		"A small white carton bearing red strawberry glyphs stands upright with too much confidence.",
		"The sides pulse gently when observed.",
		"Bare hands feel like an extremely bad administrative decision."
	])
	EventBus.first_person_objective_changed.emit("Find Keith in the utility corner and ask for safe containment gear.")


func _start_dialogue(speaker: String, lines: Array) -> void:
	EventBus.first_person_dialogue_requested.emit(speaker, lines)


func _on_dialogue_closed() -> void:
	if pending_dialogue_action == "":
		return

	var action := pending_dialogue_action
	pending_dialogue_action = ""

	if action == "grant_evidence_bag":
		var state := GameRuntime.world_state
		if state == null:
			return
		if not state.has_item("item.evidence_bag_not_my_business"):
			GameRuntime.execute_choice("ask_for_evidence_bag")
		GameRuntime.action_resolver.enter_scene(state, "scene.act1.first_sighting", false)
		EventBus.world_state_changed.emit({})
		EventBus.first_person_objective_changed.emit("Return to Wetberry at the central table and contain it.")


func _refresh_world() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return

	var wetberry := get_node_or_null("World/Wetberry")
	if wetberry != null:
		var contained := bool(state.get_flag("wetberry_contained", false))
		wetberry.visible = not contained
		wetberry.process_mode = Node.PROCESS_MODE_DISABLED if contained else Node.PROCESS_MODE_INHERIT
		var collision := wetberry.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", contained)

	if state.get_flag("wetberry_contained", false):
		EventBus.first_person_objective_changed.emit("Containment complete. Explore the breakroom and check the PDA.")
	elif state.has_item("item.evidence_bag_not_my_business"):
		EventBus.first_person_objective_changed.emit("Return to Wetberry at the central table and contain it.")
	else:
		EventBus.first_person_objective_changed.emit("Find Keith in the utility corner and ask for safe containment gear.")
