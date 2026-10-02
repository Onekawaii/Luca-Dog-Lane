class_name HiveWorldAuditor
extends RefCounted

# Internal PCO-style release gate for generated world plans.
# Deterministic facts are checked here before semantic/lore presentation is allowed.

const EXPECTED_SCHEMA := "hive_procgen_world_v2"
const EXPECTED_BIOMES := 10
const EXPECTED_LEVEL_TYPES := 20
const REQUIRED_LEVEL_TYPES := [
	"trailhead_camp", "creek_crossing", "meadow_homestead", "pine_watch",
	"old_orchard", "stone_bridge", "ranger_shed", "lakeside_dock",
	"hill_farm", "firefly_marsh", "hollow_barn", "windmill_field",
	"quarry_path", "mountain_pass", "summit_overlook", "forest_cabin",
	"rail_trail", "storm_shelter", "roadside_garage", "luca_rest",
]


func audit(plan: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	if str(plan.get("schema", "")) != EXPECTED_SCHEMA:
		issues.append("CANON: wrong world schema")
	var world_size := float(plan.get("world_size", 0.0))
	if world_size <= 0.0:
		issues.append("LOGISTICS: world_size must be positive")

	var regions: Array = plan.get("regions", [])
	var sites: Array = plan.get("sites", [])
	if regions.size() != EXPECTED_BIOMES:
		issues.append("CANON: expected exactly 10 macro regions/biomes")
	if sites.size() < EXPECTED_LEVEL_TYPES + 1:
		issues.append("LOGISTICS: insufficient sites for 20 world level types")

	var region_ids := {}
	var biome_ids := {}
	for raw in regions:
		if not raw is Dictionary:
			issues.append("STRUCTURE: invalid region record")
			continue
		var region: Dictionary = raw
		var rid := str(region.get("id", ""))
		var biome := str(region.get("biome", ""))
		if rid.is_empty() or region_ids.has(rid):
			issues.append("CANON: duplicate or empty region id: " + rid)
		region_ids[rid] = true
		if biome.is_empty() or biome_ids.has(biome):
			issues.append("CONGRUENCY: duplicate or empty biome: " + biome)
		biome_ids[biome] = true
		_check_position(region.get("position", {}), world_size, "region " + rid, issues)

	var site_ids := {}
	var level_types := {}
	for raw in sites:
		if not raw is Dictionary:
			issues.append("STRUCTURE: invalid site record")
			continue
		var site: Dictionary = raw
		var sid := str(site.get("id", ""))
		if sid.is_empty() or site_ids.has(sid):
			issues.append("CANON: duplicate or empty site id: " + sid)
		site_ids[sid] = true
		var rid := str(site.get("region_id", ""))
		if not region_ids.has(rid):
			issues.append("LOGISTICS: site " + sid + " references missing region " + rid)
		_check_position(site.get("position", {}), world_size, "site " + sid, issues)
		var archetype := str(site.get("archetype", ""))
		if REQUIRED_LEVEL_TYPES.has(archetype):
			level_types[archetype] = true

	for required in REQUIRED_LEVEL_TYPES:
		if not level_types.has(required):
			issues.append("COVERAGE: missing world level type " + required)

	_check_edges(plan.get("region_edges", []), region_ids, "region", issues)
	_check_edges(plan.get("site_edges", []), site_ids, "site", issues)

	var receipt: Dictionary = plan.get("receipt", {})
	if int(receipt.get("biome_count", 0)) != EXPECTED_BIOMES:
		issues.append("RECEIPT: biome_count mismatch")
	if int(receipt.get("level_type_count", 0)) != EXPECTED_LEVEL_TYPES:
		issues.append("RECEIPT: level_type_count mismatch")
	if str(receipt.get("sha256", "")).length() != 64:
		issues.append("PROVENANCE: missing SHA-256 world receipt")

	return {
		"passed": issues.is_empty(),
		"hard_failures": issues.size(),
		"bullshit_score": issues.size(),
		"biome_count": biome_ids.size(),
		"level_type_count": level_types.size(),
		"region_count": regions.size(),
		"site_count": sites.size(),
		"issues": issues,
		"summary": "PASS // 10 biomes // 20 level types // references congruent" if issues.is_empty() else "BLOCKED // %d deterministic issue(s)" % issues.size(),
	}


func _check_position(raw: Variant, world_size: float, label: String, issues: Array[String]) -> void:
	if not raw is Dictionary:
		issues.append("LOGISTICS: " + label + " has no position")
		return
	var pos: Dictionary = raw
	var x := float(pos.get("x", -1.0))
	var y := float(pos.get("y", -1.0))
	if x < 0.0 or y < 0.0 or x > world_size or y > world_size:
		issues.append("LOGISTICS: " + label + " is outside world bounds")


func _check_edges(raw_edges: Variant, valid_ids: Dictionary, label: String, issues: Array[String]) -> void:
	if not raw_edges is Array:
		issues.append("STRUCTURE: " + label + " edges are not an array")
		return
	for raw in raw_edges:
		if not raw is Dictionary:
			issues.append("STRUCTURE: malformed " + label + " edge")
			continue
		var edge: Dictionary = raw
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		if not valid_ids.has(a) or not valid_ids.has(b):
			issues.append("LOGISTICS: unresolved " + label + " edge " + a + " -> " + b)
		if a == b:
			issues.append("CONGRUENCY: self-edge is not allowed for " + a)
