class_name QuantumEntity
extends Node

# Reusable Quantum Entity subsystem for Godot 4 (Node, Node3D, CharacterBody3D, or 2D).
# Implements observation-dependent state pinning, line-of-sight tracking,
# grace-period unobserved transitions, deterministic weighted resolution,
# and coherence metrics.

signal state_resolved(anchor_id: String, anchor: QuantumStateAnchor)
signal observation_changed(is_observed: bool, witness_count: int)
signal unobserved_period_started()
signal unobserved_period_ended()
signal uncertainty_displaced(entity_id: String, old_anchor: String, new_anchor: String)

enum ObservationState {
	OBSERVED,       # Pinned by 1 or more witnesses
	LOS_LOST,       # In grace timer period after losing witnesses
	UNOBSERVED,     # Eligible for state transition / superposition
	REOBSERVED      # Valid authored state resolves and freezes
}

@export var entity_id: String = "quantum_entity_generic"
@export var entity_name: String = "Quantum Subject"
@export var grace_period: float = 0.75 # Configurable grace period in seconds

# Authored relative weights for resolution pool (normalized dynamically)
@export var same_state_relative_weight: float = 45.0
@export var other_state_relative_weight: float = 40.0
@export var absent_state_relative_weight: float = 15.0

# Observation state tracking
var observation_state: int = ObservationState.UNOBSERVED
var is_currently_observed: bool = false
var active_witness_count: int = 0
var grace_timer: float = 0.0
var unobserved_timer: float = 0.0
var pending_transition: bool = false
var coherence_pressure: float = 1.0

# Valid authored anchors
var anchors: Dictionary = {} # String -> QuantumStateAnchor
var current_anchor_id: String = ""
var last_confirmed_anchor_id: String = ""
var last_confirmed_location_name: String = "Breakroom"

# RNG seed & state for deterministic resolution
var resolution_seed: int = 1337
var transition_count: int = 0


func _ready() -> void:
	if has_node("/root/QuantumWitnessSystem"):
		var sys = get_node("/root/QuantumWitnessSystem")
		if sys.has_method("register_entity"):
			sys.register_entity(self)


func register_anchor(anchor: QuantumStateAnchor) -> void:
	anchors[anchor.anchor_id] = anchor
	if current_anchor_id == "" and not anchor.is_absent:
		current_anchor_id = anchor.anchor_id
		last_confirmed_anchor_id = anchor.anchor_id
		last_confirmed_location_name = anchor.display_name


func set_initial_state(anchor_id: String) -> void:
	if anchors.has(anchor_id):
		current_anchor_id = anchor_id
		last_confirmed_anchor_id = anchor_id
		var anchor = anchors[anchor_id]
		if not anchor.is_absent:
			last_confirmed_location_name = anchor.display_name
		_apply_anchor(anchor)


func process_observation(delta: float, is_visible_to_any_witness: bool, witness_count: int) -> void:
	active_witness_count = witness_count

	if is_visible_to_any_witness and witness_count > 0:
		# Directly observed by at least one valid witness
		if observation_state == ObservationState.UNOBSERVED or pending_transition:
			# Entity was unobserved and is now re-observed: resolve state!
			_resolve_state_on_reobservation()
			observation_state = ObservationState.REOBSERVED
			observation_changed.emit(true, active_witness_count)
		elif observation_state == ObservationState.LOS_LOST:
			# Regained observation before grace period expired: remain pinned!
			observation_state = ObservationState.OBSERVED
			grace_timer = 0.0
		else:
			observation_state = ObservationState.OBSERVED

		is_currently_observed = true
		grace_timer = 0.0
		coherence_pressure = 1.0
	else:
		# Not visible or 0 witnesses
		if observation_state == ObservationState.OBSERVED or observation_state == ObservationState.REOBSERVED:
			# Lost LOS, enter grace period
			observation_state = ObservationState.LOS_LOST
			grace_timer = grace_period
			is_currently_observed = true # Treated as observed until grace period expires

		if observation_state == ObservationState.LOS_LOST:
			grace_timer -= delta
			if grace_timer <= 0.0:
				# Grace period sustained loss: become genuinely unobserved
				observation_state = ObservationState.UNOBSERVED
				is_currently_observed = false
				pending_transition = true
				unobserved_timer = 0.0
				unobserved_period_started.emit()
				observation_changed.emit(false, 0)

		if observation_state == ObservationState.UNOBSERVED:
			is_currently_observed = false
			unobserved_timer += delta
			# Coherence confidence decays slowly over time unobserved
			coherence_pressure = max(0.1, 1.0 - (unobserved_timer * 0.08))


func _resolve_state_on_reobservation() -> void:
	if not pending_transition:
		return

	pending_transition = false
	var old_anchor = current_anchor_id
	var chosen_anchor_id = _pick_next_anchor_deterministic()

	if anchors.has(chosen_anchor_id):
		current_anchor_id = chosen_anchor_id
		var anchor = anchors[chosen_anchor_id]
		_apply_anchor(anchor)

		if not anchor.is_absent:
			last_confirmed_anchor_id = chosen_anchor_id
			last_confirmed_location_name = anchor.display_name

		state_resolved.emit(chosen_anchor_id, anchor)
		if old_anchor != chosen_anchor_id:
			uncertainty_displaced.emit(entity_id, old_anchor, chosen_anchor_id)

	transition_count += 1
	unobserved_period_ended.emit()


func _pick_next_anchor_deterministic() -> String:
	if anchors.is_empty():
		return current_anchor_id

	var anchor_keys = anchors.keys()
	if anchor_keys.size() == 1:
		return anchor_keys[0]

	# Build weighted pool using authored relative weights
	var candidates: Array[String] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0

	for id in anchor_keys:
		var anchor: QuantumStateAnchor = anchors[id]
		var w = anchor.relative_weight
		if id == current_anchor_id:
			w = same_state_relative_weight
		elif anchor.is_absent:
			w = absent_state_relative_weight
		else:
			w = other_state_relative_weight

		candidates.append(id)
		weights.append(w)
		total_weight += w

	if total_weight <= 0.0:
		return current_anchor_id

	# Deterministic roll based on resolution_seed + transition_count
	var roll_seed_str = "%s:%d:%d" % [entity_id, resolution_seed, transition_count]
	var hash_ctx = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(roll_seed_str.to_utf8_buffer())
	var digest = hash_ctx.finish()

	var num: int = 0
	for i in range(min(8, digest.size())):
		num = (num << 8) | digest[i]
	num = abs(num)

	var roll = fmod(float(num), total_weight)
	var cursor: float = 0.0
	for i in range(candidates.size()):
		cursor += weights[i]
		if roll < cursor:
			return candidates[i]

	return candidates[-1]


func _apply_anchor(anchor: QuantumStateAnchor) -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return

	if parent_node.has_method("apply_quantum_anchor"):
		parent_node.apply_quantum_anchor(anchor)
	elif parent_node is Node3D:
		var p3d = parent_node as Node3D
		if anchor.is_absent:
			p3d.visible = false
			p3d.process_mode = Node.PROCESS_MODE_DISABLED
			if p3d is CollisionObject3D:
				for child in p3d.find_children("", "CollisionShape3D", true, false):
					child.disabled = true
		else:
			p3d.visible = true
			p3d.process_mode = Node.PROCESS_MODE_INHERIT
			p3d.global_position = anchor.position_3d
			if p3d is CollisionObject3D:
				for child in p3d.find_children("", "CollisionShape3D", true, false):
					child.disabled = false
	elif parent_node is CanvasItem:
		var p2d = parent_node as CanvasItem
		if anchor.is_absent:
			p2d.visible = false
			p2d.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			p2d.visible = true
			p2d.process_mode = Node.PROCESS_MODE_INHERIT
			if parent_node is Node2D:
				(parent_node as Node2D).global_position = anchor.position_2d


func get_coherence_percentage() -> int:
	if is_currently_observed:
		return 100
	return int(clampf(coherence_pressure * 100.0, 10.0, 99.0))


func get_status_summary() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_name": entity_name,
		"observed": is_currently_observed,
		"observation_state": observation_state,
		"witness_count": active_witness_count,
		"current_anchor": current_anchor_id,
		"last_confirmed_anchor": last_confirmed_anchor_id,
		"last_confirmed_location": last_confirmed_location_name,
		"coherence_pct": get_coherence_percentage(),
		"unobserved_time": unobserved_timer,
		"pending_transition": pending_transition
	}
