# <PROJECT NAME> — AGENT CONTINUITY
**Status:** Living source of operational context  
**Repository:** <owner/repo>  
**Last refreshed:** <YYYY-MM-DD HH:MM TZ>

---

## 0. READ THIS FIRST

This file exists to prevent agent amnesia and wasted inference.

### Command hierarchy

1. Current user directive
2. This file
3. Verified repository state/tests
4. Existing contracts
5. Agent inference

### Entry ritual

Before searching or editing:

1. Read this file.
2. Run branch / HEAD / status checks.
3. Use documented tool paths.
4. Identify the first real blocker.
5. Work only on that blocker.
6. Update this file before stopping.

### Anti-waste law

Do not rediscover facts already recorded here.

---

## 1. PROJECT IDENTITY

What this project is:

<one paragraph>

What it is not:

- <old lineage>
- <deprecated architecture>
- <common agent misconception>

Primary product target:

<target>

---

## 2. CURRENT REPOSITORY TRUTH

Repository:

`<owner/repo>`

Local path:

`<path>`

Remote baseline:

`<sha>`

Current branch:

`<branch>`

Current HEAD:

`<sha>`

Working tree:

`clean / dirty`

Important dirty files:

- `<file>`

Frozen files/contracts:

- `<file or rule>`

---

## 3. TOOLCHAIN — DO NOT SEARCH FIRST

### Known executables

`<tool>: <absolute path>`

### Known commands

Parse / compile:

```text
<command>
```

Unit tests:

```text
<command>
```

Acceptance:

```text
<command>
```

Build/package:

```text
<command>
```

### Rule

Do not search the filesystem for a tool unless documented paths fail.

---

## 4. CURRENT WORKSTREAM

Sprint:

`<name>`

Goal:

<one paragraph>

In scope:
- <item>

Out of scope:
- <item>

Hard freezes:
- <file/system>

---

## 5. CANONICAL ARCHITECTURE

Document only the architecture that an agent must know to continue correctly.

Example:

```text
Input
→ Controller
→ Runtime State
→ Persistence
→ Presentation
```

Canonical files:
- `<file> = purpose`

Duplicate/deprecated candidates:
- `<file>`

---

## 6. CURRENT FAILURE HISTORY

Record only first real blockers and their resolution.

### Blocker 1

Symptom:
`<error>`

Root cause:
`<cause>`

Fix:
`<fix>`

Status:
`FIXED / ACTIVE`

Do not re-investigate resolved blockers unless regression evidence exists.

---

## 7. CURRENT FOCUS

The next agent starts here.

Current first failure / target:

`<exact target>`

Files to inspect:
- `<file>`

Expected call path:

```text
A
→ B
→ C
```

Required cadence:

```text
one failure
→ root cause
→ smallest fix
→ narrow verification
→ next failure
```

---

## 8. KNOWN TRAPS

- Do not weaken strong typing to hide a scene mismatch.
- Do not satisfy tests with inert comments/tokens.
- Do not rewrite broad files when a one-line fix exists.
- Do not modify frozen files.
- Do not run an expensive suite while a smaller failing test can be isolated.
- Do not trust warnings as root cause until failing assertions are identified.

Project-specific traps:
- `<trap>`

---


## CAPABILITY ROUTING — ADAPT OR HAND OFF

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

## 9. AGENT ROLES

### Builder

Use for:
- implementation,
- assets,
- scene construction.

Rules:
- narrow scope,
- no architecture invention unless requested,
- exact validation gate.

### Inspector

Use for:
- first blocker isolation,
- regression analysis,
- repository archaeology.

Rules:
- use documented paths,
- no broad searches,
- one failure at a time.

### Archivist

Before stopping:
- update this file,
- record branch/HEAD/status,
- record test receipt,
- write the next exact action.

---

## 10. LATEST VERIFICATION RECEIPT

Branch:
`<branch>`

HEAD:
`<sha>`

Tests:
`<count/result>`

Acceptance:
`<count/result>`

Build:
`<result>`

Known warnings:
`<warnings>`

Current blocker:
`<blocker>`

---

## 11. NEXT EXACT ACTION

1. <action>
2. <action>
3. <verification>

Stop after:
`<specific condition>`

---

## 12. UPDATE PROTOCOL

Update this file after:
- branch changes,
- commits,
- first blocker changes,
- test state changes,
- architecture decisions,
- build/package changes,
- handoff.

Keep this file **hot and compact**.

Move old verbose history to:

`docs/context_archive/`

Do not turn the living file into an append-only novel.


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

