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
	var save_path := "user://spiral_field_state_v1.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn missing")
		_finish()
		return

	var world := packed.instantiate()
	root.add_child(world)
	for _i in range(120):
		await physics_frame

	var director := world.get_node_or_null("SpiralWorldDirector")
	if director == null:
		_fail("SpiralWorldDirector missing")
		_finish()
		return

	var witness := director.get_node_or_null("Spiral_Witnessing")
	var wail := director.get_node_or_null("Spiral_Wailing")
	var tabby := director.get_node_or_null("Tabbytulhu")
	if witness != null and wail != null and tabby != null:
		_pass("Twin Spirals and Tabbytulhu exist in open world")
	else:
		_fail("required Spiral encounters missing")

	var before := str(director.call("status_summary"))
	var response := str(director.call("interact", witness, "act"))
	var after := str(director.call("status_summary"))
	if before != after and "ACT" in response and float(director.get("witnessing")) >= 7.0:
		_pass("ACT mutates authoritative Spiral state")
	else:
		_fail("ACT failed to mutate Spiral state")

	var mercy := str(director.call("interact", tabby, "mercy"))
	if "MERCY" in mercy and float(director.get("affection")) >= 5.0:
		_pass("MERCY/Spare changes Tabbytulhu relationship state")
	else:
		_fail("Tabbytulhu MERCY path failed")

	if FileAccess.file_exists(save_path):
		_pass("Spiral state persisted to versioned save")
	else:
		_fail("Spiral save file missing")

	var saved_witness := float(director.get("witnessing"))
	var saved_affection := float(director.get("affection"))
	world.queue_free()
	for _i in range(8):
		await physics_frame

	var world2 := packed.instantiate()
	root.add_child(world2)
	for _i in range(120):
		await physics_frame
	var director2 := world2.get_node_or_null("SpiralWorldDirector")
	if director2 != null and is_equal_approx(float(director2.get("witnessing")), saved_witness) and is_equal_approx(float(director2.get("affection")), saved_affection):
		_pass("save/reload restores Spiral world state")
	else:
		_fail("save/reload did not restore Spiral state")

	if director2 != null:
		director2.call("clear_state_for_test")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL SPIRAL FIELD V001 GATES PASSED]")
		quit(0)
	else:
		print("[SPIRAL FIELD V001 FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
