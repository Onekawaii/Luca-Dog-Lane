class_name ActionResolver
extends RefCounted

# ActionResolver for Hive-Lattice GDScript client.
# Implements exact parity with Python CampaignModule logic.

var loader: CampaignLoader


func _init(p_loader: CampaignLoader) -> void:
	loader = p_loader


func evaluate(state: WorldState, spec: Dictionary) -> bool:
	if spec.is_empty():
		return true

	if spec.has("all"):
		for child in spec["all"]:
			if not evaluate(state, child):
				return false
		return true

	if spec.has("any"):
		for child in spec["any"]:
			if evaluate(state, child):
				return true
		return false

	if spec.has("not"):
		return not evaluate(state, spec["not"])

	if spec.has("flags"):
		for k in spec["flags"]:
			if state.flags.get(k) != spec["flags"][k]:
				return false

	if spec.has("not_flags"):
		for k in spec["not_flags"]:
			if state.flags.get(k) == spec["not_flags"][k]:
				return false

	if spec.has("item"):
		if not state.has_item(spec["item"]):
			return false

	if spec.has("items_all"):
		for itm in spec["items_all"]:
			if not state.has_item(itm):
				return false

	if spec.has("items_any"):
		var found = false
		for itm in spec["items_any"]:
			if state.has_item(itm):
				found = true
				break
		if not found:
			return false

	if spec.has("scene"):
		if state.current_scene != spec["scene"]:
			return false

	if spec.has("condition"):
		if not state.conditions.has(spec["condition"]):
			return false

	if spec.has("stats"):
		for stat in spec["stats"]:
			var val = int(state.stats.get(stat, 0))
			if not _compare_number(val, spec["stats"][stat]):
				return false

	if spec.has("npc"):
		var npc_rule = spec["npc"]
		var val = int(state.npc_memory.get(npc_rule["id"], 0))
		if not _compare_number(val, npc_rule):
			return false

	if spec.has("chalk"):
		if not ChalkCircleRouter.evaluate_requirement(state, spec["chalk"]):
			return false

	if spec.has("room"):
		var room_rule = spec["room"]
		var loc = room_rule.get("location", state.current_location)
		var val = state.room_state.get(loc, {}).get(room_rule["key"])
		if room_rule.has("equals"):
			if val != room_rule["equals"]:
				return false
		var has_num_cmp = false
		for k in ["gte", "lte", "gt", "lt", "eq"]:
			if room_rule.has(k):
				has_num_cmp = true
				break
		if has_num_cmp:
			var numeric = int(val) if val != null else 0
			if not _compare_number(numeric, room_rule):
				return false

	return true


func _compare_number(val: int, rule: Dictionary) -> bool:
	if rule.has("gte") and val < int(rule["gte"]):
		return false
	if rule.has("lte") and val > int(rule["lte"]):
		return false
	if rule.has("gt") and val <= int(rule["gt"]):
		return false
	if rule.has("lt") and val >= int(rule["lt"]):
		return false
	if rule.has("eq") and val != int(rule["eq"]):
		return false
	return true


func _requirements_for_choice(choice: Dictionary) -> Dictionary:
	var parts: Array = []
	if choice.has("requires_flags"):
		parts.append({"flags": choice["requires_flags"]})
	if choice.has("forbids_flags"):
		parts.append({"not_flags": choice["forbids_flags"]})
	if choice.has("requires_items"):
		parts.append({"items_all": choice["requires_items"]})
	if choice.has("requires_any_items"):
		parts.append({"items_any": choice["requires_any_items"]})
	if choice.has("requires_stats"):
		parts.append({"stats": choice["requires_stats"]})
	if choice.has("when"):
		parts.append(choice["when"])
	if parts.is_empty():
		return {}
	return {"all": parts}


func _locked_reason(state: WorldState, choice: Dictionary) -> String:
	if choice.has("locked_reason"):
		return choice["locked_reason"]
	var missing: Array = []
	for itm in choice.get("requires_items", []):
		if not state.has_item(itm):
			var item_meta = loader.get_item(itm)
			missing.append(item_meta.get("name", itm))
	if not missing.is_empty():
		return "Requires " + ", ".join(missing)
	for stat in choice.get("requires_stats", {}):
		var rule = choice["requires_stats"][stat]
		var val = int(state.stats.get(stat, 0))
		if not _compare_number(val, rule):
			if rule.has("gte"):
				return "Requires " + stat.replace("_", " ").capitalize() + " " + str(rule["gte"]) + "+"
	if choice.has("requires_flags"):
		return "A prior action has not unlocked this yet."
	return "Unavailable because of your current state."


func scene_choices(scene_id: String) -> Array:
	var scene = loader.get_encounter(scene_id)
	var overlays = loader.interactions.get("choice_overlays", {})
	var choices: Array = []
	for base in scene.get("choices", []):
		var merged = base.duplicate(true)
		if overlays.has(base["id"]):
			var ov = overlays[base["id"]]
			for k in ov:
				merged[k] = ov[k]
		choices.append(merged)
	var extra_choices = loader.interactions.get("scene_choices", {}).get(scene_id, [])
	for extra in extra_choices:
		choices.append(extra.duplicate(true))
	return choices


func choice_views(state: WorldState) -> Array:
	var views: Array = []
	for choice in scene_choices(state.current_scene):
		var reqs = _requirements_for_choice(choice)
		var available = evaluate(state, reqs)
		if not available and choice.get("hidden_if_locked", false):
			continue
		views.append({
			"id": choice["id"],
			"label": choice.get("label", choice["id"]),
			"available": available,
			"locked_reason": "" if available else _locked_reason(state, choice),
			"kind": choice.get("kind", "choice"),
		})
	return views


func _advance_conditions(state: WorldState) -> void:
	var expired: Array = []
	for cond in state.conditions.keys():
		var turns = int(state.conditions[cond])
		if turns < 0:
			continue
		var rem = turns - 1
		if rem <= 0:
			expired.append(cond)
		else:
			state.conditions[cond] = rem
	for cond in expired:
		state.conditions.erase(cond)


func apply_effects(state: WorldState, effects: Dictionary) -> void:
	if effects.has("sets_flags"):
		for k in effects["sets_flags"]:
			state.flags[k] = effects["sets_flags"][k]

	if effects.has("stat_delta"):
		for k in effects["stat_delta"]:
			state.stats[k] = int(state.stats.get(k, 0)) + int(effects["stat_delta"][k])

	if effects.has("grants_items"):
		for itm in effects["grants_items"]:
			state.add_item(itm)

	if effects.has("removes_items"):
		for itm in effects["removes_items"]:
			state.remove_item(itm)

	if effects.has("consumes_items"):
		for itm in effects["consumes_items"]:
			state.remove_item(itm)

	if effects.has("npc_delta"):
		for npc_id in effects["npc_delta"]:
			state.npc_memory[npc_id] = int(state.npc_memory.get(npc_id, 0)) + int(effects["npc_delta"][npc_id])

	if effects.has("room_state"):
		var room_loc = effects.get("room_location", "")
		var room = state.room_memory(room_loc)
		for k in effects["room_state"]:
			room[k] = effects["room_state"][k]

	if effects.has("add_conditions"):
		for cond in effects["add_conditions"]:
			if typeof(cond) == TYPE_STRING:
				state.conditions[cond] = -1
			elif typeof(cond) == TYPE_DICTIONARY:
				state.conditions[cond["id"]] = int(cond.get("turns", -1))

	if effects.has("remove_conditions"):
		for cond in effects["remove_conditions"]:
			state.conditions.erase(cond)

	if effects.has("actor_signal"):
		for actor_id in effects["actor_signal"]:
			var sig = effects["actor_signal"][actor_id]
			if not state.actor_dynamics.has(actor_id):
				state.actor_dynamics[actor_id] = {
					"activation": 0.5,
					"coherence": 0.5,
					"social_openness": 0.5,
					"fixation": 0.5,
					"recovery_potential": 0.5,
					"memory_pressure": 0.5
				}
			var dyn = state.actor_dynamics[actor_id]
			for param in sig:
				if dyn.has(param):
					dyn[param] = clampf(dyn[param] + float(sig[param]), 0.0, 1.0)


func _deterministic_roll(state: WorldState, salt: String) -> int:
	var text = str(state.rng_seed) + ":" + str(state.turn_count) + ":" + state.current_scene + ":" + salt
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var digest = ctx.finish()
	var val: int = 0
	for i in range(min(8, digest.size())):
		val = (val << 8) | digest[i]
	return abs(val)


func trigger_table(state: WorldState, table_id: String) -> Dictionary:
	var rows = loader.random_tables.get(table_id, [])
	if rows.is_empty():
		return {}
	var total: int = 0
	for r in rows:
		total += max(0, int(r.get("weight", 1)))
	if total <= 0:
		return {}
	var pick = _deterministic_roll(state, table_id) % total
	var selected = rows[-1]
	var cursor: int = 0
	for r in rows:
		cursor += max(0, int(r.get("weight", 1)))
		if pick < cursor:
			selected = r
			break
	apply_effects(state, selected)
	var event = {
		"table": table_id,
		"text": selected.get("text", ""),
		"turn": state.turn_count,
	}
	state.event_history.append(event)
	if event["text"] != "" and (state.log.is_empty() or state.log[-1] != event["text"]):
		state.log.append(event["text"])
	return event


func resolve_rule_table(state: WorldState, table_id: String) -> Dictionary:
	var rules = loader.interactions.get("rule_tables", {}).get(table_id, [])
	for rule in rules:
		if rule.get("default", false) or evaluate(state, rule.get("when", {})):
			apply_effects(state, rule)
			return rule
	return {}


func enter_scene(state: WorldState, scene_id: String = "", apply_entry: bool = true) -> Dictionary:
	var target_scene_id = scene_id if scene_id != "" else state.current_scene
	var scene = loader.get_encounter(target_scene_id)
	if scene.is_empty():
		push_error("Scene not found: " + target_scene_id)
		return {}
	state.current_scene = scene["id"]
	state.current_location = scene.get("location", state.current_location)
	var room = state.room_memory()
	room["visited"] = true
	room["visits"] = int(room.get("visits", 0)) + (1 if apply_entry else 0)

	if apply_entry:
		for k in scene.get("on_enter_flags", {}):
			state.flags[k] = scene["on_enter_flags"][k]
		var entry_overlay = loader.interactions.get("scene_entry_effects", {}).get(scene["id"], {})
		apply_effects(state, entry_overlay)
		if entry_overlay.has("triggers_table"):
			trigger_table(state, entry_overlay["triggers_table"])
	return scene


func choose(state: WorldState, choice_id: String) -> Dictionary:
	var choices = scene_choices(state.current_scene)
	var choice: Dictionary = {}
	for c in choices:
		if c.get("id") == choice_id:
			choice = c
			break
	if choice.is_empty():
		return {"error": "Unknown choice: " + choice_id}

	var reqs = _requirements_for_choice(choice)
	if not evaluate(state, reqs):
		return {"error": _locked_reason(state, choice)}

	_advance_conditions(state)
	state.turn_count += 1

	apply_effects(state, choice)
	var result_text = choice.get("result", "")

	if choice.has("spawns_npc"):
		var npc_to_spawn = choice["spawns_npc"]
		state.set_flag(npc_to_spawn + "_spawned", true)
		state.room_memory()["tammy_present"] = true

	if choice.has("check"):
		var chk = choice["check"]
		var branch = chk.get("success", {}) if evaluate(state, chk.get("when", {})) else chk.get("failure", {})
		apply_effects(state, branch)
		if branch.has("result"):
			result_text = branch["result"]
		if branch.has("next_scene"):
			choice["next_scene"] = branch["next_scene"]

	if choice.has("rule_table"):
		var rule = resolve_rule_table(state, choice["rule_table"])
		if rule.has("result"):
			result_text = rule["result"]

	if choice.has("triggers_table"):
		trigger_table(state, choice["triggers_table"])

	state.last_outcome = {
		"choice_id": choice_id,
		"turn": state.turn_count,
		"result": result_text,
		"next_scene": choice.get("next_scene")
	}

	if result_text != "":
		state.log.append(result_text)

	if choice.has("next_scene"):
		enter_scene(state, choice["next_scene"])

	return state.last_outcome


func use_item_on_target(state: WorldState, item_id: String, target_id: String) -> Dictionary:
	# Check specific item actions in interactions.json
	var item_actions = loader.interactions.get("item_actions", [])
	for act in item_actions:
		if act.get("item") == item_id and act.get("target") == target_id:
			if evaluate(state, act.get("when", {})):
				_advance_conditions(state)
				state.turn_count += 1
				apply_effects(state, act)
				var res_text = act.get("result", "")
				state.log.append(res_text)
				state.last_outcome = {
					"action_id": act.get("id"),
					"result": res_text
				}
				return state.last_outcome

	# Fallback: check if the target has a scene choice that requires this item
	# E.g. bag_wetberry_now for Wetberry
	var choices = scene_choices(state.current_scene)
	for c in choices:
		if c.has("requires_items") and c["requires_items"].has(item_id):
			if evaluate(state, _requirements_for_choice(c)):
				return choose(state, c["id"])

	# Default feedback if not usable
	var item_meta = loader.get_item(item_id)
	var item_name = item_meta.get("name", "That item")
	var msg = item_name + " does not produce a meaningful reaction here."
	return {"error": msg}
