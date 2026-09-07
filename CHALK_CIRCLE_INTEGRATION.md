# Chalk Circle → Hive-Lattice Integration

Status: **native bridge implemented; campaign adoption is opt-in**.

## What was integrated

Hive now carries Chalk Circle's six-layer structural spine as a native Godot
runtime subsystem:

1. THE GATE
2. ANTECHAMBER
3. MIRROR HALL
4. PRESSURE CHAMBER
5. ARCHIVE VAULT
6. THE REFUSAL

The bridge observes resolved gameplay actions and stores its state under:

`WorldState.world_state["chalk_circle"]`

That field already exists in save schema v3, so this integration does **not**
add a new save field and does not modify Strawberry Omen's frozen content
schemas.

## What it does

- records recent resolved actions;
- detects repeated action patterns;
- detects mixed high route pressures as contradiction;
- notices existing Hive pressure / under-scrutiny conditions;
- maintains a small Belief × Behavior × Cost triad projection;
- maintains a SHA-256 hash chain of observed gameplay actions;
- emits layer-change, archive and refusal events on EventBus;
- exposes an optional `{"chalk": {...}}` requirement primitive through
  ActionResolver.

Supported requirement keys:

- `layer_gte`
- `layer_lte`
- `layer_eq`
- `mode`
- `refused`
- `archive_min`
- `pressure_refreshed`

No current Strawberry Omen choice is rewritten to require these. Existing
completion paths remain authoritative.

## What was deliberately NOT merged

The following stay outside Hive's engine:

- Chalk Circle's Python Witness Environment runtime;
- Ollama / Brother Ape setup;
- telemetry/backup/doctor CLI infrastructure;
- duplicate local archive implementation;
- unrelated ApeGPT bundles;
- Cluckpocalypse.

Those are separate products or support systems, not Hive engine code.

## Spiral Cow

The recovered Spiral Cow v3 world is a strong candidate for a **Hive campaign
module**, not an engine subsystem.

Recommended path:

`campaigns/spiral_cow/`

The source archive contains hundreds of authored locations plus extended
locations, scenarios, meters and tower logic. Before conversion, repair the
package-relative import bug in `spiral_adapter.py`; otherwise the documented
run path loads only its small fallback/core room set.

The correct next phase is a deterministic source-to-Hive importer that maps:

- Spiral Cow locations → Hive locations/scenes;
- Virtue/Ruin/Hope/Agency → campaign stats;
- scenarios → encounter/rule-table data;
- tower floors → room graph/progression;
- freeform outcomes → deterministic choice/result records.

This keeps Hive's engine stable while allowing the Cow to become an actual
world inside the Lattice.
