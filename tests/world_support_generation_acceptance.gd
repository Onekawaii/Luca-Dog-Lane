extends SceneTree

const Guard = preload("res://scripts/world/WorldStreamGuard.gd")
const Identity = preload("res://scripts/world/SessionWorld.gd")
const Bounds = preload("res://scripts/world/WorldBounds.gd")
var failures: Array[String] = []

class FallingBody extends CharacterBody3D:
	func _physics_process(delta: float) -> void:
		velocity.y -= 9.8 * delta
		move_and_slide()

class FloorResult extends RefCounted:
	var y := -1
	func get_position() -> Vector3i:
		return Vector3i(0, y, 0)

class VoxelStub extends RefCounted:
	var loaded := false
	var column_loaded := true
	var result: RefCounted = FloorResult.new()
	func is_area_editable(_area: AABB) -> bool:
		return loaded and (column_loaded or _area.size.y < 8.0)
	func raycast(from: Vector3, _direction: Vector3, distance: float):
		return result if loaded and result != null and from.y - result.y <= distance else null

class Slice extends "res://scripts/world/TerrainSlice.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("_verify")

func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		printerr("FAIL: " + detail)

func frames(count: int) -> void:
	for _i in count:
		await physics_frame

func _verify() -> void:
	var index_path := "user://support_generation_%d.json" % Time.get_ticks_usec()
	var identity := Identity.new()
	check(identity.configure(index_path), "isolated identity configured")
	var first: Dictionary = identity.identity("first", 6060, false)
	var second: Dictionary = identity.new_world("first", int(first.seed))
	check(first.seed != second.seed, "new world chooses a different seed")
	var reopened := Identity.new()
	check(reopened.configure(index_path), "identity reloaded")
	check(reopened.identity("first", 6060, false) == second, "continue retains exact seed and generator version")
	check(reopened.identity("legacy", 3184, true) == {"seed": 3184, "generation_version": 1}, "legacy geography remains version one")
	var terrain_path := "user://terrain_support_%d_{seed}.json" % Time.get_ticks_usec()
	var edited := Slice.new()
	edited.world_voxels = true
	edited.generation_version = 2
	edited.world_seed = int(first.seed)
	edited.save_path_override = terrain_path
	root.add_child(edited)
	edited._setup_persistence()
	edited.persistence.call("set_voxel_delta", Vector3i(1, 1, 1), 0)
	check(edited.persistence.call("save_now"), "previous terrain progress flushed")
	var archive_path: String = edited.persistence.get("save_path")
	edited.free()
	var continued := Slice.new()
	continued.world_voxels = true
	continued.generation_version = 2
	continued.world_seed = int(first.seed)
	continued.save_path_override = terrain_path
	root.add_child(continued)
	continued._setup_persistence()
	check(continued.persistence.call("get_voxel_deltas").has("1,1,1"), "continue reconstructs previous terrain edits")
	continued.free()
	var fresh := Slice.new()
	fresh.world_voxels = true
	fresh.generation_version = 2
	fresh.world_seed = int(second.seed)
	fresh.save_path_override = terrain_path
	root.add_child(fresh)
	fresh._setup_persistence()
	check(fresh.persistence.call("get_voxel_deltas").is_empty(), "new world starts without previous edits")
	check(FileAccess.file_exists(archive_path), "new world keeps previous terrain save")
	fresh.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive_path))
	var macro_a := MacroTerrain.new()
	var macro_b := MacroTerrain.new()
	var macro_c := MacroTerrain.new()
	macro_a.world_plan = KimiWorldPlan.new(11111, 2)
	macro_b.world_plan = KimiWorldPlan.new(11111, 2)
	macro_c.world_plan = KimiWorldPlan.new(22222, 2)
	var different := 0
	for x in [-400.0, -300.0, -150.0, 150.0, 300.0, 400.0]:
		for z in [-400.0, -250.0, 150.0, 300.0, 400.0]:
			check(macro_a.height_at(x, z) == macro_b.height_at(x, z), "same seed reproduces physical geometry")
			if absf(macro_a.height_at(x, z) - macro_c.height_at(x, z)) > 1.0:
				different += 1
	check(different >= 8, "different seeds change substantial geometry, not only metadata")
	macro_a.free()
	macro_b.free()
	macro_c.free()
	var player := CharacterBody3D.new()
	root.add_child(player)
	var slice := Slice.new()
	slice.player = player
	slice.world_voxels = true
	slice.active_bounds = AABB(Vector3(-480, -16, -480), Vector3(960, 128, 960))
	var voxels := VoxelStub.new()
	slice.voxel_tool = voxels
	root.add_child(slice)
	check(not slice._is_editable(Vector3i(0, -16, 0)), "bedrock refuses mining, blast and replay writes")
	var body := FallingBody.new()
	body.position = Vector3(0, 2, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	root.add_child(body)
	var guard := Guard.new()
	guard.slice = slice
	body.add_child(guard)
	await frames(90)
	check(body.position.y == 2.0 and guard.paused, "unloaded terrain cannot start gravity")
	voxels.loaded = true
	voxels.result = null
	await frames(20)
	check(body.position.y == 2.0 and guard.paused, "null voxel ray and absent collision remain paused")
	voxels.result = FloorResult.new()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 1, 12)
	floor_shape.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	await frames(90)
	check(body.is_on_floor() and not guard.paused, "collision-ready body settles onto its floor")
	var settled_y := body.position.y
	player.position.x = 160.0
	floor_body.queue_free()
	await frames(90)
	check(is_equal_approx(body.position.y, settled_y) and guard.paused, "remote parked object retains position after collision unload")
	player.position.x = 0.0
	await frames(30)
	check(is_equal_approx(body.position.y, settled_y) and guard.paused, "approach cannot resume gravity before collision")
	body.position.y = -18.0
	await frames(2)
	check(body.position.y > Bounds.BEDROCK_TOP, "already stranded actor escapes below-bedrock trap")
	var fixed := RigidBody3D.new()
	fixed.freeze = true
	root.add_child(fixed)
	var fixed_guard := Guard.new()
	fixed_guard.slice = slice
	fixed.add_child(fixed_guard)
	fixed_guard._resume()
	check(fixed.freeze, "guard preserves intentional frozen state")
	fixed_guard._pause()
	fixed_guard.request_freeze(false)
	check(fixed.freeze, "release during suspension cannot enable unsupported gravity")
	fixed_guard._resume()
	check(not fixed.freeze, "release is remembered when support resumes")
	fixed_guard._pause()
	fixed_guard.request_freeze(true)
	fixed_guard._resume()
	check(fixed.freeze, "holding survives a support suspension cycle")
	var bottom := StaticBody3D.new()
	bottom.add_to_group("world_bedrock")
	var bottom_shape := CollisionShape3D.new()
	var bottom_box := BoxShape3D.new()
	bottom_box.size = Vector3(12, 2, 12)
	bottom_shape.shape = bottom_box
	bottom.position.y = -16.0
	bottom.add_child(bottom_shape)
	root.add_child(bottom)
	body.position.y = 40.0
	voxels.result = FloorResult.new()
	voxels.result.y = -16
	voxels.column_loaded = false
	await frames(3)
	check(not slice.physics_support_ready(body) and guard.paused, "cached bedrock cannot substitute for unloaded blocks above it")
	voxels.column_loaded = true
	voxels.result = null
	await frames(3)
	check(slice.physics_support_ready(body) and not guard.paused, "fully loaded deep empty column allows descent to distant bedrock")
	await frames(240)
	check(body.is_on_floor(), "deep fall lands above permanent bottom")
	var dog = load("res://scripts/Luca.gd").new()
	dog.player = player
	dog.position = Vector3(200, 2, 0)
	root.add_child(dog)
	var dog_guard := Guard.new()
	dog_guard.slice = slice
	dog.add_child(dog_guard)
	await frames(2)
	check(dog.position.distance_to(player.position) < 16.0, "following companion recovers while physics is suspended")
	dog.follow_enabled = false
	dog.position.x = 200.0
	await frames(2)
	check(dog.position.x == 200.0, "STAY companion remains parked")
	var director = load("res://scripts/systems/SpiralWorldDirector.gd").new()
	var game = load("res://scripts/Game.gd").new()
	game.generation_version = 2
	game.world_seed = 11111
	game.active_map_id = "first"
	director.game = game
	var old_path: String = director.state_save_path()
	game.world_seed = 22222
	check(old_path != director.state_save_path(), "fresh world isolates story progress")
	game.generation_version = 1
	check(director.state_save_path() == director.SAVE_PATH, "legacy story path remains unchanged")
	director.free()
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(index_path))
	print("WORLD SUPPORT / GENERATION: %d failures; %d varied samples" % [failures.size(), different])
	quit(0 if failures.is_empty() else 1)
