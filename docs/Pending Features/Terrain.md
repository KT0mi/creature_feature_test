---
tags: [battle-system, pending]
created: 2026-11-15
status: designed, not implemented
---
# Terrain

Pending feature. Builds on statuses on cells ([[Statuses and Attributes#Statuses on cells (traps)]]), which exist already.

## Idea
Terrain = **a status for its behavior, a tile for its properties.**

### Behavior → reactions (fits statuses as they are)
| Terrain | Reacts to | Does |
|---|---|---|
| Lava | `STEPPED` into it, `TURN_ENDED` while standing on it | `lose_hp` (not an attack) |
| Healing spring | `TURN_STARTED` while standing on it | `heal` |
| Poison swamp | `STEPPED` into it | apply Poisoned 1 |
| Brambles | `STEPPED` into it | `ctx.stop_move()` |

### Properties → plain fields the rules read directly
Things the rules must know **in advance** (pathfinding, legal targets, pushes, AI previews), so they must not be implemented as reactions:
- **passable**: walls, rocks, pits;
- **blocks lines**: a pillar stops line attacks and pushes;
- **ends movement**: mud (entering it ends a walk), known to the path search;
- **occupant modifiers**: cover / high ground, e.g. def +1 for whoever stands there;
- **tile**: what the board view draws.

## Proposed model
```
TerrainDef extends StatusEffect      # inherits reacts_to/react, reveal, power…
	@export var passable := true
	@export var blocks_lines := false
	@export var ends_movement := false
	@export var occupant_modifiers: PartStats
	@export var tile: Texture2D

Cell (in BattleState)
	terrain: TerrainDef                # exactly one, default "plain"
	statuses: Array[StatusInstance]    # any number: traps, fire… (exists already)
```
- **Two layers per cell**: terrain is the base layer, one per cell, never removed, only **replaced** (fire turns grass into ash). Cell statuses (traps…) sit on top.
- Terrain is a **slot**, not a `permanent` flag: attributes can never be removed, terrain can change.

## What changes in the code
- `BattleState`: a terrain per cell (default plain).
- `Grid.find_path` / `BattleCard.targets` / `push`: read `passable`, `blocks_lines`, `ends_movement`.
- `BattleUnit.effective_stat`: add the occupied cell's `occupant_modifiers`.
- Event dispatch: also offer events to each cell's terrain (after unit statuses, with cell statuses).
- `tick_on`: maybe ROUND_START / ROUND_END for things that belong to no unit.
- Terrain library: `res://creatures/terrain/`, registry checks like cards and statuses.

## Things to fix with it
- **AI**: the greedy AI scores the board right after its action, so it can't see end-of-turn damage (lava, poison). It should also simulate `end_turn()` when scoring.

See also [[Battle Maps]].
