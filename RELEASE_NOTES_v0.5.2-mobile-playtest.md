# Release Notes — v0.5.2-mobile-playtest

This build is the integrated response to the first real Android/Termux/Chrome playtest of the Act V release.

## Player-facing changes

- normal mobile Chrome is supported without Desktop Site mode
- full-width portrait choices
- larger tabs and Save/Load/Help controls
- safe-area-aware fixed footer that no longer covers content
- vertical mobile scrolling and explicit landscape reflow
- browser zoom/accessibility restored
- ghost NPC/arena/fallback stage layers fixed
- consistent Act I-V indicator across header and protocols
- clearer save/load feedback with location + Act
- arena-render failure falls back to packaged room art
- PWA shell cache bumped and made network-first for rapid local release updates

## Engineering changes

- new pure `hive_lattice.web_app.presentation` progression layer
- `.gitignore` no longer swallows arbitrary image files
- save->mutate->load round-trip regression
- mobile/PWA/static release gate
- release docs synchronized to v0.5.2

## Verification boundary

The source defines 346 unittest cases. The build sandbox cannot install Flask, so 281 non-Flask tests plus all validators and Acts IV/V smoke paths were executed here. The remaining 65 Flask web cases are shipped and become executable after installing `requirements.txt`. The final release gate is the actual Android playtest of this packaged ZIP.
