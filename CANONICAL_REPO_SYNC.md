# Canonical Repository Sync — v0.6.0 Lattice Alive

Source release artifact: `Hive-Lattice-Next-v0.6.0-lattice-alive.zip`

- source ZIP SHA-256: `859122ad26269542ba6e459f983bf0ebf536fcf4266c98d8494d052085707a83`
- target repository: `Onekawaii/Hive-Lattice`
- pre-sync `main`: `6b853f74d356289116d16e2ff5be6d3ad8b06516`
- bootstrap commit: `2d6753b9fb59844c95e2208673e7f81b4dd49b34`
- verified release/materialization commit: `11d63e042b45e61563d3fa19dc6972eb4f99626c`
- release tag: `v0.6.0-lattice-alive`
- legacy tag: `legacy-bard-2026-04`
- verification workflow run: `34008396480`
- repository strategy: existing history preserved; `main` advanced through a verified descendant materialization commit and then housekeeping-only cleanup

## Verification receipt

GitHub Actions materialized the accepted v0.6 source and then passed the complete gate before creating the release tag:

- materialized source files: 185
- deterministic generated visual assets: 53
- canonical manifest entries: 239
- content lint: PASSED
- campaign module validation: PASSED
- visual asset validation: PASSED
- CLI campaign validation: PASSED
- automated tests: 370 run, OK, 2 expected skips
- release commit pushed to `main`: PASSED
- tags created: PASSED

The one-shot materialization workflow was removed from `main` immediately after successful canonicalization. No gameplay/source code changed in that cleanup commit.

## Battlemap materialization

The accepted release contains a 3.1 MB RGB PNG at `campaigns/strawberry_omen/assets/maps/breakroom_battlemap_v0.png`. To keep the connected-API materialization tractable, the repository bootstrap carried a temporary quality-10 JPEG derivative and reconstructed that asset as PNG in GitHub Actions. Dimensions remain `1334x1179` and the gameplay path is unchanged.

- accepted-release map SHA-256: `5188e57393fafefdda2e5e2317e44cf8854788fcbf02d5a3a6cada4154e6cb4c`
- bootstrap JPEG SHA-256: `57bba080c7353a3485bb8f15af865ed7d7e96afb3ec0378b0bb04bf1692c6f46`
- bootstrap JPEG bytes: `76446`

The accepted release ZIP remains the byte-exact historical v0.6.0 artifact. The `v0.6.0-lattice-alive` Git tag identifies the verified canonical repository materialization.
