# Schema Versions - Frozen Architecture

## room_schema_v1
**Status**: LOCKED (Chapter 1)  
**Used By**: rooms_ch01.json  
**Location**: content/rooms_ch01.json  

Required keys:
- id: "ch0X_room_name" (chapter_number, snake_case)
- chapter: integer
- level_index: integer (1-10 per chapter)
- name: string (display name)
- description: string (full room desc)
- short_description: string (brief one-liner)
- exits: dict (direction -> room_id)
- items: list of item names (must exist in items.json)
- npcs: list of NPC names (must exist in characters.json)
- tags: list (functional tags like "bureaucratic", "absurd", "entry")
- hazards: list (trap/challenge types)
- required_flags: list (flags that must be set to enter)
- set_flags_on_enter: list (flags set when entering)
- events: list (event triggers)
- special_commands: dict (command -> flavor text)
- failure_table: list (unused, reserved)
- success_table: list (unused, reserved)
- chapter_progress_value: integer (how much this room advances chapter)
- visited: boolean (runtime only, not in JSON)

No new keys without schema_v2.

---

## character_schema_v1
**Status**: LOCKED (Chapter 1)  
**Used By**: content/characters.json  

Required keys:
- name: string (must match NPC references in rooms)
- description: string
- role: string (companion, gatekeeper, judge, clerk, etc.)
- temperament: string (flavor description)
- topics: dict (topic -> response text)
- commands: list (what commands this NPC responds to)
- reputation_bands: dict (low/mid/high -> flavor text at each level)

No new keys without schema_v2.

---

## item_schema_v1
**Status**: LOCKED (Chapter 1)  
**Used By**: content/items.json  

Required keys:
- name: string (must match item references in rooms)
- weight: float
- description: string
- edible: boolean
- readable: boolean

No new keys without schema_v2.

---

## consequence_table_schema_v1
**Status**: LOCKED (Chapter 1)  
**Used By**: writing/bad_idea_results.json  

Format: dict of action_id -> list of entries  
Each entry:
- weight: integer (1-100, relative)
- conditions: list (conditional filters like "room_tag:junk", "has_item:X")
- text: string (result flavor, may contain {target} or {item})
- effects: dict (stat deltas: health, alter, bureaucracy, ape_chaos, etc.)

No new keys without schema_v2.

---

## game_state schema (runtime)
**Status**: LOCKED (Chapter 1)  

Persistent stats (saved across chapters):
- health: 0-100
- alter: 0+
- bureaucracy: 0+
- ape_chaos: 0+
- reputation_frank: -10 to +10
- reputation_goblins: -10 to +10
- reputation_succubi: -10 to +10
- chapter_progress: per-chapter (reset each chapter)
- curse: 0+
- hive_pressure: 0+
- resistance: 1+
- score: 0+

New fields (Chapter 2 prep):
- chapter_route_history: list of route_leanings (see below)

Route leaning tracking (new in Chapter 2):
- "bureaucratic" if bureaucracy > ape_chaos and bureaucracy > alter
- "feral" if ape_chaos > bureaucracy and ape_chaos > alter
- "altered" if alter > bureaucracy and alter > ape_chaos
- "hybrid" if stats are within 2 of each other

No new persistent fields without explicit schema change.

---

## End-of-Chapter Summary (new)
**Status**: LOCKED for serialization  
**Used By**: save system  

Structure (JSON):
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
  "special_actions_taken": ["eat_random_item", "ape_scream"],
  "final_health": 87,
  "final_bureaucracy": 7,
  "final_ape_chaos": 1,
  "final_alter": 0,
  "completion_time_seconds": 1247
}
```

This becomes machine-readable state for Chapter 2 branching.

---

## Validation Rules
**FROZEN** - These do not change without schema version bump:
1. Every room ID must be unique within chapter
2. Every room exit must point to a valid room ID
3. Every item/NPC reference must exist in corresponding JSON
4. Level indices must be contiguous (1-10)
5. All required keys must be present (no missing)
6. No extra keys allowed (strict whitelist)

---

## Schema Migration Path
When you move to schema_v2:
1. Create new template files
2. Update validate_content.py to check both versions
3. Migrate existing content explicitly
4. Freeze v2 before Ch3

DO NOT allow schema drift mid-chapter.
