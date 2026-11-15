@tool
## Grid and facing helpers for battles (pure functions, no state).
## Coordinates are Vector2i(x, y) with (0, 0) at the top-left and y growing
## DOWNWARDS (Godot's convention). The board is SIZE x SIZE cells.
class_name Grid
extends RefCounted

## Board size in cells (5x5 for now).
const SIZE := 5

## The 4 directions a unit can face, in clockwise order (so +1 = turn right).
enum Facing { RIGHT, DOWN, LEFT, UP }

## How a unit gets from its cell to a target cell (see MoveSelfEffect).
enum MoveMode {
	WALK,      ## step by step along a shortest path (one STEPPED per cell)
	DASH,      ## step by step, straight line only
	JUMP,      ## no cells in between: lands on the target (one STEPPED)
	TELEPORT,  ## no steps at all: just appears on the target
}

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


## The cells a unit at `from` passes through to reach `to` with `mode`,
## destination included, or [] if it can't get there. TELEPORT returns [to]
## (it uses no path, but the destination must still be free).
## `is_free` is a Callable(cell) -> bool saying whether a cell can be
## entered. `facing` breaks ties between equally short WALK paths.
##
## WALK only takes SHORTEST paths (each step brings it closer, so the
## number of steps = |dx| + |dy|): no detours, so a unit can't wander
## around to trigger step effects many times. Among shortest paths it keeps
## going in the same direction when it can (starting with `facing`), so
## the path is always the same for the same situation (replays, AI).
static func find_path(from: Vector2i, to: Vector2i, mode: MoveMode, facing: Facing,
		is_free: Callable) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if from == to or not in_bounds(to) or not is_free.call(to):
		return none
	match mode:
		MoveMode.TELEPORT, MoveMode.JUMP:
			var single: Array[Vector2i] = [to]
			return single
		MoveMode.DASH:
			var dir := facing_of(to - from)
			if dir == -1:
				return none  # not in a straight line
			var line: Array[Vector2i] = []
			var cell := from
			while cell != to:
				cell += step(dir)
				if not is_free.call(cell):
					return none
				line.append(cell)
			return line
	var path: Array[Vector2i] = []
	if _walk(from, to, step(facing), is_free, path):
		return path
	return none


## Depth-first search over shortest paths only (each step reduces the
## distance), trying the previous step's direction first. At most two
## directions per cell and a 5x5 board, so it's tiny.
static func _walk(cell: Vector2i, to: Vector2i, last_dir: Vector2i, is_free: Callable,
		path: Array[Vector2i]) -> bool:
	if cell == to:
		return true
	var d := to - cell
	var options: Array[Vector2i] = []
	if d.x != 0:
		options.append(Vector2i(signi(d.x), 0))
	if d.y != 0:
		options.append(Vector2i(0, signi(d.y)))
	# Keep going straight when possible.
	if options.size() == 2 and options[1] == last_dir:
		options.reverse()
	for dir in options:
		var next := cell + dir
		if not is_free.call(next):
			continue
		path.append(next)
		if _walk(next, to, dir, is_free, path):
			return true
		path.pop_back()
	return false
