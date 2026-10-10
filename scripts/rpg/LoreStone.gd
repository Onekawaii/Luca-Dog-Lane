extends StaticBody3D

var director: Node
var record_id := ""
var record_label := "Road record"

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("rpg_record")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.33, 0.29)
	material.roughness = 0.95
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.5, 0.30)
	slab.mesh = box
	slab.position.y = 0.75
	slab.material_override = material
	add_child(slab)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	collision.position = slab.position
	add_child(collision)
	var label := Label3D.new()
	label.text = record_label + "\nREAD RECORD"
	label.font_size = 26
	label.pixel_size = 0.009
	label.position = Vector3(0.0, 1.05, 0.16)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.87, 0.81, 0.65)
	add_child(label)

func get_interaction_prompt() -> String:
	return "READ ROAD RECORD"

func interact(_player: Node = null) -> void:
	if is_instance_valid(director):
		director.call("open_record", record_id)
