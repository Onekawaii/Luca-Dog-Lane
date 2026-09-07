class_name FirstPersonQuantumNPC
extends CharacterBody3D

# FirstPersonQuantumNPC (Kevin from Marketing in 3D).
# Physical CharacterBody3D with collision, RayCast3D interaction,
# QuantumEntity observation dynamics, and spatial Vector3 anchors.

const QuantumEntityClass = preload("res://scripts/quantum/QuantumEntity.gd")
const QuantumStateAnchorClass = preload("res://scripts/quantum/QuantumStateAnchor.gd")

@export var npc_id: String = "npc.kevin_marketing"
@export var display_name: String = "Kevin (Marketing)"
@export var default_anchor: String = "KevinCoffeeAnchor"

var quantum_component: QuantumEntity = null
var current_anchor_id: String = "KevinCoffeeAnchor"

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")


func _init() -> void:
	_setup_quantum_component()


func _ready() -> void:
	_check_presence()


func _setup_quantum_component() -> void:
	if quantum_component != null:
		return

	quantum_component = QuantumEntityClass.new()
	quantum_component.name = "QuantumComponent"
	quantum_component.entity_id = "kevin_marketing"
	quantum_component.entity_name = "Kevin (Marketing)"
	quantum_component.grace_period = 0.75
	quantum_component.same_state_relative_weight = 45.0
	quantum_component.other_state_relative_weight = 40.0
	quantum_component.absent_state_relative_weight = 15.0
	add_child(quantum_component)

	# Setup authored 3D safe anchors:
	# Anchor 1: Breakroom Coffee Area (-2.5, 0.0, -1.8)
	var anchor_coffee = QuantumStateAnchorClass.new(
		"KevinCoffeeAnchor",
		Vector3(-2.5, 0.0, -1.8),
		45.0,
		false,
		"coffee_area",
		"Coffee Area"
	)
	# Anchor 2: Utility Corner (2.8, 0.0, 2.2)
	var anchor_utility = QuantumStateAnchorClass.new(
		"KevinUtilityAnchor",
		Vector3(2.8, 0.0, 2.2),
		40.0,
		false,
		"utility_corner",
		"Utility Corner"
	)
	# Anchor 3: Hallway Doorway Threshold (0.0, 0.0, 3.8)
	var anchor_door = QuantumStateAnchorClass.new(
		"KevinDoorAnchor",
		Vector3(0.0, 0.0, 3.8),
		40.0,
		false,
		"door_threshold",
		"Hallway Doorway"
	)
	# Anchor 4: Absent State (Marketing Department)
	var anchor_absent = QuantumStateAnchorClass.new(
		"KevinAbsentAnchor",
		Vector3(0.0, -100.0, 0.0),
		15.0,
		true,
		"marketing_department",
		"Marketing Department"
	)

	quantum_component.register_anchor(anchor_coffee)
	quantum_component.register_anchor(anchor_utility)
	quantum_component.register_anchor(anchor_door)
	quantum_component.register_anchor(anchor_absent)

	quantum_component.set_initial_state(default_anchor)
	quantum_component.state_resolved.connect(_on_quantum_state_resolved)


func _on_quantum_state_resolved(anchor_id: String, anchor: QuantumStateAnchor) -> void:
	current_anchor_id = anchor_id
	apply_quantum_anchor(anchor)


func apply_quantum_anchor(anchor: QuantumStateAnchor) -> void:
	if anchor.is_absent:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		if collision_shape:
			collision_shape.disabled = true
	else:
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
		position = anchor.position_3d
		if is_inside_tree():
			global_position = anchor.position_3d
		velocity = Vector3.ZERO
		if collision_shape:
			collision_shape.disabled = false


func _check_presence() -> void:
	if quantum_component and quantum_component.current_anchor_id != "":
		var anchor = quantum_component.anchors.get(quantum_component.current_anchor_id)
		if anchor:
			apply_quantum_anchor(anchor)


func get_quantum_dialogue() -> Dictionary:
	match current_anchor_id:
		"KevinUtilityAnchor":
			return {
				"speaker": "Kevin (Marketing)",
				"lines": [
					"You keep asking where I've been.",
					"I've been standing right here in facilities since 8:14.",
					"There are noticeable brand synergies between damp concrete and corporate endurance."
				]
			}
		"KevinDoorAnchor":
			return {
				"speaker": "Kevin (Marketing)",
				"lines": [
					"I was just analyzing the hallway foot traffic.",
					"If anyone from corporate approaches, we can pitch the relocation as a strategic pivot."
				]
			}
		"KevinAbsentAnchor":
			return {
				"speaker": "Kevin (Marketing)",
				"lines": [
					"Marketing."
				]
			}
		_:
			return {
				"speaker": "Kevin (Marketing)",
				"lines": [
					"You keep asking where I've been.",
					"I haven't been anywhere.",
					"If we call the wetness a 'Hydration Reliquary', we can optimize the quarterly engagement metrics."
				]
			}


# RayCast3D Interaction target interface
func interact(_player: Node = null) -> void:
	if not visible:
		return

	var dialogue = get_quantum_dialogue()
	var hud = _get_first_person_hud()
	if hud and hud.has_method("open_dialogue"):
		hud.open_dialogue(dialogue["speaker"], dialogue["lines"])
	elif has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("dialogue_started"):
			bus.dialogue_started.emit(npc_id, dialogue["speaker"], dialogue["lines"][0], [])


func _get_first_person_hud() -> Node:
	var tree = get_tree()
	if not tree or not tree.root:
		return null
	return tree.root.find_child("FirstPersonHUD", true, false)
