extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	var player: CharacterBody3D = game.get("player")
	var hud: CanvasLayer = game.get("hud")
	var expedition: Node = game.get("quarry_expedition")

	_check(player != null, "real game owns player")
	_check(hud != null, "real game owns HUD")
	_check(expedition != null, "real game owns Quarry Expedition controller")
	if player == null or hud == null or expedition == null:
		await _finish(game)
		return

	_check(expedition.has_node("QuarryExpeditionArea"), "site has a physical discovery volume")
	_check(expedition.has_node("TrailSign_01"), "route has first in-world quarry sign")
	_check(expedition.has_node("TrailSign_02"), "route has second in-world quarry sign")
	_check(not bool(expedition.get("site_active")), "site starts inactive away from quarry")

	player.global_position = Vector3(310.0, 3.0, 348.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.set("yaw", 0.0)
	player.call("set_touch_move", Vector2(0.0, -1.0))
	for i in range(180):
		await physics_frame
		if bool(expedition.get("site_active")):
			break
	player.call("set_touch_move", Vector2.ZERO)

	_check(bool(expedition.get("site_active")), "player enters Quarry Ridge through normal movement")
	_check(not bool(player.get("noclip")), "quarry entry does not require noclip")
	var status: Label = hud.get("status_label")
	_check(status != null and status.text.contains("QUARRY RIDGE"), "HUD identifies the discovered site")
	_check(player.global_position.z < 342.0, "player physically crossed the quarry approach")

	player.call("set_touch_move", Vector2(0.0, 1.0))
	for i in range(220):
		await physics_frame
		if not bool(expedition.get("site_active")):
			break
	player.call("set_touch_move", Vector2.ZERO)

	_check(not bool(expedition.get("site_active")), "player can leave Quarry Ridge normally")
	_check(not bool(player.get("noclip")), "quarry exit still uses normal collision movement")
	await _finish(game)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		failures.append(label)
		print("[FAIL] ", label)

func _finish(game: Node) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[ALL ENG-007 QUARRY EXPEDITION GATES PASSED]")
		quit(0)
	else:
		print("[ENG-007 QUARRY EXPEDITION FAILURES] ", failures.size())
		quit(1)
