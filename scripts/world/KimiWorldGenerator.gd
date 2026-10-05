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
	var tree_count := rng.randi_range(2, 5)
	for n in tree_count:
		desc.vegetation_candidates.append({
			"id": "tree:%d:%d:%d:%d" % [plan.seed, coord.x, coord.y, n],
			"pos_x": origin.x + rng.randf() * size,
			"pos_z": origin.y + rng.randf() * size,
			"scale": 0.80 + rng.randf() * 0.65,
		})

	var rock_count := rng.randi_range(0, 2)
	for n in rock_count:
		desc.rock_candidates.append({
			"id": "rock:%d:%d:%d:%d" % [plan.seed, coord.x, coord.y, n],
			"pos_x": origin.x + rng.randf() * size,
			"pos_z": origin.y + rng.randf() * size,
			"scale": 0.70 + rng.randf() * 1.40,
			"rot_x": -10.0 + rng.randf() * 20.0,
			"rot_y": rng.randf() * 180.0,
			"rot_z": -10.0 + rng.randf() * 20.0,
		})

	desc.generation_hash = desc.compute_hash()
	return desc
