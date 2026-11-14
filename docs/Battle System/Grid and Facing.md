---
tags: [battle-system, plan]
created: 2026-11-14
---
# Grid and Facing

Back to [[Battle System Overview]]

## Grid
- 5×5 cells, coordinates `Vector2i(x, y)`, `(0,0)` top-left, **y grows downwards** (Godot convention).
- Each cell: occupant (unit or empty), later terrain.
- Kept as plain data in `BattleState` (see [[Rules Engine]]), not as nodes.

## Facing
- Every unit faces one of **4 directions**: right, down, left, up. No diagonals.
- Sprites can only show left/right (`flip_h`), so up/down need an **arrow/indicator** in the view (see [[Battle View]]). For up/down, the sprite keeps its last left/right look.

## Patterns and rotation
Card target/move patterns are authored **once, as if the unit faced right**, as a list of offsets. They are rotated in 90° steps to the unit's facing:

| Facing | Offset `(x, y)` becomes |
|---|---|
| right | `( x,  y)` |
| down | `(-y,  x)` |
| left | `(-x, -y)` |
| up | `( y, -x)` |

- A straight line stays a straight line in all 4 directions.
- A diagonal stays diagonal (it just turns 90°).
- Pure integer math, so it's exact.

Example: "hit the 2 cells in front" = offsets `(1,0), (2,0)` facing right; facing up they become `(0,-1), (0,-2)`.

## How facing changes
**Open** (decide while prototyping, see [[Battle Open Questions]]):
- Moving turns you to the direction you moved?
- Attacking turns you towards the target?
- Or turning is free / is its own action / comes from specific cards?
