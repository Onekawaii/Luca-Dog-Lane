class_name ChalkCircleRouter
extends RefCounted

# Native Hive-Lattice adaptation of Chalk Circle's six-layer control spine.
#
# This is deliberately campaign-neutral. It observes resolved gameplay actions,
# records a deterministic hash chain, and exposes optional requirements to
# campaign content. It does not add fields to WorldState or save schema v3:
# state lives under WorldState.world_state["chalk_circle"].

const SCHEMA := "hive_chalk_circle_v1"
const MAX_RECENT_ACTIONS := 8
const MAX_ARCHIVE_ENTRIES := 64

const LAYER_NAMES := {
	1: "THE GATE",
	2: "ANTECHAMBER",
	3: "MIRROR HALL",
	4: "PRESSURE CHAMBER",
	5: "ARCHIVE VAULT",
	6: "THE REFUSAL",
}


func initialize(state: WorldState) -> void:
	var existing = state.world_state.get("chalk_circle", {})
	if typeof(existing) != TYPE_DICTIONARY or existing.get("schema", "") != SCHEMA:
		reset(state)


func reset(state: WorldState) -> void:
	state.world_state["chalk_circle"] = {
		"schema": SCHEMA,
		"layer": 1,
		"layer_name": LAYER_NAMES[1],
		"mode": "ritual",
		"recent_actions": [],
		"descent_history": [],
		"archive": [],
		"archive_head": "",
		"triad": {
			"belief": "unresolved",
			"behavior": "none",
			"cost": "none",
		},
		"pressure_refresh_required": false,
		"refusal_reason": "",
	}


func snapshot(state: WorldState) -> Dictionary:
	initialize(state)
	return state.world_state["chalk_circle"].duplicate(true)


func observe_action(state: WorldState, action_data: Dictionary, outcome: Dictionary) -> Dictionary:
	initialize(state)
	var root: Dictionary = state.world_state["chalk_circle"]
	var action_id := str(action_data.get("id", "unknown"))
	var kind := str(action_data.get("kind", "action"))
	var rejected := outcome.has("error")

	_append_recent(root, {
		"id": action_id,
		"kind": kind,
		"turn": state.turn_count,
		"rejected": rejected,
	})

	var causes := _detect_causes(state, root, action_data, outcome)
	var current_layer := int(root.get("layer", 1))
	var target_layer := current_layer
	var primary_cause := ""

	if current_layer == 1 and not rejected:
		target_layer = 2
		primary_cause = "runtime_entry_passed"

	for cause in causes:
		match cause:
			"pattern_detected":
				target_layer = maxi(target_layer, 3)
			"contradiction_detected", "pressure_detected":
				target_layer = maxi(target_layer, 4)
				root["pressure_refresh_required"] = true
			"archive_requested":
				target_layer = maxi(target_layer, 5)
			"recursion_detected", "refusal_requested":
				target_layer = 6
				root["refusal_reason"] = cause
		if primary_cause == "":
			primary_cause = cause

	var transition := {
		"changed": false,
		"from_layer": current_layer,
		"to_layer": current_layer,
		"layer_name": str(root.get("layer_name", LAYER_NAMES[current_layer])),
		"cause": "",
	}
	if target_layer != current_layer:
		transition = _transition(root, target_layer, primary_cause)

	_update_triad(state, root, action_id)
	var archive_entry := _archive_event(
		root,
		kind,
		action_id,
		state.turn_count,
		int(root.get("layer", 1)),
		rejected
	)

	return {
		"transition": transition,
		"archive_entry": archive_entry,
		"causes": causes,
		"snapshot": root.duplicate(true),
	}


func request_archive_focus(state: WorldState, reason: String = "explicit_archive") -> Dictionary:
	return observe_action(
		state,
		{"kind": "system", "id": reason, "archive": true},
		{"result": reason}
	)


func request_refusal(state: WorldState, reason: String) -> Dictionary:
	return observe_action(
		state,
		{"kind": "system", "id": "refusal", "refusal_reason": reason},
		{"result": ""}
	)


func refresh_pressure(state: WorldState) -> void:
	initialize(state)
	state.world_state["chalk_circle"]["pressure_refresh_required"] = false


static func evaluate_requirement(state: WorldState, spec: Dictionary) -> bool:
	var root = state.world_state.get("chalk_circle", {})
	if typeof(root) != TYPE_DICTIONARY:
		return false
	var layer := int(root.get("layer", 1))
	if spec.has("layer_gte") and layer < int(spec["layer_gte"]):
		return false
	if spec.has("layer_lte") and layer > int(spec["layer_lte"]):
		return false
	if spec.has("layer_eq") and layer != int(spec["layer_eq"]):
		return false
	if spec.has("mode") and str(root.get("mode", "")) != str(spec["mode"]):
		return false
	if spec.has("refused") and (layer == 6) != bool(spec["refused"]):
		return false
	if spec.has("archive_min") and root.get("archive", []).size() < int(spec["archive_min"]):
		return false
	if spec.has("pressure_refreshed"):
		var refreshed := not bool(root.get("pressure_refresh_required", false))
		if refreshed != bool(spec["pressure_refreshed"]):
			return false
	return true


func _append_recent(root: Dictionary, entry: Dictionary) -> void:
	var recent: Array = root.get("recent_actions", [])
	recent.append(entry)
	while recent.size() > MAX_RECENT_ACTIONS:
		recent.pop_front()
	root["recent_actions"] = recent


func _detect_causes(
	state: WorldState,
	root: Dictionary,
	action_data: Dictionary,
	outcome: Dictionary
) -> Array:
	var causes: Array = []
	var action_id := str(action_data.get("id", "unknown"))
	var recent: Array = root.get("recent_actions", [])
	var occurrences := 0
	for entry in recent:
		if str(entry.get("id", "")) == action_id:
			occurrences += 1

	if occurrences >= 2:
		causes.append("pattern_detected")
	if occurrences >= 4:
		causes.append("recursion_detected")

	var bureaucracy := int(state.stats.get("bureaucracy", 0))
	var ape_chaos := int(state.stats.get("ape_chaos", 0))
	var alter := int(state.stats.get("alter", 0))
	if (bureaucracy >= 4 and ape_chaos >= 4) or (bureaucracy >= 4 and alter >= 4) or (ape_chaos >= 4 and alter >= 4):
		causes.append("contradiction_detected")

	if int(state.stats.get("hive_pressure", 0)) >= 5 or state.conditions.has("condition.under_scrutiny"):
		causes.append("pressure_detected")

	if bool(action_data.get("archive", false)):
		causes.append("archive_requested")

	if str(action_data.get("refusal_reason", "")) != "":
		causes.append("refusal_requested")

	if outcome.has("error") and occurrences >= 3:
		causes.append("recursion_detected")

	return causes


func _transition(root: Dictionary, target_layer: int, cause: String) -> Dictionary:
	var from_layer := int(root.get("layer", 1))
	target_layer = clampi(target_layer, 1, 6)
	root["layer"] = target_layer
	root["layer_name"] = LAYER_NAMES[target_layer]
	var history: Array = root.get("descent_history", [])
	history.append({
		"from": from_layer,
		"to": target_layer,
		"cause": cause,
	})
	root["descent_history"] = history
	return {
		"changed": true,
		"from_layer": from_layer,
		"to_layer": target_layer,
		"layer_name": LAYER_NAMES[target_layer],
		"cause": cause,
	}


func _update_triad(state: WorldState, root: Dictionary, action_id: String) -> void:
	root["triad"] = {
		"belief": _route_leaning(state),
		"behavior": action_id,
		"cost": _cost_signal(state),
	}


func _route_leaning(state: WorldState) -> String:
	var bureaucracy := int(state.stats.get("bureaucracy", 0))
	var ape_chaos := int(state.stats.get("ape_chaos", 0))
	var alter := int(state.stats.get("alter", 0))
	var hi := maxi(bureaucracy, maxi(ape_chaos, alter))
	var lo := mini(bureaucracy, mini(ape_chaos, alter))
	if hi - lo <= 2:
		return "hybrid"
	if bureaucracy == hi:
		return "bureaucratic"
	if ape_chaos == hi:
		return "feral"
	return "altered"


func _cost_signal(state: WorldState) -> String:
	var pressure := int(state.stats.get("hive_pressure", 0))
	var curse := int(state.stats.get("curse", 0))
	var conditions_count := state.conditions.size()
	if pressure >= 5:
		return "hive_pressure:" + str(pressure)
	if curse > 0:
		return "curse:" + str(curse)
	if conditions_count > 0:
		return "conditions:" + str(conditions_count)
	return "none"


func _archive_event(
	root: Dictionary,
	kind: String,
	action_id: String,
	turn: int,
	layer: int,
	rejected: bool
) -> Dictionary:
	var previous := str(root.get("archive_head", ""))
	var material := previous + "|" + kind + "|" + action_id + "|" + str(turn) + "|" + str(layer) + "|" + str(rejected)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(material.to_utf8_buffer())
	var digest := ctx.finish().hex_encode()
	var entry := {
		"sequence": root.get("archive", []).size() + 1,
		"turn": turn,
		"kind": kind,
		"action_id": action_id,
		"layer": layer,
		"previous_hash": previous,
		"hash": digest,
		"rejected": rejected,
	}
	var archive: Array = root.get("archive", [])
	archive.append(entry)
	while archive.size() > MAX_ARCHIVE_ENTRIES:
		archive.pop_front()
	root["archive"] = archive
	root["archive_head"] = digest
	return entry
