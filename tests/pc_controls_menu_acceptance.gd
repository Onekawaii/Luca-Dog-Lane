extends SceneTree
func _initialize() -> void:
	OS.set_environment("SPIRAL_SKIP_TITLE", "1")
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_pc_menu_%d_{seed}.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_pc_menu_story_%d.json" % Time.get_ticks_usec())
	call_deferred("run")
func run() -> void:
	var world := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var probe: Node = load("res://scripts/systems/PCMenuAcceptanceProbe.gd").new()
	probe.world = world
	root.add_child(probe)
