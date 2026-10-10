extends RefCounted

# Presentation and adapters own UI/saving; this model owns quest progression.
var catalog: Dictionary = {}
var anchors: Array[Dictionary] = []
var accepted := false
var completed := false
var read_ids: Array[String] = []

func configure(document: Dictionary, locations: Array, saved: Dictionary = {}) -> bool:
	if document.get("schema_version") != 1 or not document.get("quest") is Dictionary or locations.size() != 3:
		return false
	var seen: Dictionary = {}
	var prepared: Array[Dictionary] = []
	for raw in locations:
		if not raw is Dictionary or not raw.has("id") or not raw.has("title") or not raw.has("text") or not raw.has("position"):
			return false
		var id := str(raw.id)
		if id.is_empty() or seen.has(id) or not raw.position is Array or raw.position.size() != 3:
			return false
		seen[id] = true
		prepared.append(raw.duplicate(true))
	anchors = prepared
	catalog = document.duplicate(true)
	read_ids.clear()
	var saved_reads = saved.get("read_ids", [])
	if saved_reads is Array:
		for id in saved_reads:
			if seen.has(str(id)) and not read_ids.has(str(id)):
				read_ids.append(str(id))
	accepted = saved.get("accepted", false) == true
	completed = saved.get("completed", false) == true and accepted and read_ids.size() == anchors.size()
	return true

func entry(id: String) -> Dictionary:
	for record in anchors:
		if str(record.id) == id:
			return record.duplicate(true)
	return {}

func read_record(id: String) -> String:
	var record := entry(id)
	if record.is_empty():
		return "There is no readable record here."
	if not read_ids.has(id):
		read_ids.append(id)
	return str(record.text)

func talk(resident: String, topic: String) -> Array[String]:
	var voice: Dictionary = catalog.get("residents", {}).get(resident, catalog.get("default_resident", {}))
	var lines: Array[String] = []
	if topic == "history":
		lines.append(str(voice.get("history", "Every road here was built for someone who expected to return.")))
		return lines
	if completed:
		lines.append(str(catalog.quest.return_greeting))
	elif not accepted:
		accepted = true
		lines.append(str(catalog.quest.offer))
	elif read_ids.size() == anchors.size():
		completed = true
		lines.append(str(catalog.quest.conclusion))
		lines.append("Earned title: " + str(catalog.quest.reward_title))
	else:
		lines.append(str(voice.get("hint", "Follow the old road. The records are outside the buildings.")))
	lines.append(objective())
	return lines

func goal() -> Dictionary:
	if completed or not accepted:
		return {}
	for record in anchors:
		if not read_ids.has(str(record.id)):
			return record.duplicate(true)
	return {}

func objective(at := Vector3.INF) -> String:
	if completed:
		return str(catalog.quest.reward_title) + " // " + str(catalog.quest.epilogue)
	if not accepted:
		return str(catalog.quest.introduction)
	var next := goal()
	if next.is_empty():
		return str(catalog.quest.return_objective)
	var result := "Read the record at " + str(next.title)
	if at.is_finite():
		var offset := Vector2(float(next.position[0]) - at.x, float(next.position[2]) - at.z)
		var heading := ("north" if offset.y < 0.0 else "south") if absf(offset.y) > absf(offset.x) else ("east" if offset.x > 0.0 else "west")
		result += " // %dm %s" % [roundi(offset.length()), heading]
	return result

func snapshot() -> Dictionary:
	return {"accepted": accepted, "completed": completed, "read_ids": read_ids.duplicate()}

func journal_text() -> String:
	var lines: Array[String] = [str(catalog.quest.title), objective(), "", "Records recovered: %d / %d" % [read_ids.size(), anchors.size()]]
	for record in anchors:
		if read_ids.has(str(record.id)):
			lines.append("\n" + str(record.title) + "\n" + str(record.text))
	return "\n".join(lines)
