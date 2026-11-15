@tool
## The ONLY way cards and effects act on a battle.
## Cards do not affect BattleState directly but call context methods
## This way, all that cards can do is funneled through these methods
## and can therefore be recorded as events, can be logged, animated
## cancelled, reacted to, etc.
class_name BattleContext
extends RefCounted

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

## Moves `unit` to `cell` by its own movement. Returns false (and does
## nothing) if the cell is off the board or taken.
func move(_unit: BattleUnit, _cell: Vector2i) -> bool:
	return _todo("move")


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


## Removes a status instance (not attributes). Records STATUS_EXPIRED.
func remove_status(_unit: BattleUnit, _instance: StatusInstance) -> void:
	_todo("remove_status")

func _todo(what: String) -> Variant:
	push_error("BattleContext.%s() is implemented by the rules engine." % what)
	return null
