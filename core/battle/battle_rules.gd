@tool
## The rules engine: runs a battle on a BattleState.
##
## It IS the BattleContext cards and statuses act through, so everything
## they do (move, push, damage, statuses...) is recorded as a BattleEvent
## and offered to every status on the board: on units (statuses,
## attributes, armed reactions) and on cells (traps...).
##
## Typical use:
##   var rules := BattleRules.new_battle([profile_a], [profile_b], seed)
##   rules.start()                        # attributes, initiative, 1st turn
##   rules.legal_actions(unit_index)      # what a unit may do now
##   rules.apply(action)                  # -> events, in order (to animate)
##   rules.end_turn()                     # -> events
##   rules.clone()                        # independent copy, for AI/previews
##
## EVENTS RESOLVE IMMEDIATELY (depth-first): the moment something happens,
## its event is logged and every status gets to react to it, BEFORE the
## code that caused it continues. So reactions can interrupt: a trap stops
## a walk at the step that entered it, a dodge moves away before the hit.
## Whatever a reaction does is itself an event, one level deeper. Safety:
##   * a status reacts at most `max_triggers_per_action` times (default 1)
##     during one top-level call (apply / end_turn / start);
##   * events deeper than CombatRules.MAX_CHAIN_DEPTH get no reactions;
##   * statuses are offered events in a fixed order (units in order, then
##     cells row by row), so results are deterministic.
## Code that runs after an event must not assume the board is unchanged:
## every context function re-checks (alive? cell free?) before acting.
class_name BattleRules
extends BattleContext

var state: BattleState

# Depth given to events emitted right now (0 = by the action itself).
var _depth := 0
# StatusInstance -> times it reacted during the current top-level call.
var _fired := {}
# Units currently moving or being pushed (BattleUnit -> true), and those
# asked to stop by stop_move().
var _moving := {}
var _stop := {}


## How attacks roll for miss / crit:
##   ROLL      real rolls with the battle's seeded RNG (normal battles)
##   EXPECTED  no rolls: every attack hits, and its damage is scaled by
##             its expected value (miss and crit odds). The AI simulates on
##             clones in this mode, so it can't foresee the real rolls (a
##             clone copies the RNG's position).
enum Luck { ROLL, EXPECTED }
var luck: Luck = Luck.ROLL

# The attack being resolved right now: its user, the victims it missed
# and those it crit (BattleUnit -> true). Empty outside an attack.
var _attack_source: BattleUnit = null
# The attack being resolved uses grit (advantage).
var _advantage := false
var _missed := {}
var _crits := {}

func _init(p_state: BattleState = null) -> void:
	state = p_state if p_state else BattleState.new()


## A new battle: team 0 on the left column facing right, team 1 on the
## right column facing left, spread over the middle rows. Call start() next.
static func new_battle(team_a: Array[CombatProfile], team_b: Array[CombatProfile], seed: int,
		names_a := PackedStringArray(), names_b := PackedStringArray()) -> BattleRules:
	var s := BattleState.new()
	s.rng.seed = seed
	_place(s, team_a, 0, names_a)
	_place(s, team_b, 1, names_b)
	return BattleRules.new(s)

static func _place(s: BattleState, profiles: Array[CombatProfile], team: int,
		names: PackedStringArray) -> void:
	var rows: Array = [[2], [1, 3], [0, 2, 4]][clampi(profiles.size(), 1, 3) - 1]
	for i in mini(profiles.size(), 3):
		var u := BattleUnit.new(profiles[i], team)
		u.position = Vector2i(0 if team == 0 else Grid.SIZE - 1, rows[i])
		u.facing = Grid.Facing.RIGHT if team == 0 else Grid.Facing.LEFT
		if i < names.size():
			u.display_name = names[i]
		s.units.append(u)

## Independent copy of the battle (for AI simulation and previews).
func clone() -> BattleRules:
	return BattleRules.new(state.clone())


# ---------------------------------------------------------------- flow

## Applies every unit's attributes, sets up the turn schedule (lighter
## units act first and more often) and starts the first unit's turn.
## Returns the events.
func start() -> Array[BattleEvent]:
	var mark := state.battle_log.size()
	_fired.clear()
	for u in state.units:
		for attribute in u.profile.attributes:
			apply_status(null, u, attribute, 1)
	_fired.clear()
	_init_schedule()
	_advance()
	state.first_team = state.active_team
	return state.battle_log.slice(mark)


## Every action unit `unit_index` may take right now: each ready card
## (respecting the 2-card / 1-attack budget) on each of its targets.
func legal_actions(unit_index: int) -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	if state.is_over() or unit_index < 0 or unit_index >= state.units.size():
		return out
	var u := state.units[unit_index]
	if not u.is_alive() or u.team != state.active_team:
		return out
	# Only the unit whose turn it is may act.
	if unit_index != state.active_unit:
		return out
	if u.played_this_turn.size() >= CombatRules.MAX_CARDS_PER_TURN:
		return out
	var attacks := 0
	for c in u.played_this_turn:
		if c.kind == BattleCard.Kind.ATTACK:
			attacks += 1
	var deck := u.deck()
	for slot in deck.size():
		var card := deck[slot]
		if card == null or not u.is_slot_ready(slot):
			continue
		if card.kind == BattleCard.Kind.ATTACK and attacks >= CombatRules.MAX_ATTACKS_PER_TURN:
			continue
		for cell in card.targets(self, u):
			out.append(BattleAction.new(unit_index, slot, cell))
	return out


func is_legal(action: BattleAction) -> bool:
	for a in legal_actions(action.unit_index):
		if a.slot == action.slot and a.target == action.target:
			return true
	return false


## Plays a card. Order: (turn to the target) -> CARD_PLAYED -> ATTACKED
## (reactions to these happen right away, so a dodge can move out BEFORE
## the hit) -> the card's play(), whose every step is reacted to as it
## happens -> win check.
## Returns the events, or [] (with an error) if the action isn't legal.
func apply(action: BattleAction) -> Array[BattleEvent]:
	var mark := state.battle_log.size()
	if action == null or not is_legal(action):
		push_error("BattleRules: illegal action (%s)." % action)
		return []
	_fired.clear()
	var u := state.units[action.unit_index]
	var card := u.deck()[action.slot]
	u.played_this_turn.append(card)
	# +1 because cooldowns count down at the start of the owner's turn:
	# cooldown 0 = usable again next turn, 1 = skips one turn, etc.
	u.cooldowns[action.slot] = card.cooldown + 1

	# Aimed attacks turn the user towards the aim (aim SELF cards don't).
	if card.kind == BattleCard.Kind.ATTACK and card.aim == BattleCard.Aim.CELL \
			and CombatRules.TURN_TO_ATTACK:
		var facing := Grid.facing_of(action.target - u.position)
		if facing != -1:
			turn(u, facing)
	var played := _event(BattleEvent.Type.CARD_PLAYED, u)
	played.source = u
	played.to = action.target
	played.card = card
	_emit(played)
	# Every unit in the attack's area is ATTACKED (in the area's fixed order)
	# and reacts right away: one that dodges out of the area isn't hit,
	# because effects hit CELLS, not the units listed here.
	var attacked_units: Array[BattleUnit] = []
	if card.kind == BattleCard.Kind.ATTACK:
		for victim in card.victims(self, u, action.target):
			if victim == u or not victim.is_alive():
				continue
			var attacked := _event(BattleEvent.Type.ATTACKED, victim)
			attacked.source = u
			attacked.to = victim.position
			attacked.card = card
			_emit(attacked)
			attacked_units.append(victim)
	
	# Luck: after the ATTACKED reactions, roll each victim once (miss, then
	# crit). Missed victims are skipped by every effect of the card.
	_attack_source = u if card.kind == BattleCard.Kind.ATTACK else null
	_missed.clear()
	_crits.clear()
	_advantage = false
	if action.use_grit and _attack_source != null and u.grit > 0 and not attacked_units.is_empty():
		_advantage = true
		gain_grit(u, -1)
		var used := _event(BattleEvent.Type.GRIT_USED, u)
		used.card = card
		_emit(used)
	for victim in attacked_units:
		if victim.is_alive() and u.is_alive():
			_roll_attack(u, victim, _advantage)

	if u.is_alive() and not state.is_over():
		# The target is the center of the card's area (see PushEffect).
		# Saved and restored in case a reaction plays a card meanwhile.
		var saved_target := action_target
		action_target = action.target
		card.play(self, u, action.target)
		action_target = saved_target
	_attack_source = null
	_advantage = false
	_missed.clear()
	_crits.clear()
	_check_winner()
	return state.battle_log.slice(mark)


## Ends the active unit's turn (TURN_ENDED: end-of-turn statuses act and
## tick), reschedules it and starts the next unit's turn.
func end_turn() -> Array[BattleEvent]:
	var mark := state.battle_log.size()
	if state.is_over():
		return []
	_end_unit_turn()
	return state.battle_log.slice(mark)

## Resets the card budget and counts cooldowns down for `units`, then
## sends their TURN_STARTED events.
func _start_turn_for(units: Array[BattleUnit]) -> void:
	for u in units:
		u.played_this_turn.clear()
		for slot in u.cooldowns.keys():
			u.cooldowns[slot] = maxi(0, u.cooldowns[slot] - 1)
	for u in units:
		_emit(_event(BattleEvent.Type.TURN_STARTED, u))


# ------------------------------------------------- turn schedule

## Every unit's first turn comes after one delay, so lighter creatures
## start first; tie-breakers are drawn once, from the battle's seed.
func _init_schedule() -> void:
	state.next_turn_at.clear()
	state.tiebreak.clear()
	for u in state.units:
		state.next_turn_at.append(CombatRules.turn_delay(u))
		state.tiebreak.append(state.rng.randi())


## The living unit due next: earliest tick, then lower build, then the
## seeded tie-breaker. -1 if nobody is alive.
func _next_actor(times: Array[int]) -> int:
	var best := -1
	for i in state.units.size():
		var u := state.units[i]
		if not u.is_alive():
			continue
		if best == -1 or _before(i, best, times):
			best = i
	return best


func _before(a: int, b: int, times: Array[int]) -> bool:
	if times[a] != times[b]:
		return times[a] < times[b]
	var build_a := state.units[a].profile.build
	var build_b := state.units[b].profile.build
	if build_a != build_b:
		return build_a < build_b
	return state.tiebreak[a] < state.tiebreak[b]


## Starts the next unit's turn: the clock jumps to its tick.
func _advance() -> void:
	var i := _next_actor(state.next_turn_at)
	if i == -1:
		return
	state.active_unit = i
	state.active_team = state.units[i].team
	state.clock = state.next_turn_at[i]
	var just_this: Array[BattleUnit] = [state.units[i]]
	_start_turn_for(just_this)


## Ends the active unit's turn and starts the next one.
func _end_unit_turn() -> void:
	_fired.clear()
	var i := state.active_unit
	var u := state.units[i]
	if u.is_alive():
		_emit(_event(BattleEvent.Type.TURN_ENDED, u))
	_check_winner()
	if state.is_over():
		return
	state.next_turn_at[i] += CombatRules.turn_delay(u)
	state.turns_taken += 1
	# A "round" = as many unit turns as there are units (for the draw limit
	# and the HUD; there are no real rounds in active time).
	state.round = 1 + state.turns_taken / maxi(state.units.size(), 1)
	if state.round > CombatRules.MAX_ROUNDS:
		_end_battle(-2)
		return
	_fired.clear()  # the new turn's statuses may react again
	_advance()


## The indices of the next `count` turns, starting with the current one
## (for the turn-order bar, the AI, or tests). Assumes nobody dies and no
## delay changes.
func turn_order(count: int) -> Array[int]:
	var out: Array[int] = []
	if state.active_unit == -1 or state.is_over():
		return out
	var times: Array[int] = state.next_turn_at.duplicate()
	out.append(state.active_unit)
	times[state.active_unit] += CombatRules.turn_delay(state.units[state.active_unit])
	while out.size() < count:
		var i := _next_actor(times)
		if i == -1:
			break
		out.append(i)
		times[i] += CombatRules.turn_delay(state.units[i])
	return out

func _check_winner() -> void:
	if state.is_over():
		return
	var alive_0 := state.living(0).size()
	var alive_1 := state.living(1).size()
	if alive_0 == 0 and alive_1 == 0:
		_end_battle(-2)
	elif alive_0 == 0:
		_end_battle(1)
	elif alive_1 == 0:
		_end_battle(0)


func _end_battle(winner: int) -> void:
	state.winner = winner
	var ev := _event(BattleEvent.Type.BATTLE_ENDED, null)
	ev.amount = winner
	_emit(ev)

# ------------------------------------------------------------ events

func _event(type: BattleEvent.Type, unit: BattleUnit) -> BattleEvent:
	return BattleEvent.new(type, unit)


## Logs the event and lets every status react to it RIGHT NOW (one level
## deeper), then does the automatic count-downs of turn start/end.
func _emit(ev: BattleEvent) -> void:
	ev.depth = _depth
	state.battle_log.append(ev)
	if ev.depth < CombatRules.MAX_CHAIN_DEPTH:
		var saved := _depth
		_depth = ev.depth + 1
		_dispatch(ev)
		_depth = saved
	# Count-downs happen AFTER statuses acted on the event.
	if ev.type == BattleEvent.Type.TURN_STARTED:
		_tick(ev.unit, StatusEffect.Tick.OWNER_TURN_START)
	elif ev.type == BattleEvent.Type.TURN_ENDED:
		_tick(ev.unit, StatusEffect.Tick.OWNER_TURN_END)


## Offers `ev` to every status: first each living unit's (units in order,
## statuses in the order they were applied), then each cell's (row by row).
func _dispatch(ev: BattleEvent) -> void:
	for u in state.units:
		if not u.is_alive():
			continue
		for inst in u.statuses.duplicate():
			if u.statuses.has(inst):  # not removed by an earlier reaction
				_offer(inst, u, ev)
	for cell in state.status_cells():
		for inst in state.statuses_at(cell).duplicate():
			if state.statuses_at(cell).has(inst):
				_offer(inst, null, ev)


## Lets one status react to `ev` (owner = its unit, or null on a cell).
func _offer(inst: StatusInstance, owner: BattleUnit, ev: BattleEvent) -> void:
	if _fired.get(inst, 0) >= inst.status.max_triggers_per_action:
		return
	if not inst.status.reacts_to(self, owner, inst, ev):
		return
	_fired[inst] = _fired.get(inst, 0) + 1
	if inst.status.is_reaction():
		var reacted := _event(BattleEvent.Type.REACTED, owner)
		reacted.card = inst.status.card
		_emit(reacted)
	inst.status.react(self, owner, inst, ev)
	# A status that used up its count goes away.
	if inst.count <= 0:
		remove_status(owner, inst)


## Count-downs for `when`: the unit's own statuses, and statuses on cells
## that this unit placed (a trap ticks on its placer's turns).
func _tick(unit: BattleUnit, when: StatusEffect.Tick) -> void:
	if unit == null:
		return
	for inst in unit.statuses.duplicate():
		_tick_one(unit, inst, when)
	for cell in state.status_cells():
		for inst in state.statuses_at(cell).duplicate():
			if inst.source == unit:
				_tick_one(null, inst, when)


func _tick_one(owner: BattleUnit, inst: StatusInstance, when: StatusEffect.Tick) -> void:
	if inst.status.permanent or inst.status.tick_on != when:
		return
	inst.count -= 1
	if inst.count <= 0:
		remove_status(owner, inst)


# ------------------------------------------------- BattleContext (for cards)

func unit_at(cell: Vector2i) -> BattleUnit:
	return state.unit_at(cell)


## See BattleContext.move. Steps: MOVE_STARTED, then per cell entered a
## STEPPED (reacted to immediately), then MOVED with where it really ended.
## The walk stops early if, after a step's reactions, the unit is dead, was
## moved by something else, was asked to stop (stop_move), or the next cell
## is no longer free.
func move(unit: BattleUnit, cell: Vector2i, mode: Grid.MoveMode = Grid.MoveMode.WALK,
		face_movement: bool = true) -> bool:
	if unit == null or not unit.is_alive():
		return false
	var path := Grid.find_path(unit.position, cell, mode, unit.facing, is_free)
	if path.is_empty():
		return false
	var start := unit.position
	var was_moving := _moving.has(unit)
	_moving[unit] = true
	_stop.erase(unit)

	var started := _event(BattleEvent.Type.MOVE_STARTED, unit)
	started.from = start
	started.to = cell
	_emit(started)  # e.g. "when an enemy starts moving, root it"

	var expected := start
	var last_step := Vector2i.ZERO
	var interrupted := false
	for next in path:
		if not unit.is_alive() or unit.position != expected or _stop.has(unit) \
				or not is_free(next):
			interrupted = true
			break
		var from := unit.position
		unit.position = next
		expected = next
		last_step = next - from
		if mode != Grid.MoveMode.TELEPORT:  # a teleport touches no cell
			var stepped := _event(BattleEvent.Type.STEPPED, unit)
			stepped.from = from
			stepped.to = next
			_emit(stepped)
	# The last step's reactions may have moved it again.
	interrupted = interrupted or unit.position != cell

	if not was_moving:
		_moving.erase(unit)
	_stop.erase(unit)
	if face_movement and unit.is_alive() and not interrupted:
		var facing := Grid.facing_of(last_step)
		if facing != -1:
			turn(unit, facing)
	var moved := _event(BattleEvent.Type.MOVED, unit)
	moved.from = start
	moved.to = unit.position
	moved.interrupted = interrupted
	_emit(moved)
	return not interrupted


func stop_move(unit: BattleUnit) -> void:
	if unit != null and _moving.has(unit):
		_stop[unit] = true


func turn(unit: BattleUnit, facing: Grid.Facing) -> void:
	if unit == null or unit.facing == facing:
		return
	unit.facing = facing
	var ev := _event(BattleEvent.Type.TURNED, unit)
	ev.amount = facing
	_emit(ev)


## Moves `unit` cell by cell, each cell a forced STEPPED (so pushes trigger
## traps too). Hitting the board edge or a unit stops it: COLLIDED, and
## both it and the unit hit take CombatRules.collision_damage() (each from
## its own build). Reactions
## to a step can stop the push there (no collision then). Ends with PUSHED
## (where it really ended) if it moved at all.
func push(source: BattleUnit, unit: BattleUnit, direction: Vector2i, distance: int) -> void:
	if unit == null or not unit.is_alive() or direction == Vector2i.ZERO:
		return
	var start := unit.position
	var was_moving := _moving.has(unit)
	_moving[unit] = true
	_stop.erase(unit)

	var expected := start
	var interrupted := false
	var blocker: BattleUnit = null
	var hit_cell := Vector2i.ZERO
	var collided := false
	for i in distance:
		if not unit.is_alive() or unit.position != expected or _stop.has(unit):
			interrupted = true
			break
		var next := unit.position + direction
		if not Grid.in_bounds(next):
			collided = true
			hit_cell = next
			break
		blocker = unit_at(next)
		if blocker != null:
			collided = true
			hit_cell = next
			break
		var from := unit.position
		unit.position = next
		expected = next
		var stepped := _event(BattleEvent.Type.STEPPED, unit)
		stepped.from = from
		stepped.to = next
		stepped.forced = true
		stepped.source = source
		_emit(stepped)
	interrupted = interrupted or unit.position != expected

	if not was_moving:
		_moving.erase(unit)
	_stop.erase(unit)
	if unit.position != start:
		var pushed := _event(BattleEvent.Type.PUSHED, unit)
		pushed.source = source
		pushed.from = start
		pushed.to = unit.position
		pushed.interrupted = interrupted
		_emit(pushed)
	if collided and not interrupted and unit.is_alive():
		var hit := _event(BattleEvent.Type.COLLIDED, unit)
		hit.source = source
		hit.from = unit.position
		hit.to = hit_cell
		_emit(hit)
		# Each one takes damage from its OWN build (bulkier = hit harder).
		var dmg := CombatRules.collision_damage(unit)
		if dmg > 0:
			_hurt(unit, dmg, source)
		if blocker != null:
			var blocker_dmg := CombatRules.collision_damage(blocker)
			if blocker_dmg > 0:
				_hurt(blocker, blocker_dmg, source)

## Damage from the attack being played gets its luck: x crit damage if the
## roll crit (ROLL), or x its expected value (EXPECTED). Damage from
## anything else (reactions, statuses) has no luck.
func damage(source: BattleUnit, target: BattleUnit, power: int, type: DamageEffect.Type) -> void:
	if target == null or not target.is_alive():
		return
	var amount := CombatRules.attack_damage(power, type, source, target)
	var critical := false
	if source != null and source == _attack_source:
		if luck == Luck.EXPECTED:
			amount = roundi(amount * CombatRules.expected_factor(source, target, _advantage))
		elif _crits.has(target):
			amount = roundi(amount * CombatRules.crit_damage(source))
			critical = true
	_hurt(target, amount, source, critical)


func attack_missed(unit: BattleUnit) -> bool:
	return _missed.has(unit)


func gain_grit(unit: BattleUnit, amount: int) -> void:
	if unit == null or not unit.is_alive():
		return
	var new_grit := clampi(unit.grit + amount, 0, CombatRules.MAX_GRIT)
	if new_grit == unit.grit:
		return
	var ev := _event(BattleEvent.Type.GRIT_CHANGED, unit)
	ev.amount = new_grit - unit.grit
	unit.grit = new_grit
	_emit(ev)

## Rolls one attack on one victim (ROLL mode only): miss / hit / crit,
## twice with `advantage` (grit), keeping the better result.
## A final miss -> MISSED, and the attacker gains 1 grit (olive branch).
func _roll_attack(attacker: BattleUnit, victim: BattleUnit, advantage: bool) -> void:
	if luck == Luck.EXPECTED:
		return
	var result := _roll_once(attacker, victim)
	if advantage:
		result = maxi(result, _roll_once(attacker, victim))
	if result == ROLL_MISS:
		_missed[victim] = true
		var missed := _event(BattleEvent.Type.MISSED, victim)
		missed.source = attacker
		missed.to = victim.position
		_emit(missed)
		gain_grit(attacker, 1)
	elif result == ROLL_CRIT:
		_crits[victim] = true

## Results of one roll, ordered worst to best (advantage keeps the max).
const ROLL_MISS := 0
const ROLL_HIT := 1
const ROLL_CRIT := 2

## One roll: miss? if not, crit? (always two random numbers, so a roll
## takes the same RNG steps whatever it gives: replays stay aligned).
func _roll_once(attacker: BattleUnit, victim: BattleUnit) -> int:
	var miss := state.rng.randf() < CombatRules.miss_chance(attacker, victim)
	var crit := state.rng.randf() < CombatRules.crit_chance(attacker, victim)
	if miss:
		return ROLL_MISS
	return ROLL_CRIT if crit else ROLL_HIT

func heal(target: BattleUnit, amount: int) -> void:
	if target == null or not target.is_alive():
		return
	var healed := mini(amount, target.profile.hp - target.hp)
	if healed <= 0:
		return
	target.hp += healed
	var ev := _event(BattleEvent.Type.HEALED, target)
	ev.amount = healed
	_emit(ev)


func lose_hp(unit: BattleUnit, amount: int) -> void:
	if unit == null or not unit.is_alive() or amount <= 0:
		return
	unit.hp -= amount
	var ev := _event(BattleEvent.Type.HP_LOST, unit)
	ev.amount = amount
	_emit(ev)
	_check_death(unit, null)


func apply_status(source: BattleUnit, target: BattleUnit, status: StatusEffect, amount: int) -> void:
	if target == null or not target.is_alive() or status == null:
		return
	var inst := target.get_status(status.id)
	var first_apply := false
	if inst != null:
		inst.count = status.stacked_count(inst.count, amount)
	else:
		inst = StatusInstance.new(status, amount, source)
		target.statuses.append(inst)
		first_apply = true
	var ev := _event(BattleEvent.Type.STATUS_APPLIED, target)
	ev.source = source
	ev.status = status
	ev.amount = amount
	_emit(ev)
	if first_apply: inst.status.on_applied(self, target, inst, ev)


func apply_cell_status(source: BattleUnit, cell: Vector2i, status: StatusEffect, amount: int) -> void:
	if not Grid.in_bounds(cell) or status == null:
		return
	var list: Array = state.cell_statuses.get(cell, [])
	var existing: StatusInstance = null
	for inst in list:
		if inst.status.id == status.id:
			existing = inst
	if existing != null:
		existing.count = status.stacked_count(existing.count, amount)
	else:
		var inst := StatusInstance.new(status, amount, source)
		inst.on_cell = true
		inst.cell = cell
		list.append(inst)
		state.cell_statuses[cell] = list
	var ev := _event(BattleEvent.Type.STATUS_APPLIED, null)
	ev.source = source
	ev.status = status
	ev.amount = amount
	ev.to = cell
	_emit(ev)


func cell_statuses(cell: Vector2i) -> Array:
	return state.statuses_at(cell)


## Removes a unit's or a cell's status. Permanent ones (attributes) can't
## be removed.
func remove_status(unit: BattleUnit, instance: StatusInstance) -> void:
	if instance == null or instance.status.permanent:
		return
	var ev: BattleEvent
	if instance.on_cell:
		var list: Array = state.cell_statuses.get(instance.cell, [])
		if not list.has(instance):
			return
		list.erase(instance)
		if list.is_empty():
			state.cell_statuses.erase(instance.cell)
		ev = _event(BattleEvent.Type.STATUS_EXPIRED, null)
		ev.to = instance.cell
	else:
		if unit == null or not unit.statuses.has(instance):
			return
		unit.statuses.erase(instance)
		ev = _event(BattleEvent.Type.STATUS_EXPIRED, unit)
	ev.status = instance.status
	_emit(ev)


## Damage (attacks, collisions): DAMAGED event, then death check.
func _hurt(unit: BattleUnit, amount: int, source: BattleUnit, critical: bool = false) -> void:
	if not unit.is_alive():
		return
	unit.hp -= amount
	var ev := _event(BattleEvent.Type.DAMAGED, unit)
	ev.source = source
	ev.amount = amount
	ev.critical = critical
	_emit(ev)
	_check_death(unit, source)


func _check_death(unit: BattleUnit, source: BattleUnit) -> void:
	if unit.hp > 0:
		return
	unit.hp = 0
	var ev := _event(BattleEvent.Type.DIED, unit)
	ev.source = source
	ev.from = unit.position
	_emit(ev)
