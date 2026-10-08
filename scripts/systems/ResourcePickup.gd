extends RigidBody3D

var inventory: Node
var player: CharacterBody3D
var item_id := "stone"
var amount := 1
var launch_velocity := Vector3.ZERO
var age := 0.0

func _ready() -> void:
	add_to_group("terrain_pickup")
	mass = 0.28
	collision_layer = 8
	collision_mask = 1
	continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.20
	mesh_instance.mesh = mesh
	var kind := "grass" if item_id == "grass_block" else ("brick" if item_id == "stone_brick" else "stone")
	var material: StandardMaterial3D = load("res://scripts/systems/ObjectMaterials.gd").make(kind, Color.WHITE)
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.10
	collision.shape = shape
	add_child(collision)

	linear_velocity = launch_velocity

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	age += delta
	if global_position.y < -20.0:
		# Streaming/out-of-world escape must not erase mined resources.
		if inventory != null:
			inventory.call("add_item", item_id, amount)
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
