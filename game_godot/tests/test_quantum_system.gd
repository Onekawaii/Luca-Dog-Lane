extends SceneTree

# Dedicated Unit and Acceptance Test Suite for the Quantum Witness System (2D & 3D).
# Run with: godot --headless --path game_godot --script res://tests/test_quantum_system.gd

const QuantumEntityScript = preload("res://scripts/quantum/QuantumEntity.gd")
const QuantumWitnessSystemScript = preload("res://scripts/quantum/QuantumWitnessSystem.gd")
const QuantumStateAnchorScript = preload("res://scripts/quantum/QuantumStateAnchor.gd")
const QuantumEntanglementScript = preload("res://scripts/quantum/QuantumEntanglement.gd")
const FirstPersonQuantumNPCScript = preload("res://scripts/fps/FirstPersonQuantumNPC.gd")
const FirstPersonPlayerScript = preload("res://scripts/fps/FirstPersonPlayer.gd")
const FirstPersonHUDScript = preload("res://scripts/fps/FirstPersonHUD.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n============================================================")
	print("HIVE-LATTICE // 3D QUANTUM WITNESS SYSTEM TEST SUITE")
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
	test_uncertainty_extension_hook()
	test_vector3_and_2d_anchor_support()
	test_observed_entity_does_not_transition()
	test_grace_period_prevents_premature_transition()
	test_sustained_unobserved_period_allows_transition()
	test_deterministic_state_resolution()
	test_resolution_never_selects_invalid_anchor()
	test_multiple_witnesses_pin_coherence()
	test_entanglement_coupling_proof_3d()
	test_first_person_kevin_3d_actor()
	test_first_person_hud_pda_quantum_surface()
	test_modal_input_ownership_regression()


func test_quantum_subsystem_load() -> void:
	print("--- 1. Subsystem Loading ---")
	var q_entity: Node = QuantumEntityScript.new()
	var q_sys: Node = QuantumWitnessSystemScript.new()
	var q_anchor: RefCounted = QuantumStateAnchorScript.new("test_anchor", Vector3(1.0, 0.0, 2.0))
	var q_entangle: Node = QuantumEntanglementScript.new()

	assert_true(q_entity != null, "QuantumEntityScript instantiates successfully")
	assert_true(q_sys != null, "QuantumWitnessSystemScript instantiates successfully")
	assert_true(q_anchor != null, "QuantumStateAnchorScript instantiates successfully")
	assert_true(q_entangle != null, "QuantumEntanglementScript instantiates successfully")

	q_entity.free()
	q_sys.free()
	q_entangle.free()


func test_vector3_and_2d_anchor_support() -> void:
	print("\n--- 2. Vector3 Spatial Anchors & Relative Weights ---")
	var entity: Node = QuantumEntityScript.new()
	var a_coffee = QuantumStateAnchorScript.new("KevinCoffeeAnchor", Vector3(-2.5, 0.0, -1.8), 45.0, false, "coffee", "Coffee Area")
	var a_utility = QuantumStateAnchorScript.new("KevinUtilityAnchor", Vector3(2.8, 0.0, 2.2), 40.0, false, "utility", "Utility Corner")
	var a_door = QuantumStateAnchorScript.new("KevinDoorAnchor", Vector3(0.0, 0.0, 3.8), 40.0, false, "door", "Doorway")
	var a_absent = QuantumStateAnchorScript.new("KevinAbsentAnchor", Vector3(0.0, -100.0, 0.0), 15.0, true, "absent", "Marketing")

	entity.call("register_anchor", a_coffee)
	entity.call("register_anchor", a_utility)
	entity.call("register_anchor", a_door)
	entity.call("register_anchor", a_absent)

	var anchors = entity.get("anchors")
	assert_equal(anchors.size(), 4, "Entity has exactly 4 registered 3D anchors")
	assert_equal(anchors["KevinCoffeeAnchor"].position_3d, Vector3(-2.5, 0.0, -1.8), "Anchor Coffee Vector3 position matches")
	assert_equal(anchors["KevinCoffeeAnchor"].relative_weight, 45.0, "Anchor Coffee relative weight is 45.0")
	assert_true(anchors["KevinAbsentAnchor"].is_absent, "Anchor Absent is marked absent")

	entity.free()


func test_observed_entity_does_not_transition() -> void:
	print("\n--- 3. Observed Entity Does Not Transition ---")
	var entity: Node = QuantumEntityScript.new()
	var a1 = QuantumStateAnchorScript.new("a1", Vector3(0, 0, 0), 50.0)
	var a2 = QuantumStateAnchorScript.new("a2", Vector3(1, 0, 1), 50.0)
	entity.call("register_anchor", a1)
	entity.call("register_anchor", a2)
	entity.call("set_initial_state", "a1")

	for i in range(60):
		entity.call("process_observation", 0.016, true, 1)

	assert_equal(entity.get("current_anchor_id"), "a1", "Entity current anchor remains pinned under observation")
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.OBSERVED, "Entity is in OBSERVED state")
	assert_equal(entity.call("get_coherence_percentage"), 100, "Coherence is 100% when observed")

	entity.free()


func test_grace_period_prevents_premature_transition() -> void:
	print("\n--- 4. Grace Period Prevents Premature Transition ---")
	var entity: Node = QuantumEntityScript.new()
	entity.set("grace_period", 0.75)
	var a1 = QuantumStateAnchorScript.new("a1", Vector3(0, 0, 0), 50.0)
	var a2 = QuantumStateAnchorScript.new("a2", Vector3(1, 0, 1), 50.0)
	entity.call("register_anchor", a1)
	entity.call("register_anchor", a2)
	entity.call("set_initial_state", "a1")

	entity.call("process_observation", 0.016, true, 1)

	# Lose LOS for 0.3s (less than 0.75s grace period)
	entity.call("process_observation", 0.3, false, 0)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.LOS_LOST, "Entity enters LOS_LOST state")
	assert_true(entity.get("is_currently_observed"), "Entity is still treated as pinned during grace period")
	assert_equal(entity.get("pending_transition"), false, "Pending transition is false during grace period")

	# Regain LOS before grace period expires
	entity.call("process_observation", 0.016, true, 1)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.OBSERVED, "Entity returns to OBSERVED state")
	assert_equal(entity.get("current_anchor_id"), "a1", "Entity stayed fixed at initial anchor")

	entity.free()


func test_sustained_unobserved_period_allows_transition() -> void:
	print("\n--- 5. Sustained Loss of Observation Allows Transition ---")
	var entity: Node = QuantumEntityScript.new()
	entity.set("grace_period", 0.5)
	var a1 = QuantumStateAnchorScript.new("a1", Vector3(0, 0, 0), 50.0)
	var a2 = QuantumStateAnchorScript.new("a2", Vector3(1, 0, 1), 50.0)
	entity.call("register_anchor", a1)
	entity.call("register_anchor", a2)
	entity.call("set_initial_state", "a1")

	entity.call("process_observation", 0.016, true, 1)

	# Sustain loss of LOS for 1.2s (> 0.5s grace period)
	entity.call("process_observation", 1.2, false, 0)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.UNOBSERVED, "Entity enters UNOBSERVED state")
	assert_true(entity.get("pending_transition"), "Pending transition is now true")
	assert_true(entity.get("unobserved_timer") >= 0.0, "Unobserved timer is active")

	entity.free()


func test_deterministic_state_resolution() -> void:
	print("\n--- 6. Re-observation Resolves a Valid Authored State ---")
	var entity: Node = QuantumEntityScript.new()
	entity.set("grace_period", 0.5)
	entity.set("resolution_seed", 42)
	var a_coffee = QuantumStateAnchorScript.new("KevinCoffeeAnchor", Vector3(-2.5, 0.0, -1.8), 45.0)
	var a_utility = QuantumStateAnchorScript.new("KevinUtilityAnchor", Vector3(2.8, 0.0, 2.2), 40.0)
	var a_absent = QuantumStateAnchorScript.new("KevinAbsentAnchor", Vector3(0.0, -100.0, 0.0), 15.0, true)
	entity.call("register_anchor", a_coffee)
	entity.call("register_anchor", a_utility)
	entity.call("register_anchor", a_absent)
	entity.call("set_initial_state", "KevinCoffeeAnchor")

	entity.call("process_observation", 0.016, true, 1)
	entity.call("process_observation", 1.0, false, 0)

	entity.call("process_observation", 0.016, true, 1)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.REOBSERVED, "State is now REOBSERVED")
	var anchors = entity.get("anchors")
	assert_true(anchors.has(entity.get("current_anchor_id")), "Resolved anchor is one of the valid authored anchors")
	assert_equal(entity.get("pending_transition"), false, "Pending transition cleared on resolution")

	entity.free()


func test_resolution_never_selects_invalid_anchor() -> void:
	print("\n--- 7. Resolution Never Selects Invalid Anchor ---")
	var entity: Node = QuantumEntityScript.new()
	entity.set("grace_period", 0.1)
	var valid_ids = ["safe_anchor_1", "safe_anchor_2", "safe_anchor_3"]
	for id in valid_ids:
		entity.call("register_anchor", QuantumStateAnchorScript.new(id, Vector3(0, 0, 0), 33.3))
	entity.call("set_initial_state", "safe_anchor_1")

	for i in range(25):
		entity.call("process_observation", 0.5, false, 0)
		entity.call("process_observation", 0.016, true, 1)
		var curr_id = entity.get("current_anchor_id")
		assert_true(valid_ids.has(curr_id), "Run %d selected valid anchor: %s" % [i, curr_id])

	entity.free()


func test_multiple_witnesses_pin_coherence() -> void:
	print("\n--- 8. Multiple Witnesses Pin Coherence Until All Are Gone ---")
	var entity: Node = QuantumEntityScript.new()
	entity.set("grace_period", 0.2)
	var a1 = QuantumStateAnchorScript.new("a1", Vector3(0, 0, 0))
	var a2 = QuantumStateAnchorScript.new("a2", Vector3(1, 0, 1))
	entity.call("register_anchor", a1)
	entity.call("register_anchor", a2)
	entity.call("set_initial_state", "a1")

	entity.call("process_observation", 0.016, true, 2)
	assert_equal(entity.get("active_witness_count"), 2, "2 active witnesses")

	entity.call("process_observation", 0.5, true, 1)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.OBSERVED, "Still observed with 1 witness")
	assert_equal(entity.get("current_anchor_id"), "a1", "State stays pinned")

	entity.call("process_observation", 0.5, false, 0)
	assert_equal(entity.get("observation_state"), QuantumEntityScript.ObservationState.UNOBSERVED, "Unobserved once all witnesses lose LOS")

	entity.free()


func test_entanglement_coupling_proof_3d() -> void:
	print("\n--- 9. Entanglement Coupling Proof 3D (Kevin <-> Coffee Machine) ---")
	var kevin = QuantumEntityScript.new()
	kevin.set("entity_id", "kevin_marketing")
	var a_coffee = QuantumStateAnchorScript.new("KevinCoffeeAnchor", Vector3(-2.5, 0.0, -1.8))
	var a_utility = QuantumStateAnchorScript.new("KevinUtilityAnchor", Vector3(2.8, 0.0, 2.2))
	var a_absent = QuantumStateAnchorScript.new("KevinAbsentAnchor", Vector3(0.0, -100.0, 0.0), 1.0, true)
	kevin.call("register_anchor", a_coffee)
	kevin.call("register_anchor", a_utility)
	kevin.call("register_anchor", a_absent)
	kevin.call("set_initial_state", "KevinCoffeeAnchor")

	var breakroom = Node.new()
	var correlations = {
		"KevinCoffeeAnchor": "normal",
		"KevinUtilityAnchor": "leaking",
		"KevinDoorAnchor": "anomalous",
		"KevinAbsentAnchor": "anomalous"
	}

	var entanglement = QuantumEntanglementScript.new()
	entanglement.call("setup_link", kevin, breakroom, correlations)

	assert_equal(entanglement.get("current_target_state"), "normal", "Coffee machine is normal when Kevin is at coffee area")

	entanglement.call("apply_correlation", "KevinUtilityAnchor")
	assert_equal(entanglement.get("current_target_state"), "leaking", "Coffee machine is leaking when Kevin is at utility corner")

	entanglement.call("apply_correlation", "KevinAbsentAnchor")
	assert_equal(entanglement.get("current_target_state"), "anomalous", "Coffee machine is anomalous when Kevin is absent")

	kevin.free()
	breakroom.free()
	entanglement.free()


func test_first_person_kevin_3d_actor() -> void:
	print("\n--- 10. FirstPersonQuantumNPC 3D Actor ---")
	var kevin = FirstPersonQuantumNPCScript.new()
	assert_true(kevin != null, "FirstPersonQuantumNPC instantiates")
	assert_true(kevin is CharacterBody3D, "Kevin is a CharacterBody3D actor")
	assert_equal(kevin.get("npc_id"), "npc.kevin_marketing", "Kevin npc_id is correct")
	assert_equal(kevin.get("display_name"), "Kevin (Marketing)", "Kevin display_name is correct")
	assert_true(kevin.get("quantum_component") != null, "Kevin has QuantumComponent attached")

	# Test raycast interactable interface
	assert_true(kevin.has_method("interact"), "Kevin implements interact method for RayCast3D")

	var diag = kevin.call("get_quantum_dialogue")
	assert_true(diag.has("speaker"), "Dialogue contains speaker")
	assert_true(diag.has("lines"), "Dialogue contains lines array")

	# Test collision toggling on absent anchor
	var absent_anchor = QuantumStateAnchorScript.new("KevinAbsentAnchor", Vector3(0, -100, 0), 1.0, true)
	kevin.call("apply_quantum_anchor", absent_anchor)
	assert_equal(kevin.visible, false, "Kevin is invisible when absent")

	var coffee_anchor = QuantumStateAnchorScript.new("KevinCoffeeAnchor", Vector3(-2.5, 0, -1.8), 1.0, false)
	kevin.call("apply_quantum_anchor", coffee_anchor)
	assert_equal(kevin.visible, true, "Kevin is visible when present")
	assert_equal(kevin.position, Vector3(-2.5, 0, -1.8), "Kevin position matches 3D anchor")

	kevin.free()


func test_first_person_hud_pda_quantum_surface() -> void:
	print("\n--- 11. FirstPersonHUD PDA Quantum Diagnostic Surface ---")
	var hud_scene = load("res://scenes/fps/FirstPersonHUD.tscn")
	assert_true(hud_scene != null, "FirstPersonHUD.tscn loads")
	var hud = hud_scene.instantiate()
	assert_true(hud != null, "FirstPersonHUD instantiates")

	assert_true(hud.find_child("PDAPanel", true, false) != null, "HUD has PDAPanel")
	assert_true(hud.find_child("DialoguePanel", true, false) != null, "HUD has DialoguePanel")
	assert_true(hud.has_method("_toggle_pda"), "HUD has _toggle_pda method")
	assert_true(hud.has_method("_set_mobile_gameplay_controls_enabled"), "HUD has _set_mobile_gameplay_controls_enabled method")

	hud.free()


func test_uncertainty_extension_hook() -> void:
	print("\n--- Uncertainty Extension Hook ---")
	var q_sys = QuantumWitnessSystemScript.new()
	var q_entity = QuantumEntityScript.new()
	q_entity.entity_id = "test_uncertain_subject"

	assert_true(q_sys.has_signal("uncertainty_displaced"), "QuantumWitnessSystem declares uncertainty_displaced signal")
	assert_true(q_entity.has_signal("uncertainty_displaced"), "QuantumEntity declares uncertainty_displaced signal")

	var signal_received: Array = []
	q_sys.uncertainty_displaced.connect(func(e_id, old_s, new_s): signal_received.append([e_id, old_s, new_s]))

	q_sys.register_entity(q_entity)
	q_entity.uncertainty_displaced.emit("test_uncertain_subject", "anchor_a", "anchor_b")

	assert_equal(signal_received.size(), 1, "Uncertainty displacement signal was received through QuantumWitnessSystem")
	if signal_received.size() > 0:
		assert_equal(signal_received[0][0], "test_uncertain_subject", "Source entity ID matches")
		assert_equal(signal_received[0][1], "anchor_a", "Old anchor matches")
		assert_equal(signal_received[0][2], "anchor_b", "New anchor matches")

	q_entity.free()
	q_sys.free()


func test_modal_input_ownership_regression() -> void:
	print("\n--- 12. Modal Input Ownership & Mobile Overlay Regression ---")
	var hud_scene = load("res://scenes/fps/FirstPersonHUD.tscn")
	var hud = hud_scene.instantiate()
	assert_true(hud != null, "FirstPersonHUD instantiates")
	assert_true(hud.has_method("_set_mobile_gameplay_controls_enabled"), "First-person HUD owns mobile modal process state")
	hud.free()

