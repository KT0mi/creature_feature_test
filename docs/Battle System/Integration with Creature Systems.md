---
tags: [battle-system, plan]
created: 2026-11-14
---
# Integration with Creature Systems

Back to [[Battle System Overview]]

| Existing system | Role in battles |
|---|---|
| Part tree + sockets | Source of stats, build and cards ([[Combat Profile]]). The socket count already caps parts per creature |
| `copy_from` / counterparts | Tell the profile which parts are pairs (stats ×2, cards ×1) |
| Type weights / rarity | How often strong parts (and their cards) appear |
| Fusion, recipes, `fusion_only` | Recipe parts can carry **exclusive cards**: authored fusions become authored abilities |
| `CreatureBaker` | Unit sprites; `Baked.origin` is the ground anchor |
| `CreatureNamer` | Unit names in the HUD |
| Palettes / patterns | Cosmetic only (no combat effect) |
| `PartRegistry` | Also indexes and validates cards |
| Editor tools | Part editor lists a part's stats/cards; a future **card editor** paints patterns on a grid |
| Creature lab | Stats/deck readout, "auto-battle selected" key |
| Determinism | Battles are seeded: seed + actions reproduce a battle exactly (replays, bug reports) |

## Roguelike mode (later)
- The player's team is a list of owned creatures (genome + progression), see [[Combat Profile#Player-owned creatures]].
- Fusing between battles is the main way to "level up"; the combat profile updates by itself.
