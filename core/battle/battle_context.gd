@tool
## The ONLY way cards and effects act on a battle.
## Cards do not affect BattleState directly but call context methods
## This way, all that cards can do is funneled through these methods
## and can therefore be recorded as events, can be logged, animated
## cancelled, reacted to, etc.
class_name BattleContext
extends RefCounted

## The target cell of the card being played right now (set by the rules
## engine). Area effects use it as the CENTER of the area, e.g.
## PushEffect AWAY_FROM_CENTER. For aim SELF cards it's the user's cell.
var action_target: Vector2i

# ------------------------------------------------------------------ queries

## The living unit on `cell`, or null.
func unit_at(_cell: Vector2i) -> BattleUnit:
	return _todo("unit_at")


## True if a and b are on different teams.
func is_enemy(a: BattleUnit, b: BattleUnit) -> bool:
	return a != null and b != null and a.team != b.team


## True if `cell` is on the board and nobody stands on it.
func is_free(cell: Vector2i) -> bool:
	return Grid.in_bounds(cell) and unit_at(cell) == null


# ------------------------------------------------------------------ actions
# Each records the matching BattleEvent(s) and lets reactions respond.

## Moves `unit` to `cell` by its own movement, using `mode` (see
## Grid.MoveMode). WALK and DASH go cell by cell: each step is a STEPPED
## event that reactions answer at once, and may stop the move. Records
## MOVE_STARTED, the STEPPED events, then MOVED (where it really ended).
## `face_movement`: turn the unit towards its last step at the end.
## Returns true if it reached `cell`; false if it couldn't start (no path,
## cell taken) or was interrupted on the way.
func move(_unit: BattleUnit, _cell: Vector2i, _mode: Grid.MoveMode = Grid.MoveMode.WALK,
		_face_movement: bool = true) -> bool:
	return _todo("move")


## Asks a unit that is moving or being pushed right now to stop after the
## step it just took (for reactions such as "root", "trap: stops you").
## Does nothing if it isn't moving.
func stop_move(_unit: BattleUnit) -> void:
	_todo("stop_move")


## Turns `unit` to `facing`.
func turn(_unit: BattleUnit, _facing: Grid.Facing) -> void:
	_todo("turn")


## Pushes `unit` up to `distance` cells along `direction` (a unit step).
## Stops at the board edge or another unit (a collision).
func push(_source: BattleUnit, _unit: BattleUnit, _direction: Vector2i, _distance: int) -> void:
	_todo("push")


## `source` deals `power` damage of `type` to `target`; the rules apply the
## stats (phys_dmg vs def, spc_dmg vs res).
func damage(_source: BattleUnit, _target: BattleUnit, _power: int, _type: DamageEffect.Type) -> void:
	_todo("damage")


## Heals `target` by `amount`, up to its max HP.
func heal(_target: BattleUnit, _amount: int) -> void:
	_todo("heal")

## `unit` loses `amount` HP directly: not an attack, ignores def/res
## (statuses like Poisoned subtract what they need first). Records HP_LOST.
func lose_hp(_unit: BattleUnit, _amount: int) -> void:
	_todo("lose_hp")


## `source` applies `amount` of `status` to `target`, following the
## status's stack_rule if it's already there. Records STATUS_APPLIED.
func apply_status(_source: BattleUnit, _target: BattleUnit, _status: StatusEffect, _amount: int) -> void:
	_todo("apply_status")


## Removes a status instance (not attributes), from a unit or from a cell
## (then `unit` may be null). Records STATUS_EXPIRED.
func remove_status(_unit: BattleUnit, _instance: StatusInstance) -> void:
	_todo("remove_status")


## `source` places `amount` of `status` on `cell` (a trap...), following
## its stack_rule if it's already there. Records STATUS_APPLIED with
## unit = null and to = cell.
func apply_cell_status(_source: BattleUnit, _cell: Vector2i, _status: StatusEffect, _amount: int) -> void:
	_todo("apply_cell_status")


## Statuses on `cell`.
func cell_statuses(_cell: Vector2i) -> Array:
	return _todo("cell_statuses")

func _todo(what: String) -> Variant:
	push_error("BattleContext.%s() is implemented by the rules engine." % what)
	return null
