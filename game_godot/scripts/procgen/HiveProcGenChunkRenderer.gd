class_name HiveProcGenChunkRenderer
extends Node3D

# Materializes the first playable slice of hive_procgen_world_v1. The authored
# Breakroom remains the origin; generated cells extend through its east portal.

const LOCAL_CELL_SIZE := 32.0
const ACTIVE_RADIUS := 1
const WARM_RADIUS := 2
const FirstPersonInteractableClass = preload("res://scripts/fps/FirstPersonInteractable.gd")
const LEVEL_TITLES := [
	"SERVICE SPINE", "RECORDS ANNEX", "WET LAB", "GENERATOR HALL",
	"COLD STORAGE", "ARCHIVE SHAFT", "OBSERVATION WARD", "MACHINE FLOOR",
	"FLOODED OFFICES", "ROOF UTILITY", "FALSE CAFETERIA", "THE LATTICE",
	"BRUISE MOOR", "MORVEIN FUNGAL GALLERY", "GLASSWOOD STATION", "ASH ASCENT",
	"QUARRY OF FORMS", "DROWNED SUBURB", "AMBER WARREN", "MOUNTAIN RELAY",
]
const LEVEL_ARCHETYPES := [
	"industrial_plant", "service_tunnel", "records_archive", "wet_lab",
	"generator_hall", "cold_storage", "observation_ward", "machine_floor",
	"flooded_office", "roof_utility", "false_cafeteria", "lattice_vault",
	"ruined_suburb", "fungal_cavern", "mountain_pass", "quarry",
	"forest_service", "rail_yard", "drainage_network", "roadside_station",
]

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
	var candidates: Array = []
	for site in world_plan.get("sites", []):
		if str(site.get("id", "")) != "site.breakroom":
			candidates.append(site)
	if candidates.size() < LEVEL_TITLES.size():
		return
	var route_sites: Array = candidates.slice(0, LEVEL_TITLES.size())
	var branch_sites: Array = candidates.slice(LEVEL_TITLES.size())
	neighbor_site_id = str(route_sites[0].get("id", "region.00.site.01"))
	slice_cells = {
		"0:0": {"kind": "portal", "site_id": "site.breakroom", "level_index": -1},
		"1:0": {"kind": "transit", "site_id": neighbor_site_id, "level_index": -1},
	}
	var branch_cursor := 0
	for i in range(route_sites.size()):
		var site_x := 2 + i * 2
		var site_id := str(route_sites[i].get("id", ""))
		slice_cells["%d:0" % site_x] = {"kind": "site", "site_id": site_id, "level_index": i}
		# Keep the original first twelve north/south witness chambers as a stable legacy spine.
		# The eight added world levels are full walkable sites but do not need duplicate side chambers.
		if i < 12:
			for direction in [-1, 1]:
				var branch_site_id := site_id + ".branch.%d" % direction
				if branch_cursor < branch_sites.size():
					branch_site_id = str(branch_sites[branch_cursor].get("id", branch_site_id))
					branch_cursor += 1
				slice_cells["%d:%d" % [site_x, direction]] = {
					"kind": "branch", "site_id": branch_site_id, "level_index": i, "branch_dir": direction,
				}
		if i < route_sites.size() - 1:
			slice_cells["%d:0" % (site_x + 1)] = {"kind": "transit", "site_id": site_id, "level_index": i}


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
		"branch": _build_branch_site(root, definition)
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
	var level_index := int(definition.get("level_index", 0))
	var wall_mat := _wall_material.duplicate() as StandardMaterial3D
	var accent_mat := _accent_material.duplicate() as StandardMaterial3D
	var floor_mat := _floor_material.duplicate() as StandardMaterial3D
	var palette := _palette_for_level(level_index)
	wall_mat.albedo_color = palette.darkened(0.35)
	floor_mat.albedo_color = palette.darkened(0.62)
	accent_mat.albedo_color = palette
	accent_mat.emission = palette
	accent_mat.emission_energy_multiplier = 1.8
	var room_height := 3.8 + float(level_index % 3) * 0.45
	_add_static_box(root, "Floor", Vector3(LOCAL_CELL_SIZE, 0.25, 22.0), Vector3(LOCAL_CELL_SIZE * 0.5, -0.125, 0.0), floor_mat)
	# Split side walls around centered branch doors so every level can be explored laterally.
	_add_static_box(root, "NorthWallWest", Vector3(14.0, room_height, 0.3), Vector3(7.0, room_height * 0.5, -11.0), wall_mat)
	_add_static_box(root, "NorthWallEast", Vector3(14.0, room_height, 0.3), Vector3(25.0, room_height * 0.5, -11.0), wall_mat)
	_add_static_box(root, "SouthWallWest", Vector3(14.0, room_height, 0.3), Vector3(7.0, room_height * 0.5, 11.0), wall_mat)
	_add_static_box(root, "SouthWallEast", Vector3(14.0, room_height, 0.3), Vector3(25.0, room_height * 0.5, 11.0), wall_mat)
	_add_static_box(root, "Ceiling", Vector3(LOCAL_CELL_SIZE, 0.18, 22.0), Vector3(LOCAL_CELL_SIZE * 0.5, room_height, 0.0), wall_mat)
	_add_static_box(root, "FarWallNorth", Vector3(0.3, room_height, 8.0), Vector3(LOCAL_CELL_SIZE, room_height * 0.5, -7.0), wall_mat)
	_add_static_box(root, "FarWallSouth", Vector3(0.3, room_height, 8.0), Vector3(LOCAL_CELL_SIZE, room_height * 0.5, 7.0), wall_mat)
	_add_navigation(root, 0.0, LOCAL_CELL_SIZE, 21.5)
	for x in [6.0, 16.0, 26.0]:
		_add_mesh_box(root, "Guide_%d" % int(x), Vector3(0.18, 0.12, 8.0), Vector3(x, room_height - 0.22, 0.0), accent_mat)
	_build_level_dressing(root, level_index, wall_mat, accent_mat)
	var marker := Label3D.new()
	marker.name = "LevelMarker"
	marker.text = "LEVEL %02d // %s" % [level_index + 1, level_title(level_index)]
	marker.position = Vector3(7.0, 2.25, -10.55)
	marker.rotation_degrees = Vector3(0, 0, 0)
	marker.modulate = palette.lightened(0.35)
	marker.font_size = 42
	root.add_child(marker)
	var beacon := OmniLight3D.new()
	beacon.name = "LevelBeacon"
	beacon.position = Vector3(16.0, room_height - 0.55, 0.0)
	beacon.light_color = palette
	beacon.light_energy = 1.35
	beacon.omni_range = 12.0
	beacon.shadow_enabled = false
	root.add_child(beacon)
	if level_index == 11 or level_index == LEVEL_TITLES.size() - 1:
		# Preserve the original witness terminal at Level 12 while allowing the free-roam world to continue.
		# A second terminal marks the far end of the expanded twenty-level route.
		_add_static_box(root, "TerminalWall", Vector3(0.3, room_height, 6.0), Vector3(LOCAL_CELL_SIZE, room_height * 0.5, 0.0), wall_mat)
		_build_completion_terminal(root, level_index, accent_mat)


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

	var gate := StaticBody3D.new()
	gate.name = "ProcGenExitGate"
	gate.position = Vector3(7.86, 1.45, 0.0)
	gate.set_script(FirstPersonInteractableClass)
	gate.set("interaction_id", "world_exit")
	gate.set("target_id", "route.service_spine")
	gate.set("prompt", "[E / A] EXIT ? Service Spine")
	gate.set("speaker_name", "East Service Exit")
	gate.set("description", "The door leads away from the breakroom.")
	_breakroom.add_child(gate)
	var gate_mesh := MeshInstance3D.new()
	gate_mesh.name = "DoorMesh"
	var gate_box := BoxMesh.new()
	gate_box.size = Vector3(0.22, 2.8, 3.35)
	gate_mesh.mesh = gate_box
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.08, 0.13, 0.11)
	gate_mat.metallic = 0.45
	gate_mat.roughness = 0.58
	gate_mesh.material_override = gate_mat
	gate.add_child(gate_mesh)
	var gate_collision := CollisionShape3D.new()
	gate_collision.name = "Collision"
	var gate_shape := BoxShape3D.new()
	gate_shape.size = Vector3(0.22, 2.8, 3.35)
	gate_collision.shape = gate_shape
	gate.add_child(gate_collision)
	if GameRuntime.world_state != null and bool(GameRuntime.world_state.world_state.get("breakroom_exit_open", false)):
		gate.set_meta("opened", true)
		gate.position.y += 3.2
		gate_collision.disabled = true

	var exit_sign := Label3D.new()
	exit_sign.name = "ExitSign"
	exit_sign.text = "EXIT // SERVICE SPINE"
	exit_sign.position = Vector3(7.70, 3.23, 0.0)
	exit_sign.rotation_degrees = Vector3(0, 90, 0)
	exit_sign.modulate = Color(0.45, 1.0, 0.62)
	exit_sign.font_size = 48
	_breakroom.add_child(exit_sign)


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
	var key := "%d:%d" % [center.x, center.y]
	var definition: Dictionary = slice_cells.get(key, {})
	persistent["active_site"] = str(definition.get("site_id", "site.breakroom" if center.x < 2 else neighbor_site_id))
	persistent["stream_cell"] = "%d:%d" % [center.x, center.y]
	persistent["loaded_cells"] = loaded_cell_keys()
	persistent["current_level"] = level_index_for_cell_x(center.x)
	persistent["current_level_title"] = level_title(int(persistent["current_level"]))
	var cell_state: Dictionary = persistent.get("cell_state", {})
	for active_key in active_cells.keys():
		if not cell_state.has(active_key):
			cell_state[active_key] = {"visited": false}
		cell_state[active_key]["visited"] = true
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


func _build_level_dressing(root: Node3D, level_index: int, wall_mat: Material, accent_mat: Material) -> void:
	var mode := level_index % 4
	match mode:
		0:
			_add_static_box(root, "SideBayA", Vector3(8.0, 2.4, 0.35), Vector3(11.0, 1.2, -7.5), wall_mat)
			_add_static_box(root, "SideBayB", Vector3(7.0, 2.1, 0.35), Vector3(23.0, 1.05, 7.5), wall_mat)
		1:
			for x in [9.0, 18.0, 27.0]:
				_add_static_box(root, "ArchiveStack_%d" % int(x), Vector3(2.4, 2.6, 5.0), Vector3(x, 1.3, -7.2), wall_mat)
		2:
			for z in [-7.0, 7.0]:
				_add_static_box(root, "LabBench_%d" % int(z), Vector3(10.0, 0.9, 2.0), Vector3(16.0, 0.45, z), wall_mat)
		3:
			for x in [8.0, 16.0, 24.0]:
				_add_static_box(root, "Machine_%d" % int(x), Vector3(2.6, 2.8, 3.0), Vector3(x, 1.4, 7.6), wall_mat)

	_add_mesh_box(root, "ThresholdGlow", Vector3(0.24, 2.7, 5.4), Vector3(31.7, 1.35, 0.0), accent_mat)


func level_count() -> int:
	return LEVEL_TITLES.size()


func level_title(level_index: int) -> String:
	if level_index < 0 or level_index >= LEVEL_TITLES.size():
		return "BREAKROOM"
	return str(LEVEL_TITLES[level_index])


func level_index_for_cell_x(cell_x: int) -> int:
	if cell_x < 2:
		return -1
	return clampi(int((cell_x - 2) / 2), 0, LEVEL_TITLES.size() - 1)


func route_cell_count() -> int:
	return slice_cells.size()


func _palette_for_level(level_index: int) -> Color:
	var palette := [
		Color(0.95, 0.43, 0.12), Color(0.62, 0.72, 0.28), Color(0.22, 0.70, 0.62),
		Color(0.88, 0.29, 0.17), Color(0.35, 0.64, 0.92), Color(0.55, 0.42, 0.82),
		Color(0.82, 0.74, 0.36), Color(0.40, 0.82, 0.45), Color(0.22, 0.58, 0.72),
		Color(0.74, 0.48, 0.26), Color(0.73, 0.32, 0.50), Color(0.45, 0.95, 0.67),
	]
	return palette[posmod(level_index, palette.size())]


func _build_branch_site(root: Node3D, definition: Dictionary) -> void:
	var level_index := int(definition.get("level_index", 0))
	var direction := int(definition.get("branch_dir", -1))
	var palette := _palette_for_level(level_index)
	var wall_mat := _wall_material.duplicate() as StandardMaterial3D
	var floor_mat := _floor_material.duplicate() as StandardMaterial3D
	var accent_mat := _accent_material.duplicate() as StandardMaterial3D
	wall_mat.albedo_color = palette.darkened(0.48)
	floor_mat.albedo_color = palette.darkened(0.68)
	accent_mat.albedo_color = palette
	accent_mat.emission = palette
	accent_mat.emission_energy_multiplier = 2.1
	var room_height := 3.4 + float((level_index + 1) % 3) * 0.35
	var corridor_z := float(-direction) * 12.5
	var chamber_z := float(direction) * 4.0
	_add_static_box(root, "BranchCorridorFloor", Vector3(5.5, 0.25, 17.0), Vector3(16.0, -0.125, corridor_z), floor_mat)
	_add_static_box(root, "BranchCorridorWest", Vector3(0.25, room_height, 17.0), Vector3(13.25, room_height * 0.5, corridor_z), wall_mat)
	_add_static_box(root, "BranchCorridorEast", Vector3(0.25, room_height, 17.0), Vector3(18.75, room_height * 0.5, corridor_z), wall_mat)
	_add_static_box(root, "BranchFloor", Vector3(20.0, 0.25, 16.0), Vector3(16.0, -0.125, chamber_z), floor_mat)
	_add_static_box(root, "BranchWestWall", Vector3(0.3, room_height, 16.0), Vector3(6.0, room_height * 0.5, chamber_z), wall_mat)
	_add_static_box(root, "BranchEastWall", Vector3(0.3, room_height, 16.0), Vector3(26.0, room_height * 0.5, chamber_z), wall_mat)
	_add_static_box(root, "BranchFarWall", Vector3(20.0, room_height, 0.3), Vector3(16.0, room_height * 0.5, float(direction) * 12.0), wall_mat)
	_add_static_box(root, "BranchCeiling", Vector3(20.0, 0.18, 16.0), Vector3(16.0, room_height, chamber_z), wall_mat)
	_add_navigation(root, 6.2, 19.6, 15.5)
	for x in [9.0, 16.0, 23.0]:
		_add_mesh_box(root, "BranchGuide_%d" % int(x), Vector3(0.16, 0.10, 1.2), Vector3(x, room_height - 0.18, chamber_z), accent_mat)
	var marker := Label3D.new()
	marker.name = "BranchMarker"
	marker.text = "%s // %s" % [level_title(level_index), "NORTH" if direction < 0 else "SOUTH"]
	marker.position = Vector3(8.0, 2.1, chamber_z + float(direction) * 7.6)
	marker.modulate = palette.lightened(0.30)
	marker.font_size = 34
	root.add_child(marker)
	_build_lattice_echo(root, level_index, direction, accent_mat)


func _build_lattice_echo(root: Node3D, level_index: int, direction: int, accent_mat: Material) -> void:
	var echo := StaticBody3D.new()
	var side := "north" if direction < 0 else "south"
	echo.name = "LatticeEcho_%02d_%s" % [level_index + 1, side]
	echo.position = Vector3(16.0, 1.05, float(direction) * 4.0)
	echo.set_script(FirstPersonInteractableClass)
	echo.set("interaction_id", "lattice_echo")
	echo.set("target_id", "echo.%02d.%s" % [level_index + 1, side])
	echo.set("prompt", "[E / A] Record Witness Echo")
	echo.set("speaker_name", "Witness Echo %02d" % [level_index + 1])
	echo.set("description", _echo_text(level_index, direction))
	echo.set_meta("level_index", level_index)
	echo.set_meta("branch_dir", direction)
	root.add_child(echo)
	var mesh := MeshInstance3D.new()
	mesh.name = "EchoMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	mesh.mesh = sphere
	mesh.material_override = accent_mat
	echo.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := SphereShape3D.new()
	shape.radius = 0.36
	collision.shape = shape
	echo.add_child(collision)
	var light := OmniLight3D.new()
	light.name = "EchoLight"
	light.light_color = _palette_for_level(level_index)
	light.light_energy = 1.1
	light.omni_range = 3.8
	light.shadow_enabled = false
	echo.add_child(light)


func _build_completion_terminal(root: Node3D, level_index: int, accent_mat: Material) -> void:
	var terminal := StaticBody3D.new()
	terminal.name = "LatticeCompletionTerminal"
	terminal.position = Vector3(28.0, 1.15, 0.0)
	terminal.set_script(FirstPersonInteractableClass)
	terminal.set("interaction_id", "lattice_terminal")
	terminal.set("target_id", "terminal.lattice.final")
	terminal.set("prompt", "[E / A] Complete Witness Run")
	terminal.set("speaker_name", "THE LATTICE")
	terminal.set("description", "The terminal is waiting for the witness to decide whether the run is complete.")
	terminal.set_meta("level_index", level_index)
	root.add_child(terminal)
	var mesh := MeshInstance3D.new()
	mesh.name = "TerminalMesh"
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 2.1, 0.75)
	mesh.mesh = box
	mesh.material_override = accent_mat
	terminal.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 2.1, 0.75)
	collision.shape = shape
	terminal.add_child(collision)
	var label := Label3D.new()
	label.name = "TerminalLabel"
	label.text = "WITNESS TERMINAL\nEND OF ROUTE"
	label.position = Vector3(0.0, 0.35, 0.39)
	label.modulate = _palette_for_level(level_index).lightened(0.35)
	label.font_size = 32
	terminal.add_child(label)


func _echo_text(level_index: int, direction: int) -> String:
	var fragments := [
		"A maintenance log repeats the same timestamp for three days.",
		"Someone filed an incident report for a room that does not exist on the map.",
		"A specimen label lists Wetberry as both evidence and employee property.",
		"The generator ledger records power consumption while the building was disconnected.",
		"Cold-storage inventory includes one line item marked RETURNED TO WITNESS.",
		"Archive shelves contain copies of forms you have not filled out yet.",
		"Observation notes describe the exact direction you are facing now.",
		"A machine counter increments only when nobody is looking at it.",
		"The flood line on the wall is higher than the ceiling.",
		"Roof access paperwork lists weather from inside the building.",
		"The cafeteria menu offers the same meal under twelve different names.",
		"The final record contains no author, only your current save slot.",
		"Bruise-purple grass bends away from a wind that never reaches your face.",
		"Morvein's fungal shelves fruit from rejected paragraphs under the mud.",
		"Glasswood trunks return a reflection that is one decision behind you.",
		"The ash ridge carries tire tracks uphill where no road was built.",
		"Quarry walls expose filing strata instead of sediment.",
		"Flooded houses keep their office lights on below the waterline.",
		"Amber chambers preserve bees, memos, and unfinished apologies.",
		"The mountain relay transmits a route map whose roads change only when unobserved.",
	]
	var base := str(fragments[clampi(level_index, 0, fragments.size() - 1)])
	var side_text := " The north copy ends with a wet fingerprint." if direction < 0 else " The south copy ends with a dry ring from a coffee cup."
	return base + side_text


func branch_cell_count() -> int:
	var count := 0
	for definition in slice_cells.values():
		if str(definition.get("kind", "")) == "branch":
			count += 1
	return count
