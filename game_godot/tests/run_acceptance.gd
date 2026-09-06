extends SceneTree

# Headless Acceptance Test Suite for Native Hive-Lattice Game.
# Run with: godot --headless --path game_godot --script res://tests/run_acceptance.gd

const CampaignLoader = preload("res://scripts/campaign/CampaignLoader.gd")
const ActionResolver = preload("res://scripts/runtime/ActionResolver.gd")
const WorldState = preload("res://scripts/runtime/WorldState.gd")
const SaveSystem = preload("res://scripts/save/SaveSystem.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n============================================================")
	print("HIVE-LATTICE // NATIVE GODOT ACCEPTANCE SUITE")
	print("============================================================\n")

	_run_all_tests()

	print("\n============================================================")
	print("RESULTS: %d Total | %d Passed | %d Failed" % [total_tests, passed_tests, failed_tests])
	print("============================================================\n")

	if failed_tests == 0:
		print("[ALL NATIVE ACCEPTANCE TESTS PASSED]")
		quit(0)
	else:
		push_error("[SOME NATIVE ACCEPTANCE TESTS FAILED]")
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


func _run_all_tests() -> void:
	test_campaign_loading()
	test_world_state_initialization()
	test_keith_evidence_bag_loop()
	test_darla_interaction()
	test_tammy_conditional_spawning()
	test_wetberry_containment_loop()
	test_save_load_persistence()
	test_scene_and_assets()


func test_campaign_loading() -> void:
	print("--- 1. Campaign Data & Manifest Loading ---")
	var loader = CampaignLoader.new()
	var ok = loader.load_all()
	assert_true(ok, "CampaignLoader loads without errors")
	assert_true(not loader.manifest.is_empty(), "Campaign manifest is loaded")
	assert_true(loader.locations.has("location.breakroom"), "Breakroom location exists in data")
	assert_true(loader.npcs.has("npc.keith_janitor"), "Keith exists in npcs.json")
	assert_true(loader.npcs.has("npc.darla_microwave"), "Darla exists in npcs.json")
	assert_true(loader.items.has("item.evidence_bag_not_my_business"), "Evidence Bag exists in items.json")
	assert_true(loader.items.has("item.bagged_wetberry_evidence"), "Bagged Wetberry exists in items.json")
	assert_true(loader.encounters.has("scene.act1.first_sighting"), "First sighting encounter exists")
	assert_true(loader.encounters.has("scene.act1.keith_corner"), "Keith corner encounter exists")
	assert_true(loader.encounters.has("scene.act1.coffee_counter"), "Coffee counter encounter exists")


func test_world_state_initialization() -> void:
	print("\n--- 2. WorldState Initialization ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)

	assert_equal(state.campaign_id, "strawberry_omen", "Campaign ID initialized correctly")
	assert_equal(state.current_scene, "scene.act1.first_sighting", "Entry scene is first sighting")
	assert_equal(state.turn_count, 0, "Initial turn count is 0")
	assert_true(state.room_memory() is Dictionary, "Room memory initialized")


func test_keith_evidence_bag_loop() -> void:
	print("\n--- 3. Keith Interaction & Evidence Bag Acquisition ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)
	var resolver = ActionResolver.new(loader)

	resolver.enter_scene(state, "scene.act1.keith_corner")
	assert_equal(state.current_scene, "scene.act1.keith_corner", "Entered Keith corner")

	var views = resolver.choice_views(state)
	var has_ask_bag = false
	for v in views:
		if v["id"] == "ask_for_evidence_bag" and v["available"]:
			has_ask_bag = true
	assert_true(has_ask_bag, "Option to ask Keith for Evidence Bag is available")

	var res = resolver.choose(state, "ask_for_evidence_bag")
	assert_true(state.has_item("item.evidence_bag_not_my_business"), "Acquired Evidence Bag in inventory")
	assert_equal(state.get_flag("keith_trust"), 1, "Keith trust flag incremented")
	assert_equal(state.npc_memory.get("npc.keith_janitor"), 2, "Keith NPC memory updated with overlay")


func test_darla_interaction() -> void:
	print("\n--- 4. Darla Interaction ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)
	var resolver = ActionResolver.new(loader)

	resolver.enter_scene(state, "scene.act1.coffee_counter")
	var res = resolver.choose(state, "ask_darla_about_wetberry")
	assert_true(state.get_flag("darla_hint_fridge", false), "Darla hint fridge flag set")
	assert_true(state.get_flag("fridge_unlocked", false), "Fridge unlocked flag set")
	assert_equal(state.npc_memory.get("npc.darla_microwave"), 2, "Darla NPC memory updated")


func test_tammy_conditional_spawning() -> void:
	print("\n--- 5. Tammy from HR Conditional Logic ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)
	var resolver = ActionResolver.new(loader)

	resolver.enter_scene(state, "scene.act1.first_sighting")
	assert_equal(state.get_flag("tammy_alerted", false), false, "Tammy not alerted initially")

	var res = resolver.choose(state, "call_hr")
	assert_equal(state.get_flag("tammy_alerted", false), true, "Tammy alerted flag set")
	assert_equal(state.get_flag("npc.tammy_hr_spawned", false), true, "Tammy spawned flag set")
	assert_equal(state.npc_memory.get("npc.tammy_hr"), 1, "Tammy NPC memory recorded")


func test_wetberry_containment_loop() -> void:
	print("\n--- 6. Complete Wetberry Containment Vector ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)
	var resolver = ActionResolver.new(loader)

	# 1. Talk to Keith and get evidence bag
	resolver.enter_scene(state, "scene.act1.keith_corner")
	resolver.choose(state, "ask_for_evidence_bag")
	assert_true(state.has_item("item.evidence_bag_not_my_business"), "Inventory has Evidence Bag")

	# 2. Return to first sighting with Wetberry
	resolver.enter_scene(state, "scene.act1.first_sighting")
	assert_equal(state.get_flag("wetberry_contained", false), false, "Wetberry not yet contained")

	# 3. Use Evidence Bag on Wetberry
	var res = resolver.use_item_on_target(state, "item.evidence_bag_not_my_business", "relic.wetberry")
	assert_equal(state.get_flag("wetberry_contained", false), true, "Wetberry is contained!")
	assert_false(state.has_item("item.evidence_bag_not_my_business"), "Empty Evidence Bag removed")
	assert_true(state.has_item("item.bagged_wetberry_evidence"), "Bagged Wetberry acquired")
	assert_equal(state.room_memory("location.breakroom.central_table").get("wetberry_status"), "contained", "Room memory updated with contained status")


func test_save_load_persistence() -> void:
	print("\n--- 7. Save & Load Parity ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)
	var resolver = ActionResolver.new(loader)
	var save_sys = SaveSystem.new()

	# Perform actions
	resolver.enter_scene(state, "scene.act1.keith_corner")
	resolver.choose(state, "ask_for_evidence_bag")
	resolver.enter_scene(state, "scene.act1.first_sighting")
	resolver.use_item_on_target(state, "item.evidence_bag_not_my_business", "relic.wetberry")

	# Save to test slot
	var save_ok = save_sys.save_game(state, "test_acceptance_slot")
	assert_true(save_ok, "Save file written to user://")

	# Create clean state and load
	var loaded_state = WorldState.new()
	var load_ok = save_sys.load_game(loaded_state, "test_acceptance_slot")
	assert_true(load_ok, "Save file loaded from user://")

	assert_equal(loaded_state.get_flag("wetberry_contained"), true, "Saved flag wetberry_contained restored")
	assert_true(loaded_state.has_item("item.bagged_wetberry_evidence"), "Saved item bagged_wetberry restored")
	assert_equal(loaded_state.turn_count, state.turn_count, "Saved turn count restored")

	# Clean up test save
	save_sys.delete_save("test_acceptance_slot")


func test_scene_and_assets() -> void:
	print("\n--- 8. Scene Nodes and Offline Assets Integrity ---")
	var required_files = [
		"res://scenes/bootstrap/Bootstrap.tscn",
		"res://scenes/rooms/Breakroom.tscn",
		"res://scenes/actors/Player.tscn",
		"res://scenes/actors/Keith.tscn",
		"res://scenes/actors/Darla.tscn",
		"res://scenes/actors/Tammy.tscn",
		"res://scenes/ui/DialogueBubble.tscn",
		"res://scenes/ui/InventoryDock.tscn",
		"res://scenes/ui/HUD.tscn",
		"res://scenes/ui/Overlays.tscn",
		"res://assets/rooms/breakroom.png",
		"res://assets/actors/player.png",
		"res://assets/actors/keith.png",
		"res://assets/actors/darla.png",
		"res://assets/actors/tammy.png",
		"res://assets/props/central_table.png",
		"res://assets/props/wetberry_idle.png",
		"res://assets/props/counter_appliances.png",
		"res://assets/props/mop_bucket.png",
		"res://assets/ui/dialogue_bubble_frame.png",
		"res://assets/ui/inventory_dock.png",
		"res://assets/audio/fluorescent_hum.wav",
		"res://assets/audio/ui_click.wav",
		"res://assets/audio/item_pickup.wav",
		"res://assets/audio/wetberry_pulse.wav",
		"res://assets/audio/footstep.wav",
	]

	for path in required_files:
		assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Local asset exists: " + path)


func assert_false(condition: bool, test_name: String) -> void:
	assert_true(not condition, test_name)
