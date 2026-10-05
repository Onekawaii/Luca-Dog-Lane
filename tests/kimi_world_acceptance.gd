extends SceneTree

var failed := false

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failed = true
		printerr("FAIL: ", label)

func _init() -> void:
	var plan := KimiWorldPlan.new(6060)
	var generator := KimiWorldGenerator.new(plan)
	var a := generator.describe_chunk(Vector2i(0, 0))
	var again := generator.describe_chunk(Vector2i(0, 0))
	var east := generator.describe_chunk(Vector2i(1, 0))
	var north := generator.describe_chunk(Vector2i(0, 1))
	var other_seed := KimiWorldGenerator.new(KimiWorldPlan.new(6061)).describe_chunk(Vector2i(0, 0))

	check(a.generation_hash == again.generation_hash, "same seed + coord gives same descriptor hash")
	check(a.generation_hash != other_seed.generation_hash, "changing seed changes descriptor hash")
	check(a.corner_heights[1] == east.corner_heights[0], "east border south corner is continuous")
	check(a.corner_heights[3] == east.corner_heights[2], "east border north corner is continuous")
	check(a.corner_heights[2] == north.corner_heights[0], "north border west corner is continuous")
	check(a.corner_heights[3] == north.corner_heights[1], "north border east corner is continuous")

	var ids := {}
	for item in a.vegetation_candidates + a.rock_candidates:
		var item_id := str(item["id"])
		check(not ids.has(item_id), "candidate id unique: " + item_id)
		ids[item_id] = true

	var original_hash := a.compute_hash()
	a.rock_candidates.append({"id": "mutation-proof", "scale": 1.0})
	check(a.compute_hash() != original_hash, "descriptor hash covers generated content")

	var h1 := plan.terrain_height(310.0, 282.0)
	var h2 := plan.terrain_height(310.0, 282.0)
	check(h1 == h2, "world-coordinate terrain sampling is deterministic")

	if failed:
		quit(1)
	print("KIMI_WORLD_ACCEPTANCE_OK hash=", again.generation_hash, " height=", h1)
	quit(0)
