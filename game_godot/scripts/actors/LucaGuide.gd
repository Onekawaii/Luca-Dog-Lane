class_name LucaGuide
extends CharacterBody3D

@export var follow_speed := 3.8
@export var follow_distance := 5.0
@export var catchup_distance := 16.0

var _target: Node3D
var _sigh_index := 0
var _sigh_lines := [
	"Luca gives a long dramatic sigh and looks toward the trail.",
	"Luca leans into the scratch, then checks the road ahead.",
	"Luca thumps his tail once. Apparently that was sufficient.",
	"Luca sniffs the air and decides the world is still worth exploring.",
]

func set_target(target: Node3D) -> void:
	_target = target

func get_interaction_prompt() -> String:
	return "PET LUCA"

func interact(_player: Node = null) -> void:
	EventBus.notification_posted.emit(_sigh_lines[_sigh_index % _sigh_lines.size()])
	_sigh_index += 1
	_record_bond()
func _ready() -> void:
	_build_body()

func _physics_process(delta: float) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	if not is_instance_valid(_target):
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		move_and_slide()
		return
	var flat_delta := _target.global_position - global_position
	flat_delta.y = 0.0
	var distance := flat_delta.length()
	if distance > catchup_distance:
		global_position = _target.global_position - _target.global_transform.basis.z.normalized() * 4.0 + Vector3(0.0, 0.4, 0.0)
		velocity = Vector3.ZERO
		return
	if distance > follow_distance:
		var direction := flat_delta.normalized()
		velocity.x = direction.x * follow_speed
		velocity.z = direction.z * follow_speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 5.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 7.0 * delta)
	move_and_slide()
func _record_bond() -> void:
	if GameRuntime.world_state == null:
		return
	var luca_state: Dictionary = GameRuntime.world_state.world_state.get("luca", {})
	luca_state["bond"] = mini(100, int(luca_state.get("bond", 0)) + 1)
	luca_state["pets"] = int(luca_state.get("pets", 0)) + 1
	GameRuntime.world_state.world_state["luca"] = luca_state

func _build_body() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.82, 0.67, 0.38)
	fur.roughness = 0.92
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.09, 0.055)
	dark.roughness = 0.84
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.93, 0.82, 0.58)
	cream.roughness = 0.95

	_add_box("Torso", Vector3(0.78, 0.72, 1.35), Vector3(0.0, 0.78, 0.0), fur)
	_add_box("Chest", Vector3(0.64, 0.74, 0.62), Vector3(0.0, 0.86, -0.62), cream)
	_add_sphere("Head", 0.46, Vector3(0.0, 1.34, -0.78), fur)
	_add_box("Muzzle", Vector3(0.44, 0.30, 0.46), Vector3(0.0, 1.22, -1.12), cream)
	_add_sphere("Nose", 0.11, Vector3(0.0, 1.28, -1.36), dark)
	for side in [-1.0, 1.0]:
		_add_box("Ear", Vector3(0.19, 0.48, 0.18), Vector3(0.31 * side, 1.40, -0.76), dark, Vector3(0.0, 0.0, deg_to_rad(12.0 * side)))
		_add_box("FrontLeg", Vector3(0.20, 0.68, 0.22), Vector3(0.28 * side, 0.38, -0.48), fur)
		_add_box("BackLeg", Vector3(0.22, 0.68, 0.24), Vector3(0.30 * side, 0.38, 0.47), fur)
		_add_sphere("Eye", 0.055, Vector3(0.18 * side, 1.45, -1.14), dark)
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.08
	tail_mesh.bottom_radius = 0.13
	tail_mesh.height = 0.82
	tail.mesh = tail_mesh
	tail.position = Vector3(0.0, 0.95, 0.94)
	tail.rotation_degrees.x = 58.0
	tail.material_override = fur
	add_child(tail)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.25
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.68, 0.0)
	add_child(collision)
	var tag := Label3D.new()
	tag.name = "LucaTag"
	tag.text = "LUCA"
	tag.position = Vector3(0.0, 1.95, 0.0)
	tag.font_size = 28
	tag.modulate = Color(1.0, 0.90, 0.62)
	add_child(tag)

func _add_box(node_name: String, size: Vector3, pos: Vector3, material: StandardMaterial3D, rotation_radians: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation = rotation_radians
	mesh.material_override = material
	add_child(mesh)

func _add_sphere(node_name: String, radius: float, pos: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.position = pos
	mesh.material_override = material
	add_child(mesh)
