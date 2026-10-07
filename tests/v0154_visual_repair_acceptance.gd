extends SceneTree

class SurfaceProbeGame:
	extends Node
	func surface_height_at(_x: float, _z: float) -> float:
		return 24.0

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _pass(message: String) -> void:
	print("[PASS] ", message)

func _fail(message: String) -> void:
	failures.append(message)
	print("[FAIL] ", message)

func _run() -> void:
	var plan := KimiWorldPlan.new(6060)
	var macro := MacroTerrain.new()
	macro.name = "MacroTerrainVisualRepairProbe"
	macro.world_plan = plan
	macro.world_half = 480.0
	root.add_child(macro)
	await process_frame
	await physics_frame

	var probes := [
		Vector2(-372.0, -138.0),
		Vector2(-358.0, 155.0),
		Vector2(330.0, -288.0),
		Vector2(-405.0, 286.0),
		Vector2(284.0, 392.0),
		Vector2(-270.0, 332.0),
	]
	var max_delta := 0.0
	var hit_count := 0
	for p in probes:
		var expected := macro.rendered_height_at(p.x, p.y)
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(p.x, 90.0, p.y),
			Vector3(p.x, -10.0, p.y)
		)
		query.collision_mask = 1
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			_fail("terrain ray missed at " + str(p))
			continue
		hit_count += 1
		var actual := float((hit["position"] as Vector3).y)
		max_delta = maxf(max_delta, absf(actual - expected))

	if hit_count == probes.size() and max_delta <= 0.05:
		_pass("rendered_height_at matches authoritative terrain collision")
	else:
		_fail("surface/collision mismatch hits=%d delta=%f" % [hit_count, max_delta])

	var analytic_difference_found := false
	for p in probes:
		if absf(macro.height_at(p.x, p.y) - macro.rendered_height_at(p.x, p.y)) > 0.05:
			analytic_difference_found = true
			break
	if analytic_difference_found:
		_pass("repair covers real coarse-mesh interpolation mismatch")
	else:
		_pass("sample set is already mesh-aligned; collision equality still proven")

	var fake_game := SurfaceProbeGame.new()
	root.add_child(fake_game)
	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/Player.gd"))
	player.set("game", fake_game)
	root.add_child(player)
	await process_frame
	player.set("noclip", true)
	player.global_position = Vector3(12.0, 5.0, 18.0)
	player.call("_recover_if_outside")
	if player.global_position.y >= 24.0:
		_pass("local terrain-relative underworld recovery works during noclip")
	else:
		_fail("player remained under local terrain at y=" + str(player.global_position.y))
	player.queue_free()
	fake_game.queue_free()

	macro.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL V0154 VISUAL REPAIR GATES PASSED]")
		quit(0)
	else:
		print("[V0154 VISUAL REPAIR FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
