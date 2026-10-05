extends Node3D

const SITE_CENTER := Vector3(310.0, 18.0, 282.0)
const SITE_SIZE := Vector3(112.0, 44.0, 112.0)

var player: CharacterBody3D
var hud: CanvasLayer
var site_active := false
var discovery_count := 0

func _ready() -> void:
	_build_route()
	_build_discovery_area()

func set_hud(hud_node: CanvasLayer) -> void:
	hud = hud_node

func _build_route() -> void:
	_build_sign(
		"TrailSign_01",
		Vector3(175.0, 0.0, 142.0),
		"QUARRY RIDGE  >",
		Color(0.74, 0.81, 0.52)
	)
	_build_sign(
		"TrailSign_02",
		Vector3(244.0, 0.0, 214.0),
		"QUARRY RIDGE  >",
		Color(0.82, 0.72, 0.43)
	)
	_build_sign(
		"EntrySign",
		Vector3(272.0, 0.0, 244.0),
		"MINE  •  CRAFT  •  BUILD",
		Color(0.88, 0.67, 0.35)
	)

	for i in range(6):
		var t := float(i) / 5.0
		var point := Vector3(205.0, 0.0, 169.0).lerp(Vector3(270.0, 0.0, 240.0), t)
		_build_trail_post("TrailPost_%02d" % (i + 1), point)

func _build_discovery_area() -> void:
	var area := Area3D.new()
	area.name = "QuarryExpeditionArea"
	area.position = SITE_CENTER
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitoring = true
	area.monitorable = false

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = SITE_SIZE
	collision.shape = shape
	area.add_child(collision)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _build_sign(marker_name: String, at: Vector3, words: String, color: Color) -> void:
	var marker := Node3D.new()
	marker.name = marker_name
	marker.position = at
	add_child(marker)

	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.18, 2.4, 0.18)
	pole.mesh = pole_mesh
	pole.position.y = 1.2
	pole.material_override = _material(Color(0.22, 0.17, 0.10))
	marker.add_child(pole)

	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(4.9, 1.05, 0.18)
	board.mesh = board_mesh
	board.position.y = 2.55
	board.material_override = _material(Color(0.12, 0.14, 0.11))
	marker.add_child(board)

	var label := Label3D.new()
	label.add_to_group("world_sign")
	label.text = words
	label.position = Vector3(0.0, 2.55, 0.12)
	label.font_size = 42
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.add_child(label)

func _build_trail_post(marker_name: String, at: Vector3) -> void:
	var post := MeshInstance3D.new()
	post.name = marker_name
	post.position = at + Vector3.UP * 0.55
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.24, 1.1, 0.24)
	post.mesh = mesh
	post.material_override = _material(Color(0.72, 0.54, 0.24))
	add_child(post)

	var cap := MeshInstance3D.new()
	cap.position = at + Vector3.UP * 1.16
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.18
	cap_mesh.height = 0.36
	cap.mesh = cap_mesh
	cap.material_override = _material(Color(0.92, 0.72, 0.30))
	add_child(cap)

func _on_body_entered(body: Node3D) -> void:
	if body != player and not body.is_in_group("player"):
		return
	site_active = true
	discovery_count += 1
	if hud != null:
		hud.call(
			"flash",
			"QUARRY RIDGE // MINE stone  •  CRAFT brick  •  PLACE",
			4.0
		)

func _on_body_exited(body: Node3D) -> void:
	if body != player and not body.is_in_group("player"):
		return
	site_active = false
	if hud != null:
		hud.call("flash", "Leaving Quarry Ridge // materials stay with you", 2.2)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.90
	return material
