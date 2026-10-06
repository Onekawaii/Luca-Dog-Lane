class_name KimiWorldGenerator
extends RefCounted

var plan: KimiWorldPlan

func _init(world_plan: KimiWorldPlan) -> void:
	assert(world_plan != null)
	plan = world_plan

func chunk_seed_for(coord: Vector2i) -> int:
	return KimiDeterministic.hash2i(
		plan.seed ^ (KimiWorldPlan.GENERATOR_VERSION << 20), coord.x, coord.y)

func describe_chunk(coord: Vector2i) -> KimiChunkDescriptor:
	var desc := KimiChunkDescriptor.new()
	desc.coord = coord
	desc.generator_version = KimiWorldPlan.GENERATOR_VERSION
	var size := KimiChunkDescriptor.SIZE_M
	var origin := Vector2(coord.x * size, coord.y * size)
	desc.biome = plan.sample_biome(origin.x + size * 0.5, origin.y + size * 0.5)

	for j in 2:
		for i in 2:
			desc.corner_heights.append(
				plan.terrain_height(origin.x + float(i) * size, origin.y + float(j) * size))

	var rng := KimiDeterministic.RNG.new(chunk_seed_for(coord))
	var tree_range := _tree_range_for_biome(desc.biome)
	var tree_count := rng.randi_range(tree_range.x, tree_range.y)
	for n in tree_count:
		var pos_x := origin.x + rng.randf() * size
		var pos_z := origin.y + rng.randf() * size
		var local_biome := plan.sample_biome(pos_x, pos_z)
		desc.vegetation_candidates.append({
			"id": "tree:%d:%d:%d:%d" % [plan.seed, coord.x, coord.y, n],
			"pos_x": pos_x,
			"pos_z": pos_z,
			"scale": _vegetation_scale(local_biome, rng),
			"biome": String(local_biome),
		})

	var rock_range := _rock_range_for_biome(desc.biome)
	var rock_count := rng.randi_range(rock_range.x, rock_range.y)
	for n in rock_count:
		var pos_x := origin.x + rng.randf() * size
		var pos_z := origin.y + rng.randf() * size
		var local_biome := plan.sample_biome(pos_x, pos_z)
		desc.rock_candidates.append({
			"id": "rock:%d:%d:%d:%d" % [plan.seed, coord.x, coord.y, n],
			"pos_x": pos_x,
			"pos_z": pos_z,
			"scale": _rock_scale(local_biome, rng),
			"rot_x": -10.0 + rng.randf() * 20.0,
			"rot_y": rng.randf() * 180.0,
			"rot_z": -10.0 + rng.randf() * 20.0,
			"biome": String(local_biome),
		})

	desc.generation_hash = desc.compute_hash()
	return desc

func _tree_range_for_biome(biome: StringName) -> Vector2i:
	match biome:
		&"pine_forest", &"mixed_forest":
			return Vector2i(6, 10)
		&"birch_grove":
			return Vector2i(5, 9)
		&"cedar_swamp":
			return Vector2i(4, 7)
		&"riverlands":
			return Vector2i(3, 6)
		&"dry_meadow":
			return Vector2i(1, 3)
		&"badlands", &"rocky_scree", &"alpine_highlands":
			return Vector2i(0, 2)
		&"marsh":
			return Vector2i(0, 1)
		_:
			return Vector2i(2, 5)

func _rock_range_for_biome(biome: StringName) -> Vector2i:
	match biome:
		&"rocky_scree", &"alpine_highlands":
			return Vector2i(4, 8)
		&"badlands":
			return Vector2i(3, 6)
		&"dry_meadow":
			return Vector2i(1, 4)
		&"riverlands":
			return Vector2i(0, 2)
		&"marsh", &"cedar_swamp":
			return Vector2i(0, 1)
		_:
			return Vector2i(1, 3)

func _vegetation_scale(biome: StringName, rng: KimiDeterministic.RNG) -> float:
	var base := 0.78 + rng.randf() * 0.62
	match biome:
		&"cedar_swamp":
			base *= 0.88
		&"riverlands":
			base *= 0.92
		&"birch_grove":
			base *= 0.96
		&"alpine_highlands", &"rocky_scree":
			base *= 0.72
	return base

func _rock_scale(biome: StringName, rng: KimiDeterministic.RNG) -> float:
	var base := 0.65 + rng.randf() * 1.35
	if biome == &"rocky_scree" or biome == &"alpine_highlands":
		base *= 1.35
	elif biome == &"badlands":
		base *= 1.18
	return base
