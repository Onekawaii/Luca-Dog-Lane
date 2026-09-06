# Strawberry Reactive Gameplay Contract — v1

**Schema id:** `strawberry_interactions_v1`  
**Introduced:** Hive-Lattice `v0.6.0-lattice-alive`

This contract is campaign-local. It does not alter `room_schema_v1`,
`character_schema_v1`, `item_schema_v1`, or other frozen Bard schemas.

## Runtime state

`ModuleState` adds the following persisted reactive state:

- `room_state`: per-location durable memory;
- `npc_memory`: integer relationship/reputation values keyed by NPC id;
- `conditions`: condition id -> remaining turns (`-1` = persistent);
- `event_history`: deterministic table events already fired;
- `turn_count`: interaction clock;
- `rng_seed`: deterministic campaign seed;
- `last_outcome`: last rule/check/event metadata.

## Choice requirements

Existing encounter choices may be overlaid, and new contextual choices may be
added, using:

- `requires_flags`, `forbids_flags`;
- `requires_items`, `requires_any_items`;
- `requires_stats`;
- composable `when` conditions over flags, items, stats, NPC memory, room state,
  conditions and current scene;
- `hidden_if_locked` to reveal routes only when earned.

## Effects

Reactive records may apply:

- `sets_flags`;
- `stat_delta`;
- `grants_items`, `removes_items`, `consumes_items`;
- `npc_delta`;
- `room_state`;
- `add_conditions`, `remove_conditions`;
- `next_scene`;
- deterministic `triggers_table`;
- threshold `check` success/failure effects;
- ordered `rule_table` resolution.

## Determinism

Weighted tables use a SHA-256-derived roll over campaign seed, turn count,
scene id and table id. Identical state + identical action therefore yields the
same event. Save/load persists seed, turn and event history.

## Compatibility

- Encounter JSON without reactive metadata behaves exactly as before.
- Existing choice ids remain valid.
- Save v1 is accepted and upgraded in-memory with empty/default reactive fields.
- Save v2 persists the full reactive state.
- The v0.5.2 mobile UX is treated as a presentation contract, not redesigned by
  this schema.

## Act V verdict

`department_verdict` is a rule table. The current implementation considers
actual evidence/testimony, relationship memory, earlier hostile actions and core
stats, and produces an exoneration, procedural exoneration, cosmic compromise or
guilty result. The player chooses how to present the record; they do not directly
select the verdict label.
