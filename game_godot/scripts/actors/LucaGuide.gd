class_name LucaGuide
extends CharacterBody3D

const BrainClass = preload("res://scripts/luca/LucaCompanionBrain.gd")

@export var follow_speed := 3.8
@export var follow_distance := 5.0
@export var catchup_distance := 16.0

var _target: Node3D
var _sigh_index := 0
var _tail: MeshInstance3D
var _brain = BrainClass.new()
var _investigate_until_msec := 0
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
	_investigate_until_msec = Time.get_ticks_msec() + 1800
	_record_bond()

func companion_state_name() -> String:
	return _brain.state_name()

func _ready() -> void:
	_build_body()

func _physics_process(delta: float) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	if not is_instance_valid(_target):
		_brain.choose_state(0.0, false, false, false)
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		move_and_slide()
		return

	var flat_delta := _target.global_position - global_position
	flat_delta.y = 0.0
	var distance := flat_delta.length()
	var interest_nearby := Time.get_ticks_msec() < _investigate_until_msec
	var state: int = int(_brain.choose_state(distance, true, interest_nearby, false))

	if state == BrainClass.State.RECOVER:
		global_position = _target.global_position - _target.global_transform.basis.z.normalized() * 4.0 + Vector3(0.0, 0.4, 0.0)
		velocity = Vector3.ZERO
		return
	if state == BrainClass.State.FOLLOW:
		var direction := flat_delta.normalized()
		velocity.x = direction.x * follow_speed
		velocity.z = direction.z * follow_speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 5.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 7.0 * delta)
	move_and_slide()
	if is_instance_valid(_tail):
		var wag_scale := 1.7 if state == BrainClass.State.INVESTIGATE else 1.0
		_tail.rotation.z = sin(Time.get_ticks_msec() * 0.0065) * 0.32 * wag_scale

func _record_bond() -> void:
	if GameRuntime.world_state == null:
		return
	var luca_state: Dictionary = GameRuntime.world_state.world_state.get("luca", {})
	luca_state["bond"] = mini(100, int(luca_state.get("bond", 0)) + 1)
	luca_state["pets"] = int(luca_state.get("pets", 0)) + 1
	GameRuntime.world_state.world_state["luca"] = luca_state

func _build_body() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.80, 0.62, 0.28)
	fur.roughness = 0.96
	var light_fur := StandardMaterial3D.new()
	light_fur.albedo_color = Color(0.91, 0.78, 0.48)
	light_fur.roughness = 0.97
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.055, 0.043, 0.028)
	dark.roughness = 0.82
	var collar := StandardMaterial3D.new()
	collar.albedo_color = Color(0.08, 0.28, 0.46)
	collar.metallic = 0.12
	collar.roughness = 0.58

	_add_ellipsoid("Torso", 0.62, Vector3(0.0, 0.86, 0.02), fur, Vector3(0.86, 0.78, 1.55))
	_add_ellipsoid("Chest", 0.46, Vector3(0.0, 0.94, -0.60), light_fur, Vector3(0.86, 1.05, 0.82))
	_add_ellipsoid("Head", 0.44, Vector3(0.0, 1.43, -0.83), fur, Vector3(0.93, 1.02, 0.88))
	_add_ellipsoid("Muzzle", 0.28, Vector3(0.0, 1.29, -1.16), light_fur, Vector3(1.10, 0.72, 1.18))
	_add_ellipsoid("Nose", 0.105, Vector3(0.0, 1.32, -1.40), dark, Vector3(1.08, 0.82, 0.92))
	_add_capsule("Collar", 0.37, 0.16, Vector3(0.0, 1.15, -0.66), collar, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_add_ellipsoid("Ear", 0.24, Vector3(0.32 * side, 1.43, -0.78), fur, Vector3(0.52, 1.30, 0.38), Vector3(0.0, 0.0, deg_to_rad(18.0 * side)))
		_add_capsule("FrontLeg", 0.11, 0.72, Vector3(0.25 * side, 0.43, -0.48), fur)
		_add_capsule("BackLeg", 0.13, 0.76, Vector3(0.30 * side, 0.43, 0.50), fur)
		_add_ellipsoid("Paw", 0.14, Vector3(0.25 * side, 0.08, -0.51), light_fur, Vector3(1.08, 0.58, 1.35))
		_add_ellipsoid("RearPaw", 0.15, Vector3(0.30 * side, 0.08, 0.53), light_fur, Vector3(1.10, 0.58, 1.28))
		_add_ellipsoid("Eye", 0.052, Vector3(0.17 * side, 1.52, -1.15), dark, Vector3(1.0, 1.0, 0.72))

	_tail = MeshInstance3D.new()
	_tail.name = "Tail"
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.045
	tail_mesh.bottom_radius = 0.12
	tail_mesh.height = 0.95
	_tail.mesh = tail_mesh
	_tail.position = Vector3(0.0, 0.94, 0.98)
	_tail.rotation_degrees.x = 68.0
	_tail.material_override = fur
	add_child(_tail)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.44
	capsule.height = 1.24
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.66, 0.0)
	add_child(collision)


func _add_ellipsoid(node_name: String, radius: float, pos: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.position = pos
	mesh.scale = scale_value
	mesh.rotation = rot
	mesh.material_override = material
	add_child(mesh)


func _add_capsule(node_name: String, radius: float, height: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh.mesh = capsule
	mesh.position = pos
	mesh.rotation = rot
	mesh.material_override = material
	add_child(mesh)
