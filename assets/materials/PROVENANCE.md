# Object material sources

Acquired 2026-10-08 from ambientCG's official API and download endpoints.
License: CC0 1.0 Universal, https://docs.ambientcg.com/license/.
Creator: ambientCG / Lennart Demes. Assets may be redistributed with this game.

Only Color, NormalGL and Roughness maps are included from each 1K-JPG package.
Original maps are preserved; Godot imports are capped at 512 pixels, mipmapped
and VRAM-compressed for desktop/Android. NormalGL maps use normal-map import.

| Material | Source | Downloaded archive SHA-256 |
| --- | --- | --- |
| Wood | https://ambientcg.com/a/Wood066 | df2226dfec75777b4e4ad9db0694cfaf9a04588dcb8a4f9b4687d79fd3355c51 |
| Stone | https://ambientcg.com/a/Rock035 | c5e4dbd7d5555734498834c1e09b799ef3d1f00c61fe08c0d953b93a8fb1bb95 |
| Grass | https://ambientcg.com/a/Grass005 | 58a7fb7f32c44a86879483325b62781d04e0ab8f70b0f70ede36c8f1726f8a22 |
| Fabric | https://ambientcg.com/a/Fabric030 | 82d4d00ccf901cf4707c5489005945ab8574933fc60437e26c6737f0436699e0 |
| Brick | https://ambientcg.com/a/Bricks005 | 5d7b5584245ffa94eb74b9173c412e33a7cb012b75632a5125b426f9ff9fa0f6 |
| Metal | https://ambientcg.com/a/Metal049A | 4f6a79e535261ab55cc6feefed0037124885720ce7b781fc2efa3fa22792af42 |

The API identifies Wood066, Fabric030 and Bricks005 as PBRApproximated;
Rock035 and Grass005 are PBRProcedural. These are object-specific PBR
materials, not a claim that every source was photographed. Cat fur remains
an original procedural striped texture; this is not a photorealistic animal asset.
Acquisition receipts and individual map hashes: dist/material-acquisition-final.log.
