@tool
## Grid and facing helpers for battles (pure functions, no state).
##
## Coordinates are Vector2i(x, y) with (0, 0) at the top-left and y growing
## DOWNWARDS (Godot's convention). The board is SIZE x SIZE cells.
##
## Card patterns are authored as if the unit faced RIGHT, then rotated in
## 90-degree steps to the unit's facing with rotate():
##   right ( x,  y)   down (-y,  x)   left (-x, -y)   up ( y, -x)
## Straight lines stay straight lines, diagonals stay diagonal.
class_name Grid
extends RefCounted

## Board size in cells (5x5 for now).
const SIZE := 5

## The 4 directions a unit can face, in clockwise order (so +1 = turn right).
enum Facing { RIGHT, DOWN, LEFT, UP }

## One-cell step for each Facing.
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


## `offset` (authored facing right) rotated to `facing`.
static func rotate(offset: Vector2i, facing: Facing) -> Vector2i:
	match facing:
		Facing.DOWN:
			return Vector2i(-offset.y, offset.x)
		Facing.LEFT:
			return Vector2i(-offset.x, -offset.y)
		Facing.UP:
			return Vector2i(offset.y, -offset.x)
	return offset


## One-cell step in the direction of `facing`.
static func step(facing: Facing) -> Vector2i:
	return STEPS[facing]


## The Facing that points along `direction`, or -1 if it isn't a straight
## orthogonal direction (diagonal or zero). Only the sign matters, so
## (3, 0) is RIGHT.
static func facing_of(direction: Vector2i) -> int:
	var d := direction.sign()
	if d.x != 0 and d.y != 0:
		return -1
	return STEPS.find(d)


## True if `cell` is on the board.
static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


## True if a and b share a side (4-neighbourhood).
static func is_orthogonally_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := (a - b).abs()
	return d.x + d.y == 1


## True if a and b touch, diagonals included (8-neighbourhood).
static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := (a - b).abs()
	return a != b and d.x <= 1 and d.y <= 1
