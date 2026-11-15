---
tags: [battle-system]
created: 2026-11-15
status: implemented (branch claude/rules-engine-depth-refactor)
---
# Movement

Back to [[Battle System Overview]]

Movement is no longer a teleport: units **walk cell by cell**, and every cell entered is an event that can be reacted to **immediately** ([[Rules Engine#Events and triggers (needed for reactions)]]). That's what lets a trap in the middle of a path stop a unit there.

## Events of a move
| Event | When | Fields |
|---|---|---|
| `MOVE_STARTED` | once, before the first step | from, **intended** to |
| `STEPPED` | once per cell entered | from, to, `forced` (true for pushes) |
| `MOVED` | once, at the end | from, **actual** to, `interrupted` |

Pushes produce forced `STEPPED`s and end with `PUSHED` (actual end, `interrupted`), then a collision if they hit something.

Choosing what to react to:
- "When an enemy **starts** moving": `MOVE_STARTED` (overwatch, root).
- "When an enemy **enters** a cell next to me": `STEPPED` (Backstep, traps).
- "When an enemy **ends** its move next to me": `MOVED`.

## Interruption
After each step's reactions, the walk stops if the unit:
- died,
- was moved by something else (pushed by a reaction…),
- was asked to stop (`ctx.stop_move(unit)`, for roots and traps),
- or the next cell is no longer free.

`MOVED` then reports where it really is, with `interrupted = true`. Later effects of the same card still run from there.

## Move modes (`MoveSelfEffect.mode`)
| Mode | Path | Steps (can trigger traps) |
|---|---|---|
| **WALK** (default) | shortest path, orthogonal steps | every cell |
| **DASH** | straight line only | every cell |
| **JUMP** | none | only the landing cell |
| **TELEPORT** | none | none |

The mode also decides which cells a movement card can **target**: a path must exist (a WALK can't go through units; a DASH needs a free straight line).

## Paths are fixed, not chosen
- WALK uses only **shortest** paths (steps = distance): no detours, so a unit can't wander around a big pattern to trigger step effects many times.
- Among shortest paths it **keeps going in the same direction** when it can, starting with its facing. The same situation always gives the same path (replays, AI), and the battle view can preview it.
- The player picks the **target**, not the route. Choosing among shortest routes could be added later if tests show it's wanted.

## Facing
With `face_movement` on, the unit faces the direction of its **last step** (if the move wasn't interrupted).
