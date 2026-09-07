extends Node

# Headless Acceptance Test Suite for Native Hive-Lattice Game.
# Run with: godot --headless --path game_godot --script res://tests/run_acceptance.gd

const CampaignLoader = preload("res://scripts/campaign/CampaignLoader.gd")
const ActionResolver = preload("res://scripts/runtime/ActionResolver.gd")
const WorldState = preload("res://scripts/runtime/WorldState.gd")
const SaveSystem = preload("res://scripts/save/SaveSystem.gd")
const RoomBaseClass = preload("res://scripts/rooms/RoomBase.gd")
const ChalkCircleRouter = preload("res://scripts/runtime/ChalkCircleRouter.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _ready() -> void:
	print("\n============================================================")
	print("HIVE-LATTICE // NATIVE GODOT ACCEPTANCE SUITE")
	print("============================================================\n")

	_run_all_tests()

	print("\n============================================================")
	print("RESULTS: %d Total | %d Passed | %d Failed" % [total_tests, passed_tests, failed_tests])
	print("============================================================\n")

	if failed_tests == 0:
		print("[ALL NATIVE ACCEPTANCE TESTS PASSED]")
		get_tree().quit(0)
	else:
		push_error("[SOME NATIVE ACCEPTANCE TESTS FAILED]")
		get_tree().quit(1)


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
	test_kevin_presence_and_dialogue()
	test_multi_room_system()
	test_mobile_controls_and_readability()
	test_first_person_runtime()
	test_chalk_circle_bridge()


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
		"res://assets/props/table_back.png",
		"res://assets/props/table_surface.png",
		"res://assets/props/table_front_rim.png",
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
		"res://scenes/rooms/Hallway.tscn",
		"res://scenes/rooms/FridgeLabyrinth.tscn",
		"res://scenes/actors/Kevin.tscn",
		"res://assets/actors/kevin.png",
		"res://assets/portraits/kevin_neutral.png",
		"res://assets/rooms/hallway.png",
		"res://assets/rooms/fridge_labyrinth.png"
	]

	for path in required_files:
		assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Local asset exists: " + path)


func test_kevin_presence_and_dialogue() -> void:
	print("\n--- 9. Kevin Actor Presence & Dialogue Dispatch ---")
	var kevin_scene = load("res://scenes/actors/Kevin.tscn")
	assert_true(kevin_scene != null, "Kevin.tscn loads successfully")
	var kevin = kevin_scene.instantiate()
	assert_true(kevin is CharacterBody2D, "Kevin is a CharacterBody2D actor")
	assert_equal(kevin.actor_id, "npc.kevin_marketing", "Kevin actor_id is correct")
	assert_equal(kevin.display_name, "Kevin from Marketing", "Kevin display_name is correct")
	kevin.queue_free()


func test_multi_room_system() -> void:
	print("\n--- 10. Multi-Room Instantiation & Transitions ---")
	var breakroom_scene = load("res://scenes/rooms/Breakroom.tscn")
	var hallway_scene = load("res://scenes/rooms/Hallway.tscn")
	var fridge_scene = load("res://scenes/rooms/FridgeLabyrinth.tscn")

	assert_true(breakroom_scene != null, "Breakroom.tscn loads")
	assert_true(hallway_scene != null, "Hallway.tscn loads")
	assert_true(fridge_scene != null, "FridgeLabyrinth.tscn loads")

	var breakroom = breakroom_scene.instantiate()
	assert_true(breakroom != null, "Breakroom instantiates successfully")
	assert_true(breakroom.find_child("StaticBodies", true, false) != null, "Breakroom has StaticBodies")
	assert_true(breakroom.find_child("NavigationRegion2D", true, false) != null, "Breakroom has NavigationRegion2D")
	assert_true(breakroom.find_child("ExitHotspot", true, false) != null, "Breakroom has exit door to Hallway")
	breakroom.queue_free()

	var hallway = hallway_scene.instantiate()
	assert_true(hallway != null, "Hallway instantiates successfully")
	assert_true(hallway.find_child("DoorToBreakroom", true, false) != null, "Hallway has return door to Breakroom")
	assert_true(hallway.find_child("DoorToFridge", true, false) != null, "Hallway has door to Fridge")
	hallway.queue_free()

	var fridge = fridge_scene.instantiate()
	assert_true(fridge != null, "FridgeLabyrinth instantiates successfully")
	assert_true(fridge.find_child("DoorToHallway", true, false) != null, "FridgeLabyrinth has return door to Hallway")
	fridge.queue_free()


func test_mobile_controls_and_readability() -> void:
	print("\n--- 11. Mobile Controls, Virtual Stick & Touch Readability ---")
	# 1. VirtualStick and HUD tests
	var hud_scene = load("res://scenes/ui/HUD.tscn")
	assert_true(hud_scene != null, "HUD.tscn loads")
	var hud = hud_scene.instantiate()
	assert_true(hud != null, "HUD instantiates")
	var mobile_stick = hud.find_child("MobileStick", true, false)
	assert_true(mobile_stick != null, "HUD has MobileStick control")
	assert_true(mobile_stick.get_script() != null, "MobileStick has VirtualStick script attached")
	assert_true(mobile_stick.find_child("StickBase", true, false) != null, "MobileStick has StickBase")
	assert_true(mobile_stick.find_child("StickKnob", true, false) != null, "MobileStick has StickKnob")

	# Test topbar buttons sizing
	var topbar = hud.find_child("TopBar", true, false)
	assert_true(topbar.custom_minimum_size.y >= 48, "TopBar height is mobile touch friendly (>= 48px)")

	hud.queue_free()

	# 2. Split Table Depth & Darla Floor Positioning
	var breakroom_scene = load("res://scenes/rooms/Breakroom.tscn")
	var breakroom = breakroom_scene.instantiate()
	var table_back = breakroom.find_child("TableBack", true, false)
	var table_front = breakroom.find_child("TableFrontRim", true, false)
	var table_hotspot = breakroom.find_child("CentralTableHotspot", true, false)
	var darla = breakroom.find_child("Darla", true, false)

	assert_true(table_back != null, "Breakroom has TableBack node for depth YSorting")
	assert_true(table_front != null, "Breakroom has TableFrontRim node for depth YSorting")
	assert_true(table_hotspot != null, "Breakroom has CentralTableHotspot")
	assert_true(darla != null, "Breakroom has Darla actor")
	assert_true(darla.position.y > 420.0, "Darla is positioned cleanly on the walkable floor (y > 420)")

	breakroom.queue_free()

	# 3. Virtual move event handling in PlayerActor
	var player_scene = load("res://scenes/actors/Player.tscn")
	var player = player_scene.instantiate()
	assert_true(player != null, "Player instantiates")
	player._on_virtual_move_input(Vector2(0.8, -0.6))
	assert_equal(player.virtual_input_vector, Vector2(0.8, -0.6), "PlayerActor updates virtual_input_vector on stick input")
	player._on_virtual_move_input(Vector2.ZERO)
	assert_equal(player.virtual_input_vector, Vector2.ZERO, "PlayerActor resets virtual_input_vector on stick release")
	player.queue_free()

	# 4. Overlays Modal Sizing
	var overlays_scene = load("res://scenes/ui/Overlays.tscn")
	var overlays = overlays_scene.instantiate()
	var status_modal = overlays.find_child("StatusModal", true, false)
	assert_true(status_modal.custom_minimum_size.x >= 600, "StatusModal width is mobile friendly (>= 600px)")
	var status_close = status_modal.find_child("CloseButton", true, false)
	assert_true(status_close.custom_minimum_size.y >= 44, "Status close button height is touch friendly (>= 44px)")
	overlays.queue_free()


func test_first_person_runtime() -> void:
	print("\n--- 12. First-Person Runtime Baseline ---")
	var bootstrap_scene = load("res://scenes/bootstrap/FirstPersonBootstrap.tscn")
	var world_scene = load("res://scenes/fps/FirstPersonBreakroom.tscn")
	var hud_scene = load("res://scenes/fps/FirstPersonHUD.tscn")

	assert_true(bootstrap_scene != null, "FirstPersonBootstrap.tscn loads")
	assert_true(world_scene != null, "FirstPersonBreakroom.tscn loads")
	assert_true(hud_scene != null, "FirstPersonHUD.tscn loads")

	var bootstrap = bootstrap_scene.instantiate()
	assert_true(bootstrap != null, "First-person bootstrap instantiates")

	var player = bootstrap.find_child("Player", true, false)
	assert_true(player is CharacterBody3D, "First-person player is CharacterBody3D")
	assert_true(player.find_child("Camera3D", true, false) is Camera3D, "First-person player owns active Camera3D")
	assert_true(player.find_child("InteractionRay", true, false) is RayCast3D, "First-person player owns interaction ray")

	var wetberry = bootstrap.find_child("Wetberry", true, false)
	var keith = bootstrap.find_child("Keith", true, false)
	assert_true(wetberry != null and wetberry.has_method("interact"), "Wetberry is a physical first-person interactable")
	assert_true(keith != null and keith.has_method("interact"), "Keith is a physical first-person interactable")

	var fp_hud = bootstrap.find_child("FirstPersonHUD", true, false)
	assert_true(fp_hud != null, "First-person HUD is present")
	assert_true(fp_hud.find_child("DialoguePanel", true, false) != null, "First-person HUD has manually advanced dialogue panel")
	assert_true(fp_hud.find_child("PDAPanel", true, false) != null, "First-person HUD has PDA panel")
	assert_true(fp_hud.find_child("MobileStick", true, false) != null, "First-person HUD preserves mobile movement stick")
	assert_true(fp_hud.find_child("TouchLookZone", true, false) != null, "First-person HUD has mobile touch-look zone")
	assert_true(fp_hud.find_child("InteractButton", true, false) != null, "First-person HUD has mobile interact button")

	bootstrap.queue_free()


func test_chalk_circle_bridge() -> void:
	print("\n--- 13. Chalk Circle Pressure Spine ---")
	var loader = CampaignLoader.new()
	loader.load_all()
	var state = WorldState.new()
	state.init_from_campaign(loader.campaign)
	var router = ChalkCircleRouter.new()

	router.initialize(state)
	assert_equal(router.snapshot(state).get("layer"), 1, "Chalk Circle starts at THE GATE")

	router.observe_action(state, {"kind": "choice", "id": "inspect"}, {"result": "ok"})
	assert_equal(router.snapshot(state).get("layer"), 2, "First resolved action passes into ANTECHAMBER")

	router.observe_action(state, {"kind": "choice", "id": "inspect"}, {"result": "ok"})
	assert_equal(router.snapshot(state).get("layer"), 3, "Repeated action pattern reaches MIRROR HALL")

	state.stats["bureaucracy"] = 5
	state.stats["ape_chaos"] = 5
	router.observe_action(state, {"kind": "choice", "id": "file_form"}, {"result": "ok"})
	assert_equal(router.snapshot(state).get("layer"), 4, "Mixed high route pressure reaches PRESSURE CHAMBER")
	assert_true(
		router.snapshot(state).get("pressure_refresh_required", false),
		"Pressure chamber requests an explicit refresh before deeper authored use"
	)

	router.refresh_pressure(state)
	assert_true(
		ChalkCircleRouter.evaluate_requirement(state, {"layer_gte": 4, "pressure_refreshed": true}),
		"Chalk requirement hook can gate content without changing WorldState schema"
	)

	router.request_archive_focus(state, "acceptance_archive")
	assert_equal(router.snapshot(state).get("layer"), 5, "Explicit archive focus reaches ARCHIVE VAULT")
	assert_true(router.snapshot(state).get("archive", []).size() >= 4, "Chalk archive records hash-chained gameplay receipts")

	router.request_refusal(state, "acceptance_refusal")
	assert_equal(router.snapshot(state).get("layer"), 6, "Explicit refusal reaches THE REFUSAL")

	var save_payload = state.to_dict()
	var restored = WorldState.new()
	restored.from_dict(save_payload)
	router.initialize(restored)
	assert_equal(
		router.snapshot(restored).get("layer"),
		6,
		"Chalk state survives save-v3 WorldState round trip"
	)


func assert_false(condition: bool, test_name: String) -> void:
	assert_true(not condition, test_name)

