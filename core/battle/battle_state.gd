@tool
## Everything about a battle in progress, as plain data. BattleRules
## changes it; clone() makes an independent copy for simulations.
class_name BattleState
extends RefCounted

## All units, alive or not, in a fixed order (BattleAction.unit_index).
var units: Array[BattleUnit] = []
## Team whose turn it is.
var active_team: int = 0
## 1 = first round. A round = both teams' turns.
var round: int = 1
## Team that took the very first turn (a new round starts when it's its
## turn again).
var first_team: int = 0
## -1 while fighting, else the winning team; -2 = draw (MAX_ROUNDS).
var winner: int = -1
## Every event so far, in order.
var log: Array[BattleEvent] = []
## The battle's only source of randomness (seeded).
var rng := RandomNumberGenerator.new()


func is_over() -> bool:
	return winner != -1


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
		c.cooldowns = u.cooldowns.duplicate()
		c.played_this_turn = u.played_this_turn.duplicate()
		copy.units.append(c)
		mapping[u] = c
	for i in units.size():
		for s in units[i].statuses:
			copy.units[i].statuses.append(StatusInstance.new(s.status, s.count, mapping.get(s.source)))
	return copy
