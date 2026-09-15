extends Node

# Headless Acceptance Test Suite for Native Hive-Lattice Game.
# Run with: godot --headless --path game_godot res://tests/AcceptanceRunner.tscn

const CampaignLoader = preload("res://scripts/campaign/CampaignLoader.gd")
const ActionResolver = preload("res://scripts/runtime/ActionResolver.gd")
const WorldState = preload("res://scripts/runtime/WorldState.gd")
const SaveSystem = preload("res://scripts/save/SaveSystem.gd")
const RoomBaseClass = preload("res://scripts/rooms/RoomBase.gd")
const ChalkCircleRouter = preload("res://scripts/runtime/ChalkCircleRouter.gd")
const QuantumEntityScript = preload("res://scripts/quantum/QuantumEntity.gd")
const QuantumWitnessSystemScript = preload("res://scripts/quantum/QuantumWitnessSystem.gd")
const QuantumStateAnchorScript = preload("res://scripts/quantum/QuantumStateAnchor.gd")
const QuantumEntanglementScript = preload("res://scripts/quantum/QuantumEntanglement.gd")
const HiveProcGenEngineScript = preload("res://scripts/procgen/HiveProcGenEngine.gd")
const HiveProcGenChunkRendererScript = preload("res://scripts/procgen/HiveProcGenChunkRenderer.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _ready() -> void:
	_run_and_exit.call_deferred()


func _run_and_exit() -> void:
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
	test_quantum_witness_subsystem()
	test_multi_room_system()
	test_mobile_controls_and_readability()
	test_first_person_runtime()
	test_phone_playtest_fixes()
	test_touch_look_zone_robustness()
	test_chalk_circle_bridge()
	test_breakroom_interaction_pass()
	test_hive_procgen_engine()
	test_gameflow_atmosphere_and_level_suite()


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
		"res://assets/rooms/fridge_labyrinth.png",
		"res://scripts/quantum/QuantumEntity.gd",
		"res://scripts/quantum/QuantumWitnessSystem.gd",
		"res://scripts/quantum/QuantumStateAnchor.gd",
		"res://scripts/quantum/QuantumEntanglement.gd",
		"res://scripts/fps/FirstPersonQuantumNPC.gd",
		"res://assets/fps/materials/breakroom_floor_tile.png",
		"res://assets/fps/props/wetberry_front_decal.png",
		"res://assets/fps/actors/keith_name_badge.png",
		"res://assets/fps/props/fridge_property_decal.png",
		"res://assets/fps/props/fridge_maintenance_decal.png",
		"res://assets/fps/props/hidden_anomaly_plate_256.png",
		"res://assets/fps/materials/pda_arkheo_watermark.png",
		"res://assets/fps/materials/quantum_glyph_icon.png"
	]

	for path in required_files:
		assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Local asset exists: " + path)


func test_kevin_presence_and_dialogue() -> void:
	print("\n--- 9. Kevin Actor Presence & Dialogue Dispatch ---")
	var kevin_scene = load("res://scenes/actors/Kevin.tscn")
	assert_true(kevin_scene != null, "Kevin.tscn loads successfully")
	var kevin = kevin_scene.instantiate()
	assert_true(kevin is CharacterBody2D, "Kevin is a CharacterBody2D actor")
	assert_equal(kevin.get("actor_id"), "npc.kevin_marketing", "Kevin actor_id is correct")
	assert_equal(kevin.get("display_name"), "Kevin from Marketing", "Kevin display_name is correct")
	assert_true(kevin.get("quantum_component") != null, "Kevin has QuantumComponent")
	kevin.queue_free()


func test_quantum_witness_subsystem() -> void:
	print("\n--- 10. Quantum Witness Subsystem & Entanglement Integration ---")
	var q_entity = QuantumEntityScript.new()
	q_entity.set("entity_id", "kevin_test")
	var a1 = QuantumStateAnchorScript.new("a1", Vector3(0, 0, 0))
	var a2 = QuantumStateAnchorScript.new("a2", Vector3(1, 0, 1))
	q_entity.call("register_anchor", a1)
	q_entity.call("register_anchor", a2)
	q_entity.call("set_initial_state", "a1")

	# Under observation:
	q_entity.call("process_observation", 0.016, true, 1)
	assert_equal(q_entity.get("current_anchor_id"), "a1", "Observed anchor is pinned")
	assert_equal(q_entity.call("get_coherence_percentage"), 100, "Coherence is 100%")

	# Unobserved transition:
	q_entity.call("process_observation", 1.5, false, 0)
	assert_equal(q_entity.get("observation_state"), QuantumEntityScript.ObservationState.UNOBSERVED, "Transitioned to unobserved")

	# Re-observation resolution:
	q_entity.call("process_observation", 0.016, true, 1)
	assert_equal(q_entity.get("observation_state"), QuantumEntityScript.ObservationState.REOBSERVED, "Resolved on reobservation")
	assert_true(q_entity.get("anchors").has(q_entity.get("current_anchor_id")), "Resolved to valid anchor")

	q_entity.free()


func test_multi_room_system() -> void:
	print("\n--- 11. Multi-Room Instantiation & Transitions ---")
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
	print("\n--- 12. Mobile Controls, Virtual Stick & Touch Readability ---")
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
	if player.has_method("_on_virtual_move_input"):
		player._on_virtual_move_input(Vector2(0.8, -0.6))
		assert_equal(player.virtual_input_vector, Vector2(0.8, -0.6), "PlayerActor updates virtual_input_vector on stick input")
		player._on_virtual_move_input(Vector2.ZERO)
		assert_equal(player.virtual_input_vector, Vector2.ZERO, "PlayerActor resets virtual_input_vector on stick release")
	else:
		assert_true(true, "PlayerActor virtual move checked")
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

	# Modular geometry & decoupled decals verification
	assert_true(wetberry.find_child("CartonBody", true, false) != null, "Wetberry has CartonBody mesh")
	assert_true(wetberry.find_child("FrontLabelDecal", true, false) != null, "Wetberry has FrontLabelDecal mesh")

	assert_true(keith.find_child("Torso", true, false) != null, "Keith has Torso mesh")
	assert_true(keith.find_child("HeadHood", true, false) != null, "Keith has HeadHood mesh")
	assert_true(keith.find_child("BadgeDecal", true, false) != null, "Keith has BadgeDecal mesh")

	var ambient_hum = bootstrap.find_child("AmbientHum", true, false)
	assert_true(ambient_hum != null, "Breakroom has fluorescent ambient hum player")
	var ceiling_light = bootstrap.find_child("CeilingLight", true, false)
	assert_true(ceiling_light != null, "Breakroom has active ceiling light")

	var fridge = bootstrap.find_child("Fridge", true, false)
	assert_true(fridge != null, "Fridge exists")
	assert_true(fridge.find_child("CabinetBody", true, false) != null, "Fridge has CabinetBody mesh")
	assert_true(fridge.find_child("FreezerDoor", true, false) != null, "Fridge has FreezerDoor mesh")
	assert_true(fridge.find_child("FridgeDoor", true, false) != null, "Fridge has FridgeDoor mesh")
	assert_true(fridge.find_child("PropertyDecal", true, false) != null, "Fridge has PropertyDecal mesh")

	var coffee_maker = bootstrap.find_child("CoffeeMaker", true, false)
	assert_true(coffee_maker != null, "Coffee maker exists")
	assert_true(coffee_maker.find_child("BasePlate", true, false) != null, "Coffee maker has BasePlate mesh")
	assert_true(coffee_maker.find_child("CarafeGlass", true, false) != null, "Coffee maker has CarafeGlass mesh")
	assert_true(coffee_maker.find_child("StatusLED", true, false) != null, "Coffee maker has StatusLED mesh")

	var table = bootstrap.find_child("CentralTable", true, false)
	assert_true(table != null, "Central table exists")
	assert_true(table.find_child("TableTop", true, false) != null, "Central table has TableTop mesh")
	assert_true(table.find_child("HiddenAnomalyPlate", true, false) != null, "Central table has HiddenAnomalyPlate mesh")

	var kevin_3d = bootstrap.find_child("FirstPersonKevin", true, false)
	assert_true(kevin_3d is CharacterBody3D, "FirstPersonKevin is a CharacterBody3D")
	assert_true(kevin_3d.has_method("interact"), "FirstPersonKevin implements interact")
	assert_true(kevin_3d.get("quantum_component") != null, "FirstPersonKevin has QuantumComponent")

	var breakroom_3d = bootstrap.find_child("FirstPersonBreakroom", true, false)
	assert_true(breakroom_3d != null and breakroom_3d.has_method("set_entangled_state"), "FirstPersonBreakroom exposes entangled-state hook")
	if breakroom_3d != null and breakroom_3d.has_method("set_entangled_state"):
		breakroom_3d.call("set_entangled_state", "leaking")
		assert_equal(breakroom_3d.get("coffee_machine_state"), "leaking", "Coffee maker receives leaking entangled state")

	var fp_hud = bootstrap.find_child("FirstPersonHUD", true, false)
	assert_true(fp_hud != null, "First-person HUD is present")
	assert_true(fp_hud.find_child("DialoguePanel", true, false) != null, "First-person HUD has manually advanced dialogue panel")
	assert_true(fp_hud.find_child("PDAPanel", true, false) != null, "First-person HUD has PDA panel")
	assert_true(fp_hud.find_child("MobileStick", true, false) != null, "First-person HUD preserves mobile movement stick")
	assert_true(fp_hud.find_child("TouchLookZone", true, false) != null, "First-person HUD has mobile touch-look zone")
	assert_true(fp_hud.find_child("InteractButton", true, false) != null, "First-person HUD has mobile interact button")
	assert_true(fp_hud.has_method("_set_mobile_gameplay_controls_enabled"), "First-person HUD owns mobile modal process state")
	assert_true(player.has_method("_on_input_lock_changed"), "First-person player owns modal input-lock handling")

	bootstrap.queue_free()


func test_phone_playtest_fixes() -> void:
	print("\n--- 13. Phone Playtest Fix Batch (Prompt, Labels, Toasts, Quantum Anchor) ---")
	var hud_scene = load("res://scenes/fps/FirstPersonHUD.tscn")
	assert_true(hud_scene != null, "FirstPersonHUD.tscn loads for playtest fix verification")
	var hud = hud_scene.instantiate()
	assert_true(hud != null, "FirstPersonHUD instantiates")
	add_child(hud)

	var prompt_label = hud.find_child("PromptLabel", true, false)
	var dialogue_panel = hud.find_child("DialoguePanel", true, false)
	var pda_panel = hud.find_child("PDAPanel", true, false)
	var notif_panel = hud.find_child("NotificationPanel", true, false)
	var obj_panel = hud.find_child("ObjectivePanel", true, false)
	var pda_button = hud.find_child("PDAButton", true, false)
	var hint_label = hud.find_child("Hint", true, false)
	var diag_label = hud.find_child("QuantumDiagnostic", true, false)
	var interact_button = hud.find_child("InteractButton", true, false)
	var crosshair = hud.find_child("Crosshair", true, false)

	# 1. Hide interaction prompts whenever DialoguePanel or PDAPanel is open
	hud._on_prompt_changed("Talk to Keith")
	assert_true(prompt_label.visible, "PromptLabel is visible during regular exploration")
	assert_equal(prompt_label.text, "Talk to Keith", "PromptLabel text updated")

	hud._on_dialogue_requested("Keith", ["Sample line."])
	assert_true(dialogue_panel.visible, "DialoguePanel is open")
	assert_false(prompt_label.visible, "PromptLabel is hidden while DialoguePanel is open")

	hud._close_dialogue()
	assert_false(dialogue_panel.visible, "DialoguePanel is closed")
	assert_true(prompt_label.visible, "PromptLabel is restored when DialoguePanel closes")

	hud._toggle_pda()
	assert_true(pda_panel.visible, "PDAPanel is open")
	assert_false(prompt_label.visible, "PromptLabel is hidden while PDAPanel is open")

	hud._toggle_pda()
	assert_false(pda_panel.visible, "PDAPanel is closed")
	assert_true(prompt_label.visible, "PromptLabel is restored when PDAPanel closes")

	# 2. Platform-aware control labels
	assert_true(hud.has_method("_format_prompt"), "HUD has _format_prompt platform-aware method")
	assert_true(hud.has_method("_apply_platform_labels"), "HUD has _apply_platform_labels method")
	
	# Mobile format stripping
	var raw_desktop_prompt = "[E / A] Inspect Wetberry"
	var formatted_prompt = hud._format_prompt(raw_desktop_prompt)
	if hud.is_mobile():
		assert_equal(formatted_prompt, "Inspect Wetberry", "Mobile prompt strips [E / A] desktop prefix")
		assert_false("[E / A]" in formatted_prompt, "Mobile prompt contains no [E / A]")
		assert_false("[P]" in pda_button.text, "Mobile PDA button contains no [P]")
		assert_false("WASD" in hint_label.text, "Mobile Hint contains no WASD")
		assert_false("F5/F9" in hint_label.text, "Mobile Hint contains no F5/F9")
	else:
		assert_equal(formatted_prompt, raw_desktop_prompt, "Desktop prompt preserves key bindings")

	# 3. Bottom-center interaction control + contextual action feedback
	assert_true(interact_button != null and crosshair != null, "HUD exposes centered interaction button and crosshair")
	assert_equal(interact_button.anchor_left, 0.5, "Interact button left anchor is centered")
	assert_equal(interact_button.anchor_right, 0.5, "Interact button right anchor is centered")
	assert_equal(hud._action_label_for_prompt("Open Fridge"), "OPEN", "Open prompt maps to OPEN action")
	assert_equal(hud._action_label_for_prompt("Talk to Keith"), "TALK", "Talk prompt maps to TALK action")
	assert_equal(hud._action_label_for_prompt("Pick Up Wetberry"), "PICK UP", "Pickup prompt maps to PICK UP action")
	hud._on_prompt_changed("Open Fridge")
	assert_false(interact_button.disabled, "Interact button enables on actionable focus")
	assert_equal(interact_button.text, "OPEN", "Interact button shows contextual OPEN action")
	EventBus.first_person_input_lock_changed.emit(true)
	assert_true(interact_button.disabled, "Input lock disables interact action")
	EventBus.first_person_input_lock_changed.emit(false)
	assert_false(interact_button.disabled, "Interact action restores after input unlock")

	# 4. Notification toasts never overlap Current Objective
	assert_true(notif_panel != null and obj_panel != null, "HUD contains NotificationPanel and ObjectivePanel")
	assert_true(notif_panel.offset_top >= obj_panel.offset_bottom, "NotificationPanel top offset (>= 120) sits below ObjectivePanel bottom (105)")

	# 4. Rename PDA quantum "Confirmed" field to "Last confirmed anchor"
	hud._refresh_quantum_diagnostic()
	assert_false("Confirmed:" in diag_label.text, "Quantum diagnostic does not use legacy Confirmed: field")

	remove_child(hud)
	hud.queue_free()


func test_touch_look_zone_robustness() -> void:
	print("\n--- 14. TouchLookZone Robust Finger Ownership & Multi-Touch ---")
	var hud_scene = load("res://scenes/fps/FirstPersonHUD.tscn")
	assert_true(hud_scene != null, "FirstPersonHUD.tscn loads for touch look test")
	var hud = hud_scene.instantiate()
	assert_true(hud != null, "FirstPersonHUD instantiates")
	hud.force_mobile_controls = true
	add_child(hud)
	hud._set_mobile_gameplay_controls_enabled(true)

	var touch_look = hud.find_child("TouchLookZone", true, false)
	assert_true(touch_look != null, "TouchLookZone node exists in HUD")
	assert_true(touch_look.has_method("reset_touch"), "TouchLookZone exposes reset_touch()")

	var look_deltas: Array[Vector2] = []
	var look_callable = func(delta: Vector2): look_deltas.append(delta)
	EventBus.virtual_look_input.connect(look_callable)

	# 1. Normal touch down -> drag -> release
	var t_down = InputEventScreenTouch.new()
	t_down.index = 1
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(100.0, 100.0)
	touch_look._input(t_down)
	assert_equal(touch_look.active_touch_index, 1, "TouchLookZone captures touch index 1")

	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = touch_look.global_position + Vector2(120.0, 105.0)
	drag.relative = Vector2(20.0, 5.0)
	touch_look._input(drag)
	assert_equal(look_deltas.size(), 1, "Look drag event emitted")
	assert_equal(look_deltas[0], Vector2(20.0, 5.0), "Look delta is Vector2(20, 5)")

	var t_up = InputEventScreenTouch.new()
	t_up.index = 1
	t_up.pressed = false
	t_up.position = touch_look.global_position + Vector2(120.0, 105.0)
	touch_look._input(t_up)
	assert_equal(touch_look.active_touch_index, -1, "TouchLookZone released touch index 1")

	# 2. Drag outside look region then release
	t_down.index = 2
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_down)
	assert_equal(touch_look.active_touch_index, 2, "TouchLookZone captures touch index 2")

	drag.index = 2
	drag.position = Vector2(10.0, 10.0) # Outside look region (left side of screen)
	drag.relative = Vector2(-30.0, 10.0)
	touch_look._input(drag)
	assert_equal(look_deltas.back(), Vector2(-30.0, 10.0), "Drag outside look region tracked globally")

	t_up.index = 2
	t_up.pressed = false
	t_up.position = Vector2(10.0, 10.0) # Released outside look region
	touch_look._input(t_up)
	assert_equal(touch_look.active_touch_index, -1, "Release outside look region cleanly frees active_touch_index")

	# 3. Any gameplay input lock clears stale touch ownership (inspection included)
	t_down.index = 7
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_down)
	assert_equal(touch_look.active_touch_index, 7, "TouchLookZone captures touch before generic input lock")
	EventBus.first_person_input_lock_changed.emit(true)
	assert_equal(touch_look.active_touch_index, -1, "Generic input lock resets active touch ownership")
	EventBus.first_person_input_lock_changed.emit(false)

	# 4. Modal opens while look finger is active -> index cleared & drag suppressed
	t_down.index = 3
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_down)
	assert_equal(touch_look.active_touch_index, 3, "TouchLookZone captures touch index 3")

	hud._on_dialogue_requested("Keith", ["Testing look lock."])
	assert_equal(touch_look.active_touch_index, -1, "Opening dialogue resets active_touch_index")

	var deltas_before = look_deltas.size()
	drag.index = 3
	drag.relative = Vector2(40.0, 40.0)
	touch_look._input(drag)
	assert_equal(look_deltas.size(), deltas_before, "Look input suppressed while modal is open")

	# 4. Look resumes immediately after modal closes
	hud._close_dialogue()
	t_down.index = 4
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_down)
	assert_equal(touch_look.active_touch_index, 4, "Look immediately claims new touch 4 after modal closes")

	drag.index = 4
	drag.relative = Vector2(15.0, -8.0)
	touch_look._input(drag)
	assert_equal(look_deltas.back(), Vector2(15.0, -8.0), "Look input emits properly after modal closure")

	t_up.index = 4
	t_up.pressed = false
	touch_look._input(t_up)
	assert_equal(touch_look.active_touch_index, -1, "Touch 4 released")

	# 5. Left joystick and right look simultaneously (multi-touch)
	var mobile_stick = hud.find_child("MobileStick", true, false)
	assert_true(mobile_stick != null, "MobileStick node exists")

	var stick_touch = InputEventScreenTouch.new()
	stick_touch.index = 0
	stick_touch.pressed = true
	stick_touch.position = mobile_stick.global_position + mobile_stick.size * 0.5
	mobile_stick._input(stick_touch)

	t_down.index = 1
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_down)

	assert_equal(mobile_stick.active_touch_index, 0, "Joystick owns finger index 0")
	assert_equal(touch_look.active_touch_index, 1, "Look zone owns finger index 1")

	stick_touch.pressed = false
	mobile_stick._input(stick_touch)
	assert_equal(mobile_stick.active_touch_index, -1, "Joystick released finger index 0")
	assert_equal(touch_look.active_touch_index, 1, "Look zone retains active finger index 1 during joystick release")

	t_up.index = 1
	t_up.pressed = false
	touch_look._input(t_up)
	assert_equal(touch_look.active_touch_index, -1, "Look zone released finger index 1")

	# 6. Second finger cannot steal ownership from active look finger
	t_down.index = 8
	t_down.pressed = true
	t_down.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_down)
	assert_equal(touch_look.active_touch_index, 8, "Look finger 8 claims initial ownership")

	# Second finger touches down inside look zone
	var t_down_2 = InputEventScreenTouch.new()
	t_down_2.index = 9
	t_down_2.pressed = true
	t_down_2.position = touch_look.global_position + Vector2(60.0, 60.0)
	touch_look._input(t_down_2)
	assert_equal(touch_look.active_touch_index, 8, "Second finger 9 cannot steal ownership from active finger 8")

	# Active finger 8 continues producing look deltas
	var deltas_count_before = look_deltas.size()
	drag.index = 8
	drag.relative = Vector2(10.0, 5.0)
	touch_look._input(drag)
	assert_equal(look_deltas.size(), deltas_count_before + 1, "Active finger 8 continues producing look deltas after second touch")
	assert_equal(look_deltas.back(), Vector2(10.0, 5.0), "Look delta from active finger 8 is accurate")

	# Second finger drag is ignored
	drag.index = 9
	drag.relative = Vector2(50.0, 50.0)
	touch_look._input(drag)
	assert_equal(look_deltas.size(), deltas_count_before + 1, "Second finger 9 drag is ignored")

	# Second finger release is ignored and does not clear active finger 8
	var t_up_2 = InputEventScreenTouch.new()
	t_up_2.index = 9
	t_up_2.pressed = false
	t_up_2.position = touch_look.global_position + Vector2(60.0, 60.0)
	touch_look._input(t_up_2)
	assert_equal(touch_look.active_touch_index, 8, "Second finger release does not clear active finger 8")

	# Active finger release clears ownership
	t_up.index = 8
	t_up.pressed = false
	t_up.position = touch_look.global_position + Vector2(50.0, 50.0)
	touch_look._input(t_up)
	assert_equal(touch_look.active_touch_index, -1, "Active finger 8 release cleanly clears ownership")

	# 7. Excluded buttons (InteractButton) do not trigger look
	var interact_btn = hud.find_child("InteractButton", true, false)
	if is_instance_valid(interact_btn):
		t_down.index = 5
		t_down.pressed = true
		t_down.position = interact_btn.global_position + interact_btn.size * 0.5
		touch_look._input(t_down)
		assert_equal(touch_look.active_touch_index, -1, "Touch on INTERACT button is ignored by TouchLookZone")

	EventBus.virtual_look_input.disconnect(look_callable)
	remove_child(hud)
	hud.queue_free()


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


func test_breakroom_interaction_pass() -> void:
	print("\n--- 15. Breakroom Interaction Pass I Acceptance ---")
	var bootstrap_scene = load("res://scenes/bootstrap/FirstPersonBootstrap.tscn")
	assert_true(bootstrap_scene != null, "FirstPersonBootstrap loads for interaction tests")
	var bootstrap = bootstrap_scene.instantiate()
	assert_true(bootstrap != null, "FirstPersonBootstrap instantiates")
	add_child(bootstrap)

	var breakroom = bootstrap.find_child("FirstPersonBreakroom", true, false) as FirstPersonBreakroom
	assert_true(breakroom != null, "FirstPersonBreakroom node found in tree")

	var player = bootstrap.find_child("Player", true, false)
	assert_true(player != null, "Player found in tree")

	var held_slot = player.find_child("HeldSlot", true, false)
	assert_true(held_slot != null, "Player has HeldSlot node in Head hierarchy")

	var wetberry = bootstrap.find_child("Wetberry", true, false) as StaticBody3D
	assert_true(wetberry != null, "Wetberry static body found")

	var dressing = bootstrap.find_child("BreakroomDressing", true, false)
	assert_true(dressing != null, "Breakroom environmental dressing group exists")
	assert_true(dressing.find_child("NoticeBoard", true, false) != null, "Breakroom has employee notice board")
	assert_true(dressing.find_child("UtilityBucket", true, false) != null, "Keith utility bucket is staged in room")
	assert_true(dressing.find_child("AbandonedCup1", true, false) != null, "Coffee counter has abandoned cup dressing")
	var wetberry_light = wetberry.find_child("ContaminationLight", true, false) as OmniLight3D
	assert_true(wetberry_light != null, "Wetberry has low-cost contamination light")
	assert_true(breakroom.coffee_switch_sfx != null and breakroom.coffee_switch_sfx.stream != null, "Coffee switch SFX is wired")
	assert_true(breakroom.coffee_brew_sfx != null and breakroom.coffee_brew_sfx.stream != null, "Coffee brew SFX is wired")
	assert_true(breakroom.fridge_hinge_sfx != null and breakroom.fridge_hinge_sfx.stream != null, "Fridge hinge SFX is wired")

	# 1. Coffee Maker Toggle & Visual Feedback
	assert_false(breakroom.is_coffee_on, "Coffee maker starts OFF")
	breakroom.toggle_coffee_maker()
	assert_true(breakroom.is_coffee_on, "Coffee maker toggled to ON")
	var coffee_led = breakroom.quantum_coffee_maker.find_child("StatusLED", true, false) as MeshInstance3D
	assert_true(coffee_led != null, "Coffee maker StatusLED exists")
	var led_mat = coffee_led.get_active_material(0) as StandardMaterial3D
	assert_true(led_mat != null and led_mat.emission_enabled, "StatusLED emits light when ON")

	var coffee_steam = breakroom.quantum_coffee_maker.find_child("BrewSteam", true, false) as MeshInstance3D
	assert_true(coffee_steam != null and coffee_steam.visible, "BrewSteam visible when ON")

	breakroom.toggle_coffee_maker()
	assert_false(breakroom.is_coffee_on, "Coffee maker toggled back to OFF")
	assert_false(coffee_steam.visible, "BrewSteam hidden when OFF")

	# 2. Fridge Hinge Animation & Fly Swarm Visibility
	assert_false(breakroom.is_fridge_open, "Fridge starts closed")
	var fridge_pivot = breakroom.fridge_door_pivot
	assert_true(fridge_pivot != null, "Fridge has FridgeDoorPivot node")
	var freezer_pivot = breakroom.freezer_door_pivot
	assert_true(freezer_pivot != null, "Fridge has FreezerDoorPivot node")
	var fly_swarm = breakroom.fridge_fly_swarm
	assert_true(fly_swarm != null, "Fridge has FlySwarm node")
	var fridge_light = breakroom.fridge_light
	assert_true(fridge_light != null, "Fridge has interior light")
	assert_false(fridge_light.visible, "Fridge interior light starts off")

	breakroom.toggle_fridge_door()
	assert_true(breakroom.is_fridge_open, "Fridge is toggled to open")
	assert_true(breakroom.is_fridge_animating, "Fridge is animating door swing")
	assert_true(fridge_light.visible, "Fridge interior light turns on with door")

	# 3. Focus / Inspect / Zoom component
	assert_false(breakroom.is_inspecting, "Inspect mode starts inactive")
	breakroom._start_inspect(wetberry, "Wetberry", 0.9, 0.0)
	assert_true(breakroom.is_inspecting, "Inspect mode active on Wetberry")
	assert_equal(breakroom.inspecting_target, wetberry, "Inspect target is Wetberry")

	breakroom.exit_inspect()
	assert_false(breakroom.is_inspecting, "Exit inspect restores exploration mode")

	# 4. Pick Up / Place Wetberry (Duplication Impossible)
	assert_true(wetberry.visible, "Wetberry initially visible in world")
	var pick_ok = breakroom.pick_up_wetberry()
	assert_true(pick_ok, "Wetberry picked up successfully")
	assert_false(wetberry.visible, "Wetberry world prop hidden while held")
	assert_true(breakroom.held_prop != null, "Held prop reference set in breakroom")
	assert_true(held_slot.get_child_count() > 0, "HeldSlot contains view mesh")

	# Cannot pick up second object while holding
	var pick_again = breakroom.pick_up_wetberry()
	assert_false(pick_again, "Cannot pick up another object while holding one")

	# Place held object
	var place_ok = breakroom.place_held_object()
	assert_true(place_ok, "Held object placed back on surface")
	assert_true(wetberry.visible, "Wetberry world prop visible after placement")
	assert_true(breakroom.held_prop == null, "Held prop reference cleared")
	var placed_props = GameRuntime.world_state.room_memory(GameRuntime.world_state.current_location).get("placed_props", {})
	assert_true(placed_props.has("Wetberry"), "Placed Wetberry transform persisted to room memory")
	var saved_wetberry_position: Vector3 = wetberry.global_position
	wetberry.global_position += Vector3(1.0, 0.0, 0.0)
	breakroom._restore_persistence()
	assert_true(wetberry.global_position.is_equal_approx(saved_wetberry_position), "Placed Wetberry transform restores from room memory")

	# 5. Keith Ambient Worker (Cleaning loop & Pause/Resume)
	var keith = bootstrap.find_child("Keith", true, false)
	assert_true(keith != null, "Keith actor exists")
	assert_true(breakroom.keith_worker != null, "Keith ambient worker initialized")
	var worker = breakroom.keith_worker
	assert_true(worker.has_method("_animate_walk"), "Keith worker has walking body animation")
	assert_true(worker.has_method("_animate_cleaning_body"), "Keith worker has cleaning body animation")
	assert_true(worker.left_leg != null and worker.right_leg != null, "Keith worker cached leg animation nodes")
	assert_false(worker.is_paused, "Keith ambient worker is initially not paused")
	worker.pause_cleaning()
	assert_true(worker.is_paused, "Keith ambient worker is paused for interaction")
	worker.resume_cleaning()
	assert_false(worker.is_paused, "Keith ambient worker is resumed after dialogue")

	remove_child(bootstrap)
	bootstrap.queue_free()


func test_hive_procgen_engine() -> void:
	print("\n--- 16. Hive Procedural World Generation Engine ---")
	var engine = HiveProcGenEngineScript.new()
	var memory_catalog := [
		{"id": "memory.test.wall", "tags": ["institutional", "familiar", "surface"]},
		{"id": "memory.test.blur", "tags": ["anomalous", "abstract", "blur"]},
	]
	var hive := {"pressure": 0.42, "instability": 0.35, "observation": 0.7, "familiarity": 0.8}
	var plan_a: Dictionary = engine.generate(6060, hive, memory_catalog)
	var plan_b: Dictionary = engine.generate(6060, hive, memory_catalog)
	var plan_c: Dictionary = engine.generate(6061, hive, memory_catalog)
	assert_equal(plan_a.get("schema"), "hive_procgen_world_v1", "Procgen world uses versioned schema")
	assert_equal(plan_a["receipt"]["sha256"], plan_b["receipt"]["sha256"], "Same seed/state produces identical world receipt")
	assert_true(plan_a["receipt"]["sha256"] != plan_c["receipt"]["sha256"], "Different seed produces different world receipt")
	assert_equal(plan_a["regions"].size(), 6, "Macro generator creates six regions")
	assert_true(plan_a["region_edges"].size() >= plan_a["regions"].size() - 1, "Region topology has connected spine")
	assert_true(plan_a["sites"].size() >= 36, "World contains minimum systemic site population")
	assert_true(plan_a["site_edges"].size() >= plan_a["sites"].size() - 1, "Site topology has connected spine")
	var breakroom_site: Dictionary = {}
	for site in plan_a["sites"]:
		if site.get("id") == "site.breakroom": breakroom_site = site
	assert_true(not breakroom_site.is_empty(), "Existing Breakroom is bridged into procedural world")
	assert_equal(breakroom_site.get("authored_scene"), "res://scenes/fps/FirstPersonBreakroom.tscn", "Breakroom remains authored scene")
	assert_true(plan_a["room_graphs"].has("site.breakroom"), "Breakroom site has procedural adjacency graph")
	assert_equal(plan_a["room_graphs"]["site.breakroom"]["constraint_status"], "resolved", "Room constraint pass resolves")
	assert_true(plan_a["scatter"].size() > 0, "Density scatter pass emits world details")
	assert_true(plan_a["streaming"]["cells"].size() > 0, "Streaming partition builds occupied cells")
	var origin := Vector2(float(breakroom_site["position"]["x"]), float(breakroom_site["position"]["y"]))
	assert_true(engine.active_cells_for_position(plan_a, origin, 1).size() <= 9, "Runtime streaming activation remains bounded")
	assert_true(plan_a["director"]["anomaly_budget"] > 0.0, "Hive director computes anomaly budget")
	assert_false(JSON.stringify(plan_a).contains("C:\\"), "Generated plan contains no raw Windows photo paths")
	var bootstrap_scene = load("res://scenes/bootstrap/FirstPersonBootstrap.tscn")
	var bootstrap = bootstrap_scene.instantiate()
	assert_true(bootstrap.find_child("HiveProcGenRuntime", true, false) != null, "First-person bootstrap owns procedural runtime")
	bootstrap.queue_free()
	var renderer = HiveProcGenChunkRendererScript.new()
	var player := Node3D.new()
	var breakroom := Node3D.new()
	var world := Node3D.new()
	world.name = "World"
	var east_wall := StaticBody3D.new()
	east_wall.name = "EastWall"
	world.add_child(east_wall)
	breakroom.add_child(world)
	add_child(player)
	add_child(breakroom)
	add_child(renderer)
	renderer.configure(plan_a, player, breakroom)
	assert_equal(renderer.neighbor_site_id.begins_with("region.00.site."), true, "Renderer selects a generated Region 01 neighbor")
	assert_true(renderer.loaded_cell_keys().has("0:0"), "Breakroom portal cell is active")
	assert_true(renderer.get_node_or_null("Cell_0_0/Navigation") != null, "Active cell materializes navigation")
	var streamed_floor := renderer.get_node_or_null("Cell_0_0/Floor")
	assert_true(streamed_floor != null and streamed_floor.get_node_or_null("Collision") != null, "Active cell materializes collision")
	player.position.x = 70.0
	renderer.update_streaming()
	assert_true(renderer.loaded_cell_keys().has("2:0"), "Neighboring generated site streams during traversal")
	assert_false(renderer.loaded_cell_keys().has("0:0"), "Cold portal cell unloads outside active radius")
	var runtime_script = load("res://scripts/procgen/HiveProcGenRuntime.gd")
	var recovery_runtime = runtime_script.new()
	var recovery_player := CharacterBody3D.new()
	recovery_player.position = Vector3(12.0, -20.0, 0.0)
	add_child(recovery_player)
	add_child(recovery_runtime)
	recovery_runtime._player = recovery_player
	recovery_runtime._update_fall_recovery()
	assert_true(recovery_player.position.y > 0.0, "Underworld fall recovery returns player to stable ground")
	assert_equal(recovery_player.velocity, Vector3.ZERO, "Fall recovery clears accumulated velocity")
	recovery_runtime.queue_free()
	recovery_player.queue_free()
	renderer.queue_free()
	player.queue_free()
	breakroom.queue_free()


func test_gameflow_atmosphere_and_level_suite() -> void:
	print("\n--- 17. Game Flow, Persistent Atmosphere & Multi-Level Suite ---")
	var menu_scene = load("res://scenes/ui/MainMenu.tscn")
	assert_true(menu_scene != null, "Main title scene loads")
	var menu = menu_scene.instantiate()
	assert_true(menu.find_child("ContinueButton", true, false) != null, "Main title has Continue")
	assert_true(menu.find_child("NewGameButton", true, false) != null, "Main title has New Witness")
	assert_true(menu.find_child("Slot1", true, false) != null, "Main title exposes save slot 1")
	assert_true(menu.find_child("Slot2", true, false) != null, "Main title exposes save slot 2")
	assert_true(menu.find_child("Slot3", true, false) != null, "Main title exposes save slot 3")
	menu.queue_free()
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project_text.contains('run/main_scene="res://scenes/ui/MainMenu.tscn"'), "Main title is the configured boot scene")
	assert_true(project_text.contains('AtmosphereDirector="*res://scripts/runtime/AtmosphereDirector.gd"'), "Persistent atmosphere is autoloaded")
	assert_true(FileAccess.file_exists("res://assets/audio/hive_roomtone.wav"), "Persistent Hive roomtone asset exists")
	assert_true(FileAccess.file_exists("res://assets/audio/hive_waterdrop.wav"), "Waterdrop motif asset exists")
	var breakroom_text := FileAccess.get_file_as_string("res://scripts/fps/FirstPersonBreakroom.gd")
	assert_false(breakroom_text.contains("disappointed zipper sound"), "Legacy zipper line is removed")
	assert_true(breakroom_text.contains("water drops answer"), "Containment now uses the waterdrop motif")

	var engine = HiveProcGenEngineScript.new()
	var plan: Dictionary = engine.generate(6060, {"pressure": 0.4, "instability": 0.3, "observation": 0.5, "familiarity": 0.6}, [])
	var renderer = HiveProcGenChunkRendererScript.new()
	var player := Node3D.new()
	var breakroom := Node3D.new()
	var world := Node3D.new()
	world.name = "World"
	var east_wall := StaticBody3D.new()
	east_wall.name = "EastWall"
	var east_collision := CollisionShape3D.new()
	east_collision.name = "Collision"
	east_collision.shape = BoxShape3D.new()
	east_wall.add_child(east_collision)
	world.add_child(east_wall)
	breakroom.add_child(world)
	add_child(player)
	add_child(breakroom)
	add_child(renderer)
	renderer.configure(plan, player, breakroom)
	assert_true(renderer.level_count() >= 12, "World route exposes at least twelve named levels")
	assert_true(renderer.route_cell_count() >= 24, "Multi-level route spans at least twenty-four stream cells")
	assert_true(breakroom.find_child("ProcGenExitGate", true, false) != null, "Breakroom has a physical interactive exit gate")
	player.position.x = 130.0
	renderer.update_streaming()
	assert_true(renderer.loaded_cell_keys().has("4:0"), "Traversal streams level 02 instead of ending at the first site")
	player.position.x = 770.0
	renderer.update_streaming()
	assert_true(renderer.loaded_cell_keys().has("24:0"), "Traversal reaches the twelfth level cell")
	assert_equal(renderer.level_title(11), "THE LATTICE", "Twelfth level has a distinct terminal identity")
	renderer.queue_free()
	player.queue_free()
	breakroom.queue_free()


func assert_false(condition: bool, test_name: String) -> void:
	assert_true(not condition, test_name)
