# Luca Dog World — Hardened Engineering Protocol

This file is binding project procedure. It is not motivational prose.

## 0. Prime directive

**No receipt, no banana.**

Never claim FIXED, PASS, COMPLETE, RELEASED, SAFE, STABLE, or DONE without exact-state evidence from the current commit/worktree.

A successful command is not proof of the intended behavior unless that command actually exercises the behavior.

## 1. Operating posture

Act like a senior software engineer conducting a design review and laboratory exercise:

- define the invariant before editing code;
- state the failure mode being attacked;
- identify the cheapest falsifier;
- preserve a known-good baseline;
- change one architectural layer at a time;
- prefer mechanisms that are testable over mechanisms that are impressive;
- distinguish observation, inference, hypothesis, and proof;
- record unexpected behavior instead of explaining it away;
- never weaken a test merely to make it green;
- never silently expand scope;
- never silently migrate dependencies;
- never merge a migration branch until old behavior and new acceptance gates both pass.

## 2. HTE + Demander separation

Use HTE for truth acquisition, mechanism modeling, implementation, and test/inspect/fix loops. Use Demander as an independent completion judge. HTE's conclusion is not evidence for Demander, and Demander must re-inspect exact-state evidence independently.

`CLAIMED_COMPLETE != QUALIFIED != DELIVERED`

Any exact-state change invalidates affected qualification evidence and requires requalification.

## 3. Required task sequence

Every substantial task MUST follow this order.

### A. Exact state
Record:
- branch;
- HEAD SHA;
- clean/dirty status;
- engine version;
- dependency lock;
- relevant artifact versions.

### B. Problem statement
Describe:
- observed failure;
- expected behavior;
- invariant being violated;
- likely subsystem boundary.

### C. Falsifier
Write at least one test or probe that would prove the proposed fix is wrong.

### D. Design
State:
- ownership boundaries;
- data flow;
- lifecycle;
- persistence implications;
- Android/performance implications;
- rollback path.

### E. Implementation
Make the smallest coherent architectural change that satisfies the invariant.

### F. Verification
Run, as applicable:
- static contract tests;
- unit tests;
- parser/import gate;
- live headless runtime gate;
- targeted physics/gameplay harness;
- exported Windows runtime smoke;
- Android export/signature/package verification;
- performance telemetry;
- physical Android acceptance workbook.

### G. Demolition
Actively try to break the feature with boundary values, repeated actions, teleports, collisions, save/reload, and stress cases.

### H. Receipt
Append the exact commands/results/hashes to `engineering/BUILD_LEDGER.md`.

Only then may a commit be promoted or released.

## 4. Architecture laws for v0.13+

### 4.1 Stable release isolation
`main` remains the last verified release until the migration branch passes all release gates.
The Godot 4.3 v0.12.2 release is an immutable rollback point.

### 4.2 Toolchain pinning
External engines/plugins must be pinned by:
- semantic version/tag;
- download URL;
- SHA-256;
- license/source location.

No unpinned "latest" dependencies.

### 4.3 Deterministic world
Given the same world seed + generator version + mod set:
- base terrain;
- biome assignment;
- site placement;
- resource strata;
- NPC seed identities
must be reproducible.

Player edits are stored as deltas, not by serializing the entire generated world.

### 4.4 World simulation ownership
Separate:
- terrain generation;
- terrain mutation;
- streaming;
- navigation;
- entity simulation;
- vehicle physics;
- damage/injury;
- crafting/inventory;
- presentation/UI.

No god-object script may own all of these.

### 4.5 Mobile is a first-class target
Every world/physics design must budget:
- active rigid bodies;
- active ragdolls;
- streamed chunks;
- voxel remesh work;
- navigation rebuilds;
- memory;
- draw calls.

"Works on desktop" is not acceptance.

### 4.6 Physics is measured
Vehicle and injury systems must derive behavior from measurable state such as:
- mass;
- relative velocity;
- collision normal;
- impulse;
- contact point;
- component state.

Do not encode arbitrary damage directly from visual speed without tests.

### 4.7 NPCs are persistent agents
NPCs are not decorative walkers. Each persistent NPC must have:
- identity;
- trait vector;
- needs/goals;
- home/site relationships;
- current state;
- memory/event history sufficient to explain behavior;
- damage/injury state.

### 4.8 Ragdoll is a state transition
Humanoid NPCs use animated locomotion normally.
Physical ragdoll activates only under explicit conditions and must have a defined exit/incapacitation path.
Ragdoll count is budgeted on Android.

### 4.9 Editable terrain is authoritative
Mining/placing/terraforming must alter:
- voxel data;
- collision;
- resource inventory;
- saved edit delta.

Navigation is invalidated by region/chunk, never rebuilt globally after every block edit.

### 4.10 Data-driven content
Biomes, site archetypes, block types, recipes, resources, personalities, damage thresholds, and spawn tables belong in data/resources, not giant match statements.

## 5. Performance budgets: provisional

Until measured on the target Android device:

- physics target: 60 Hz;
- frame target: 30 FPS minimum on Android playtest;
- active full humanoid ragdolls near player: <= 6;
- active high-fidelity vehicles: <= 8;
- terrain edits: coalesce remesh/navigation work by chunk;
- no synchronous whole-world save;
- no whole-world navmesh rebake;
- no unbounded entity spawning.

These are hypotheses until profiled; the ledger must update them with measurements.

## 6. Code review rubric

Reject a change if any answer is "no":

1. Is the invariant explicit?
2. Is there a falsifier?
3. Is ownership clear?
4. Is rollback possible?
5. Is state deterministic where required?
6. Is persistence behavior defined?
7. Is mobile cost bounded?
8. Are failure paths observable?
9. Are tests stronger than string-presence checks where behavior matters?
10. Is the evidence from the exact commit being promoted?

## 7. Forbidden shortcuts

- no editing `main` for migration experiments;
- no deleting the last known-good release;
- no passing tests by removing assertions;
- no "temporary" global singleton that becomes permanent architecture;
- no hidden network dependency for core gameplay;
- no giant world node containing unrelated systems;
- no release generated from a dirty worktree;
- no binary/toolchain upgrade without lockfile update;
- no gameplay claim based only on headless parsing;
- no physical-phone claim without physical-phone evidence.

## 8. Definition of done

A feature is done only when:
- implementation exists;
- automated acceptance exists;
- demolition attempt exists;
- expected persistence exists;
- relevant exported artifact runs;
- ledger receipt exists;
- no unrelated files changed;
- known limitations are named.

If any of those is absent, report PARTIAL or BLOCKED.
