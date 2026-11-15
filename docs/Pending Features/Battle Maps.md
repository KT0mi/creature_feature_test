---
tags: [battle-system, pending]
created: 2026-11-15
status: designed, not implemented
---
# Battle Maps

Pending feature, needs [[Terrain]].

## Idea
A battle is fought on a **map**: the 5×5 board with a terrain in each cell, chosen per battle (e.g. by the roguelike's current area).

## Proposed model
```
BattleMap (Resource, res://creatures/maps/)
	@export var id: StringName
	@export var biome: StringName            # e.g. "swamp", "volcano"
	@export var terrain: Array[StringName]   # 25 terrain ids, row by row
	@export var spawn_team_0: Array[Vector2i]
	@export var spawn_team_1: Array[Vector2i]
	@export var weight: float = 1.0          # for random picking per biome
```
- `BattleRules.new_battle(..., map)` places units on the map's spawn cells instead of the fixed columns.
- Deterministic like everything else: the map is chosen from the battle seed.

## Tools
- A **map paint tool** in the Creature Tools plugin: click cells to paint terrain, preview spawns. The part editor's canvas (zoom, grid, click/drag) can be reused.

## Balance
- The balance script ([[AI and Balance Testing]]) should run on several maps and report per-map results (first-team win rate per map, draws…).
