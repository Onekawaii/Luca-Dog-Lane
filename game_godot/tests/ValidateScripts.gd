extends SceneTree

var checked := 0
var failures := 0

func _initialize() -> void:
	_scan("res://scripts")
	print("[SCRIPT-CHECK] parsed %d GDScript files" % checked)
	if failures > 0:
		printerr("[SCRIPT-CHECK] %d script(s) failed to load" % failures)
		quit(1)
		return
	print("[SCRIPT-CHECK] all scripts parsed successfully")
	quit(0)

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		printerr("[SCRIPT-CHECK] cannot open %s" % path)
		failures += 1
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := path.path_join(name)
			if dir.current_is_dir():
				_scan(child)
			elif name.ends_with(".gd"):
				checked += 1
				if load(child) == null:
					printerr("[SCRIPT-CHECK] failed: %s" % child)
					failures += 1
		name = dir.get_next()
	dir.list_dir_end()
