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
	var required := [
		"VoxelTerrain",
		"VoxelViewer",
		"VoxelGeneratorNoise2D",
		"VoxelMesherBlocky",
		"VoxelBlockyLibrary",
		"VoxelBlockyModelEmpty",
		"VoxelBlockyModelCube",
		"VoxelBuffer",
	]
	for type_name in required:
		if not ClassDB.class_exists(type_name):
			_fail("missing class: " + type_name)

	if not failures.is_empty():
		_finish()
		return

	var type_channel: int = ClassDB.class_get_integer_constant("VoxelBuffer", "CHANNEL_TYPE")
	if type_channel < 0:
		_fail("VoxelBuffer.CHANNEL_TYPE missing")
		_finish()
		return

	var library = ClassDB.instantiate("VoxelBlockyLibrary")
	var empty_model = ClassDB.instantiate("VoxelBlockyModelEmpty")
	var cube_model = ClassDB.instantiate("VoxelBlockyModelCube")
	cube_model.set("color", Color(0.42, 0.72, 0.38))
	library.call("add_model", empty_model)
	var solid_id: int = library.call("add_model", cube_model)
	library.call("bake")
	if solid_id <= 0:
		_fail("solid block model ID was not allocated")
	else:
		_pass("block library baked with air + solid model")

	var mesher = ClassDB.instantiate("VoxelMesherBlocky")
	mesher.set("library", library)

	var generator = ClassDB.instantiate("VoxelGeneratorNoise2D")
	var noise := FastNoiseLite.new()
	noise.seed = 130013
	noise.frequency = 0.025
	generator.set("noise", noise)
	generator.set("channel", type_channel)

	var terrain = ClassDB.instantiate("VoxelTerrain")
	terrain.name = "VoxelEditProofTerrain"
	terrain.set("generator", generator)
	terrain.set("mesher", mesher)
	terrain.set("max_view_distance", 48)
	terrain.set("generate_collisions", true)
	root.add_child(terrain)

	var viewer = ClassDB.instantiate("VoxelViewer")
	viewer.name = "VoxelEditProofViewer"
	viewer.set("view_distance", 32)
	viewer.set("requires_collisions", true)
	viewer.set("requires_visuals", true)
	viewer.position = Vector3(0, 4, 0)
	root.add_child(viewer)

	var tool = terrain.call("get_voxel_tool")
	tool.set("channel", type_channel)

	var edit_box := AABB(Vector3(-2, -2, -2), Vector3(5, 8, 5))
	var editable := false
	for i in range(360):
		await process_frame
		if bool(tool.call("is_area_editable", edit_box)):
			editable = true
			break

	if not editable:
		_fail("voxel area never became editable")
		_finish()
		return
	_pass("streamed voxel area became editable")

	var pos := Vector3i(1, 2, 1)
	var original: int = tool.call("get_voxel", pos)

	tool.call("set_voxel", pos, solid_id)
	var after_place: int = tool.call("get_voxel", pos)
	if after_place == solid_id:
		_pass("placed voxel is immediately authoritative")
	else:
		_fail("voxel placement readback mismatch")

	tool.call("set_voxel", pos, 0)
	var after_remove: int = tool.call("get_voxel", pos)
	if after_remove == 0:
		_pass("removed voxel reads back as air")
	else:
		_fail("voxel removal readback mismatch")

	tool.call("set_voxel", pos, original)
	var restored: int = tool.call("get_voxel", pos)
	if restored == original:
		_pass("test restores original voxel state")
	else:
		_fail("voxel state restoration failed")

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL VOXEL EDIT GATES PASSED]")
		quit(0)
	else:
		print("[VOXEL EDIT FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
