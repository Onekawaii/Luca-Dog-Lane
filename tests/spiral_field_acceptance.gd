extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _pass(message: String) -> void:
	print("[PASS] ", message)

func _fail(message: String) -> void:
	failures.append(message)
	print("[FAIL] ", message)

func _run() -> void:
	var save_v2 := "user://qa_spiral_%d.json" % Time.get_ticks_usec()
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", save_v2)

	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn missing")
		_finish()
		return

	var world := packed.instantiate()
	root.add_child(world)
	for _i in range(140):
		await physics_frame

	var director := world.get_node_or_null("SpiralWorldDirector")
	var hud := world.get_node_or_null("SandboxHUD")
	if director == null or hud == null:
		_fail("Spiral director or HUD missing")
		_finish()
		return

	var witness := director.get_node_or_null("Spiral_Witnessing")
	var wail := director.get_node_or_null("Spiral_Wailing")
	var tabby := director.get_node_or_null("Tabbytulhu")
	if witness != null and wail != null and tabby != null:
		_pass("Twin Spirals and Tabby'tulhu exist")
	else:
		_fail("required Spiral encounters missing")

	if (
		witness != null and witness.get_node_or_null("DistantBeacon") != null
		and wail != null and wail.get_node_or_null("DistantBeacon") != null
	):
		_pass("both Spirals have distant visual beacons")
	else:
		_fail("Spiral distant-beacon guidance missing")

	if (
		tabby != null
		and tabby.get_node_or_null("Ear_L") != null
		and tabby.get_node_or_null("Ear_R") != null
		and tabby.get_node_or_null("Leg_00") != null
		and tabby.get_node_or_null("Tail_00") != null
		and tabby.get_node_or_null("WhiskerTentacle_00") != null
	):
		_pass("Tabby'tulhu has readable cat anatomy plus eldritch appendages")
	else:
		_fail("Tabby'tulhu anatomy contract failed")

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if player != null and tabby != null:
		player.global_position = tabby.global_position + Vector3(0.0, 0.0, 5.5)
		player.rotation = Vector3.ZERO
		player.set("yaw", 0.0)
		var pivot = player.get("pivot") as Node3D
		if pivot != null:
			pivot.rotation.x = 0.0
		for _i in range(4):
			await physics_frame
		player.call("use_tool")
		await process_frame
		var encounter_panel = hud.get("encounter_panel") as Panel
		if encounter_panel != null and encounter_panel.visible:
			_pass("Player USE raycasts a Spiral and opens contextual encounter UI")
			hud.call("close_encounter")
		else:
			_fail("Player USE did not open contextual encounter UI")
	else:
		_fail("player or Tabby'tulhu missing for contextual raycast test")

	# Reproduce the recording's Spiral engulfment path: approach under normal
	# collision, prove the landmark stops the camera outside its outer rings,
	# and prove USE still reaches the encounter from that stand-off distance.
	if player != null and witness != null:
		var witness_collision: CollisionShape3D = null
		var witness_collisions := witness.find_children("*", "CollisionShape3D", false, false)
		if not witness_collisions.is_empty():
			witness_collision = witness_collisions[0] as CollisionShape3D
		var witness_shape: CylinderShape3D = null
		if witness_collision != null:
			witness_shape = witness_collision.shape as CylinderShape3D
		player.global_position = witness.global_position + Vector3(0.0, 0.0, 9.0)
		player.rotation = Vector3.ZERO
		player.set("yaw", 0.0)
		var pivot = player.get("pivot") as Node3D
		if pivot != null:
			pivot.rotation.x = 0.0
		player.call("set_touch_move", Vector2(0.0, -1.0))
		for _i in range(90):
			await physics_frame
		player.call("set_touch_move", Vector2.ZERO)
		var planar_delta: Vector3 = player.global_position - witness.global_position
		planar_delta.y = 0.0
		var look_target := Vector3(witness.global_position.x, player.global_position.y, witness.global_position.z)
		player.look_at(look_target, Vector3.UP)
		player.set("yaw", player.rotation.y)
		var stand_off_ok: bool = (
			witness_shape != null
			and witness_shape.radius >= 7.5
			and planar_delta.length() >= 7.75
		)
		var approach_hit: Dictionary = player.call("_raycast", 9.5)
		var interaction_reaches: bool = approach_hit.get("collider") == witness
		if stand_off_ok and interaction_reaches:
			_pass("Spiral collision preserves camera stand-off and interaction reach")
		else:
			_fail(
				"Spiral stand-off or retained interaction reach failed: distance=%s radius=%s hit=%s"
				% [planar_delta.length(), witness_shape.radius if witness_shape != null else -1.0, approach_hit.get("collider")]
			)
	else:
		_fail("player or Witnessing Spiral missing for stand-off test")

	var tabby_options: Array = director.call("get_encounter_options", tabby)
	if tabby_options.size() == 4 and str(tabby_options[0].get("action")) == "talk" and str(tabby_options[3].get("action")) == "mercy":
		_pass("Tabby'tulhu exposes contextual TALK/PET/FEED/MERCY")
	else:
		_fail("Tabby'tulhu contextual options failed")

	var witness_options: Array = director.call("get_encounter_options", witness)
	if witness_options.size() == 4 and str(witness_options[0].get("action")) == "behold":
		_pass("Witnessing exposes site-specific contextual verbs")
	else:
		_fail("Witnessing contextual options failed")

	var before_pressure := float(director.call("pressure"))
	var response := str(director.call("interact", witness, "touch"))
	var after_pressure := float(director.call("pressure"))
	if after_pressure > before_pressure and "shadow" in response:
		_pass("contextual action mutates authoritative Spiral pressure")
	else:
		_fail("contextual action failed to mutate pressure")

	var tabby_response := str(director.call("interact", tabby, "pet"))
	if "whisker" in tabby_response and float(director.get("affection")) >= 3.0:
		_pass("Tabby'tulhu PET changes relationship state")
	else:
		_fail("Tabby'tulhu PET path failed")

	# Corruption alone should not falsely present a fully infected world while
	# both Twin Spirals are untouched.
	director.set("corruption", 50.0)
	director.set("witnessing", 0.0)
	director.set("wailing", 0.0)
	director.call("_refresh_world_state")
	if str(director.get("stage")) != "INFECTED":
		_pass("corruption alone no longer falsely reports INFECTED")
	else:
		_fail("stage still reports INFECTED with EYE/MOUTH at zero")

	# Force a real resonance threshold and verify environment reacts.
	var env := world.get_node_or_null("FieldEnvironment") as WorldEnvironment
	var fog_before := 0.0
	if env != null and env.environment != null:
		fog_before = env.environment.fog_density
	director.set("witnessing", 86.0)
	director.set("corruption", 62.0)
	director.call("_refresh_world_state")
	var fog_after := env.environment.fog_density if env != null and env.environment != null else 0.0
	if str(director.get("stage")) == "VELVET BREACH" and fog_after > fog_before:
		_pass("Spiral pressure visibly drives environment state")
	else:
		_fail("world environment did not respond to Spiral pressure")

	var terrain_slice: Node = world.get("terrain_slice") as Node
	if terrain_slice != null and terrain_slice.call("get_voxel_tool_for_test") != null:
		_pass("actual player TerrainSlice owns a live VoxelTool")
	else:
		_fail("actual player TerrainSlice VoxelTool is unavailable")

	if not bool(hud.get("mobile_ui")):
		var move_base = hud.get("move_base") as Panel
		var use_button = hud.get("use_button") as Button
		var spawn_button = hud.get("spawn_button") as Button
		var noclip_button = hud.get("noclip_button") as Button
		if not move_base.visible and not use_button.visible and not spawn_button.visible and not noclip_button.visible:
			_pass("desktop HUD hides touch and developer controls")
		else:
			_fail("desktop still shows mobile/developer controls")

	director.call("_save_state")
	if FileAccess.file_exists(save_v2):
		_pass("Spiral v2 state persisted to versioned save")
	else:
		_fail("Spiral v2 save file missing")

	var saved_witness := float(director.get("witnessing"))
	var saved_affection := float(director.get("affection"))
	world.queue_free()
	for _i in range(10):
		await physics_frame

	var world2 := packed.instantiate()
	root.add_child(world2)
	for _i in range(140):
		await physics_frame
	var director2 := world2.get_node_or_null("SpiralWorldDirector")
	if director2 != null and is_equal_approx(float(director2.get("witnessing")), saved_witness) and is_equal_approx(float(director2.get("affection")), saved_affection):
		_pass("v2 save/reload restores Spiral state")
	else:
		_fail("v2 save/reload failed")

	if director2 != null:
		director2.call("clear_state_for_test")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL SPIRAL FIELD V02 GATES PASSED]")
		quit(0)
	else:
		print("[SPIRAL FIELD V02 FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
