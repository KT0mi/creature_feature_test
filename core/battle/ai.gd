@tool
## Plays turns for a team, using only the public rules (legal_actions,
## apply, clone), exactly like a player would.
##
##   RANDOM  picks random legal actions (baseline for balance tests).
##   GREEDY  for each card slot of the turn, simulates every legal action on
##           a clone of the battle, scores the result, and plays the best
##           one, or stops if nothing beats doing nothing. (One step at a
##           time, not every 2-card combination: much faster, still decent.)
##
## Note: simulating on a clone means the AI "sees" hidden reactions. Fine
## for now; a fairer AI would ignore statuses it can't see.
class_name BattleAI
extends RefCounted

enum Mode { RANDOM, GREEDY }

## How much one grit "in the bank" is worth in the score (about the HP an
## advantage roll is expected to gain). The greedy AI only spends grit
## when the expected gain beats keeping it.
const GRIT_VALUE := 2.0

var mode: Mode
var rng := RandomNumberGenerator.new()


func _init(p_mode: Mode = Mode.GREEDY, seed: int = 0) -> void:
	mode = p_mode
	rng.seed = seed


## Plays the active team's whole turn (every living unit, up to 2 cards
## each), then ends the turn.
func play_turn(rules: BattleRules) -> void:
	var team := rules.state.active_team
	for i in rules.state.units.size():
		var u := rules.state.units[i]
		if u.team == team and u.is_alive():
			play_unit(rules, i)
	if not rules.state.is_over():
		rules.end_turn()


## Plays up to 2 cards for one unit. Returns the actions taken.
func play_unit(rules: BattleRules, unit_index: int) -> Array[BattleAction]:
	var taken: Array[BattleAction] = []
	for i in CombatRules.MAX_CARDS_PER_TURN:
		if rules.state.is_over():
			break
		var options := rules.legal_actions(unit_index)
		if options.is_empty():
			break
		var choice := _choose(rules, unit_index, options)
		if choice == null:
			break  # doing nothing scored best
		rules.apply(choice)
		taken.append(choice)
	return taken

## The action the AI would play next for unit `unit_index`, or null if it
## would stop (no options, or doing nothing scores best). Doesn't apply it:
## the battle scene applies it itself so it can animate each action.
func choose_action(rules: BattleRules, unit_index: int) -> BattleAction:
	var options := rules.legal_actions(unit_index)
	if options.is_empty():
		return null
	return _choose(rules, unit_index, options)


func _choose(rules: BattleRules, unit_index: int, options: Array[BattleAction]) -> BattleAction:
	if mode == Mode.RANDOM:
		return options[rng.randi_range(0, options.size() - 1)]
	var team := rules.state.units[unit_index].team
	var best: BattleAction = null
	var best_score := score(rules.state, team)  # baseline: do nothing
	# Every attack is also tried WITH grit (advantage), if the unit has some.
	var unit := rules.state.units[unit_index]
	if unit.grit > 0:
		var with_grit: Array[BattleAction] = []
		for option in options:
			if unit.deck()[option.slot].kind == BattleCard.Kind.ATTACK:
				var g := BattleAction.new(option.unit_index, option.slot, option.target)
				g.use_grit = true
				with_grit.append(g)
		options = options.duplicate()  # don't modify the caller's array
		options.append_array(with_grit)
	for option in options:
		var sim := rules.clone()
		# Expected values instead of rolls: the clone has the same RNG
		# position, so real rolls would let the AI foresee misses/crits.
		sim.luck = BattleRules.Luck.EXPECTED
		sim.apply(option)
		var s := score(sim.state, team)
		if s > best_score + 0.001:
			best_score = s
			best = option
	return best


## How good `state` is for `team`. Higher = better.
##   + own HP, - enemy HP (enemy HP weighs a bit more: be aggressive)
##   +/- 20 per living unit (kills matter most)
##   - small penalty per cell of distance to the nearest enemy (approach)
##   + small bonus for facing the nearest enemy and for armed reactions
static func score(state: BattleState, team: int) -> float:
	if state.winner == team:
		return 10000.0
	if state.winner != -1 and state.winner != -2:
		return -10000.0
	var s := 0.0
	for u in state.units:
		if not u.is_alive():
			continue
		if u.team == team:
			s += u.hp + 20.0 + u.grit * GRIT_VALUE
			if u.has_reaction_ready():
				s += 0.5
			var nearest := _nearest_enemy(state, u)
			if nearest != null:
				var d := nearest.position - u.position
				s -= 0.1 * (absi(d.x) + absi(d.y))
				if Grid.facing_of(d) == u.facing:
					s += 0.05
		else:
			s -= u.hp * 1.2 + 20.0
	return s


static func _nearest_enemy(state: BattleState, u: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_d := 1 << 30
	for other in state.units:
		if other.is_alive() and other.team != u.team:
			var d := absi(other.position.x - u.position.x) + absi(other.position.y - u.position.y)
			if d < best_d:
				best_d = d
				best = other
	return best
