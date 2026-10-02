class_name LucaModVM
extends RefCounted

const ALLOWED_OPS := ["emit_text", "set_tag", "spawn_request", "objective"]
const DENIED_CAPABILITIES := ["filesystem", "shell", "network", "native_code", "process"]

func validate_program(program: Array) -> Dictionary:
	var errors: Array[String] = []
	for i in range(program.size()):
		var row: Variant = program[i]
		if not row is Dictionary:
			errors.append("instruction %d is not an object" % i)
			continue
		var op := str((row as Dictionary).get("op", ""))
		if op not in ALLOWED_OPS:
			errors.append("instruction %d uses forbidden op %s" % [i, op])
	return {"ok": errors.is_empty(), "errors": errors}

func run(program: Array, context: Dictionary = {}) -> Dictionary:
	var validation := validate_program(program)
	if not bool(validation["ok"]):
		return {"ok": false, "errors": validation["errors"], "effects": []}
	var effects: Array = []
	var tags: Dictionary = context.get("tags", {}).duplicate(true)
	for row in program:
		var instruction: Dictionary = row
		match str(instruction.get("op", "")):
			"emit_text":
				effects.append({"kind": "text", "text": str(instruction.get("text", ""))})
			"set_tag":
				var key := str(instruction.get("key", ""))
				if not key.is_empty():
					tags[key] = instruction.get("value", true)
					effects.append({"kind": "tag", "key": key, "value": tags[key]})
			"spawn_request":
				effects.append({
					"kind": "spawn_request",
					"entity_type": str(instruction.get("entity_type", "")),
					"spec": (instruction.get("spec", {}) as Dictionary).duplicate(true),
				})
			"objective":
				effects.append({"kind": "objective", "text": str(instruction.get("text", ""))})
	return {"ok": true, "errors": [], "effects": effects, "tags": tags}
