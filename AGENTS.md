# AGENTS.md — HIVE-LATTICE BOOTSTRAP

## First commandment

Before searching, planning, editing, or asking the user for project context:

**READ `docs/AGENT_CONTINUITY.md` COMPLETELY.**

That file contains:
- current branch / HEAD / remote baseline,
- exact local tool paths,
- frozen files and architecture,
- current blocker,
- known false fixes,
- verified test state,
- next exact action.

## Entry sequence

1. Read `docs/AGENT_CONTINUITY.md`.
2. Run:
   - `git branch --show-current`
   - `git rev-parse --short HEAD`
   - `git status --short`
3. Compare reality with the continuity file.
4. If repository state changed, update the continuity file.
5. Work only on the documented current target unless the user explicitly changes direction.

## Anti-waste rules

- Do not search for tools whose paths are documented.
- Do not re-derive resolved failures.
- Do not rerun broad suites while a narrow failing test exists.
- Do not modify frozen files casually.
- Do not satisfy tests with inert comments or string tokens.
- Do not weaken architecture merely to silence a type/runtime error.
- Do not broaden the task because adjacent work looks interesting.


## Capability routing

If a required tool/skill is unavailable:

1. Adapt with an equivalent safe capability if correctness is preserved.
2. Otherwise stop that subtask and prepare a handoff packet for another agent/pool.
3. Never pretend the unavailable verification/action happened.
4. Record the unavailable capability and exact next action in `docs/AGENT_CONTINUITY.md`.

Required handoff fields:
- target capability/agent
- why handoff is required
- branch / HEAD
- working-tree state
- completed verified work
- first unresolved blocker
- facts not to rediscover
- exact next action
- success condition

## Shell policy

For the owner's local Windows machine, default to **PowerShell**.

Do not emit Bash/heredoc/`awk`/`grep`/`sed` commands unless the active shell is explicitly Bash/WSL.

Use documented executable paths and pasteable PowerShell blocks.


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


## Exit sequence

Before stopping or handing off:

1. Record current branch / HEAD / status.
2. Record exact test/build receipt.
3. Record first remaining blocker.
4. Record the next exact command/action.
5. Update `docs/AGENT_CONTINUITY.md`.

Continuity is part of the deliverable.
