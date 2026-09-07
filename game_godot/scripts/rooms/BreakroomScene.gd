class_name BreakroomScene
extends RoomBase

# Breakroom Scene Controller with Quantum Witness System & Entanglement Proof.

const QuantumWitnessSystemClass = preload("res://scripts/quantum/QuantumWitnessSystem.gd")
const QuantumEntanglementClass = preload("res://scripts/quantum/QuantumEntanglement.gd")

@onready var keith: KeithActor = $YSortContainer/Keith
@onready var darla: DarlaActor = $YSortContainer/Darla
@onready var tammy: TammyActor = $YSortContainer/Tammy
@onready var kevin: KevinActor = $YSortContainer/Kevin
@onready var wetberry_prop: Sprite2D = $YSortContainer/CentralTableHotspot/WetberrySprite
@onready var coffee_counter_hotspot: Hotspot = $YSortContainer/CoffeeCounterHotspot
@onready var appliances_sprite: Sprite2D = $YSortContainer/CoffeeCounterHotspot/AppliancesSprite

var witness_system: QuantumWitnessSystem = null
var entanglement_link: QuantumEntanglement = null
var coffee_machine_state: String = "normal"


func _ready() -> void:
	room_id = "breakroom"
	location_id = "location.breakroom"
	super._ready()

	_init_quantum_breakroom()


func _get_runtime() -> Node:
	if has_node("/root/GameRuntime"):
		return get_node("/root/GameRuntime")
	return null


func _init_quantum_breakroom() -> void:
	# 1. Initialize local QuantumWitnessSystem
	witness_system = QuantumWitnessSystemClass.new()
	witness_system.name = "QuantumWitnessSystem"
	add_child(witness_system)

	# Register player as primary witness
	if player:
		witness_system.register_witness("player_primary", player, 1200.0, 360.0, "player")
	if camera:
		witness_system.register_witness("camera_primary", camera, 1200.0, 360.0, "camera")

	# Register Kevin's quantum component
	if kevin and kevin.quantum_component:
		witness_system.register_entity(kevin.quantum_component)

		# 2. Setup Entanglement Proof: Kevin <-> Coffee Machine
		entanglement_link = QuantumEntanglementClass.new()
		entanglement_link.name = "KevinCoffeeEntanglement"
		add_child(entanglement_link)

		var correlations = {
			"kevin_anchor_a": "normal",
			"kevin_anchor_b": "leaking",
			"kevin_anchor_c": "anomalous",
			"kevin_anchor_d": "anomalous"
		}
		entanglement_link.setup_link(kevin.quantum_component, self, correlations)


func set_entangled_state(state_name: String) -> void:
	coffee_machine_state = state_name
	_update_coffee_machine_visuals()


func _update_coffee_machine_visuals() -> void:
	if not appliances_sprite:
		return

	match coffee_machine_state:
		"leaking":
			# Tint slightly humid/amber indicating a leaking gasket
			appliances_sprite.modulate = Color(1.3, 1.1, 0.8, 1.0)
			if coffee_counter_hotspot:
				coffee_counter_hotspot.display_name = "Coffee Counter (Dripping Gasket)"
		"anomalous":
			# Tint quantum violet/cyan indicating anomalous displacement
			appliances_sprite.modulate = Color(0.8, 1.2, 1.4, 1.0)
			if coffee_counter_hotspot:
				coffee_counter_hotspot.display_name = "Coffee Counter (Hissing Blue Steam)"
		_:
			# Normal state
			appliances_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if coffee_counter_hotspot:
				coffee_counter_hotspot.display_name = "Coffee Counter & Microwave"


func _update_room_visuals() -> void:
	var runtime = _get_runtime()
	if runtime and runtime.get("world_state"):
		var state = runtime.world_state
		var is_contained = state.get_flag("wetberry_contained", false) == true or state.room_memory().get("wetberry_status") == "contained"
		if wetberry_prop:
			wetberry_prop.visible = not is_contained
	_update_coffee_machine_visuals()


func _draw() -> void:
	var runtime = _get_runtime()
	if runtime and runtime.get("debug_mode") and is_instance_valid(witness_system) and is_instance_valid(kevin):
		_draw_quantum_debug()


func _draw_quantum_debug() -> void:
	var q = kevin.quantum_component
	if not q:
		return

	var summary = q.get_status_summary()
	var pos = Vector2(40, 120)
	var line_h = 22.0

	var debug_lines = [
		"=== QUANTUM WITNESS DIAGNOSTIC ===",
		"Subject: %s (%s)" % [summary["entity_name"], summary["entity_id"]],
		"Observed: %s | Active Witnesses: %d" % ["YES" if summary["observed"] else "NO", summary["witness_count"]],
		"Current Anchor: %s" % [summary["current_anchor"]],
		"Last Confirmed: %s (%s)" % [summary["last_confirmed_location"], summary["last_confirmed_anchor"]],
		"Coherence: %d%% | Unobserved Time: %.2fs" % [summary["coherence_pct"], summary["unobserved_time"]],
		"Pending Transition: %s" % ["YES" if summary["pending_transition"] else "NO"],
		"Coffee Machine Entangled: %s" % [coffee_machine_state.to_upper()]
	]

	for i in range(debug_lines.size()):
		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(0, i * line_h),
			debug_lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color(0.2, 1.0, 0.4, 0.95)
		)
