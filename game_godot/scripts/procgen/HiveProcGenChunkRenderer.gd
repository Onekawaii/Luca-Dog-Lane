class_name HiveProcGenChunkRenderer
extends Node3D

# Materializes the first playable slice of hive_procgen_world_v1. The authored
# Breakroom remains the origin; generated cells extend through its east portal.

const LOCAL_CELL_SIZE := 32.0
const ACTIVE_RADIUS := 1
const WARM_RADIUS := 2

var world_plan: Dictionary = {}
var active_cells: Dictionary = {}
var warm_cells: Dictionary = {}
var slice_cells: Dictionary = {}
var neighbor_site_id := ""
var _player: Node3D
var _breakroom: Node3D

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _accent_material: StandardMaterial3D


func configure(plan: Dictionary, player: Node3D, breakroom: Node3D) -> void:
	world_plan = plan
	_player = player
	_breakroom = breakroom
	_build_materials()
	_build_region_one_slice()
	_open_breakroom_portal()
	update_streaming(true)


func update_streaming(force: bool = false) -> void:
	if world_plan.is_empty() or not is_instance_valid(_player):
		return
	var center := Vector2i(
		int(floor(_player.global_position.x / LOCAL_CELL_SIZE)),
		int(floor(_player.global_position.z / LOCAL_CELL_SIZE))
	)
	var next_active := _cells_within(center, ACTIVE_RADIUS)
	var next_warm := _cells_within(center, WARM_RADIUS)
	if not force and next_active.keys() == active_cells.keys() and next_warm.keys() == warm_cells.keys():
		return
	for key in active_cells.keys():
		if not next_active.has(key):
			_unload_cell(str(key))
	for key in next_active.keys():
		if not active_cells.has(key):
			_load_cell(str(key))
	warm_cells = next_warm
	active_cells = next_active
	_persist_streaming_state(center)


func loaded_cell_keys() -> Array:
	var keys := active_cells.keys()
	keys.sort()
	return keys


func _build_region_one_slice() -> void:
	var breakroom_site := _site_by_id("site.breakroom")
	if breakroom_site.is_empty():
		return
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var origin := _plan_position(breakroom_site)
	for site in world_plan.get("sites", []):
		if site.get("id") == "site.breakroom" or site.get("region_id") != breakroom_site.get("region_id"):
			continue
		var distance := origin.distance_squared_to(_plan_position(site))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = site
	neighbor_site_id = str(nearest.get("id", "region.00.site.01"))
	slice_cells = {
		"0:0": {"kind": "portal", "site_id": "site.breakroom"},
		"1:0": {"kind": "transit", "site_id": neighbor_site_id},
		"2:0": {"kind": "site", "site_id": neighbor_site_id},
	}


func _load_cell(key: String) -> void:
	if not slice_cells.has(key) or has_node("Cell_" + key.replace(":", "_")):
		return
	var definition: Dictionary = slice_cells[key]
	var coords := _parse_cell_key(key)
	var root := Node3D.new()
	root.name = "Cell_" + key.replace(":", "_")
	root.position = Vector3(coords.x * LOCAL_CELL_SIZE, 0.0, coords.y * LOCAL_CELL_SIZE)
	root.set_meta("procgen_cell", key)
	root.set_meta("site_id", definition.get("site_id", ""))
	add_child(root)
	match str(definition.get("kind", "transit")):
		"portal": _build_corridor(root, true)
		"site": _build_neighbor_site(root, definition)
		_: _build_corridor(root, false)


func _unload_cell(key: String) -> void:
	var node := get_node_or_null("Cell_" + key.replace(":", "_"))
	if node != null:
		node.queue_free()


func _build_corridor(root: Node3D, portal_cell: bool) -> void:
	var start_x := 8.0 if portal_cell else 0.0
	var length := LOCAL_CELL_SIZE - start_x
	var center_x := start_x + length * 0.5
	_add_static_box(root, "Floor", Vector3(length, 0.25, 5.5), Vector3(center_x, -0.125, 0.0), _floor_material)
	_add_static_box(root, "NorthWall", Vector3(length, 3.4, 0.25), Vector3(center_x, 1.7, -2.875), _wall_material)
	_add_static_box(root, "SouthWall", Vector3(length, 3.4, 0.25), Vector3(center_x, 1.7, 2.875), _wall_material)
	_add_static_box(root, "Ceiling", Vector3(length, 0.18, 5.75), Vector3(center_x, 3.4, 0.0), _wall_material)
	_add_navigation(root, start_x, length, 5.25)
	for offset in range(int(start_x) + 4, int(LOCAL_CELL_SIZE), 8):
		_add_mesh_box(root, "GuideLight", Vector3(0.18, 0.10, 1.2), Vector3(float(offset), 3.28, 0.0), _accent_material)


func _build_neighbor_site(root: Node3D, definition: Dictionary) -> void:
	_add_static_box(root, "Floor", Vector3(LOCAL_CELL_SIZE, 0.25, 22.0), Vector3(LOCAL_CELL_SIZE * 0.5, -0.125, 0.0), _floor_material)
	_add_static_box(root, "NorthWall", Vector3(LOCAL_CELL_SIZE, 3.8, 0.3), Vector3(LOCAL_CELL_SIZE * 0.5, 1.9, -11.0), _wall_material)
	_add_static_box(root, "SouthWall", Vector3(LOCAL_CELL_SIZE, 3.8, 0.3), Vector3(LOCAL_CELL_SIZE * 0.5, 1.9, 11.0), _wall_material)
	_add_static_box(root, "FarWall", Vector3(0.3, 3.8, 22.0), Vector3(LOCAL_CELL_SIZE, 1.9, 0.0), _wall_material)
	_add_navigation(root, 0.0, LOCAL_CELL_SIZE, 21.5)
	var site := _site_by_id(str(definition.get("site_id", "")))
	var archetype := str(site.get("archetype", "institutional"))
	for i in 4:
		var z := -7.5 + float(i) * 5.0
		_add_static_box(root, "Support_%d" % i, Vector3(0.7, 3.1, 0.7), Vector3(10.0 + float(i % 2) * 10.0, 1.55, z), _wall_material)
	var marker := Label3D.new()
	marker.name = "SiteMarker"
	marker.text = "%s\n%s" % [neighbor_site_id, archetype.to_upper()]
	marker.position = Vector3(17.0, 2.2, -10.6)
	marker.modulate = Color(0.95, 0.55, 0.22)
	marker.font_size = 38
	root.add_child(marker)


func _open_breakroom_portal() -> void:
	if not is_instance_valid(_breakroom):
		return
	var east_wall := _breakroom.get_node_or_null("World/EastWall")
	if east_wall != null:
		east_wall.visible = false
		east_wall.process_mode = Node.PROCESS_MODE_DISABLED
		var collision := east_wall.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			collision.disabled = true
	var portal := Node3D.new()
	portal.name = "ProcGenPortalFrame"
	_breakroom.add_child(portal)
	_add_static_box(portal, "NorthJamb", Vector3(0.3, 3.2, 4.2), Vector3(8.0, 1.6, -3.9), _wall_material)
	_add_static_box(portal, "SouthJamb", Vector3(0.3, 3.2, 4.2), Vector3(8.0, 1.6, 3.9), _wall_material)
	_add_static_box(portal, "Lintel", Vector3(0.3, 0.55, 3.6), Vector3(8.0, 2.925, 0.0), _wall_material)


func _add_static_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)


func _add_mesh_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = position
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	parent.add_child(mesh)


func _add_navigation(parent: Node3D, start_x: float, length: float, width: float) -> void:
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	var navigation := NavigationMesh.new()
	var half_width := width * 0.5
	navigation.vertices = PackedVector3Array([
		Vector3(start_x, 0.0, -half_width), Vector3(start_x + length, 0.0, -half_width),
		Vector3(start_x + length, 0.0, half_width), Vector3(start_x, 0.0, half_width),
	])
	navigation.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navigation
	parent.add_child(region)


func _build_materials() -> void:
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = Color(0.18, 0.20, 0.19)
	_floor_material.roughness = 0.88
	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.36, 0.39, 0.35)
	_wall_material.roughness = 0.92
	_accent_material = StandardMaterial3D.new()
	_accent_material.albedo_color = Color(0.95, 0.42, 0.10)
	_accent_material.emission_enabled = true
	_accent_material.emission = Color(0.72, 0.16, 0.025)
	_accent_material.emission_energy_multiplier = 1.4


func _cells_within(center: Vector2i, radius: int) -> Dictionary:
	var result := {}
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var key := "%d:%d" % [x, y]
			if slice_cells.has(key):
				result[key] = true
	return result


func _persist_streaming_state(center: Vector2i) -> void:
	if GameRuntime.world_state == null:
		return
	var persistent: Dictionary = GameRuntime.world_state.world_state.get("procedural_world", {})
	persistent["active_site"] = neighbor_site_id if center.x >= 2 else "site.breakroom"
	persistent["stream_cell"] = "%d:%d" % [center.x, center.y]
	persistent["loaded_cells"] = loaded_cell_keys()
	var cell_state: Dictionary = persistent.get("cell_state", {})
	for key in active_cells.keys():
		if not cell_state.has(key):
			cell_state[key] = {"visited": false}
		cell_state[key]["visited"] = true
	persistent["cell_state"] = cell_state
	GameRuntime.world_state.world_state["procedural_world"] = persistent


func _site_by_id(site_id: String) -> Dictionary:
	for site in world_plan.get("sites", []):
		if site.get("id") == site_id:
			return site
	return {}


func _plan_position(site: Dictionary) -> Vector2:
	var value: Dictionary = site.get("position", {})
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(":")
	return Vector2i(int(parts[0]), int(parts[1]))
