class_name KevinActor
extends ActorBase

# Kevin from Marketing - First Quantum NPC.
# Subsystem: QuantumEntity observation dynamics with spatial anchors,
# deterministic resolution, and state-aware dialogue responses.

const QuantumEntityClass = preload("res://scripts/quantum/QuantumEntity.gd")
const QuantumStateAnchorClass = preload("res://scripts/quantum/QuantumStateAnchor.gd")

var quantum_component: QuantumEntity = null
var current_anchor_id: String = "kevin_anchor_a"
var dialogue_memory: Dictionary = {}


func _init() -> void:
	actor_id = "npc.kevin_marketing"
	display_name = "Kevin (Marketing)"
	portrait_path = "res://assets/portraits/kevin_neutral.png"
	approach_offset = Vector2(0, 50)
	_init_quantum_system()


func _ready() -> void:
	super._ready()

	var bus = _get_event_bus()
	if bus and bus.has_signal("world_state_changed"):
		bus.world_state_changed.connect(_on_world_state_changed)
	_check_presence()


func _get_event_bus() -> Node:
	if has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null


func _get_game_runtime() -> Node:
	if has_node("/root/GameRuntime"):
		return get_node("/root/GameRuntime")
	return null


func _init_quantum_system() -> void:
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

	# Setup authored safe anchors:
	# Anchor A: Breakroom coffee counter area (330, 430)
	var anchor_a = QuantumStateAnchorClass.new(
		"kevin_anchor_a",
		Vector2(330, 430),
		45.0,
		false,
		"coffee_area",
		"Breakroom Coffee Area"
	)
	# Anchor B: Utility corner (920, 520)
	var anchor_b = QuantumStateAnchorClass.new(
		"kevin_anchor_b",
		Vector2(920, 520),
		40.0,
		false,
		"utility_corner",
		"Breakroom Utility Corner"
	)
	# Anchor C: Hallway doorway / edge position (1120, 450)
	var anchor_c = QuantumStateAnchorClass.new(
		"kevin_anchor_c",
		Vector2(1120, 450),
		40.0,
		false,
		"hallway_doorway",
		"Breakroom Hallway Threshold"
	)
	# Anchor D: Absent state (absent / in marketing)
	var anchor_d = QuantumStateAnchorClass.new(
		"kevin_anchor_d",
		Vector2(-9999, -9999),
		15.0,
		true,
		"absent_marketing",
		"Marketing Department"
	)

	quantum_component.register_anchor(anchor_a)
	quantum_component.register_anchor(anchor_b)
	quantum_component.register_anchor(anchor_c)
	quantum_component.register_anchor(anchor_d)

	quantum_component.set_initial_state("kevin_anchor_a")
	quantum_component.state_resolved.connect(_on_quantum_state_resolved)


func _on_quantum_state_resolved(anchor_id: String, anchor: QuantumStateAnchor) -> void:
	current_anchor_id = anchor_id
	if anchor.is_absent:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
		global_position = anchor.position_2d
		velocity = Vector2.ZERO


func _on_world_state_changed(_delta: Dictionary) -> void:
	_check_presence()


func _check_presence() -> void:
	var runtime = _get_game_runtime()
	if not runtime or not runtime.get("world_state"):
		return
	var state = runtime.world_state
	var is_present = (
		state.get_flag("kevin_present", true) == true and
		not state.get_flag("kevin_departed", false)
	)
	if not is_present:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
	elif quantum_component and quantum_component.current_anchor_id != "":
		var anchor = quantum_component.anchors.get(quantum_component.current_anchor_id)
		if anchor and anchor.is_absent:
			visible = false
			process_mode = Node.PROCESS_MODE_DISABLED
		else:
			visible = true
			process_mode = Node.PROCESS_MODE_INHERIT


func get_quantum_dialogue_override() -> Dictionary:
	# Dynamic dialogue variations based on Kevin's resolved anchor
	match current_anchor_id:
		"kevin_anchor_b":
			return {
				"read_aloud": "Kevin is leaning against the mop bucket with a warm thermos.",
				"remark": "\"I've been standing in facilities since 8:14. It has optimal brand synergies with janitorial silence.\""
			}
		"kevin_anchor_c":
			return {
				"read_aloud": "Kevin is lingering right at the threshold of the forgotten hallway.",
				"remark": "\"I'm scouting the hallway demographic. Very high potential for moist engagement.\""
			}
		"kevin_anchor_d":
			return {
				"read_aloud": "Kevin is nowhere to be found. Only a faint smell of burnt dark roast remains.",
				"remark": "\"Marketing.\""
			}
		_:
			return {
				"read_aloud": "Kevin is waiting by the coffee maker, staring fixedly at the drip tray.",
				"remark": "\"If we call it a 'Hydration Reliquary', we can optimize the Social Stun rate for key demographics.\""
			}


func _handle_interaction() -> void:
	if not visible:
		return
	var runtime = _get_game_runtime()
	if runtime and runtime.inventory_system and runtime.inventory_system.is_item_armed():
		runtime.use_armed_item_on(actor_id)
		return

	var dialogue_data = get_quantum_dialogue_override()
	var bus = _get_event_bus()
	if bus and bus.has_signal("action_requested"):
		bus.action_requested.emit({
			"type": "approach_and_interact_actor",
			"actor": self,
			"actor_id": actor_id,
			"scene_id": "scene.act1.coffee_counter",
			"approach_pos": get_approach_position(),
			"dialogue_override": dialogue_data
		})
