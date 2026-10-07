class_name EggHunt
extends Node3D

var player: CharacterBody3D
var hud: CanvasLayer
var macro_terrain: MacroTerrain
var found: Dictionary = {}
var egg_nodes: Dictionary = {}

const EGG_MESSAGES := [
	"THE HILL WAS LISTENING",
	"FRIED BUT UNBROKEN",
	"THE PASS REMEMBERS YOUR TIRES",
	"NO CHICKEN CLAIMS THIS ONE",
	"VALLEY YOLK // BAD OMEN",
	"FOUND UNDER IMPOSSIBLE GEOLOGY",
	"WORKSHOP BREAKFAST CONTRABAND",
	"PLAZA EGG // CIVIC PROPERTY",
	"SKATE EGG // DO NOT GRIND",
	"RIDGE EGG // WIND CHILLED",
	"THE DOG DID NOT HIDE THIS",
	"LAST EGG // PROBABLY",
	"BREAKFAST OF THE NORTH",
	"SCRAMBLED SIGNAL",
	"EGG OF UNAUTHORIZED ALTITUDE",
	"THE RIDGE OWES YOU NOTHING",
	"ROAD SHOULDER OMELET",
	"UNDER EASY SKY",
	"THE SHELL KNOWS 6060",
	"WESTERN YOLK INCIDENT",
	"NO FORK PROVIDED",
	"SECOND-TO-LAST EGG // MAYBE",
	"LUCA SNIFFED THIS ONE",
	"TWENTY FOURTH BREAKFAST",
]

func _ready() -> void:
	_spawn_all()
	print("EGG_HUNT_READY total=", EGG_MESSAGES.size())

func total_eggs() -> int:
	return EGG_MESSAGES.size()

func found_eggs() -> int:
	return found.size()

func _spawn_all() -> void:
	var positions := [
		_surface_position(-122.0, -372.0),
		_surface_position(128.0, -354.0),
		_surface_position(-205.0, -318.0),
		_surface_position(205.0, -324.0),
		_surface_position(-372.0, -138.0),
		_surface_position(-358.0, 155.0),
		Vector3(68.0, 9.25, 70.0),
		Vector3(-235.0, 1.15, -205.0),
		Vector3(-95.0, 5.05, 96.0),
		_surface_position(-118.0, 380.0),
		_surface_position(122.0, 374.0),
		_surface_position(-304.0, 215.0),
		_surface_position(238.0, -402.0),
		_surface_position(-248.0, -400.0),
		_surface_position(330.0, -288.0),
		_surface_position(-405.0, 286.0),
		_surface_position(346.0, 108.0),
		_surface_position(176.0, 414.0),
		_surface_position(-176.0, 421.0),
		_surface_position(-420.0, -246.0),
		_surface_position(412.0, -176.0),
		_surface_position(392.0, 268.0),
		_surface_position(-270.0, 332.0),
		_surface_position(284.0, 392.0),
	]
	for i in range(positions.size()):
		_spawn_egg(i, positions[i], EGG_MESSAGES[i])

func _surface_position(x: float, z: float) -> Vector3:
	var y := 0.0
	if macro_terrain != null:
		y = macro_terrain.rendered_height_at(x, z)
	return Vector3(x, y + 1.05, z)

func _spawn_egg(index: int, at: Vector3, message: String) -> void:
	var area := Area3D.new()
	area.name = "Egg_%02d" % (index + 1)
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitoring = true
	area.monitorable = false
	area.add_to_group("easter_egg")
	area.set_meta("egg_index", index)
	area.set_meta("egg_message", message)

	var white := MeshInstance3D.new()
	white.name = "White"
	var white_mesh := SphereMesh.new()
	white_mesh.radius = 0.62
	white_mesh.height = 0.90
	white.mesh = white_mesh
	white.scale = Vector3(1.22, 0.16, 1.0)
	white.material_override = _material(Color(0.96, 0.94, 0.82), 0.82)
	area.add_child(white)

	var yolk := MeshInstance3D.new()
	yolk.name = "Yolk"
	var yolk_mesh := SphereMesh.new()
	yolk_mesh.radius = 0.25
	yolk_mesh.height = 0.40
	yolk.mesh = yolk_mesh
	yolk.position.y = 0.18
	yolk.material_override = _material(Color(1.0, 0.61, 0.06), 0.64)
	area.add_child(yolk)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.88
	collision.shape = shape
	area.add_child(collision)

	area.rotation.y = float(index) * 0.71
	area.body_entered.connect(_on_egg_entered.bind(area, index, message))
	add_child(area)
	egg_nodes[index] = area

func _on_egg_entered(body: Node3D, egg: Area3D, index: int, message: String) -> void:
	if body != player and not body.is_in_group("player"):
		return
	_collect(egg, index, message)

func collect_for_test(index: int) -> bool:
	if not egg_nodes.has(index):
		return false
	var egg = egg_nodes[index]
	if egg == null or not is_instance_valid(egg):
		return false
	_collect(egg, index, str(egg.get_meta("egg_message", "")))
	return true

func _collect(egg: Area3D, index: int, message: String) -> void:
	if found.has(index):
		return
	found[index] = true
	egg_nodes.erase(index)
	egg.monitoring = false
	egg.queue_free()
	var count := found.size()
	print("EASTER_EGG_FOUND index=", index, " count=", count, "/", total_eggs(), " message=", message)
	if hud != null:
		hud.call("flash", "EGG %d/%d // %s" % [count, total_eggs(), message], 3.0)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
