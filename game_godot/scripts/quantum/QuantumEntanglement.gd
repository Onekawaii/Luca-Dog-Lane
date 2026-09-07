class_name QuantumEntanglement
extends Node

# Reusable Entanglement Link component.
# Causally couples the state of a primary QuantumEntity (or state source)
# to a target entity, prop, or environment object based on declarative state correlation maps.

signal state_propagated(source_state: String, target_state: String)

@export var source_entity_path: NodePath
@export var target_node_path: NodePath

# State correlation dictionary: source_anchor_id -> target_state_id
@export var state_correlations: Dictionary = {
	"anchor_coffee": "normal",
	"anchor_utility": "leaking",
	"anchor_doorway": "anomalous",
	"anchor_absent": "anomalous"
}

var source_entity: QuantumEntity = null
var target_node: Node = null
var current_target_state: String = "normal"


func _ready() -> void:
	if not source_entity_path.is_empty():
		source_entity = get_node_or_null(source_entity_path)
	if not target_node_path.is_empty():
		target_node = get_node_or_null(target_node_path)

	_bind_source_entity()


func setup_link(p_source: QuantumEntity, p_target: Node, p_correlations: Dictionary = {}) -> void:
	source_entity = p_source
	target_node = p_target
	if not p_correlations.is_empty():
		state_correlations = p_correlations
	_bind_source_entity()


func _bind_source_entity() -> void:
	if is_instance_valid(source_entity):
		if not source_entity.state_resolved.is_connected(_on_source_state_resolved):
			source_entity.state_resolved.connect(_on_source_state_resolved)
		# Initialize with source entity's current anchor
		if source_entity.current_anchor_id != "":
			apply_correlation(source_entity.current_anchor_id)


func _on_source_state_resolved(anchor_id: String, _anchor: QuantumStateAnchor) -> void:
	apply_correlation(anchor_id)


func apply_correlation(source_state: String) -> void:
	var target_state = state_correlations.get(source_state, "normal")
	current_target_state = target_state

	if is_instance_valid(target_node):
		if target_node.has_method("set_entangled_state"):
			target_node.set_entangled_state(target_state)
		elif target_node.has_method("set_state"):
			target_node.set_state(target_state)

	state_propagated.emit(source_state, target_state)
