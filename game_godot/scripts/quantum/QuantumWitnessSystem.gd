class_name QuantumWitnessSystem
extends Node

# Reusable Quantum Witness Subsystem (2D and 3D portable).
# Tracks multiple observer sources (Camera3D, Player, Security Cameras, NPCs, Mirrors, Devices),
# evaluates viewport frustum + PhysicsRayQueryParameters3D / 2D line-of-sight occlusion tests,
# pins entity state whenever witness_count > 0, and dispatches displacement events.

signal witness_registered(witness_id: String, witness_node: Node)
signal witness_unregistered(witness_id: String)
signal coherence_pressure_changed(entity_id: String, pressure: float)
signal uncertainty_displaced(entity_id: String, old_state: String, new_state: String)
signal quantum_state_forced(entity_id: String, target_state: String)

var registered_entities: Array[QuantumEntity] = []
var registered_witnesses: Dictionary = {} # witness_id -> Dictionary { "node": Node, "type": String, "range": float, "fov_deg": float }

@export var max_observation_range: float = 30.0 # 30 meters in 3D / configurable
@export var debug_visualization: bool = false


func _ready() -> void:
	call_deferred("_discover_witnesses_in_scene")


func register_entity(entity: QuantumEntity) -> void:
	if not registered_entities.has(entity):
		registered_entities.append(entity)
		if not entity.uncertainty_displaced.is_connected(_on_entity_uncertainty_displaced):
			entity.uncertainty_displaced.connect(_on_entity_uncertainty_displaced)


func unregister_entity(entity: QuantumEntity) -> void:
	registered_entities.erase(entity)


func register_witness(witness_id: String, witness_node: Node, max_range: float = 30.0, fov: float = 360.0, type: String = "generic") -> void:
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

	# First-Person 3D Camera witness (the true authoritative observation source)
	var cam3d = root.find_child("Camera3D", true, false)
	if cam3d:
		register_witness("camera3d_player", cam3d, max_observation_range, 360.0, "camera3d")
		return

	# 2D fallback camera
	var cam2d = root.find_child("Camera2D", true, false)
	if cam2d:
		register_witness("camera2d_player", cam2d, 1200.0, 360.0, "camera2d")


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

	var target_parent = entity.get_parent()
	if target_parent == null:
		return false

	# 1. Evaluate 3D Line-of-Sight if nodes are 3D
	if w_node is Node3D and target_parent is Node3D:
		var w3d = w_node as Node3D
		var t3d = target_parent as Node3D

		var w_pos = w3d.global_position
		var t_pos = t3d.global_position + Vector3(0, 0.9, 0) # Target chest/head height

		# Range check
		var dist = w_pos.distance_to(t_pos)
		if dist > max_range:
			return false

		# Camera3D Frustum check
		if w_node is Camera3D:
			var cam = w_node as Camera3D
			if not cam.is_position_in_frustum(t_pos):
				return false

		# Direct PhysicsRayQueryParameters3D occlusion test
		var world3d = w3d.get_world_3d()
		if world3d:
			var space_state = world3d.direct_space_state
			if space_state:
				var query = PhysicsRayQueryParameters3D.create(w_pos, t_pos)
				var excludes: Array[RID] = []
				if w_node is CollisionObject3D:
					excludes.append((w_node as CollisionObject3D).get_rid())
				if target_parent is CollisionObject3D:
					excludes.append((target_parent as CollisionObject3D).get_rid())
				if w_node.get_parent() is CollisionObject3D:
					excludes.append((w_node.get_parent() as CollisionObject3D).get_rid())
				query.exclude = excludes

				var result = space_state.intersect_ray(query)
				if not result.is_empty():
					var collider = result.get("collider")
					if collider != null and collider != target_parent and collider != w_node:
						return false # Raycast blocked by solid geometry / wall
		return true

	# 2. Evaluate 2D Line-of-Sight fallback
	if w_node is Node2D:
		var w2d = w_node as Node2D
		var t_pos2d = Vector2.ZERO
		if target_parent is Node2D:
			t_pos2d = (target_parent as Node2D).global_position
		else:
			return false

		var w_pos2d = w2d.global_position
		if w_pos2d.distance_to(t_pos2d) > max_range:
			return false

		var world2d = w2d.get_world_2d()
		if world2d:
			var space_state2d = world2d.direct_space_state
			if space_state2d:
				var query2d = PhysicsRayQueryParameters2D.create(w_pos2d, t_pos2d)
				var res2d = space_state2d.intersect_ray(query2d)
				if not res2d.is_empty():
					var col2d = res2d.get("collider")
					if col2d != null and col2d != target_parent and col2d != w_node:
						return false
		return true

	return false


func _on_entity_uncertainty_displaced(entity_id: String, old_anchor: String, new_anchor: String) -> void:
	uncertainty_displaced.emit(entity_id, old_anchor, new_anchor)


func force_state(entity_id: String, target_anchor_id: String) -> void:
	for entity in registered_entities:
		if is_instance_valid(entity) and entity.entity_id == entity_id:
			entity.set_initial_state(target_anchor_id)
			quantum_state_forced.emit(entity_id, target_anchor_id)
			break
