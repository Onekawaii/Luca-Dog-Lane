extends Node3D

# Bounded local feedback; base materials remain untouched.
var overlay: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var timer := 0.0
var scars: Node3D

func _ready() -> void:
	overlay = StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(1.0, 0.16, 0.05, 0.0)
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_collect(get_parent())
	scars = Node3D.new()
	scars.name = "VisibleDamage"
	add_child(scars)

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child != self:
			_collect(child)

func hit(health: float, maximum: float, vehicle := false, source := Vector3.ZERO) -> void:
	timer = 0.32
	for mesh in meshes:
		mesh.material_overlay = overlay
	if scars.get_child_count() >= 8:
		return
	var mark := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.24, 0.12, 0.015) if not vehicle else Vector3(0.45, 0.18, 0.025)
	mark.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.045, 0.025) if not vehicle else Color(0.08, 0.055, 0.035)
	material.roughness = 0.97
	mark.material_override = material
	var index := scars.get_child_count()
	var local_source := to_local(source)
	var outward := Vector3(0, 0, -1)
	if source != Vector3.ZERO and Vector2(local_source.x, local_source.z).length() > 0.1:
		outward = Vector3(signf(local_source.x), 0, 0) if absf(local_source.x) > absf(local_source.z) else Vector3(0, 0, signf(local_source.z))
	var radius := Vector3(1.24, 0, 2.015) if vehicle else Vector3(0.37, 0, 0.207)
	mark.position = outward * radius
	mark.position.y = (0.70 if vehicle else 1.14) + (index / 3) * 0.13
	mark.position += outward.cross(Vector3.UP) * (index % 3 - 1) * (0.25 if vehicle else 0.13)
	mark.rotation.y = atan2(outward.x, outward.z)
	scars.add_child(mark)
	set_meta("health_fraction", health / maximum)

func _process(delta: float) -> void:
	timer = maxf(timer - delta, 0.0)
	overlay.albedo_color.a = timer / 0.32 * 0.65
	if timer == 0.0:
		for mesh in meshes:
			mesh.material_overlay = null
