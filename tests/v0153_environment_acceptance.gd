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
	var plan := KimiWorldPlan.new(6060)
	var generator := KimiWorldGenerator.new(plan)
	var macro := MacroTerrain.new()
	macro.name = "MacroTerrainProbe"
	macro.world_plan = plan
	macro.world_half = 480.0
	root.add_child(macro)
	await process_frame

	var biome_ids := plan.biome_ids()
	var unique_declared := {}
	for biome in biome_ids:
		unique_declared[String(biome)] = true
	if biome_ids.size() == 10 and unique_declared.size() == 10:
		_pass("exactly ten unique biome types are declared")
	else:
		_fail("biome contract expected 10 unique IDs, got %d/%d" % [biome_ids.size(), unique_declared.size()])

	var observed := {}
	for z in range(-1600, 1601, 160):
		for x in range(-1600, 1601, 160):
			observed[String(plan.sample_biome(float(x), float(z)))] = true
	var river_z := plan.primary_river_center_z(260.0)
	observed[String(plan.sample_biome(260.0, river_z))] = true
	var lake_center := plan.lake_center()
	observed[String(plan.sample_biome(lake_center.x, lake_center.y))] = true
	if observed.size() == 10:
		_pass("world-scale deterministic sampling can express all ten biomes")
	else:
		_fail("not all biome types are reachable in deterministic sampling: " + str(observed.keys()))

	var descriptor_biomes := {}
	var labeled_candidates := 0
	for z in range(-4, 4):
		for x in range(-4, 4):
			var desc := generator.describe_chunk(Vector2i(x, z))
			descriptor_biomes[String(desc.biome)] = true
			for item in desc.vegetation_candidates + desc.rock_candidates:
				if str(item.get("biome", "")) != "":
					labeled_candidates += 1
	if descriptor_biomes.size() >= 5 and labeled_candidates >= 100:
		_pass("chunk descriptors carry biome-aware ecology metadata")
	else:
		_fail("descriptor ecology diversity insufficient: biomes=%s labels=%d" % [descriptor_biomes.keys(), labeled_candidates])

	var hydro_stats: Dictionary = macro.get_hydrology_stats_for_test()
	if int(hydro_stats.get("water_nodes", 0)) == 4:
		_pass("river, two tributaries, and marsh lake materialize as four water surfaces")
	else:
		_fail("hydrology surface count mismatch: " + str(hydro_stats))

	for node_name in ["PrimaryRiverWater", "TributaryWater_0", "TributaryWater_1", "MarshLakeWater"]:
		if macro.get_node_or_null(node_name) == null:
			_fail("missing hydrology visual " + node_name)
	if failures.all(func(item: String): return not item.begins_with("missing hydrology visual")):
		_pass("all named hydrology surfaces exist")

	var river_probes := [-360.0, -240.0, -120.0, 120.0, 240.0, 360.0]
	var best_relief := 0.0
	var valid_water_probe := false
	for x in river_probes:
		var center_z := plan.primary_river_center_z(x)
		if macro.is_water_at(x, center_z):
			valid_water_probe = true
			var channel := macro.height_at(x, center_z)
			var bank_a := macro.height_at(x, center_z - 42.0)
			var bank_b := macro.height_at(x, center_z + 42.0)
			best_relief = maxf(best_relief, maxf(bank_a, bank_b) - channel)
	if valid_water_probe and best_relief > 0.75:
		_pass("hydrology carves a measurable channel below at least one bank")
	else:
		_fail("river channel/bank relief insufficient: " + str(best_relief))

	if macro.is_water_at(lake_center.x, lake_center.y) and macro.water_kind_at(lake_center.x, lake_center.y) == &"marsh":
		_pass("seeded marsh/lake center is recognized as water")
	else:
		_fail("seeded marsh/lake is not recognized as water")

	var terrain_bodies := get_nodes_in_group("macro_terrain")
	if (
		terrain_bodies.size() == 1
		and terrain_bodies[0].get_node_or_null("TerrainMesh") is MeshInstance3D
		and terrain_bodies[0].get_node_or_null("TerrainCollision") is CollisionShape3D
	):
		_pass("continuous terrain collision remains authoritative")
	else:
		_fail("terrain/collision ownership regressed")

	macro.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL V0153 ENVIRONMENT GATES PASSED]")
		quit(0)
	else:
		print("[V0153 ENVIRONMENT FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
