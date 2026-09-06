# Hive-Lattice Ring Renderer Contract Bundle

This bundle implements the three-phase integration plan:

1. **Temp harness first**
2. **Real engine second**
3. **Runtime incorporation last**

The point of this bundle is not fake completeness. The point is to freeze the contract now so the renderer backend can change later without rewriting the adapter layer.

## Frozen contract

### Canonical adapter API

```python
params = arena_state_to_render_params(world, arena_id)
```

### Canonical renderer API

```python
image = render_ring(params, size=256, device="cpu", engine="temp")
```

### Canonical parameter schema

`RenderParams` lives in `render/core/types.py`.

Fields:
- `cx: float`
- `cy: float`
- `width: float`
- `height: float`
- `rotation: float`
- `damage: float`
- `crowd_heat: float`
- `faction_control: str`
- `match_phase: str`
- `hazards: list[str]`
- `style: str`

## File tree

```text
project/
├── game/
│   └── state.py
├── render/
│   ├── adapters/
│   │   └── arena_adapter.py
│   ├── core/
│   │   ├── compositor.py
│   │   └── types.py
│   ├── effects/
│   │   └── basic.py
│   ├── modules/
│   │   ├── ring_temp.py
│   │   └── ring_real.py
│   └── styles/
│       └── presets.py
├── main.py
└── README.md
```

## What each engine means

### Temp engine
- deliberately simple
- proves the contract works
- safe placeholder for Milestone A

### Real engine
- rectangular ring geometry
- rope bands
- corner posts
- deterministic style passes
- proper Phase B backend

Both engines use the same adapter and the same `RenderParams` object.

## Install

```bash
pip install -r requirements.txt
```

## Run

Temp harness:

```bash
python main.py
```

Explicit temp:

```bash
python main.py --engine temp --out outputs/temp.png
```

Real engine:

```bash
python main.py --engine real --out outputs/real.png
```

## Milestone map

### Milestone A — temp harness done
- stable schema
- stable adapter
- stable renderer entrypoint
- deterministic output

### Milestone B — real engine done
- rectangular ring geometry
- style presets
- export works
- same contract as temp engine

### Milestone C — runtime incorporation
- Hive-Lattice runtime calls the adapter
- adapter produces `RenderParams`
- compositor selects backend
- game loop owns truth

### Milestone D — extended incorporation
- lattice module
- hazards module
- scene compositor
- multi-module render pipeline

## Why this layout matters

The temp harness is not throwaway junk. It is a contract harness.

That means the following swap is legal and cheap:

```text
ArenaState -> Adapter -> RenderParams -> TEMP backend
ArenaState -> Adapter -> RenderParams -> REAL backend
```

The adapter does not change. The renderer backend changes.

That is the whole strategy.
