from __future__ import annotations

import argparse
import os

from game.state import build_demo_world
from render.adapters.arena_adapter import arena_state_to_render_params
from render.core.compositor import render_ring, save_image_tensor


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Hive-Lattice ring renderer contract harness")
    parser.add_argument("--engine", choices=["temp", "real"], default="temp")
    parser.add_argument("--arena-id", default="arena_alpha")
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--out", default="outputs/render.png")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    world = build_demo_world()
    params = arena_state_to_render_params(world, args.arena_id)
    image = render_ring(params=params, size=args.size, device=args.device, engine=args.engine)
    save_image_tensor(image, args.out)
    print(f"engine={args.engine}")
    print(f"arena_id={args.arena_id}")
    print(f"style={params.style}")
    print(f"out={os.path.abspath(args.out)}")


if __name__ == "__main__":
    main()
