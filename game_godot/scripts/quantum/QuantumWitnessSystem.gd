class_name QuantumWitnessSystem
extends Node

# Reusable Quantum Witness and Observation Subsystem.
# Tracks multiple observer sources (Player Camera, Security Cameras, NPCs, Mirrors/Devices),
# calculates frustum/viewport visibility + Physics Raycast line-of-sight occlusion tests,
# pins quantum entity coherence whenever witness_count > 0,
# and emits displacement and coherence pressure events.

signal witness_registered(witness_id: String, witness_node: Node)
signal witness_unregistered(witness_id: String)
signal coherence_pressure_changed(entity_id: String, pressure: float)
signal uncertainty_displaced(entity_id: String, old_state: String, new_state: String)
signal quantum_state_forced(entity_id: String, target_state: String)

var registered_entities: Array[QuantumEntity] = []
var registered_witnesses: Dictionary = {} # witness_id -> Dictionary { "node": Node, "type": String, "range": float, "fov_deg": float }

@export var max_observation_range: float = 1200.0
@export var debug_visualization: bool = false


func _ready() -> void:
	# Add default player witness if present
	call_deferred("_discover_witnesses_in_scene")


func register_entity(entity: QuantumEntity) -> void:
	if not registered_entities.has(entity):
		registered_entities.append(entity)
		if not entity.uncertainty_displaced.is_connected(_on_entity_uncertainty_displaced):
			entity.uncertainty_displaced.connect(_on_entity_uncertainty_displaced)


func unregister_entity(entity: QuantumEntity) -> void:
	registered_entities.erase(entity)


func register_witness(witness_id: String, witness_node: Node, max_range: float = 1200.0, fov: float = 360.0, type: String = "generic") -> void:
	registered_witnesses[witness_id] = {
		"node": witness_node,
		"max_range": max_range,
		"fov_deg": fov,
		"type": type
	}
	witness_registered.emit(witness_id, witness_node)


func unregister_witness(witness_id: String) -> void:
	if registered_witnesses.has(witness_id):
		registered_witnesses.erase(witness_id)
		witness_unregistered.emit(witness_id)


func _discover_witnesses_in_scene() -> void:
	var tree = get_tree()
	if not tree:
		return
	var root = tree.current_scene
	if not root:
		return

	# Look for Player or Camera
	var player = root.find_child("Player", true, false)
	if player:
		register_witness("player_primary", player, max_observation_range, 360.0, "player")

	var cam = root.find_child("Camera2D", true, false)
	if cam and not registered_witnesses.has("player_primary"):
		register_witness("camera_primary", cam, max_observation_range, 360.0, "camera")


func _physics_process(delta: float) -> void:
	if registered_entities.is_empty():
		return

	for entity in registered_entities:
		if not is_instance_valid(entity):
			continue

		var valid_witness_count = 0
		var visible_to_any = false

		for w_id in registered_witnesses.keys():
			var w_data = registered_witnesses[w_id]
			var w_node: Node = w_data["node"]
			if not is_instance_valid(w_node):
				continue

			var is_visible = _evaluate_witness_los(w_data, entity)
			if is_visible:
				valid_witness_count += 1
				visible_to_any = true

		entity.process_observation(delta, visible_to_any, valid_witness_count)


func _evaluate_witness_los(witness_data: Dictionary, entity: QuantumEntity) -> bool:
	var w_node: Node = witness_data["node"]
	var max_range: float = witness_data.get("max_range", max_observation_range)

	var witness_pos = Vector2.ZERO
	if w_node is Node2D:
		witness_pos = (w_node as Node2D).global_position
	else:
		return false

	var entity_target_pos = entity.global_position

	# 1. Distance check
	var dist = witness_pos.distance_to(entity_target_pos)
	if dist > max_range:
		return false

	# 2. Viewport / Frustum check if witness is a Camera2D
	if w_node is Camera2D:
		var cam = w_node as Camera2D
		var vp_rect = cam.get_viewport_rect()
		var cam_pos = cam.global_position
		var visible_bounds = Rect2(cam_pos - (vp_rect.size * 0.5) / cam.zoom, vp_rect.size / cam.zoom)
		if not visible_bounds.has_point(entity_target_pos):
			return false

	# 3. Physics Raycast Occlusion Test (Checks for solid walls / opaque occluders)
	var space_state = entity.get_world_2d().direct_space_state
	if space_state:
		var query = PhysicsRayQueryParameters2D.create(witness_pos, entity_target_pos)
		query.exclude = [entity.get_rid()]
		if w_node is CollisionObject2D:
			query.exclude.append((w_node as CollisionObject2D).get_rid())

		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			# Hit an obstacle between witness and entity
			var collider = result.get("collider")
			if collider != null and collider != entity and collider != w_node:
				return false

	return true


func _on_entity_uncertainty_displaced(entity_id: String, old_anchor: String, new_anchor: String) -> void:
	uncertainty_displaced.emit(entity_id, old_anchor, new_anchor)


func force_state(entity_id: String, target_anchor_id: String) -> void:
	for entity in registered_entities:
		if is_instance_valid(entity) and entity.entity_id == entity_id:
			entity.set_initial_state(target_anchor_id)
			quantum_state_forced.emit(entity_id, target_anchor_id)
			break
