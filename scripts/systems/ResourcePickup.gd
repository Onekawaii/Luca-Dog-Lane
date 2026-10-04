extends RigidBody3D

var inventory: Node
var player: CharacterBody3D
var item_id := "stone"
var amount := 1
var launch_velocity := Vector3.ZERO
var age := 0.0

func _ready() -> void:
	mass = 0.28
	collision_layer = 8
	collision_mask = 1
	continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.52, 0.56, 0.53)
	material.roughness = 0.95
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	collision.shape = shape
	add_child(collision)

	linear_velocity = launch_velocity

func _physics_process(delta: float) -> void:
	age += delta
	if global_position.y < -20.0:
		queue_free()
		return
	if age < 0.15 or player == null or inventory == null:
		return
	if global_position.distance_to(player.global_position + Vector3.UP * 0.8) > 1.55:
		return

	inventory.call("add_item", item_id, amount)
	var player_hud = player.get("hud")
	if player_hud != null:
		player_hud.call("flash", "+%d %s // %s" % [amount, item_id.to_upper(), inventory.call("summary")], 1.5)
	queue_free()
