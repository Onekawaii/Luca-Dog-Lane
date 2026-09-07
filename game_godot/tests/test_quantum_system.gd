extends SceneTree

# Dedicated Unit and Acceptance Test Suite for the Quantum Witness System.
# Run with: godot --headless --path game_godot --script res://tests/test_quantum_system.gd

const QuantumEntityScript = preload("res://scripts/quantum/QuantumEntity.gd")
const QuantumWitnessSystemScript = preload("res://scripts/quantum/QuantumWitnessSystem.gd")
const QuantumStateAnchorScript = preload("res://scripts/quantum/QuantumStateAnchor.gd")
const QuantumEntanglementScript = preload("res://scripts/quantum/QuantumEntanglement.gd")
const KevinActorScript = preload("res://scripts/actors/KevinActor.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n============================================================")
	print("HIVE-LATTICE // QUANTUM WITNESS SYSTEM TEST SUITE")
	print("============================================================\n")

	_run_all_quantum_tests()

	print("\n============================================================")
	print("RESULTS: %d Total | %d Passed | %d Failed" % [total_tests, passed_tests, failed_tests])
	print("============================================================\n")

	if failed_tests == 0:
		print("[ALL QUANTUM WITNESS TESTS PASSED]")
		quit(0)
	else:
		push_error("[SOME QUANTUM WITNESS TESTS FAILED]")
		quit(1)


func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] " + test_name)
	else:
		failed_tests += 1
		push_error("  [FAIL] " + test_name)


func assert_equal(actual: Variant, expected: Variant, test_name: String) -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print("  [PASS] " + test_name)
	else:
		failed_tests += 1
		push_error("  [FAIL] " + test_name + " (Expected: " + str(expected) + ", Got: " + str(actual) + ")")


func _run_all_quantum_tests() -> void:
	test_quantum_subsystem_load()
	test_multiple_valid_states_definition()
	test_observed_entity_does_not_transition()
	test_grace_period_prevents_premature_transition()
	test_sustained_unobserved_period_allows_transition()
	test_deterministic_state_resolution()
	test_resolution_never_selects_invalid_anchor()
	test_multiple_witnesses_pin_coherence()
	test_entanglement_coupling_proof()
	test_kevin_presence_and_dialogue_retention()
	test_pda_quantum_diagnostic_surface()


func test_quantum_subsystem_load() -> void:
	print("--- 1. Subsystem Loading ---")
	var q_entity: CharacterBody2D = QuantumEntityScript.new()
	var q_sys: Node = QuantumWitnessSystemScript.new()
	var q_anchor: RefCounted = QuantumStateAnchorScript.new("test_anchor", Vector2(100, 200))
	var q_entangle: Node = QuantumEntanglementScript.new()

	assert_true(q_entity != null, "QuantumEntityScript instantiates successfully")
	assert_true(q_sys != null, "QuantumWitnessSystemScript instantiates successfully")
	assert_true(q_anchor != null, "QuantumStateAnchorScript instantiates successfully")
	assert_true(q_entangle != null, "QuantumEntanglementScript instantiates successfully")

	q_entity.free()
	q_sys.free()
	q_entangle.free()


func test_multiple_valid_states_definition() -> void:
	print("\n--- 2. Defining Multiple Valid States ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	var anchor_a: RefCounted = QuantumStateAnchorScript.new("anchor_a", Vector2(100, 100), 45.0, false, "coffee", "Coffee Area")
	var anchor_b: RefCounted = QuantumStateAnchorScript.new("anchor_b", Vector2(200, 200), 40.0, false, "utility", "Utility Corner")
	var anchor_c: RefCounted = QuantumStateAnchorScript.new("anchor_c", Vector2(300, 300), 40.0, false, "doorway", "Doorway")
	var anchor_d: RefCounted = QuantumStateAnchorScript.new("anchor_d", Vector2.ZERO, 15.0, true, "absent", "Marketing")

	entity.call("register_anchor", anchor_a)
	entity.call("register_anchor", anchor_b)
	entity.call("register_anchor", anchor_c)
	entity.call("register_anchor", anchor_d)

	var anchors_dict = entity.get("anchors")
	assert_equal(anchors_dict.size(), 4, "Entity has exactly 4 registered anchors")
	assert_equal(anchors_dict["anchor_a"].position_2d, Vector2(100, 100), "Anchor A position matches")
	assert_true(anchors_dict["anchor_d"].is_absent, "Anchor D is marked absent")

	entity.free()


func test_observed_entity_does_not_transition() -> void:
	print("\n--- 3. Observed Entity Does Not Transition ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	var anchor_a: RefCounted = QuantumStateAnchorScript.new("anchor_a", Vector2(100, 100), 50.0)
	var anchor_b: RefCounted = QuantumStateAnchorScript.new("anchor_b", Vector2(200, 200), 50.0)
	entity.call("register_anchor", anchor_a)
	entity.call("register_anchor", anchor_b)
	entity.call("set_initial_state", "anchor_a")

	# Process 60 frames under active observation (1 witness)
	for i in range(60):
		entity.call("process_observation", 0.016, true, 1)

	assert_equal(entity.get("current_anchor_id"), "anchor_a", "Entity current anchor remains pinned under observation")
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.OBSERVED, "Entity is in OBSERVED state")
	assert_equal(entity.call("get_coherence_percentage"), 100, "Coherence is 100% when observed")

	entity.free()


func test_grace_period_prevents_premature_transition() -> void:
	print("\n--- 4. Grace Period Prevents Premature Transition ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	entity.set("grace_period", 0.75)
	var anchor_a: RefCounted = QuantumStateAnchorScript.new("anchor_a", Vector2(100, 100), 50.0)
	var anchor_b: RefCounted = QuantumStateAnchorScript.new("anchor_b", Vector2(200, 200), 50.0)
	entity.call("register_anchor", anchor_a)
	entity.call("register_anchor", anchor_b)
	entity.call("set_initial_state", "anchor_a")

	# Observed initially
	entity.call("process_observation", 0.016, true, 1)

	# Lose LOS for 0.3s (less than 0.75s grace period)
	entity.call("process_observation", 0.3, false, 0)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.LOS_LOST, "Entity enters LOS_LOST state")
	assert_true(entity.get("is_currently_observed"), "Entity is still treated as pinned during grace period")
	assert_equal(entity.get("pending_transition"), false, "Pending transition is false during grace period")

	# Regain LOS before grace period expires
	entity.call("process_observation", 0.016, true, 1)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.OBSERVED, "Entity returns to OBSERVED state")
	assert_equal(entity.get("current_anchor_id"), "anchor_a", "Entity stayed fixed at initial anchor")

	entity.free()


func test_sustained_unobserved_period_allows_transition() -> void:
	print("\n--- 5. Sustained Loss of Observation Allows Transition ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	entity.set("grace_period", 0.5)
	var anchor_a: RefCounted = QuantumStateAnchorScript.new("anchor_a", Vector2(100, 100), 50.0)
	var anchor_b: RefCounted = QuantumStateAnchorScript.new("anchor_b", Vector2(200, 200), 50.0)
	entity.call("register_anchor", anchor_a)
	entity.call("register_anchor", anchor_b)
	entity.call("set_initial_state", "anchor_a")

	# Observed initially
	entity.call("process_observation", 0.016, true, 1)

	# Sustain loss of LOS for 1.2s (> 0.5s grace period)
	entity.call("process_observation", 1.2, false, 0)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.UNOBSERVED, "Entity enters UNOBSERVED state")
	assert_true(entity.get("pending_transition"), "Pending transition is now true")
	assert_true(entity.get("unobserved_timer") >= 0.0, "Unobserved timer is active")

	entity.free()


func test_deterministic_state_resolution() -> void:
	print("\n--- 6. Re-observation Resolves a Valid Authored State ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	entity.set("grace_period", 0.5)
	entity.set("resolution_seed", 42)
	var anchor_a: RefCounted = QuantumStateAnchorScript.new("anchor_a", Vector2(100, 100), 45.0)
	var anchor_b: RefCounted = QuantumStateAnchorScript.new("anchor_b", Vector2(200, 200), 40.0)
	var anchor_c: RefCounted = QuantumStateAnchorScript.new("anchor_c", Vector2(300, 300), 15.0)
	entity.call("register_anchor", anchor_a)
	entity.call("register_anchor", anchor_b)
	entity.call("register_anchor", anchor_c)
	entity.call("set_initial_state", "anchor_a")

	# Sustained unobserved period
	entity.call("process_observation", 0.016, true, 1)
	entity.call("process_observation", 1.0, false, 0)

	# Re-observe
	entity.call("process_observation", 0.016, true, 1)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.REOBSERVED, "State is now REOBSERVED")
	var anchors_dict = entity.get("anchors")
	assert_true(anchors_dict.has(entity.get("current_anchor_id")), "Resolved anchor is one of the valid authored anchors")
	assert_equal(entity.get("pending_transition"), false, "Pending transition cleared on resolution")

	entity.free()


func test_resolution_never_selects_invalid_anchor() -> void:
	print("\n--- 7. Resolution Never Selects Invalid Anchor ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	entity.set("grace_period", 0.1)
	var valid_ids = ["safe_spot_1", "safe_spot_2", "safe_spot_3"]
	for id in valid_ids:
		entity.call("register_anchor", QuantumStateAnchorScript.new(id, Vector2(50, 50), 33.3))
	entity.call("set_initial_state", "safe_spot_1")

	for i in range(25):
		entity.call("process_observation", 0.5, false, 0)
		entity.call("process_observation", 0.016, true, 1)
		var curr_id = entity.get("current_anchor_id")
		assert_true(valid_ids.has(curr_id), "Run %d selected valid anchor: %s" % [i, curr_id])

	entity.free()


func test_multiple_witnesses_pin_coherence() -> void:
	print("\n--- 8. Multiple Witnesses Pin Coherence Until All Are Gone ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	entity.set("grace_period", 0.2)
	var a1: RefCounted = QuantumStateAnchorScript.new("a1", Vector2(100, 100))
	var a2: RefCounted = QuantumStateAnchorScript.new("a2", Vector2(200, 200))
	entity.call("register_anchor", a1)
	entity.call("register_anchor", a2)
	entity.call("set_initial_state", "a1")

	# Observed by 2 witnesses (e.g. Player + Security Cam)
	entity.call("process_observation", 0.016, true, 2)
	assert_equal(entity.get("active_witness_count"), 2, "2 active witnesses")

	# 1 witness looks away, 1 remains
	entity.call("process_observation", 0.5, true, 1)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.OBSERVED, "Still observed with 1 witness")
	assert_equal(entity.get("current_anchor_id"), "a1", "State stays pinned")

	# Final witness looks away
	entity.call("process_observation", 0.5, false, 0)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.UNOBSERVED, "Unobserved once all witnesses lose LOS")

	entity.free()


func test_entanglement_coupling_proof() -> void:
	print("\n--- 9. Entanglement Coupling Proof (Kevin <-> Coffee Machine) ---")
	var kevin: CharacterBody2D = QuantumEntityScript.new()
	kevin.set("entity_id", "kevin")
	var a_coffee: RefCounted = QuantumStateAnchorScript.new("kevin_anchor_a", Vector2(330, 430))
	var a_utility: RefCounted = QuantumStateAnchorScript.new("kevin_anchor_b", Vector2(920, 520))
	var a_absent: RefCounted = QuantumStateAnchorScript.new("kevin_anchor_d", Vector2.ZERO, 1.0, true)
	kevin.call("register_anchor", a_coffee)
	kevin.call("register_anchor", a_utility)
	kevin.call("register_anchor", a_absent)
	kevin.call("set_initial_state", "kevin_anchor_a")

	var coffee_prop: Node = Node.new()
	var correlations = {
		"kevin_anchor_a": "normal",
		"kevin_anchor_b": "leaking",
		"kevin_anchor_d": "anomalous"
	}

	var entanglement: Node = QuantumEntanglementScript.new()
	entanglement.call("setup_link", kevin, coffee_prop, correlations)

	assert_equal(entanglement.get("current_target_state"), "normal", "Coffee machine is normal when Kevin is at coffee area")

	entanglement.call("apply_correlation", "kevin_anchor_b")
	assert_equal(entanglement.get("current_target_state"), "leaking", "Coffee machine is leaking when Kevin is at utility corner")

	entanglement.call("apply_correlation", "kevin_anchor_d")
	assert_equal(entanglement.get("current_target_state"), "anomalous", "Coffee machine is anomalous when Kevin is absent")

	kevin.free()
	coffee_prop.free()
	entanglement.free()


func test_kevin_presence_and_dialogue_retention() -> void:
	print("\n--- 10. Kevin Actor Presence & Dialogue Retention ---")
	var kevin: CharacterBody2D = KevinActorScript.new()
	assert_true(kevin != null, "KevinActor instantiates")
	assert_equal(kevin.get("actor_id"), "npc.kevin_marketing", "Kevin actor_id is correct")
	assert_true(kevin.get("quantum_component") != null, "Kevin has QuantumComponent attached")

	var diag_a = kevin.call("get_quantum_dialogue_override")
	assert_true(diag_a.has("read_aloud"), "Has read_aloud dialogue override")
	assert_true(diag_a.has("remark"), "Has remark dialogue override")

	kevin.free()


func test_pda_quantum_diagnostic_surface() -> void:
	print("\n--- 11. PDA Quantum Diagnostic Surface ---")
	var entity: CharacterBody2D = QuantumEntityScript.new()
	entity.set("entity_name", "Kevin (Marketing)")
	entity.set("entity_id", "kevin_marketing")
	var a1: RefCounted = QuantumStateAnchorScript.new("kevin_anchor_a", Vector2(330, 430), 1.0, false, "coffee", "Breakroom Coffee Area")
	entity.call("register_anchor", a1)
	entity.call("set_initial_state", "kevin_anchor_a")
	entity.call("process_observation", 0.016, true, 1)

	var summary: Dictionary = entity.call("get_status_summary")
	assert_equal(summary["entity_name"], "Kevin (Marketing)", "Summary entity name matches")
	assert_equal(summary["observed"], true, "Summary observed status is true")
	assert_equal(summary["coherence_pct"], 100, "Summary coherence percentage is 100%")
	assert_equal(summary["last_confirmed_location"], "Breakroom Coffee Area", "Summary last confirmed location matches")

	entity.free()
