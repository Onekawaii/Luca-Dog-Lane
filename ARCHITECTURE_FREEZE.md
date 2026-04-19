# Architecture Freeze Report

**Status**: 🔒 LOCKED  
**As of**: Build completion after Chapter 1 vertical slice  
**Next Release**: Chapter 2 Production Pipeline  

---

## Part 1: Schemas Frozen at V1

All content schemas are now explicitly versioned and locked. **Do not add keys without a schema version bump**.

### Frozen Schemas
- ✅ **room_schema_v1** — LOCKED (rooms_ch01.json)
- ✅ **character_schema_v1** — LOCKED (characters.json)
- ✅ **item_schema_v1** — LOCKED (items.json)
- ✅ **consequence_table_schema_v1** — LOCKED (writing/bad_idea_results.json)
- ✅ **game_state schema** — LOCKED (persistent stats across chapters)

Full schema definitions: see `SCHEMA_VERSIONS.md`

### Validation Rules (FROZEN)
1. Every room ID must be unique within chapter
2. Every exit must point to a valid room ID in that chapter
3. Every item/NPC reference must exist in corresponding JSON
4. Level indices must be contiguous (1-10 per chapter)
5. All required keys must be present (strict whitelist)
6. No extra keys allowed (fails validation)

---

## Part 2: Content Infrastructure

### New Tools Created
- **`tools/content_lint.py`** — Clean validation reporting (run before every build)
  ```bash
  python tools/content_lint.py
  ```
  Output: 20 rooms, 10 items, 4 NPCs, 0 broken exits, ✅ PASSED

- **`tools/generate_chapter_shell.py`** — Generate valid empty chapter files
  ```bash
  python tools/generate_chapter_shell.py 2 3 4
  ```
  Creates rooms_chXX.json with proper structure (prevents malformed content)

- **`tests/test_chapter1_minimal_path.py`** — Spine test (automated playthrough)
  ```bash
  python tests/test_chapter1_minimal_path.py
  ```
  Output: ✅ Chapter 1 spine intact, ✅ Content valid

### Authoring Templates (content/templates/)
- `room_template.json` — Copy this for new rooms
- `character_template.json` — Copy this for new NPCs
- `item_template.json` — Copy this for new items
- `consequence_table_template.json` — Copy this for action outcomes

---

## Part 3: State Tracking Added

### New Fields in GameState
```python
chapter_route_history: []  # List of end-of-chapter summaries
chapters_completed: []     # [1, 2, 3] etc
```

### New Methods in GameState
- `calculate_route_leaning()` — Returns "bureaucratic", "feral", "altered", or "hybrid"
- `save_chapter_summary(chapter_num)` — Serializes end-of-chapter state

### End-of-Chapter Summary Structure
```json
{
  "chapter": 1,
  "route_leaning": "bureaucratic",
  "chapters_completed": [1],
  "key_flags": ["global:entered_mall"],
  "npc_standings": {
    "frank": 3,
    "chicken": 1
  },
  "special_actions_taken": ["eat_random_item"],
  "final_health": 87,
  "final_bureaucracy": 7,
  "final_ape_chaos": 1,
  "final_alter": 0
}
```

This enables Chapter 2 to branch based on Chapter 1 choices.

---

## Part 4: Current Coverage

### Chapters Ready
- ✅ **Chapter 1** — 10 rooms, full content, tested
- ✅ **Chapter 2** — 10-room empty shell, passes validation
- ✅ **Chapter 3** — 10-room empty shell, passes validation

### Spine Test Results
```
✅ Automated path through Ch1 executes correctly
✅ Player navigates from Entry Mall → Escalator Split → Hive Concourse → Queue Vestibule → and beyond
✅ Inventory persists (can take/carry items)
✅ Health remains at 100 (no damage dealt)
✅ All rooms accessible without crashes
```

---

## Part 5: Gates Before Next Phase

**DO NOT PROCEED to Chapter 2 authoring until:**

1. ✅ `python tools/content_lint.py` returns 0 exit code
2. ✅ `python tests/test_chapter1_minimal_path.py` shows all tests PASSED
3. ✅ `python main.py` runs validation and starts without errors
4. ✅ Manual test: `look → take receipt → go east → go down` works

**If any of these fail:** Fix before moving forward.

---

## Part 6: Exact Next Sprint

### Sprint: "Chapter 2 Production Pipeline"

#### Task 1: Freeze and Validate ✅ DONE
- Schemas documented in SCHEMA_VERSIONS.md
- Tools created: lint, generator, spine test
- Empty Ch2 and Ch3 shells pass validation

#### Task 2: Add Progression Gates (NEXT)
- Implement Frank reputation system (Chapter 2 focus)
- Add low/mid/high reputation bands to all interactions
- Test: Frank denies player with low reputation

#### Task 3: Chapter-End Checkpoint (NEXT)
- Wire save system to capture summaries
- Create Chapter 2 end gate with multiple paths
- Test: Chapter 1 → Chapter 2 with persistent route_leaning

#### Task 4: Write Chapter 2 (NEXT)
- ~10 rooms around Frank's bureaucratic pressure
- NPC interactions increase based on route_leaning
- Test: Spine test for Chapter 2 minimal path

#### Task 5: Integration Test (NEXT)
- Full Chapter 1 → Chapter 2 playthrough
- Verify route history persists
- Validate NPC reactions to prior route

---

## Part 7: What NOT To Do Now

❌ Do NOT add new verbs/commands to Chapter 1  
❌ Do NOT change room/item/character schemas  
❌ Do NOT add decorative flavor without mechanical purpose  
❌ Do NOT create content without running `content_lint.py` first  
❌ Do NOT skip the spine test when changing core flow  

---

## Part 8: How to Prevent Rot

**Before every commit:**
```bash
python tools/content_lint.py          # Validate structure
python tests/test_chapter1_minimal_path.py  # Validate flow
python main.py                         # Quick smoke test
```

**Before authoring Chapter 2 content:**
```bash
# Copy template
cp content/templates/room_template.json content/my_new_room.json

# Author in rooms_ch02.json
# Then validate
python tools/content_lint.py
```

**If validator fails:** You introduced schema drift. Revert or fix immediately.

---

## Part 9: Files to Send for Chapter 2 Plan

Ready to receive Chapter 2 build spec. Will provide:

1. ✅ Frozen schemas (SCHEMA_VERSIONS.md)
2. ✅ Validation infrastructure (validate_content.py, content_lint.py)
3. ✅ Authoring templates (content/templates/)
4. ✅ Chapter shells (rooms_ch02.json, rooms_ch03.json)
5. ✅ Spine test (test_chapter1_minimal_path.py)
6. ✅ Generator script (generate_chapter_shell.py)
7. ✅ Route tracking (GameState methods)

**Awaiting**: Exact Chapter 2 room specs, Frank system design, NPC reactivity rules.

---

## Summary

The architecture is now frozen. The spine is tested. The path to Chapter 2 is clear.

🔒 No more schema drift.  
🧪 Every build validated.  
⚙️ Systems ready to scale.  

**Next exact step**: Receive Chapter 2 specification and NPC design.
