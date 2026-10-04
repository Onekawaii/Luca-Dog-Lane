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
	var required_classes := [
		"VoxelTerrain",
		"VoxelViewer",
		"VoxelMesherBlocky",
		"VoxelBlockyLibrary",
		"VoxelBlockyModelCube",
		"VoxelTool",
		"VoxelBuffer",
	]

	for type_name in required_classes:
		if ClassDB.class_exists(type_name):
			_pass("class available: " + type_name)
		else:
			_fail("class missing: " + type_name)

	if failures.is_empty():
		var terrain = ClassDB.instantiate("VoxelTerrain")
		if terrain == null:
			_fail("VoxelTerrain instantiation failed")
		else:
			_pass("VoxelTerrain can be instantiated")
			terrain.free()

	if failures.is_empty():
		print("[ALL VOXEL EXTENSION GATES PASSED]")
		quit(0)
	else:
		print("[VOXEL EXTENSION FAILURES] ", failures.size())
		quit(1)
