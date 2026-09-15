class_name FirstPersonBreakroom
extends Node3D

const QuantumWitnessSystemClass = preload("res://scripts/quantum/QuantumWitnessSystem.gd")
const QuantumEntanglementClass = preload("res://scripts/quantum/QuantumEntanglement.gd")
const FirstPersonInspectableClass = preload("res://scripts/fps/FirstPersonInspectable.gd")
const KeithAmbientWorkerClass = preload("res://scripts/fps/KeithAmbientWorker.gd")

@onready var ceiling_light: DirectionalLight3D = get_node_or_null("CeilingLight")
@onready var ambient_hum: AudioStreamPlayer = get_node_or_null("AmbientHum")
@onready var coffee_switch_sfx: AudioStreamPlayer = get_node_or_null("CoffeeSwitchSFX")
@onready var coffee_brew_sfx: AudioStreamPlayer = get_node_or_null("CoffeeBrewSFX")
@onready var fridge_hinge_sfx: AudioStreamPlayer = get_node_or_null("FridgeHingeSFX")
@onready var quantum_player: CharacterBody3D = get_node_or_null("Player")
@onready var quantum_kevin: Node3D = get_node_or_null("World/FirstPersonKevin")
@onready var quantum_coffee_maker: StaticBody3D = get_node_or_null("World/CoffeeMaker")
@onready var quantum_coffee_light: OmniLight3D = get_node_or_null("World/CoffeeMaker/CoffeeLight")
@onready var coffee_led: MeshInstance3D = get_node_or_null("World/CoffeeMaker/StatusLED")
@onready var coffee_steam: MeshInstance3D = get_node_or_null("World/CoffeeMaker/BrewSteam")

@onready var fridge_body: StaticBody3D = get_node_or_null("World/Fridge")
@onready var fridge_door_pivot: Node3D = get_node_or_null("World/Fridge/FridgeDoorPivot")
@onready var freezer_door_pivot: Node3D = get_node_or_null("World/Fridge/FreezerDoorPivot")
@onready var fridge_fly_swarm: Node3D = get_node_or_null("World/Fridge/FlySwarm")
@onready var fridge_light: OmniLight3D = get_node_or_null("World/Fridge/FridgeLight")

@onready var keith_actor: CharacterBody3D = get_node_or_null("World/Keith")
@onready var wetberry_prop: Node3D = get_node_or_null("World/Wetberry")
@onready var wetberry_contamination_light: OmniLight3D = get_node_or_null("World/Wetberry/ContaminationLight")
@onready var central_table: StaticBody3D = get_node_or_null("World/CentralTable")

var witness_system = null
var entanglement = null
var keith_worker = null
var coffee_machine_state: String = "normal"
var is_coffee_on: bool = false
var is_fridge_open: bool = false
var is_fridge_animating: bool = false

var pending_dialogue_action: String = ""

# Inspection & Hold systems
var inspecting_target: Node3D = null
var inspect_camera_start_transform: Transform3D
var is_inspecting: bool = false
var inspect_tween: Tween = null

var wetberry_holdable = null
var held_prop = null
var held_view_mesh: Node3D = null

var fly_time: float = 0.0
var breakroom_audio_active := true


func _ready() -> void:
	EventBus.first_person_interaction_requested.connect(_on_interaction_requested)
	EventBus.first_person_dialogue_closed.connect(_on_dialogue_closed)
	EventBus.world_state_changed.connect(func(_delta): _refresh_world())
	EventBus.inventory_changed.connect(_refresh_world)

	if GameRuntime.world_state != null:
		GameRuntime.action_resolver.enter_scene(GameRuntime.world_state, "scene.act1.first_sighting", false)
		EventBus.world_state_changed.emit({})

	_setup_interaction_systems()
	_refresh_world()
	_init_quantum_system()
	if is_instance_valid(ambient_hum) and not ambient_hum.finished.is_connected(_restart_ambient_hum):
		ambient_hum.finished.connect(_restart_ambient_hum)


func _setup_interaction_systems() -> void:
	# 1. Holdable Wetberry
	wetberry_prop = get_node_or_null("World/Wetberry")
	if wetberry_prop:
		# prefer editor-placed Holdable component under the prop
		var holdable_node = wetberry_prop.get_node_or_null("Holdable")
		wetberry_holdable = holdable_node as Holdable

	# 2. Keith Ambient Worker
	if keith_actor:
		keith_worker = KeithAmbientWorkerClass.new(keith_actor)

	# 3. Dynamic Prompts
	_update_appliance_prompts()
	# Restore persisted room_state for appliances and placements
	_restore_persistence()


func _restore_persistence() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return
	var mem := state.room_memory(state.current_location)
	# coffee
	if mem.has("coffee_on"):
		is_coffee_on = bool(mem.get("coffee_on"))
		_update_coffee_maker_state()
	# fridge
	if mem.has("fridge_open"):
		is_fridge_open = bool(mem.get("fridge_open"))
		if is_instance_valid(fridge_fly_swarm):
			fridge_fly_swarm.visible = is_fridge_open
		if is_instance_valid(fridge_light):
			fridge_light.visible = is_fridge_open
		if is_instance_valid(fridge_door_pivot):
			fridge_door_pivot.rotation.y = deg_to_rad(95.0) if is_fridge_open else 0.0
		if is_instance_valid(freezer_door_pivot):
			freezer_door_pivot.rotation.y = deg_to_rad(95.0) * 0.8 if is_fridge_open else 0.0
	# placed props
	if mem.has("placed_props"):
		var placed = mem.get("placed_props")
		for key in placed.keys():
			var info = placed.get(key)
			var node = get_node_or_null(str(info.get("path", "")))
			if node and node is Node3D:
				var tr = Transform3D(Basis(info.get("basis", Basis.IDENTITY)), Vector3(info.get("x", 0.0), info.get("y", 0.0), info.get("z", 0.0)))
				node.global_transform = tr


func _restart_ambient_hum() -> void:
	if breakroom_audio_active and is_instance_valid(ambient_hum):
		ambient_hum.play()


func set_breakroom_audio_active(active: bool) -> void:
	breakroom_audio_active = active
	if is_instance_valid(ambient_hum):
		if active:
			if not ambient_hum.playing:
				ambient_hum.play()
		else:
			ambient_hum.stop()
	if keith_worker:
		if active:
			keith_worker.resume_cleaning()
		else:
			keith_worker.pause_cleaning()
	if not active:
		if is_instance_valid(coffee_switch_sfx):
			coffee_switch_sfx.stop()
		if is_instance_valid(coffee_brew_sfx):
			coffee_brew_sfx.stop()
		if is_instance_valid(fridge_hinge_sfx):
			fridge_hinge_sfx.stop()


func _update_fluorescent_flutter() -> void:
	if not is_instance_valid(ceiling_light):
		return
	var seconds := Time.get_ticks_msec() * 0.001
	var flutter := sin(seconds * 7.3) * 0.014 + sin(seconds * 17.1) * 0.006
	var rare_dip := -0.08 if sin(seconds * 0.41) > 0.997 else 0.0
	ceiling_light.light_energy = clampf(0.95 + flutter + rare_dip, 0.82, 1.0)


func _update_wetberry_presence() -> void:
	if not is_instance_valid(wetberry_contamination_light):
		return
	var seconds := Time.get_ticks_msec() * 0.001
	var pulse := sin(seconds * 2.25) * 0.065 + sin(seconds * 0.47) * 0.025
	wetberry_contamination_light.light_energy = clampf(0.32 + pulse, 0.22, 0.42)


func _process(delta: float) -> void:
	_update_fluorescent_flutter()
	_update_wetberry_presence()
	if keith_worker:
		keith_worker.update(delta)

	# Animate fridge flies when open
	if is_fridge_open and is_instance_valid(fridge_fly_swarm) and fridge_fly_swarm.visible:
		fly_time += delta * 6.0
		for i in range(fridge_fly_swarm.get_child_count()):
			var fly = fridge_fly_swarm.get_child(i) as Node3D
			if fly:
				var offset_x = sin(fly_time + float(i) * 1.7) * 0.12
				var offset_y = cos(fly_time * 1.3 + float(i) * 2.1) * 0.08
				var offset_z = sin(fly_time * 0.9 + float(i)) * 0.10
				fly.position = fly.get_meta("base_pos", Vector3.ZERO) + Vector3(offset_x, offset_y, offset_z)

	# Coffee brewing subtle steam pulse
	if is_coffee_on and is_instance_valid(coffee_steam) and coffee_steam.visible:
		var pulse = 0.7 + sin(Time.get_ticks_msec() * 0.008) * 0.3
		coffee_steam.scale = Vector3(pulse, pulse, pulse)


func _unhandled_input(event: InputEvent) -> void:
	if is_inspecting:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_E):
			# delegate to canonical controller
			var ctrl = get_tree().get_root().find_child("InspectController", true, false)
			if ctrl:
				ctrl.exit_inspect()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch and event.pressed:
			var ctrl2 = get_tree().get_root().find_child("InspectController", true, false)
			if ctrl2:
				ctrl2.exit_inspect()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var ctrl3 = get_tree().get_root().find_child("InspectController", true, false)
			if ctrl3:
				ctrl3.exit_inspect()
			get_viewport().set_input_as_handled()


func _update_appliance_prompts() -> void:
	if coffee_steam:
		coffee_steam.visible = is_coffee_on

	if quantum_coffee_maker and quantum_coffee_maker is FirstPersonInteractable:
		var c_prompt = "[E / A] Turn Off Coffee Maker" if is_coffee_on else "[E / A] Turn On Coffee Maker"
		quantum_coffee_maker.set("dynamic_prompt", c_prompt)

	if fridge_body and fridge_body is FirstPersonInteractable:
		var f_prompt = "[E / A] Close Fridge" if is_fridge_open else "[E / A] Open Fridge"
		fridge_body.set("dynamic_prompt", f_prompt)

	if wetberry_prop and wetberry_prop is FirstPersonInteractable:
		var w_prompt = "[E / A] Inspect Wetberry"
		wetberry_prop.set("dynamic_prompt", w_prompt)


func _on_interaction_requested(data: Dictionary) -> void:
	if is_inspecting:
		exit_inspect()
		return

	var inter_id = str(data.get("interaction_id", ""))
	match inter_id:
		"keith":
			if keith_worker:
				keith_worker.pause_cleaning()
			_interact_keith()
		"wetberry":
			_interact_wetberry()
		"coffee":
			_interact_coffee()
		"fridge":
			_interact_fridge()
		"world_exit":
			_interact_world_exit()
		"lattice_echo":
			_interact_lattice_echo(data)
		"lattice_terminal":
			_interact_lattice_terminal()
		"central_table":
			_start_inspect(central_table, "Central Table", 2.2, 0.4)
		_:
			var node := data.get("node") as Node3D
			if node and node.get("can_inspect"):
				var dist_val = node.get("inspect_distance")
				var dist: float = float(dist_val) if dist_val != null else 1.4
				var offset_val = node.get("inspect_height_offset")
				var offset_h: float = float(offset_val) if offset_val != null else 0.0
				_start_inspect(node, str(data.get("speaker_name", "Object")), dist, offset_h)
			else:
				var speaker := str(data.get("speaker_name", "Hive-Lattice"))
				var description := str(data.get("description", "Nothing happens."))
				_start_dialogue(speaker, [description])


# ============================================================
# 1. FOCUS / INSPECT / ZOOM SYSTEM
# ============================================================
func _start_inspect(target: Node3D, target_name: String, distance: float = 1.4, height_offset: float = 0.0) -> void:
	# Delegate to InspectController singleton to perform canonical inspection
	if not is_instance_valid(target) or not is_instance_valid(quantum_player):
		return
	var ctrl = get_tree().get_root().find_child("InspectController", true, false)
	if ctrl and ctrl.has_method("request_inspect"):
		ctrl.request_inspect(target, quantum_player)
		is_inspecting = true
		inspecting_target = target
		return




func exit_inspect() -> void:
	if not is_inspecting:
		return
	is_inspecting = false
	inspecting_target = null
	var ctrl = get_tree().get_root().find_child("InspectController", true, false)
	if ctrl and ctrl.has_method("exit_inspect"):
		ctrl.exit_inspect()


# ============================================================
# 2. PICK UP / HOLD / PLACE SYSTEM
# ============================================================
func pick_up_wetberry() -> bool:
	if held_prop != null or wetberry_holdable == null:
		return false
	if not wetberry_holdable.can_pick_up():
		return false
	var ok: bool = wetberry_holdable.pick_up(quantum_player)
	if ok:
		held_prop = wetberry_holdable
		_create_held_view_mesh()
		EventBus.notification_posted.emit("Picked up Wetberry.")
		_update_appliance_prompts()
	return ok


func place_held_object() -> bool:
	if held_prop == null or not is_instance_valid(quantum_player):
		return false

	var cam := quantum_player.get("camera") as Camera3D
	if not cam:
		return false

	# Raycast downward/forward from player to find legal flat surface
	var _space_state = get_world_3d().direct_space_state
	var from_pos: Vector3 = cam.global_position
	var to_pos: Vector3 = from_pos + -cam.global_transform.basis.z * 2.2 + Vector3(0, -1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1
	var hit: Dictionary = _space_state.intersect_ray(query)

	var place_pos := Vector3.ZERO
	var half_height: float = held_prop.get_half_height() if held_prop is Holdable else 0.25
	if not hit.is_empty():
		place_pos = hit.position + Vector3(0.0, half_height + 0.02, 0.0)
	else:
		# Fallback: probe straight down at a point in front of the player.
		var probe_xz := quantum_player.global_position + -quantum_player.global_transform.basis.z * 1.2
		var down_query := PhysicsRayQueryParameters3D.create(
			probe_xz + Vector3(0.0, 2.0, 0.0),
			probe_xz + Vector3(0.0, -2.0, 0.0)
		)
		down_query.collision_mask = 1
		var down_hit: Dictionary = _space_state.intersect_ray(down_query)
		if not down_hit.is_empty():
			hit = down_hit
			place_pos = down_hit.position + Vector3(0.0, half_height + 0.02, 0.0)
		else:
			place_pos = probe_xz
			place_pos.y = half_height + 0.12

	# Check room bounds
	place_pos.x = clampf(place_pos.x, -7.0, 7.0)
	place_pos.z = clampf(place_pos.z, -5.0, 5.0)

	var t := Transform3D(Basis.IDENTITY, place_pos)
	var ok: bool = false
	if held_prop and held_prop is Holdable:
		var ignored_colliders: Array = [quantum_player]
		var support = hit.get("collider") if not hit.is_empty() else null
		if support != null:
			ignored_colliders.append(support)
		if held_prop.can_place_at(t, _space_state, ignored_colliders):
			ok = held_prop.place(t)
	if ok:
		var placed_root := held_prop.get_parent() as Node3D
		var state := GameRuntime.world_state
		if placed_root != null and state != null:
			var mem := state.room_memory(state.current_location)
			var placed_props: Dictionary = mem.get("placed_props", {})
			placed_props[str(placed_root.name)] = {
				"path": str(get_path_to(placed_root)),
				"x": placed_root.global_position.x,
				"y": placed_root.global_position.y,
				"z": placed_root.global_position.z,
			}
			mem["placed_props"] = placed_props
			EventBus.world_state_changed.emit({})
		_destroy_held_view_mesh()
		held_prop = null
		EventBus.notification_posted.emit("Placed Wetberry.")
		_update_appliance_prompts()
	return ok


func _create_held_view_mesh() -> void:
	if not is_instance_valid(quantum_player):
		return
	var held_slot := quantum_player.find_child("HeldSlot", true, false) as Node3D
	if not held_slot:
		return

	_destroy_held_view_mesh()
	held_view_mesh = Node3D.new()
	held_view_mesh.name = "HeldWetberryMesh"
	held_slot.add_child(held_view_mesh)

	var carton := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.14)
	carton.mesh = box
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.92, 0.90, 0.85, 1.0)
	carton.material_override = mat_body
	held_view_mesh.add_child(carton)

	var gable := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.18, 0.08, 0.14)
	gable.mesh = prism
	gable.position = Vector3(0.0, 0.13, 0.0)
	var mat_gable := StandardMaterial3D.new()
	mat_gable.albedo_color = Color(0.75, 0.12, 0.18, 1.0)
	gable.material_override = mat_gable
	held_view_mesh.add_child(gable)


func _destroy_held_view_mesh() -> void:
	if is_instance_valid(held_view_mesh):
		held_view_mesh.queue_free()
		held_view_mesh = null


# ============================================================
# 3. COFFEE MAKER INTERACTION
# ============================================================
func _interact_coffee() -> void:
	toggle_coffee_maker()


func toggle_coffee_maker() -> void:
	is_coffee_on = not is_coffee_on
	if is_instance_valid(coffee_switch_sfx):
		coffee_switch_sfx.play()
	if is_coffee_on and is_instance_valid(coffee_brew_sfx):
		coffee_brew_sfx.play()
	_update_coffee_maker_state()
	_update_appliance_prompts()
	# persist
	var state := GameRuntime.world_state
	if state != null:
		var mem := state.room_memory(state.current_location)
		mem["coffee_on"] = is_coffee_on
		EventBus.world_state_changed.emit({})
	if is_coffee_on:
		EventBus.notification_posted.emit("Coffee maker humming. Fluid circulating.")
	else:
		EventBus.notification_posted.emit("Coffee maker turned off.")


func _update_coffee_maker_state() -> void:
	if coffee_led:
		var mat := coffee_led.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = is_coffee_on
			mat.emission = Color(0.1, 0.9, 0.3) if is_coffee_on else Color(0.2, 0.1, 0.05)
			mat.emission_energy_multiplier = 2.0 if is_coffee_on else 0.0

	if quantum_coffee_light:
		quantum_coffee_light.visible = is_coffee_on

	if coffee_steam:
		coffee_steam.visible = is_coffee_on


# ============================================================
# 4. REFRIGERATOR INTERACTION (Hinge & Contaminated Cavity)
# ============================================================
func _interact_fridge() -> void:
	toggle_fridge_door()


func toggle_fridge_door() -> void:
	if is_fridge_animating:
		return

	is_fridge_open = not is_fridge_open
	is_fridge_animating = true
	if is_instance_valid(fridge_hinge_sfx):
		fridge_hinge_sfx.play()
	if is_instance_valid(fridge_light):
		fridge_light.visible = is_fridge_open

	var target_angle := deg_to_rad(95.0) if is_fridge_open else 0.0

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(fridge_door_pivot):
		tween.tween_property(fridge_door_pivot, "rotation:y", target_angle, 0.6)
	if is_instance_valid(freezer_door_pivot):
		tween.tween_property(freezer_door_pivot, "rotation:y", target_angle * 0.8, 0.55)

	tween.finished.connect(func():
		is_fridge_animating = false
		if is_instance_valid(fridge_fly_swarm):
			fridge_fly_swarm.visible = is_fridge_open
		_update_appliance_prompts()
		# persist fridge state
		var state := GameRuntime.world_state
		if state != null:
			var mem := state.room_memory(state.current_location)
			mem["fridge_open"] = is_fridge_open
			EventBus.world_state_changed.emit({})
	)


# ============================================================
# 5. KEITH & WETBERRY DIALOGUE / CONTAINMENT
# ============================================================
func _interact_keith() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return

	if state.get_flag("wetberry_contained", false):
		_start_dialogue("Keith the Janitor", [
			"You got it sealed? Good. I heard the bag close from here.",
			"That east service door should have released. If you're leaving, take the evidence with you. I am not putting that thing back in the fridge."
		])
		return
	if state.has_item("item.evidence_bag_not_my_business"):
		_start_dialogue("Keith the Janitor", [
			"You're back. Good — you've still got the bag I gave you.",
			"Wetberry is on the central table. Get close, use the bag on it, seal it, and then come tell me if the bag starts breathing."
		])
		return

	GameRuntime.action_resolver.enter_scene(state, "scene.act1.keith_corner", false)
	pending_dialogue_action = "grant_evidence_bag"
	_start_dialogue("Keith the Janitor", [
		"Hey — yeah, you. You came over because of the carton, right? Do not touch it bare-handed.",
		"Here. Take this evidence bag. Open it, get Wetberry inside, seal the zipper, and keep your face away from the opening.",
		"If it makes a noise after that, come back and tell me. I would rather know than pretend I didn't hear it."
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
			AudioManager.play_bag_zip()
			AtmosphereDirector.play_containment_drop()
			_start_dialogue("Wetberry", [
				"The zipper closes with a short plastic rasp. A moment later, two distant drops answer from inside the ceiling.",
				"Wetberry settles inside the clear bag. You can still see it through the plastic; it is no longer pulsing."
			])
		_refresh_world()
		return

	# If player does not have bag, inspect it or provide pickup
	_start_inspect(wetberry_prop, "Wetberry", 0.9, 0.0)
	EventBus.first_person_objective_changed.emit("Find Keith in the utility corner and ask for safe containment gear.")


func _start_dialogue(speaker: String, lines: Array) -> void:
	EventBus.first_person_dialogue_requested.emit(speaker, lines)


func _on_dialogue_closed() -> void:
	if keith_worker:
		keith_worker.resume_cleaning()

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
			AudioManager.play_item_pickup()
		GameRuntime.action_resolver.enter_scene(state, "scene.act1.first_sighting", false)
		EventBus.world_state_changed.emit({})
		EventBus.first_person_objective_changed.emit("Return to Wetberry at the central table and contain it.")
	elif action == "complete_campaign":
		_complete_campaign_and_show_ending()


func _refresh_world() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return

	var wetberry := get_node_or_null("World/Wetberry")
	if wetberry != null and held_prop == null:
		var contained := bool(state.get_flag("wetberry_contained", false))
		wetberry.visible = not contained
		wetberry.process_mode = Node.PROCESS_MODE_DISABLED if contained else Node.PROCESS_MODE_INHERIT
		var collision := wetberry.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", contained)

	if state.get_flag("wetberry_contained", false):
		EventBus.first_person_objective_changed.emit("Containment complete. Find the glowing EXIT on the east wall and leave the breakroom.")
	elif state.has_item("item.evidence_bag_not_my_business"):
		EventBus.first_person_objective_changed.emit("Return to Wetberry at the central table and contain it.")
	else:
		EventBus.first_person_objective_changed.emit("Find Keith in the utility corner and ask for safe containment gear.")


func _init_quantum_system() -> void:
	witness_system = QuantumWitnessSystemClass.new()
	witness_system.name = "QuantumWitnessSystem"
	add_child(witness_system)
	if quantum_player != null and quantum_player.get("camera") != null:
		witness_system.register_witness("camera3d_player", quantum_player.get("camera"), 30.0, 360.0, "camera3d")
	if quantum_kevin != null and quantum_kevin.get("quantum_component") != null:
		var q = quantum_kevin.get("quantum_component")
		if witness_system.has_method("register_entity"):
			witness_system.register_entity(q)
		entanglement = QuantumEntanglementClass.new()
		entanglement.name = "BreakroomQuantumEntanglement"
		add_child(entanglement)


func set_entangled_state(state_name: String) -> void:
	coffee_machine_state = state_name
	_update_coffee_machine_visuals()


func _update_coffee_machine_visuals() -> void:
	if quantum_coffee_maker == null or quantum_coffee_light == null:
		return
	match coffee_machine_state:
		"leaking":
			quantum_coffee_light.light_color = Color(1.0, 0.7, 0.2)
			quantum_coffee_light.light_energy = 1.5
		"anomalous":
			quantum_coffee_light.light_color = Color(0.3, 0.8, 1.0)
			quantum_coffee_light.light_energy = 2.5
		_:
			quantum_coffee_light.light_color = Color(0.9, 0.9, 0.9)
			quantum_coffee_light.light_energy = 0.8


func _interact_world_exit() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return
	if not bool(state.get_flag("wetberry_contained", false)):
		EventBus.notification_posted.emit("The service exit remains locked while Wetberry is loose.")
		return
	var gate := get_node_or_null("ProcGenExitGate") as StaticBody3D
	if gate == null:
		EventBus.notification_posted.emit("The exit mechanism is unavailable.")
		return
	if bool(gate.get_meta("opened", false)):
		return
	gate.set_meta("opened", true)
	var collision := gate.get_node_or_null("Collision") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	gate.set("dynamic_prompt", "EXIT OPEN")
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(gate, "position:y", gate.position.y + 3.2, 1.05)
	state.room_memory()["exit_open"] = true
	state.world_state["breakroom_exit_open"] = true
	AtmosphereDirector.play_waterdrop(-11.0)
	EventBus.notification_posted.emit("The service door drags upward. The roomtone follows you.")
	EventBus.first_person_objective_changed.emit("Leave the breakroom. Follow the threshold lights into the Service Spine.")


func _interact_lattice_echo(data: Dictionary) -> void:
	var state := GameRuntime.world_state
	if state == null:
		return
	var echo_id := str(data.get("target_id", "echo.unknown"))
	var node := data.get("node") as Node
	var level_index := int(node.get_meta("level_index", -1)) if node != null else -1
	var echoes: Dictionary = state.world_state.get("lattice_echoes", {})
	var description := str(data.get("description", "The recording contains only roomtone."))
	var already_recorded := echoes.has(echo_id)
	if not already_recorded:
		echoes[echo_id] = {
			"level_index": level_index,
			"text": description,
			"recorded_turn": state.turn_count,
		}
		state.world_state["lattice_echoes"] = echoes
		EventBus.notification_posted.emit("Witness echo recorded: %d / 24" % echoes.size())
		AtmosphereDirector.play_waterdrop(-14.0)
	var prefix := "Already recorded. " if already_recorded else "Recorded. "
	_start_dialogue(str(data.get("speaker_name", "Witness Echo")), [prefix + description])


func _interact_lattice_terminal() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return
	var echoes: Dictionary = state.world_state.get("lattice_echoes", {})
	if bool(state.world_state.get("campaign_complete", false)):
		pending_dialogue_action = "complete_campaign"
		_start_dialogue("THE LATTICE", [
			"The witness record is already closed.",
			"The terminal still remembers %d optional echoes." % echoes.size(),
		])
		return
	pending_dialogue_action = "complete_campaign"
	_start_dialogue("THE LATTICE", [
		"The final terminal accepts the witness record without asking whether you understood it.",
		"Optional echoes recovered: %d / 24." % echoes.size(),
		"The building stops pretending there is another mandatory corridor.",
	])


func _complete_campaign_and_show_ending() -> void:
	var state := GameRuntime.world_state
	if state == null:
		return
	var echoes: Dictionary = state.world_state.get("lattice_echoes", {})
	var procedural: Dictionary = state.world_state.get("procedural_world", {})
	state.world_state["campaign_complete"] = true
	state.world_state["completion_echo_count"] = echoes.size()
	var visited_cells: Dictionary = procedural.get("cell_state", {})
	state.world_state["completion_visited_cells"] = visited_cells.size()
	state.world_state["completion_timestamp"] = Time.get_datetime_string_from_system(true)
	EventBus.world_state_changed.emit({"campaign_complete": true})
	var active_slot := str(state.world_state.get("active_save_slot", "slot_1"))
	GameRuntime.save_slot(active_slot)
	AtmosphereDirector.play_waterdrop(-8.0)
	get_tree().change_scene_to_file("res://scenes/ui/EndingScreen.tscn")
