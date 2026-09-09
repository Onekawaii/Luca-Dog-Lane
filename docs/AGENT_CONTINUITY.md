# HIVE-LATTICE — AGENT CONTINUITY
**Status:** Living source of operational context  
**Project:** Onekawaii/Hive-Lattice  
**Last refreshed:** 2026-09-09  
**Owner directive:** Read this file before searching, planning, editing, or asking for context.

---

## 0. THE FLOCK PROTOCOL — READ FIRST

You are entering an existing project with history, constraints, known tools, and active work.

Your first duty is **continuity, not discovery**.

### Command hierarchy

1. **Current user directive**
2. **This living context file**
3. **Verified repository state / tests**
4. **Existing project contracts and architecture**
5. **Your own inference**

If your inference conflicts with a verified fact here, the verified fact wins.

### Ritual on entry

Before doing anything expensive:

1. Read this file completely.
2. Read the current branch, HEAD, and `git status`.
3. Use exact tool paths documented here before searching the machine.
4. Identify the current blocker.
5. Work on that blocker only.
6. Do not broaden scope because something nearby looks interesting.
7. After meaningful work, update this file before stopping.

### The anti-waste law

**Do not spend tokens rediscovering facts already recorded here.**

Examples:
- Do not search the filesystem for Godot when its path is listed below.
- Do not re-investigate which branch is active if the current Git output already says it.
- Do not re-derive frozen-control policy.
- Do not rerun a 400+ test suite while a smaller failing acceptance assertion can be isolated directly.
- Do not invent commands when a verified repo-supported command exists.

### Psychological operating rule

Treat this project like a ritualized handoff between specialized agents:

- **Leader / Keeper of Doctrine:** sets direction and protects project identity.
- **Builder:** implements only the current construction target.
- **Inspector:** hunts first real failures, regressions, and contract violations.
- **Archivist:** updates this document so the next agent does not repeat old work.

Agents are not rewarded for activity. They are rewarded for **reducing uncertainty without destroying continuity**.

---

# 1. PROJECT IDENTITY

Hive-Lattice is a **native Godot first-person systemic horror RPG** evolving toward an open-world game.

Do not regress it into:
- the old Python text adventure,
- the old web/PWA prototype,
- a point-and-click game,
- a static “room showcase.”

Current direction:
- first-person native runtime,
- Windows + Android,
- phone-first touch support,
- reactive world systems,
- physical interactions,
- quantum mechanics,
- eventual open-world / STALKER-scale region architecture.

The Breakroom is becoming **one site inside a larger world**, not the whole game.

---

# 2. CURRENT REPOSITORY TRUTH

## Repository

`Onekawaii/Hive-Lattice`

## Local repo path

`C:\Users\jmgar\Desktop\AI-UNIVERSE\The Projects\Hive-Lattice`

## Accepted remote baseline

`origin/main = 259c99209ecaec54b161df216935486f7c37ae0e`

Commit:
`feat(visuals): modular breakroom geometry, materials, and decoupled decals`

## Current feature branch

`feat/fps-world-interactions`

## Current verified checkout

- HEAD: `fb4beb9` (`docs(agent): add living continuity and capability doctrine`)
- Dirty authored files:
  - `game_godot/data/strawberry_omen/manifest.json` — generated campaign manifest metadata/hash refresh.
  - `game_godot/scenes/bootstrap/FirstPersonBootstrap.tscn` — adds the canonical `InspectController` node.
  - `game_godot/scripts/fps/FirstPersonBreakroom.gd` — canonical inspection delegation/state bridge and strong `CharacterBody3D` Player typing.
  - `game_godot/scripts/interaction/InspectController.gd` — Godot 4 syntax/tween lifecycle corrections.
- Untracked debug artifacts:
  - `test_output.txt` — captured broad Python test output; disposable diagnostic log, not authored runtime code.
  - `tools/list_test_failures.py` — disposable helper that runs the broad Python suite and prints failures; diagnostic tooling, not runtime code.
  - `tools/parse_failures.py` — disposable parser for `test_output.txt`; diagnostic tooling, not runtime code.

## Branch creation baseline

Local branch was created from:

`603111a`

Parent:

`259c992`

Commit message:

`feat(interaction): add focusable component and inspect controller + prompt HUD`

Important:
- `603111a` is a mixed local implementation commit.
- It directly descends from `259c992`.
- It was originally made on local `main`.
- The feature branch now preserves it safely.
- Do not merge to `main` until the interaction pass is fully green and phone-tested.

## Frozen files verified against 259c992

These were confirmed unchanged by `git diff --exit-code`:

- `game_godot/scripts/fps/TouchLookZone.gd`
- `game_godot/scripts/ui/VirtualStick.gd`
- `game_godot/scripts/fps/FirstPersonPlayer.gd`

Do not modify them casually.

---

# 3. EXACT GODOT ENVIRONMENT — DO NOT SEARCH FIRST

Known working Godot installation:

`C:\Users\jmgar\.godot_bin\Godot_v4.3-stable_win64_console.exe`

A local executable/alias has also been discovered at:

`C:\Users\jmgar\.godot_bin\godot.exe`

Prefer the explicit 4.3 console binary for deterministic CI-equivalent checks.

## PowerShell variable

```powershell
$GODOT = "$env:USERPROFILE\.godot_bin\Godot_v4.3-stable_win64_console.exe"
```

## Parse / editor check

```powershell
& $GODOT --headless --editor --path game_godot --quit
```

## Direct native acceptance

```powershell
& $GODOT --headless --path game_godot res://tests/AcceptanceRunner.tscn --quit
```

## Python test suite

```powershell
python -m unittest discover -s tests -p "test*.py" -v
```

## Full native verifier

```powershell
python tools/verify_native_contract.py
```

### Rule

Do **not** search `C:\`, `Program Files`, or PATH for Godot unless both documented paths fail.

---

# 4. CURRENT WORKSTREAM

## Sprint

**FPS World Interactions**

Goal: make the Breakroom physically interactive without destabilizing the accepted mobile-control baseline.

### Intended features

- object focus / inspection zoom,
- physical pickup / hold / placement,
- persistent world-object state,
- coffee maker on/off,
- opening refrigerator,
- flies / ooze environmental treatment,
- Keith ambient cleaning,
- Keith collision-safe movement,
- Wetberry readability,
- later visual polish.

### Hard freeze

Do not change:
- `TouchLookZone.gd`
- `VirtualStick.gd`
- player movement physics
- touch ownership semantics
- save schema v3
- quantum semantics

Additive FPS interaction hooks are acceptable only when necessary.

---

# 5. CANONICAL INTERACTION ARCHITECTURE

## Inspection

Canonical design:

### Metadata / transform helper
`game_godot/scripts/fps/FirstPersonInspectable.gd`

### Authoritative controller
`game_godot/scripts/interaction/InspectController.gd`

The controller must:
- emit `EventBus.first_person_input_lock_changed`,
- save exact original camera transform,
- save exact original camera FOV,
- enter inspection around FOV 42,
- restore transform exactly,
- restore FOV exactly,
- always unlock input on exit,
- support desktop and mobile exit,
- safely cancel active tweens,
- never strand camera state.

Do not keep two competing runtime inspection paths.

## Holdable

Canonical scene component:

`game_godot/scripts/interaction/Holdable.gd`

Required:
- generic reusable prop component,
- disable real prop collision while held,
- keep ownership explicit,
- use HeldObjectAnchor / equivalent representation,
- validate placement with physics overlap/intersection,
- reject placement inside geometry,
- restore collisions after valid placement,
- persist successful placement in `WorldState.room_state`,
- do not make the architecture Wetberry-specific.

Duplicate candidate that should disappear only after references are migrated:

`game_godot/scripts/fps/FirstPersonHoldable.gd`

## Persistence

Use existing:

`WorldState.room_state`

or:

`WorldState.room_memory(...)`

No new top-level save fields.

Expected interaction state keys include:
- `coffee_on`
- `fridge_open`
- holdable transform/state keys

Exact names should remain stable once chosen.

## Keith

FPS Keith should be:

`CharacterBody3D`

Godot 4 locomotion pattern:

```gdscript
keith_node.velocity = desired_velocity
keith_node.move_and_slide()
```

Do not use Godot 3 style:

```gdscript
move_and_slide(velocity, Vector3.UP)
```

Do not move Keith via direct `global_position += ...`.

Keith must:
- patrol authored safe cleaning points,
- respect collision geometry,
- pause and mop,
- stop during dialogue,
- resume afterward.

---

# 6. CURRENT FAILURE HISTORY

This section records the **first real blockers**, so future agents do not rediscover downstream noise.

## Parser blocker — FIXED

Initial acceptance symptom:

`Could not parse global class "FirstPersonBreakroom"`

Root error:

`There is already a variable named "space_state" declared in this scope.`

Location:

`game_godot/scripts/fps/FirstPersonBreakroom.gd`
around the placement code near line ~298.

Repair:
- conflicting local was renamed,
- small GDScript typing/inference issues were corrected,
- parse check subsequently completed cleanly.

## Parse check after repair

Command:

```powershell
& $GODOT --headless --editor --path game_godot --quit
```

Result:
- Godot parsed project scripts cleanly.

## Native acceptance state after inspection repair

Observed acceptance summary:

`257 Total | 253 Passed | 4 Failed`

The inspection, pickup, and world-visibility assertions now pass. The current first unresolved native blocker is:

1. Held object placed back on surface.

The remaining four failures are downstream placement and Keith failures; do not investigate them before the first blocker.

### Recent interaction commits

- `990d467` added the initial FPS interaction pass: inspection/locking, holdable components and collision handling, appliance persistence, Wetberry/Keith interaction systems, HUD/event hooks, and the native acceptance coverage.
- `3d6048d` canonicalized inspection usage, corrected placement typing and parse issues, and changed Keith movement to collision-aware locomotion.

### Current debugging order

Fix in this order:

1. **Pickup / hold**
2. **Placement**
3. **Keith**
4. Persistence verification
5. Full suite
6. Full native verifier

Do not jump ahead.

---

# 7. IMPORTANT FALSE FIXES / TRAPS

## Do not mask wrong Player node type

A temporary change relaxed:

`quantum_player: CharacterBody3D`

to:

`Node3D`

This is not the preferred fix if the scene has the wrong Player node type.

Expected:
- Player scene node is `CharacterBody3D`.
- Strong typing should remain if architecture supports it.

Verify scene type before weakening code.

## Do not satisfy source tests with inert comments

A temporary compatibility comment containing:

`first_person_inspect_started`

was added only to satisfy a source-string assertion.

Do not use inert comments to “pass” tests.

If a structural test is stale because architecture intentionally moved to `InspectController`, update the test honestly **after runtime behavior is correct**.

## Headless renderer noise

Headless acceptance has emitted errors such as:

`Parameter "m" is null`
from dummy renderer mesh storage,

plus ObjectDB/resource-at-exit warnings.

Do not automatically treat these as the root blocker.

First inspect acceptance assertions and script/runtime errors.

---

# 8. CURRENT FOCUS — NEXT AGENT START HERE

**Do not run the full Python suite first.**

Current focus is the first unresolved native acceptance failure:

### Wetberry held representation

Expected next path:

```text
Wetberry pickup request
→ canonical Holdable
→ held ownership / collision state
→ HeldSlot representation
```

Do not revisit the already-passing inspection or pickup assertions. Investigate only the held-world representation assertion:

- `game_godot/scripts/fps/FirstPersonBreakroom.gd`
- `game_godot/scripts/interaction/Holdable.gd`
- exact held-state block in `game_godot/tests/run_acceptance.gd`

### Required cadence

```text
one native failure
→ root cause
→ smallest fix
→ direct acceptance rerun
→ next first failure
```

Do not touch pickup, placement, or Keith until Wetberry inspection passes.

---

# 9. VISUAL BASELINE

Accepted visual checkpoint:

`259c992`

Current accepted visual direction:
- tiled institutional floor,
- muted walls/baseboards,
- modeled table,
- modeled Wetberry carton,
- low-poly Keith,
- modeled fridge,
- modeled coffee machine,
- phone-readable HUD,
- no giant wrapped textures.

Known visual issues from physical phone test:
- Keith black parts clip.
- Keith needs a readable face.
- Wetberry label is difficult to read.
- Interaction systems are more important than further decoration right now.

Do not use image generation for Hive-Lattice visual fixes unless explicitly requested.
Prefer Godot geometry, materials, decals, simple procedural visuals, and mobile-friendly assets.

---

# 10. PHONE / ANDROID CONTEXT

The Native Build workflow produces artifacts including:

- `Hive-Lattice-Native-Android`
- `Hive-Lattice-Native-Windows`
- `Hive-Lattice-Native-Source`
- Android boot diagnostics

Phone test workflow:
GitHub → repo → Actions → successful Native Build → Artifacts → Android artifact → extract APK.

Do not consider an interaction branch complete until:
- native verification is green,
- Android build succeeds,
- emulator boot passes,
- physical phone controls and interactions are tested.

---

# 11. OPEN-WORLD FUTURE — DO NOT BUILD YET

After the FPS interaction pass is green and phone-tested, the next major milestone is:

**Hive-Lattice Expansive Update — Region 01 / Open World Foundation**

Target world vocabulary:

```text
WORLD
REGION
AREA
SITE
ROOM / CELL
INSTANCE
HIVE STATE
WORLD EVENT
```

The future Breakroom becomes one site inside an Industrial Complex region.

Do not start this expansion until the current interaction kernel is trustworthy.

---

# 12. KNOWN LEGACY LINEAGES — DO NOT CASUALLY MERGE

Several old Hive-Lattice files/bundles exist from separate architectural lineages.

They include:
- old Python Bard text adventure,
- old web/PWA work,
- ring renderer contract harness,
- old 2D/native experiments,
- historical Strawberry encounter specs.

Treat them as:
- lore/content substrate,
- reference material,
- historical contracts,

not as current Godot runtime files unless explicitly integrated.

---


# CAPABILITY ROUTING — ADAPT OR HAND OFF

An agent must never stall merely because one preferred tool, skill, connector, executable, permission, or environment is unavailable.

Use this routing law:

```text
NEEDED CAPABILITY
        │
        ↓
Can current agent perform it safely?
        │
   ┌────┴────┐
  YES       NO
   │         │
   ↓         ↓
EXECUTE   Is there a safe local substitute?
             │
        ┌────┴────┐
       YES       NO
        │         │
        ↓         ↓
     ADAPT      HAND OFF
```

## Adaptation order

When a preferred capability is unavailable:

1. Use an equivalent already-available tool or repo-native command.
2. Use a narrower manual/structural method that preserves correctness.
3. Reduce the task to a verifiable intermediate artifact.
4. If the missing capability is essential, prepare a handoff for another agent/pool instead of pretending completion.

Examples:
- Cannot use a browser: inspect repo-local docs/logs or hand off web-only verification.
- Cannot run Android emulator: complete deterministic build/contract work, record exact artifact and hand off emulator boot verification.
- Cannot access GitHub mutation tools: prepare branch/commit/PR instructions and hand off the push/merge action.
- Cannot use image generation: use existing assets, geometry, materials, or hand off asset creation.
- Cannot use a proprietary IDE skill: use repo-native CLI/test/build commands.
- Cannot use a connector because permission is denied: do not repeatedly retry; preserve state and hand off.

## Handoff packet — mandatory when blocked

If handing work to another agent/pool, produce a compact packet containing:

```text
HANDOFF TARGET:
<capability or agent type needed>

WHY HANDOFF IS REQUIRED:
<exact unavailable tool/permission/skill>

CURRENT BRANCH / HEAD:
<branch>
<sha>

WORKING TREE:
<clean/dirty + important files>

COMPLETED:
<what is already verified>

CURRENT BLOCKER:
<first unresolved blocker>

DO NOT REDO:
<facts/tools/searches already established>

EXACT NEXT ACTION:
<single next command or operation>

SUCCESS CONDITION:
<what proves completion>
```

The receiving agent must continue from the packet rather than restarting discovery.

## No fake capability

Never:
- claim a tool was used when it was not,
- claim a build/test passed without receipts,
- silently skip an essential verification,
- replace a required external action with speculation,
- repeatedly search for a capability already proven unavailable.

Adaptation is preferred when correctness is preserved.
Handoff is preferred when adaptation would weaken correctness.



# POWERSHELL EXECUTION POLICY

This project is Windows-first when operating on the owner's local machine.

When giving shell commands for local execution, default to **PowerShell**, not Bash, CMD, WSL, or heredoc syntax.

## Rules

- Start from the repository path explicitly when context may be lost.
- Prefer one pasteable PowerShell block.
- Use `$env:USERPROFILE` and quoted paths for spaces.
- Use the documented executable paths before searching.
- Do not use Bash-only constructs such as `&&`, `grep`, `sed`, `awk`, `cat <<EOF`, or Unix path syntax unless the active environment is explicitly Bash/WSL.
- Use `;` or separate PowerShell statements when sequencing.
- Stop on meaningful failures when appropriate.
- Do not normalize line endings merely because Visual Studio offers to.
- Never use `git reset --hard` or `git clean -fd` as a convenience cleanup step.

## Canonical PowerShell bootstrap

```powershell
Set-Location "C:\Users\jmgar\Desktop\AI-UNIVERSE\The Projects\Hive-Lattice"

$GODOT = "$env:USERPROFILE\.godot_bin\Godot_v4.3-stable_win64_console.exe"

git branch --show-current
git rev-parse --short HEAD
git status --short
```

## Canonical focused verification

```powershell
Set-Location "C:\Users\jmgar\Desktop\AI-UNIVERSE\The Projects\Hive-Lattice"

$GODOT = "$env:USERPROFILE\.godot_bin\Godot_v4.3-stable_win64_console.exe"

& $GODOT --headless --editor --path game_godot --quit
if ($LASTEXITCODE -ne 0) { throw "Godot parse/editor check failed with exit code $LASTEXITCODE" }

& $GODOT --headless --path game_godot res://tests/AcceptanceRunner.tscn --quit
if ($LASTEXITCODE -ne 0) { throw "Godot acceptance failed with exit code $LASTEXITCODE" }
```

Do not run the full Python/native verifier until the current narrow blocker is repaired unless the continuity file explicitly says otherwise.

# 13. AGENT ROLES

## Builder / Antigravity

Best for:
- substantial implementation,
- scene construction,
- geometry,
- assets,
- behavior polish.

Risk:
- tends to overbuild,
- may rewrite large scenes,
- may duplicate systems.

## Inspector / Copilot

Best for:
- repo archaeology,
- parser errors,
- first real blocker isolation,
- contract verification,
- small architecture repairs,
- test triage.

Risk:
- may waste tokens rediscovering environment/tool paths,
- may “fix” tests by satisfying implementation-detail strings,
- may run broad suites before isolating the first runtime failure.

## Keeper / ChatGPT

Best for:
- maintaining project doctrine,
- coordinating agents,
- deciding architecture,
- preventing branch/scope drift,
- updating this living handoff.

---

# 14. UPDATE PROTOCOL — MANDATORY

Every agent that materially changes the project should update this file before stopping.

Update only these hot sections unless architecture changed:

- `Current Repository Truth`
- `Current Workstream`
- `Current Failure History`
- `Current Focus`
- `Latest Verification Receipt`
- `Next Exact Action`

### Keep it compact

This file is for **hot continuity**, not a diary.

When sections become historical and no longer affect execution:
- compress them to one or two lines,
- move verbose history into `docs/context_archive/` if needed.

Target:
- immediately useful to an agent within 2–3 minutes,
- no filesystem archaeology required,
- no repeated discovery.

---

# 15. LATEST VERIFICATION RECEIPT

Last known verified facts at this snapshot:

- Branch: `feat/fps-world-interactions`
- HEAD: `fb4beb9`
- `origin/main`: `259c992`
- frozen controls: unchanged vs `259c992`
- Godot parser blocker: fixed
- Godot headless editor parse check: clean
- native acceptance last observed after world-visibility repair: `257 total / 253 passed / 4 failed`
- latest fixed assertion: `Wetberry world prop hidden while held`
- first unresolved native assertion: `Held object placed back on surface`
- files changed in the latest pass: `game_godot/scripts/interaction/Holdable.gd`
- dirty authored files: manifest, bootstrap scene, breakroom script, inspect controller
- untracked debug files: captured test output plus two diagnostic helper scripts
- no Python suite or full native verifier run for this reconciliation
- full verifier should wait until native acceptance is repaired

These counts are a snapshot, not eternal truth. Refresh them after the next direct acceptance run.

---

# 16. NEXT EXACT ACTION

After restart, continue exactly at the placement blocker:

1. Trace `Held object placed back on surface` through `FirstPersonBreakroom.place_held_object()` and canonical `Holdable.place()`.
2. Do not investigate Keith or any later assertion.
3. Run only the direct acceptance command after the smallest placement repair.

The last verified direct command was:

```powershell
Set-Location "C:\Users\jmgar\Desktop\AI-UNIVERSE\The Projects\Hive-Lattice"
$GODOT = "$env:USERPROFILE\.godot_bin\Godot_v4.3-stable_win64_console.exe"
& $GODOT --headless --path game_godot res://tests/AcceptanceRunner.tscn --quit
```

Then confirm `Wetberry picked up successfully` remains the first failure, investigate only the canonical pickup path, apply the smallest runtime fix, rerun the same command, and update this file.

**Do not search for Godot. Use the documented path.**


# DESKTOP COMMANDER TRUST GATE

Remote desktop / terminal control is a privileged capability.

The preferred integration is **Remote Desktop Commander**. It may expose an authorized machine's filesystem, terminal, processes, local documents, and development workflows. Treat it as a high-trust capability.

## Trust tiers

### Tier 0 — Observer
May:
- read continuity docs,
- inspect pasted logs,
- reason,
- prepare handoffs.

May NOT:
- run local commands,
- edit files,
- use Desktop Commander.

### Tier 1 — Repo Worker
May:
- use repository-scoped tools,
- read/write files inside the active repo,
- run narrow repo-native tests/build commands when available.

May NOT:
- roam the desktop,
- inspect unrelated folders,
- manage arbitrary processes,
- use Desktop Commander.

### Tier 2 — Verified Executor
Requirements:
- read `AGENTS.md` and `docs/AGENT_CONTINUITY.md`,
- confirmed branch / HEAD / working tree,
- demonstrated correct use of narrow tests,
- respected frozen files and stop conditions,
- no deceptive test-passing hacks,
- no unnecessary environment rediscovery.

May:
- perform broader repo-local execution,
- build/package,
- prepare artifacts,
- perform approved Git operations.

May NOT automatically receive Desktop Commander.

### Tier 3 — Desktop Custodian
This is the **only tier allowed to use Remote Desktop Commander**.

Promotion is explicit and task-scoped. It is never inherited from a previous agent or handoff.

Before promotion, the agent must:
1. Read the living continuity file completely.
2. State the exact desktop task.
3. State the exact directories/processes it expects to touch.
4. Confirm branch / HEAD / working tree when repo work is involved.
5. Prove that repo-scoped tools are insufficient or that Desktop Commander materially reduces waste.
6. Name the stop condition.
7. Accept the destructive-action rules below.

## Desktop scope rule

Desktop Commander authority is bounded to the minimum necessary scope.

Default allowed scope for Hive-Lattice:

`C:\Users\jmgar\Desktop\AI-UNIVERSE\The Projects\Hive-Lattice`

Known auxiliary executable scope:

`C:\Users\jmgar\.godot_bin\`

Everything else is out of scope unless explicitly justified.

Do not browse:
- unrelated personal folders,
- browser profiles,
- credential stores,
- messaging apps,
- password managers,
- unrelated repositories,
- private documents.

## Destructive-action rule

Even Tier 3 must stop and request explicit authorization before:
- deleting files outside generated/debug outputs,
- `git reset --hard`,
- `git clean -fd`,
- mass renames/moves,
- uninstalling software,
- killing unrelated processes,
- changing system settings,
- modifying startup/services,
- changing security settings,
- installing drivers,
- touching credentials/secrets,
- irreversible Git history rewrites.

## Read / write distinction

Preferred permission posture:

- Reads: permitted only inside the scoped project/tool directories.
- Writes: limited to the active task.
- Broad desktop writes: prohibited by default.
- Destructive writes: explicit approval required.

## Trust decay

Trust is session-specific.

A Tier 3 agent loses Desktop Commander authority when:
- the task changes materially,
- it hands work to another agent,
- it violates scope,
- it makes unexplained destructive changes,
- repo state diverges unexpectedly,
- the user revokes access.

The next agent starts at the lower trust tier unless explicitly promoted again.

## Capability handoff

If a lower-tier agent reaches a task requiring Desktop Commander:

Do not improvise desktop access.

Produce:

```text
DESKTOP HANDOFF REQUEST

WHY DESKTOP ACCESS IS NEEDED:
<reason>

TARGET PATHS:
<exact paths>

EXPECTED COMMANDS/ACTIONS:
<commands or actions>

CURRENT BRANCH / HEAD:
<branch / sha>

WORKING TREE:
<status>

VERIFIED COMPLETED WORK:
<receipt>

STOP CONDITION:
<condition>

RISK:
<low / medium / high + explanation>
```

A Tier 3 agent may then accept and execute only that packet.

## Audit receipt

Every Desktop Commander session must end with:

```text
DESKTOP COMMANDER RECEIPT

AGENT:
<agent/session>

TASK:
<task>

PATHS TOUCHED:
<paths>

COMMANDS/ACTIONS:
<summary>

FILES CHANGED:
<files>

PROCESSES STARTED/STOPPED:
<processes>

GIT STATE BEFORE:
<branch / head / status>

GIT STATE AFTER:
<branch / head / status>

VERIFICATION:
<tests/build>

UNRESOLVED:
<remaining blocker>

NEXT ACTION:
<exact next step>
```

No receipt = incomplete desktop task.



## 2026-09-09 — Remote repair/build checkpoint (ChatGPT via Desktop Commander)

Branch: `feat/fps-world-interactions`
Base HEAD at start of repair: `fb4beb9`

### Verified repair outcome
- Native acceptance: **262 total | 262 passed | 0 failed**
- Native acceptance reports **0 SCRIPT ERROR** after HUD teardown guard repair.
- Python suite: **439 tests OK, 1 skipped**
- `python tools/verify_native_contract.py`: **ALL GATES PASSED**
- Frozen controls unchanged:
  - `game_godot/scripts/fps/TouchLookZone.gd`
  - `game_godot/scripts/ui/VirtualStick.gd`
  - `game_godot/scripts/fps/FirstPersonPlayer.gd`

### Repairs completed
- Canonical inspection remains delegated to `scripts/interaction/InspectController.gd`; stale test-token expectation was corrected to test the canonical controller instead of restoring a shim.
- Canonical holdable remains `scripts/interaction/Holdable.gd`.
- Placement now probes a real support surface, validates overlap against the holdable's real collision shape, allows the supporting surface/player appropriately, restores the world root/collision, clears held ownership, and persists the placed Wetberry transform in existing room memory.
- Placement restore from room memory is covered by native acceptance.
- Keith is now a `CharacterBody3D` using a character-compatible interactable script and the existing Godot 4 `KeithAmbientWorker` locomotion.
- `FirstPersonHUD._refresh_quantum_diagnostic()` now guards against teardown-time missing SceneTree/root, eliminating prior headless SCRIPT ERROR noise.

### Final build artifacts
- `dist/Hive-Lattice-native-windows-playtest.zip`
  - SHA256: `885ec6e233ae90b70b8286df282a1527a0df4ba227b451f8146cf4c190cfa0ab`
- `dist/Hive-Lattice-native-android-playtest.apk`
  - SHA256: `5b8162d0874e53066ce22ee23c16679bcdb44be6d2bc0ce86f80c779c3d11f36`
- `dist/Hive-Lattice-native-playtest-source.zip`
  - SHA256: `4a6ad396953a74db547a090e1554eff7c4b07e8c85ccc0436aa03c4a4b77087c`

Windows exported executable smoke:
- exit 0
- 0 SCRIPT ERROR

Android build:
- official Godot 4.3 Android debug export succeeded
- signature verified
- arm64-v8a + x86_64 present
- APK structural inspection passed
- no Android device/emulator was connected, so the device boot gate was skipped.

### Known non-blocking environment warnings
- Godot Windows export reports missing `rcedit` for executable resource metadata/icon modification; export still exits 0 and executable is produced.
- Headless/dummy renderer may report `Parameter "m" is null` / mesh storage cleanup warnings. These are not acceptance failures.
- Godot import may report a Windows safe-save warning; verification gate still passes.

### Repository cleanup
Disposable untracked diagnostics were removed after the repair:
- `test_output.txt`
- `tools/list_test_failures.py`
- `tools/parse_failures.py`

### Trust gate
**James has NOT manually playtested this build yet.**
Do not describe this branch/build as user-accepted until James runs the packaged Windows and/or Android build and explicitly accepts the interaction behavior.

### Manual playtest target
1. Movement and look still match the accepted controls.
2. Inspect Wetberry; exit inspection; camera restores correctly.
3. Pick Wetberry up; world prop disappears; HeldSlot representation is visible.
4. Walk while holding.
5. Invalid placement is rejected.
6. Valid placement succeeds.
7. Save/load or leave/re-enter confirms placement persistence.
8. Coffee maker toggles with visible LED/light/steam feedback.
9. Fridge opens/closes with visible state feedback.
10. Keith moves without clipping through room geometry.
11. Talking to Keith pauses cleaning; closing dialogue resumes it.
12. Abuse the interaction loop and report anything weird.
