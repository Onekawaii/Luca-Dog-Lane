# Hive-Lattice — Project Status

## Current baseline

**v0.6.0-lattice-alive** — reactive-gameplay build on top of the accepted
**v0.5.2-mobile-playtest** UX baseline.

Strawberry Omen remains complete through **Act V — Department of Adjudication**.
No Act VI content was added.

## Mobile baseline is frozen

Real Android/Termux play accepted the v0.5.2 phone shell: normal Chrome portrait with Desktop Site OFF,
full-width choices, large bottom controls, working scrolling/rotation, corrected
stage visibility and Act display. v0.6.0 preserves those behaviors and focuses
on game systems.

## Reactive systems now active

- conditional + hidden choices;
- contextual item actions;
- persistent room memory;
- persistent NPC relationship memory;
- turn-based/persistent conditions;
- deterministic weighted events;
- stat-gated alternate routes;
- cross-Act consequences;
- rule-driven Department verdicts;
- save version 2 with v1 backward compatibility.

The reactive layer is additive and versioned as `strawberry_interactions_v1`.
Frozen Bard v1 schemas are unchanged.

## Validation status

Executed in the build sandbox:

- content lint — PASS
- campaign module validator — PASS
- visual asset validator — PASS
- CLI campaign validation — PASS
- Act IV smoke — PASS
- Act V smoke — PASS
- v0.6 reactive-system gate — PASS
- inherited non-Flask suite — **305/305 executed successfully** (1 intentional renderer-path skip is reported by unittest)

Full suite definition: **370 unittest cases**. The remaining 65 cases require
Flask, which is not installed in this sandbox and cannot be downloaded here.

## Known boundaries

1. Generated room/token/item art is still procedural placeholder-tier.
2. The optional PyTorch hearing renderer remains optional on Android.
3. Historical `ARCHITECTURE_FREEZE.md`, `SPRINT_SUMMARY.md`, and the v0.5.2
   mobile receipt describe earlier baselines and are intentionally preserved.
4. This build originates from a release archive rather than a `.git` checkout;
   no fake descendant Git commit is invented. Apply the accepted tree to the
   canonical repository before minting the permanent Git tag.

## Next gate

Play the packaged v0.6.0 artifact on the same Android/Termux device. Specifically
exercise the Evidence Bag, Gear item actions, a stat-gated route, relationship
readouts, save/load after reactive state changes, and the Act V verdict.
