@tool
##Data about a battle in progress.
class_name BattleState
extends  RefCounted

##All units in a fixed order
var units: Array[BattleUnit] = []

## Team of the unit whose turn it is.
var active_team: int = 0

var round: int = 1

## Team of the unit that took the very first turn.
var first_team: int = 0

##-1 while fighting, else the winning team; -2 = draw (after MAX_ROUNDS).
var winner: int = -1

## Turns are given out by ACTIVE TIME: every unit has its own schedule
## (see CombatRules.turn_delay).
## Index of the unit whose turn it is (-1 before the battle starts).
var active_unit: int = -1
## The battle clock: the tick the current turn started at.
var clock: int = 0
## Per unit (same index as `units`): the tick of its next turn.
var next_turn_at: Array[int] = []
## Per unit: a seeded random number, last tie-breaker when two units are
## due at the same tick with the same build (keeps replays exact).
var tiebreak: Array[int] = []
## Unit turns taken so far (rounds are counted from this).
var turns_taken: int = 0

## Statuses placed on cells (traps, burning ground...): cell (Vector2i) ->
## Array[StatusInstance]. Cells without any aren't in the dictionary.
var cell_statuses: Dictionary = {}

##Every event so far
var battle_log: Array[BattleEvent] = []

##The battle's only source of randomness (seeded).
var rng := RandomNumberGenerator.new()

func is_over() -> bool:
	return winner != -1
	
## Statuses on `cell` (empty array if none). Don't modify the result.
func statuses_at(cell: Vector2i) -> Array:
	return cell_statuses.get(cell, [])


## Cell statuses a unit of `viewer_team` can see: everything placed by its
## own team; for the other team's, SHOWN and HIDDEN_DETAILS ones (the view
## shows only "something is there" for the latter). HIDDEN ones (traps)
## are left out.
func cell_statuses_visible_to(cell: Vector2i, viewer_team: int) -> Array[StatusInstance]:
	var out: Array[StatusInstance] = []
	for inst in statuses_at(cell):
		var placer: BattleUnit = inst.source
		if (placer != null and placer.team == viewer_team) \
				or inst.status.reveal != StatusEffect.Reveal.HIDDEN:
			out.append(inst)
	return out


## Cells that hold statuses, in a fixed order (row by row), so they react
## in the same order every time.
func status_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(cell_statuses.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


## The living unit on `cell`, or null.
func unit_at(cell: Vector2i) -> BattleUnit:
	for u in units:
		if u.is_alive() and u.position == cell:
			return u
	return null


func living(team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.team == team and u.is_alive():
			out.append(u)
	return out


## Independent copy: units, statuses (sources remapped to the copied
## units), cooldowns, RNG position. Profiles and cards are shared (they're
## read-only during a battle). The log isn't copied.
func clone() -> BattleState:
	var copy := BattleState.new()
	copy.active_team = active_team
	copy.round = round
	copy.first_team = first_team
	copy.active_unit = active_unit
	copy.clock = clock
	copy.next_turn_at = next_turn_at.duplicate()
	copy.tiebreak = tiebreak.duplicate()
	copy.turns_taken = turns_taken
	copy.winner = winner
	copy.rng.seed = rng.seed
	copy.rng.state = rng.state
	var mapping := {}
	for u in units:
		var c := BattleUnit.new(u.profile, u.team)
		c.display_name = u.display_name
		c.position = u.position
		c.facing = u.facing
		c.hp = u.hp
		c.grit = u.grit
		c.cooldowns = u.cooldowns.duplicate()
		c.played_this_turn = u.played_this_turn.duplicate()
		copy.units.append(c)
		mapping[u] = c
	for i in units.size():
		for s in units[i].statuses:
			copy.units[i].statuses.append(StatusInstance.new(s.status, s.count, mapping.get(s.source)))
	for cell in cell_statuses:
		var list: Array[StatusInstance] = []
		for s in cell_statuses[cell]:
			var c := StatusInstance.new(s.status, s.count, mapping.get(s.source))
			c.on_cell = true
			c.cell = cell
			list.append(c)
		copy.cell_statuses[cell] = list
	return copy
