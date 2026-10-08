extends RefCounted

const Materials = preload("res://scripts/systems/ObjectMaterials.gd")

static func rebuild_spiral(body: Node3D, color: Color, witness: bool) -> void:
	_clear(body)
	var points := PackedVector3Array()
	# One continuous expanding spiral, with an open center and readable silhouette.
	for i in range(161):
		var t := float(i) / 160.0
		var angle := t * TAU * 2.75
		var radius := 0.55 + t * 4.4
		points.append(Vector3(cos(angle) * radius, 1.2 + t * 5.0, sin(angle) * radius))
	_tube(body, "SpiralStone", points, 0.24, Materials.make("stone", Color(0.29, 0.28, 0.25)))
	var seam := PackedVector3Array()
	for p in points:
		seam.append(p + Vector3.UP * 0.24)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 0.8
	_tube(body, "SpiralVein", seam, 0.035, glow)
	_sphere(body, "DistantBeacon", Vector3(0, 9.0, 0), Vector3(0.28, 0.55, 0.28), glow)
	_sphere(body, "WitnessEye" if witness else "WailingCore", Vector3(0, 2.2, 0), Vector3(0.7, 0.45, 0.45), glow)
	var light := OmniLight3D.new()
	light.name = "FieldLight"
	light.position.y = 3.0
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 12.0
	body.add_child(light)

static func rebuild_cat(body: Node3D) -> void:
	_clear(body)
	var fur := Materials.make("fur", Color(0.34, 0.29, 0.23))
	var muzzle := Materials.make("fur", Color(0.70, 0.65, 0.54))
	_sphere(body, "Torso", Vector3(0, 0.7, 0.25), Vector3(0.40, 0.46, 0.80), fur)
	_sphere(body, "Chest", Vector3(0, 0.85, -0.25), Vector3(0.33, 0.48, 0.38), fur)
	_sphere(body, "Head", Vector3(0, 1.34, -0.40), Vector3(0.38, 0.33, 0.32), fur)
	for side in [-1.0, 1.0]:
		_sphere(body, "Muzzle", Vector3(side * 0.12, 1.23, -0.69), Vector3(0.14, 0.10, 0.10), muzzle)
		var ear := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18
		cone.height = 0.35
		cone.radial_segments = 3
		ear.mesh = cone
		ear.name = "Ear_L" if side < 0 else "Ear_R"
		ear.position = Vector3(side * 0.25, 1.66, -0.37)
		ear.scale.z = 0.45
		ear.rotation.z = side * -0.15
		ear.material_override = fur
		body.add_child(ear)
		var eye := Materials.make("metal", Color(0.55, 0.66, 0.18))
		_sphere(body, "Eye", Vector3(side * 0.19, 1.38, -0.675), Vector3(0.095, 0.075, 0.045), eye)
		_sphere(body, "Pupil", Vector3(side * 0.19, 1.38, -0.715), Vector3(0.019, 0.065, 0.012), Materials.make("stone", Color(0.025, 0.02, 0.02)))
		for z in [-0.38, 0.72]:
			var leg_id := (0 if side < 0.0 else 1) + (0 if z < 0.0 else 2)
			_sphere(body, "Leg_%02d" % leg_id, Vector3(side * 0.27, 0.36, z), Vector3(0.115, 0.36, 0.14), fur)
			_sphere(body, "Paw", Vector3(side * 0.27, 0.09, z - 0.07), Vector3(0.15, 0.10, 0.20), muzzle)
		for j in range(3):
			var points := PackedVector3Array([Vector3(side * 0.16, 1.23, -0.73), Vector3(side * 0.36, 1.23 + j * 0.04, -0.76), Vector3(side * 0.64, 1.19 + j * 0.09, -0.72)])
			_tube(body, "WhiskerTentacle_%02d" % (j + (0 if side < 0.0 else 3)), points, 0.006, muzzle)
	_sphere(body, "Nose", Vector3(0, 1.28, -0.77), Vector3(0.065, 0.044, 0.025), Materials.make("stone", Color(0.31, 0.13, 0.12)))
	var tail := PackedVector3Array()
	for i in range(25):
		var t := float(i) / 24.0
		tail.append(Vector3(sin(t * 2.7) * 0.42, 0.72 + t * 0.60, 0.92 + t * 0.7))
	_tube(body, "Tail_00", tail, 0.085, fur)

static func _clear(body: Node3D) -> void:
	for child in body.get_children():
		if child is MeshInstance3D or child is Light3D:
			body.remove_child(child)
			child.queue_free()

static func _sphere(body: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	part.mesh = mesh
	part.scale = size
	part.position = at
	part.material_override = material
	body.add_child(part)

static func _tube(body: Node3D, label: String, points: PackedVector3Array, radius: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var direction := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var axis := direction.cross(Vector3.UP).normalized()
		if axis.length_squared() < 0.01:
			axis = Vector3.RIGHT
		var other := direction.cross(axis).normalized()
		for j in range(8):
			var normal := axis * cos(j * TAU / 8.0) + other * sin(j * TAU / 8.0)
			surface.set_normal(normal)
			surface.set_uv(Vector2(float(j) / 8.0, float(i) / 8.0))
			surface.add_vertex(points[i] + normal * radius)
	for i in range(points.size() - 1):
		for j in range(8):
			var a := i * 8 + j
			var b := i * 8 + (j + 1) % 8
			for index in [a, b + 8, a + 8, a, b, b + 8]:
				surface.add_index(index)
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	part.material_override = material
	body.add_child(part)
