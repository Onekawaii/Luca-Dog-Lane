class_name HiveProcGenEngine
extends RefCounted

# Deterministic layered PCG planner for Hive-Lattice.
# Generates data first; rendering/streaming consume the resulting plan.

const SCHEMA := "hive_procgen_world_v1"
const WORLD_SIZE := 4096.0
const CELL_SIZE := 256.0
const REGION_COUNT := 6
const MIN_SITES_PER_REGION := 6
const MAX_SITES_PER_REGION := 10

const ARCHETYPES := [
	"industrial", "institutional", "maintenance", "storage",
	"service_tunnel", "office", "anomalous", "transitional"
]

const ROOM_MODULES := [
	"junction", "corridor", "workroom", "utility", "storage",
	"office", "stairwell", "service_bay", "anomaly_chamber"
]

var _seed: int = 6060
var _hive_state: Dictionary = {}
var _memory_catalog: Array = []
func generate(seed_value: int, hive_state: Dictionary = {}, memory_catalog: Array = []) -> Dictionary:
	_seed = seed_value
	_hive_state = hive_state.duplicate(true)
	_memory_catalog = memory_catalog.duplicate(true)
	var regions := _generate_regions()
	var region_edges := _connect_points(regions, "region")
	var sites := _generate_sites(regions)
	var site_edges := _connect_points(sites, "site")
	var rooms := _generate_room_graphs(sites)
	var scatter := _generate_scatter(sites)
	var streaming := _build_streaming_index(sites, scatter)
	var director := _build_director_state(regions, sites)
	var plan := {
		"schema": SCHEMA,
		"seed": _seed,
		"world_size": WORLD_SIZE,
		"cell_size": CELL_SIZE,
		"hive_state": _hive_state.duplicate(true),
		"regions": regions,
		"region_edges": region_edges,
		"sites": sites,
		"site_edges": site_edges,
		"room_graphs": rooms,
		"scatter": scatter,
		"streaming": streaming,
		"director": director,
	}
	plan["receipt"] = _build_receipt(plan)
	return plan
func _generate_regions() -> Array:
	var rng := _rng("regions")
	var regions: Array = []
	var cols := 3
	var rows := 2
	for i in REGION_COUNT:
		var gx := i % cols
		var gy := i / cols
		var cell_w := WORLD_SIZE / float(cols)
		var cell_h := WORLD_SIZE / float(rows)
		var center := Vector2(
			(gx + 0.5) * cell_w + rng.randf_range(-cell_w * 0.22, cell_w * 0.22),
			(gy + 0.5) * cell_h + rng.randf_range(-cell_h * 0.22, cell_h * 0.22)
		)
		var pressure := _sample_field("pressure", center, 0.00055)
		var contamination := _sample_field("contamination", center, 0.0008)
		regions.append({
			"id": "region.%02d" % i,
			"position": _v2(center),
			"pressure": pressure,
			"contamination": contamination,
			"biome": _pick_region_biome(pressure, contamination, i),
			"generation_tier": 0,
		})
	return regions
func _generate_sites(regions: Array) -> Array:
	var sites: Array = []
	for region in regions:
		var rid := str(region["id"])
		var rng := _rng("sites:" + rid)
		var count := rng.randi_range(MIN_SITES_PER_REGION, MAX_SITES_PER_REGION)
		var center := _dict_v2(region["position"])
		for j in count:
			var angle := rng.randf_range(0.0, TAU)
			var radius := rng.randf_range(120.0, 620.0)
			var pos := center + Vector2(cos(angle), sin(angle)) * radius
			pos.x = clamp(pos.x, 64.0, WORLD_SIZE - 64.0)
			pos.y = clamp(pos.y, 64.0, WORLD_SIZE - 64.0)
			var sid := "%s.site.%02d" % [rid, j]
			var archetype := _pick_site_archetype(region, j, pos)
			sites.append({
				"id": sid, "region_id": rid, "position": _v2(pos),
				"archetype": archetype,
				"importance": 1.0 if j == 0 else rng.randf_range(0.2, 0.9),
				"memory_resonance": _memory_for_site(archetype, pos),
				"generation_tier": 1,
			})
	# Region 00 site 00 is the authored bridge into the existing Breakroom.
	if not sites.is_empty():
		sites[0]["id"] = "site.breakroom"
		sites[0]["archetype"] = "institutional"
		sites[0]["authored_scene"] = "res://scenes/fps/FirstPersonBreakroom.tscn"
	return sites
func _connect_points(items: Array, salt: String) -> Array:
	if items.size() < 2:
		return []
	var edges: Array = []
	var connected: Array[int] = [0]
	var remaining: Array[int] = []
	for i in range(1, items.size()):
		remaining.append(i)
	while not remaining.is_empty():
		var best_a := -1
		var best_b := -1
		var best_d := INF
		for a in connected:
			for b in remaining:
				var d := _dict_v2(items[a]["position"]).distance_squared_to(_dict_v2(items[b]["position"]))
				if d < best_d:
					best_d = d; best_a = a; best_b = b
		edges.append(_edge(items[best_a]["id"], items[best_b]["id"], sqrt(best_d), "spine"))
		connected.append(best_b)
		remaining.erase(best_b)
	var rng := _rng("loops:" + salt)
	for _i in maxi(1, items.size() / 3):
		var a := rng.randi_range(0, items.size() - 1)
		var b := rng.randi_range(0, items.size() - 1)
		if a != b and not _has_edge(edges, items[a]["id"], items[b]["id"]):
			var d := _dict_v2(items[a]["position"]).distance_to(_dict_v2(items[b]["position"]))
			edges.append(_edge(items[a]["id"], items[b]["id"], d, "loop"))
	return edges
func _generate_room_graphs(sites: Array) -> Dictionary:
	var graphs := {}
	for site in sites:
		var sid := str(site["id"])
		var rng := _rng("rooms:" + sid)
		var room_count := rng.randi_range(4, 9)
		var nodes: Array = []
		var edges: Array = []
		var previous := "junction"
		for i in room_count:
			var module := _choose_room_module(previous, str(site["archetype"]), rng)
			var room_id := "%s.room.%02d" % [sid, i]
			nodes.append({
				"id": room_id, "module": module,
				"socket_class": _socket_class(module),
				"local_seed": _stable_seed("%s:%d" % [room_id, _seed]),
			})
			if i > 0:
				edges.append(_edge(nodes[i - 1]["id"], room_id, 1.0, "door"))
			previous = module
		if room_count >= 6 and rng.randf() < 0.7:
			edges.append(_edge(nodes[1]["id"], nodes[room_count - 2]["id"], 1.0, "loop_door"))
		graphs[sid] = {
			"site_id": sid,
			"nodes": nodes,
			"edges": edges,
			"constraint_status": "resolved",
		}
	return graphs
func _choose_room_module(previous: String, archetype: String, rng: RandomNumberGenerator) -> String:
	var domains := {
		"junction": ["corridor", "workroom", "utility", "office"],
		"corridor": ["junction", "workroom", "storage", "stairwell", "service_bay"],
		"workroom": ["corridor", "utility", "storage", "office"],
		"utility": ["corridor", "service_bay", "storage", "anomaly_chamber"],
		"storage": ["corridor", "utility", "service_bay"],
		"office": ["corridor", "workroom", "junction"],
		"stairwell": ["corridor", "junction", "service_bay"],
		"service_bay": ["corridor", "utility", "storage", "anomaly_chamber"],
		"anomaly_chamber": ["corridor", "utility"],
	}
	var candidates: Array = domains.get(previous, ROOM_MODULES).duplicate()
	if archetype == "anomalous" and not candidates.has("anomaly_chamber"):
		candidates.append("anomaly_chamber")
	if archetype == "office":
		candidates.append("office")
	if archetype == "maintenance":
		candidates.append("utility")
	return str(candidates[rng.randi_range(0, candidates.size() - 1)])


func _socket_class(module: String) -> String:
	if module in ["corridor", "junction", "stairwell"]:
		return "transit"
	if module == "anomaly_chamber":
		return "sealed"
	return "room"
func _generate_scatter(sites: Array) -> Array:
	var out: Array = []
	for site in sites:
		var sid := str(site["id"])
		var rng := _rng("scatter:" + sid)
		var center := _dict_v2(site["position"])
		var accepted: Array[Vector2] = []
		var desired := rng.randi_range(5, 14)
		var attempts := 0
		while accepted.size() < desired and attempts < desired * 12:
			attempts += 1
			var angle := rng.randf_range(0.0, TAU)
			var radius := sqrt(rng.randf()) * 170.0
			var p := center + Vector2(cos(angle), sin(angle)) * radius
			if _far_enough(p, accepted, 22.0):
				accepted.append(p)
		for i in accepted.size():
			var p := accepted[i]
			var density := _sample_field("scatter", p, 0.008)
			out.append({
				"id": "%s.scatter.%02d" % [sid, i],
				"site_id": sid, "position": _v2(p),
				"kind": _scatter_kind(density, str(site["archetype"])),
				"density": density,
				"lod": 2 if center.distance_to(p) > 110.0 else 1,
			})
	return out
func _build_streaming_index(sites: Array, scatter: Array) -> Dictionary:
	var cells := {}
	for site in sites:
		var key := _cell_key(_dict_v2(site["position"]))
		if not cells.has(key):
			cells[key] = {"sites": [], "scatter": []}
		cells[key]["sites"].append(site["id"])
	for item in scatter:
		var key := _cell_key(_dict_v2(item["position"]))
		if not cells.has(key):
			cells[key] = {"sites": [], "scatter": []}
		cells[key]["scatter"].append(item["id"])
	return {
		"cells": cells,
		"active_radius_cells": 1,
		"warm_radius_cells": 2,
		"cold_radius_cells": 4,
		"policy": "hierarchical_runtime_partition",
	}


func active_cells_for_position(plan: Dictionary, world_pos: Vector2, radius_cells: int = 1) -> Array:
	var center_x := int(floor(world_pos.x / CELL_SIZE))
	var center_y := int(floor(world_pos.y / CELL_SIZE))
	var available: Dictionary = plan.get("streaming", {}).get("cells", {})
	var result: Array = []
	for y in range(center_y - radius_cells, center_y + radius_cells + 1):
		for x in range(center_x - radius_cells, center_x + radius_cells + 1):
			var key := "%d:%d" % [x, y]
			if available.has(key): result.append(key)
	return result
func _build_director_state(regions: Array, sites: Array) -> Dictionary:
	var pressure := float(_hive_state.get("pressure", 0.35))
	var observation := float(_hive_state.get("observation", 0.5))
	var instability := float(_hive_state.get("instability", 0.25))
	return {
		"threat_budget": snappedf(12.0 + pressure * 38.0, 0.01),
		"anomaly_budget": snappedf(8.0 + instability * 42.0, 0.01),
		"ambient_budget": snappedf(35.0 + (1.0 - pressure) * 25.0, 0.01),
		"observation_bias": clamp(observation, 0.0, 1.0),
		"region_count": regions.size(),
		"site_count": sites.size(),
		"spawn_policy": "budgeted_contextual",
		"mutation_policy": "local_seed_preserving",
	}


func _pick_region_biome(pressure: float, contamination: float, index: int) -> String:
	if index == 0: return "industrial_complex"
	if contamination > 0.70: return "contaminated_service_zone"
	if pressure > 0.68: return "hostile_institutional"
	if pressure < 0.30: return "quiet_periphery"
	return "mixed_infrastructure"


func _pick_site_archetype(region: Dictionary, index: int, pos: Vector2) -> String:
	if index == 0: return "institutional"
	var n := _sample_field("archetype", pos, 0.0016)
	var offset := int(floor(n * float(ARCHETYPES.size()))) % ARCHETYPES.size()
	if str(region.get("biome", "")).contains("contaminated") and index % 3 == 0:
		return "anomalous"
	return str(ARCHETYPES[offset])
func _memory_for_site(archetype: String, pos: Vector2) -> Dictionary:
	if _memory_catalog.is_empty():
		return {"memory_id": null, "strength": 0.0, "mode": "none"}
	var desired := [archetype]
	if float(_hive_state.get("instability", 0.0)) > 0.6: desired.append("anomalous")
	if float(_hive_state.get("familiarity", 0.0)) > 0.5: desired.append("familiar")
	var best: Dictionary = {}
	var best_score := -1.0
	for raw in _memory_catalog:
		if not raw is Dictionary: continue
		var item: Dictionary = raw
		var tags: Array = item.get("tags", [])
		var score := 0.0
		for tag in desired:
			if tags.has(tag): score += 1.0
		var jitter := _stable_unit("memory:%s:%s" % [str(item.get("id", "")), str(pos)]) * 0.25
		score += jitter
		if score > best_score:
			best_score = score; best = item
	if best.is_empty(): return {"memory_id": null, "strength": 0.0, "mode": "none"}
	var instability: float = clampf(float(_hive_state.get("instability", 0.25)), 0.0, 1.0)
	var mode: String = "literal" if instability < 0.25 else ("recognizable" if instability < 0.7 else "abstract")
	return {
		"memory_id": best.get("id"),
		"strength": snappedf(clamp(0.35 + best_score * 0.18, 0.0, 1.0), 0.001),
		"mode": mode,
		"tags": best.get("tags", []).duplicate(),
	}
func _sample_field(salt: String, pos: Vector2, frequency: float) -> float:
	var noise := FastNoiseLite.new()
	noise.seed = _stable_seed("%d:%s" % [_seed, salt])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var raw := noise.get_noise_2d(pos.x, pos.y)
	return clamp((raw + 1.0) * 0.5, 0.0, 1.0)


func _scatter_kind(density: float, archetype: String) -> String:
	if archetype == "anomalous" and density > 0.55: return "anomaly_trace"
	if density > 0.72: return "clutter_dense"
	if density > 0.48: return "prop_cluster"
	if density > 0.26: return "utility_detail"
	return "ambient_marker"


func _far_enough(candidate: Vector2, accepted: Array[Vector2], minimum: float) -> bool:
	for p in accepted:
		if candidate.distance_squared_to(p) < minimum * minimum: return false
	return true


func _cell_key(pos: Vector2) -> String:
	return "%d:%d" % [int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE))]
func _edge(a: Variant, b: Variant, distance: float, kind: String) -> Dictionary:
	return {
		"a": str(a), "b": str(b),
		"distance": snappedf(distance, 0.01),
		"kind": kind,
	}


func _has_edge(edges: Array, a: Variant, b: Variant) -> bool:
	for edge in edges:
		if (edge["a"] == a and edge["b"] == b) or (edge["a"] == b and edge["b"] == a):
			return true
	return false


func _v2(value: Vector2) -> Dictionary:
	return {"x": snappedf(value.x, 0.001), "y": snappedf(value.y, 0.001)}


func _dict_v2(value: Dictionary) -> Vector2:
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _rng(salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed("%d:%s" % [_seed, salt])
	return rng
func _stable_seed(text: String) -> int:
	var h: int = 2166136261
	for i in text.length():
		h = int(((h ^ text.unicode_at(i)) * 16777619) & 0x7fffffff)
	return maxi(1, h)


func _stable_unit(text: String) -> float:
	return float(_stable_seed(text)) / 2147483647.0


func _build_receipt(plan: Dictionary) -> Dictionary:
	var canonical := JSON.stringify(_sorted_variant(plan))
	return {
		"generator": "HiveProcGenEngine",
		"schema": SCHEMA,
		"seed": _seed,
		"sha256": canonical.sha256_text(),
		"region_count": plan.get("regions", []).size(),
		"site_count": plan.get("sites", []).size(),
		"scatter_count": plan.get("scatter", []).size(),
		"streaming_cell_count": plan.get("streaming", {}).get("cells", {}).size(),
	}


func _sorted_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys: out[key] = _sorted_variant(value[key])
		return out
	if value is Array:
		var out_array: Array = []
		for item in value:
			out_array.append(_sorted_variant(item))
		return out_array
	return value
