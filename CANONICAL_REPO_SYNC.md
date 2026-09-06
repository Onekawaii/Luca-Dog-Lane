# Canonical Repository Sync — v0.6.0 Lattice Alive

Source release artifact: `Hive-Lattice-Next-v0.6.0-lattice-alive.zip`

- source ZIP SHA-256: `859122ad26269542ba6e459f983bf0ebf536fcf4266c98d8494d052085707a83`
- target repository: `Onekawaii/Hive-Lattice`
- pre-sync `main`: `6b853f74d356289116d16e2ff5be6d3ad8b06516`
- repository strategy: preserve existing history and advance `main` through a verified materialization commit

## Battlemap materialization

The accepted release contains a 3.1 MB RGB PNG at `campaigns/strawberry_omen/assets/maps/breakroom_battlemap_v0.png`. To keep the connected-API materialization tractable, the repository bootstrap carries a temporary quality-10 JPEG derivative and reconstructs that asset as PNG in GitHub Actions. Dimensions remain `1334x1179` and the gameplay path is unchanged.

- accepted-release map SHA-256: `5188e57393fafefdda2e5e2317e44cf8854788fcbf02d5a3a6cada4154e6cb4c`
- bootstrap JPEG SHA-256: `57bba080c7353a3485bb8f15af865ed7d7e96afb3ec0378b0bb04bf1692c6f46`
- bootstrap JPEG bytes: `76446`

The accepted release ZIP remains the byte-exact v0.6.0 artifact. The canonical repository records the materialized source tree and its own generated manifest.
