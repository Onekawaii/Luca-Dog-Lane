extends Node3D

# Presentation only: no collider, inventory, or gameplay ownership.
var tool_id := ""
var swing := 0.0
var icon: ImageTexture

func equip(id: String) -> void:
	tool_id = id
	for child in get_children():
		remove_child(child)
		child.queue_free()
	position = Vector3(0.34, -0.29, -0.65)
	rotation = Vector3(0.12, -0.25, -0.12)
	scale = Vector3.ONE * 0.7
	var wood := Color(0.40, 0.22, 0.09)
	var steel := Color(0.48, 0.53, 0.57)
	_piece("Hand", Vector3(0, -0.12, 0.07), Vector3(0.12, 0.18, 0.15), Color(0.53, 0.34, 0.23))
	match id:
		"field_hammer":
			_piece("WoodHandle", Vector3.ZERO, Vector3(0.055, 0.42, 0.055), wood)
			_piece("SteelHead", Vector3(0, 0.23, 0), Vector3(0.28, 0.12, 0.12), steel, true)
		"mine":
			_piece("WoodHandle", Vector3.ZERO, Vector3(0.055, 0.44, 0.055), wood)
			_piece("PickHead", Vector3(0, 0.23, 0), Vector3(0.43, 0.06, 0.065), steel, true)
		"place":
			_piece("StoneBrick", Vector3(0, 0.05, 0), Vector3(0.24, 0.18, 0.16), Color(0.49, 0.46, 0.40))
		"inspect":
			_piece("Scanner", Vector3(0, 0.06, 0), Vector3(0.16, 0.24, 0.06), steel, true)
			_piece("Screen", Vector3(0, 0.10, 0.034), Vector3(0.12, 0.12, 0.01), Color(0.10, 0.72, 0.63))
		"craft":
			_piece("WrenchHandle", Vector3.ZERO, Vector3(0.06, 0.34, 0.04), steel, true)
			for side in [-1.0, 1.0]:
				_piece("WrenchJaw", Vector3(side * 0.065, 0.2, 0), Vector3(0.05, 0.13, 0.04), steel, true)
		"duplicate":
			_piece("Stamp", Vector3.ZERO, Vector3(0.06, 0.3, 0.06), wood)
			_piece("StampBase", Vector3(0, -0.08, 0), Vector3(0.19, 0.06, 0.15), steel, true)
		"remove":
			_piece("Cutter", Vector3.ZERO, Vector3(0.06, 0.34, 0.06), Color(0.72, 0.18, 0.10))
			_piece("Blade", Vector3(0, 0.22, 0), Vector3(0.13, 0.10, 0.025), steel, true)
		_:
			_piece("Glove", Vector3(0, 0.06, 0), Vector3(0.15, 0.23, 0.10), Color(0.35, 0.31, 0.22))
	icon = _make_icon(id)

func use_animation() -> void:
	swing = 0.32

func _process(delta: float) -> void:
	swing = maxf(0.0, swing - delta)
	rotation.x = 0.12 - sin(swing / 0.32 * PI) * 0.65
	var player := get_parent().get_parent().get_parent()
	visible = player.get("riding") == null

func _piece(label: String, at: Vector3, size: Vector3, color: Color, metallic := false) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	var kind := "metal" if metallic else ("wood" if label == "WoodHandle" or label == "Stamp" else "fabric")
	if label == "StoneBrick":
		kind = "brick"
	var material: StandardMaterial3D = load("res://scripts/systems/ObjectMaterials.gd").make(kind, color)
	material.metallic = 0.85 if metallic else 0.0
	material.roughness = 0.35 if metallic else 0.82
	if label == "Hand" or label == "Screen":
		material.albedo_texture = null
		material.normal_enabled = false
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)

func _make_icon(id: String) -> ImageTexture:
	var picture := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.05, 0.07, 0.08, 0.92))
	# Silhouettes match the held object, not arbitrary letters or emoji.
	var shapes: Array[Rect2i] = []
	match id:
		"field_hammer": shapes = [Rect2i(21, 15, 6, 27), Rect2i(10, 8, 28, 12)]
		"mine": shapes = [Rect2i(21, 14, 6, 28), Rect2i(5, 9, 38, 5)]
		"place": shapes = [Rect2i(8, 13, 32, 22)]
		"inspect": shapes = [Rect2i(14, 6, 20, 36), Rect2i(18, 10, 12, 16)]
		"craft": shapes = [Rect2i(21, 19, 6, 23), Rect2i(12, 6, 6, 19), Rect2i(30, 6, 6, 19), Rect2i(12, 20, 24, 6)]
		"duplicate": shapes = [Rect2i(20, 6, 8, 24), Rect2i(9, 30, 30, 9)]
		"remove": shapes = [Rect2i(20, 20, 8, 22), Rect2i(15, 7, 18, 14)]
		_: shapes = [Rect2i(15, 20, 22, 20), Rect2i(15, 8, 5, 20), Rect2i(22, 6, 5, 20), Rect2i(29, 10, 5, 20), Rect2i(8, 23, 8, 9)]
	for rect in shapes:
		picture.fill_rect(rect, Color(0.80, 0.77, 0.62))
	return ImageTexture.create_from_image(picture)
