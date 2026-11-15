@tool
## The rules engine: runs a battle on a BattleState.
##
## It IS the BattleContext cards and statuses act through, so everything
## they do (move, push, damage, statuses...) is recorded as BattleEvents and
## offered to every status on the board (reactions and attributes included).
##
## Typical use:
##   var rules := BattleRules.new_battle([profile_a], [profile_b], seed)
##   rules.start()                        # attributes, initiative, 1st turn
##   rules.legal_actions(unit_index)      # what a unit may do now
##   rules.apply(action)                  # -> events, in order (to animate)
##   rules.end_turn()                     # -> events
##   rules.clone()                        # independent copy, for AI/previews
##
## Event processing: changes happen immediately and their events go into a
## queue; _flush() then offers each event to the statuses, whose own changes
## add more events (one level deeper). Safety rules:
##   * a status instance reacts at most once per top-level call
##     (apply / end_turn / start);
##   * events deeper than CombatRules.MAX_CHAIN_DEPTH get no reactions;
##   * the queue is first in, first out, so results are deterministic.
class_name BattleRules
extends BattleContext

var state: BattleState

var _queue: Array[BattleEvent] = []
# Depth given to events emitted right now (0 = by the action itself).
var _depth := 0
# StatusInstances that already reacted during the current top-level call.
var _fired := {}


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
	# Rows for 1, 2 or 3 units, centered on the 5x5 board.
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

## Applies every unit's attributes, decides who goes first (lower build)
## and starts that team's turn. Returns the events.
func start() -> Array[BattleEvent]:
	var mark := state.log.size()
	_fired.clear()
	for u in state.units:
		for attribute in u.profile.attributes:
			apply_status(null, u, attribute, 1)
	_flush()
	state.active_team = CombatRules.first_team(state.units, state.rng)
	state.first_team = state.active_team
	_start_turn()
	_flush()
	return state.log.slice(mark)


## Every action unit `unit_index` may take right now: each ready card
## (respecting the 2-card / 1-attack budget) on each of its targets.
func legal_actions(unit_index: int) -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	if state.is_over() or unit_index < 0 or unit_index >= state.units.size():
		return out
	var u := state.units[unit_index]
	if not u.is_alive() or u.team != state.active_team:
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


## Plays a card. Order: (turn to the target) -> CARD_PLAYED -> ATTACKED ->
## reactions to those (so a dodge can move away BEFORE the hit) -> the
## card's play() -> reactions to what it did -> win check.
## Returns the events, or [] (with an error) if the action isn't legal.
func apply(action: BattleAction) -> Array[BattleEvent]:
	var mark := state.log.size()
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

	if card.kind == BattleCard.Kind.ATTACK and CombatRules.TURN_TO_ATTACK:
		var facing := Grid.facing_of(action.target - u.position)
		if facing != -1:
			turn(u, facing)
	var played := _event(BattleEvent.Type.CARD_PLAYED, u)
	played.source = u
	played.to = action.target
	played.card = card
	_emit(played)
	if card.kind == BattleCard.Kind.ATTACK:
		var victim := unit_at(action.target)
		if victim != null and victim != u:
			var attacked := _event(BattleEvent.Type.ATTACKED, victim)
			attacked.source = u
			attacked.to = action.target
			attacked.card = card
			_emit(attacked)
	_flush()

	if u.is_alive() and not state.is_over():
		card.play(self, u, action.target)
	_flush()
	_check_winner()
	_flush()
	return state.log.slice(mark)


## Ends the active team's turn: TURN_ENDED for its units (end-of-turn
## statuses act and tick), then the other team's turn starts.
func end_turn() -> Array[BattleEvent]:
	var mark := state.log.size()
	if state.is_over():
		return []
	_fired.clear()
	for u in state.living(state.active_team):
		_emit(_event(BattleEvent.Type.TURN_ENDED, u))
	_flush()
	_check_winner()
	if not state.is_over():
		state.active_team = 1 - state.active_team
		if state.active_team == state.first_team:
			state.round += 1
		if state.round > CombatRules.MAX_ROUNDS:
			_end_battle(-2)
		else:
			_fired.clear()  # the new turn's statuses may react again
			_start_turn()
	_flush()
	return state.log.slice(mark)


func _start_turn() -> void:
	for u in state.living(state.active_team):
		u.played_this_turn.clear()
		for slot in u.cooldowns.keys():
			u.cooldowns[slot] = maxi(0, u.cooldowns[slot] - 1)
	for u in state.living(state.active_team):
		_emit(_event(BattleEvent.Type.TURN_STARTED, u))


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


# ------------------------------------------------------------ event queue

func _event(type: BattleEvent.Type, unit: BattleUnit) -> BattleEvent:
	return BattleEvent.new(type, unit)


## Logs the event and queues it for reactions.
func _emit(ev: BattleEvent) -> void:
	ev.depth = _depth
	state.log.append(ev)
	_queue.append(ev)


func _flush() -> void:
	while not _queue.is_empty():
		var ev: BattleEvent = _queue.pop_front()
		if ev.depth < CombatRules.MAX_CHAIN_DEPTH:
			var saved := _depth
			_depth = ev.depth + 1  # whatever reacts happens one level deeper
			_dispatch(ev)
			_depth = saved
		# Automatic count-downs happen AFTER statuses acted on the event.
		if ev.type == BattleEvent.Type.TURN_STARTED:
			_tick(ev.unit, StatusEffect.Tick.OWNER_TURN_START)
		elif ev.type == BattleEvent.Type.TURN_ENDED:
			_tick(ev.unit, StatusEffect.Tick.OWNER_TURN_END)


## Offers `ev` to every status of every living unit (units in order, each
## unit's statuses in the order they were applied).
func _dispatch(ev: BattleEvent) -> void:
	for u in state.units:
		if not u.is_alive():
			continue
		for inst in u.statuses.duplicate():
			if not u.statuses.has(inst) or _fired.has(inst):
				continue  # removed meanwhile, or already reacted this call
			if not inst.status.reacts_to(self, u, inst, ev):
				continue
			_fired[inst] = true
			if inst.status.is_reaction():
				var reacted := _event(BattleEvent.Type.REACTED, u)
				reacted.card = inst.status.card
				_emit(reacted)
			inst.status.react(self, u, inst, ev)
			# A status that used up its count goes away.
			if inst.count <= 0 and u.statuses.has(inst):
				remove_status(u, inst)


func _tick(unit: BattleUnit, when: StatusEffect.Tick) -> void:
	if unit == null:
		return
	for inst in unit.statuses.duplicate():
		if inst.status.permanent or inst.status.tick_on != when:
			continue
		inst.count -= 1
		if inst.count <= 0:
			remove_status(unit, inst)


# ------------------------------------------------- BattleContext (for cards)

func unit_at(cell: Vector2i) -> BattleUnit:
	return state.unit_at(cell)


func move(unit: BattleUnit, cell: Vector2i) -> bool:
	if unit == null or not unit.is_alive() or not is_free(cell):
		return false
	var ev := _event(BattleEvent.Type.MOVED, unit)
	ev.from = unit.position
	ev.to = cell
	unit.position = cell
	_emit(ev)
	return true


func turn(unit: BattleUnit, facing: Grid.Facing) -> void:
	if unit == null or unit.facing == facing:
		return
	unit.facing = facing
	var ev := _event(BattleEvent.Type.TURNED, unit)
	ev.amount = facing
	_emit(ev)


## Moves `unit` cell by cell. Hitting the board edge or a unit stops it and
## both (unit and the one hit) take CombatRules.COLLISION_DAMAGE.
func push(source: BattleUnit, unit: BattleUnit, direction: Vector2i, distance: int) -> void:
	if unit == null or not unit.is_alive() or direction == Vector2i.ZERO:
		return
	var start := unit.position
	var pos := start
	var collided := false
	var blocker: BattleUnit = null
	var hit_cell := Vector2i.ZERO
	for i in distance:
		var next := pos + direction
		if not Grid.in_bounds(next):
			collided = true
			hit_cell = next
			break
		blocker = unit_at(next)
		if blocker != null:
			collided = true
			hit_cell = next
			break
		pos = next
	if pos != start:
		unit.position = pos
		var pushed := _event(BattleEvent.Type.PUSHED, unit)
		pushed.source = source
		pushed.from = start
		pushed.to = pos
		_emit(pushed)
	if collided:
		var hit := _event(BattleEvent.Type.COLLIDED, unit)
		hit.source = source
		hit.from = pos
		hit.to = hit_cell
		_emit(hit)
		_hurt(unit, CombatRules.COLLISION_DAMAGE, source)
		if blocker != null:
			_hurt(blocker, CombatRules.COLLISION_DAMAGE, source)


func damage(source: BattleUnit, target: BattleUnit, power: int, type: DamageEffect.Type) -> void:
	if target == null or not target.is_alive():
		return
	_hurt(target, CombatRules.attack_damage(power, type, source, target), source)


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
	if inst != null:
		inst.count = status.stacked_count(inst.count, amount)
	else:
		target.statuses.append(StatusInstance.new(status, amount, source))
	var ev := _event(BattleEvent.Type.STATUS_APPLIED, target)
	ev.source = source
	ev.status = status
	ev.amount = amount
	_emit(ev)


## Attributes (permanent) can't be removed.
func remove_status(unit: BattleUnit, instance: StatusInstance) -> void:
	if unit == null or instance == null or instance.status.permanent:
		return
	if not unit.statuses.has(instance):
		return
	unit.statuses.erase(instance)
	var ev := _event(BattleEvent.Type.STATUS_EXPIRED, unit)
	ev.status = instance.status
	_emit(ev)


## Damage (attacks, collisions): DAMAGED event, then death check.
func _hurt(unit: BattleUnit, amount: int, source: BattleUnit) -> void:
	if not unit.is_alive():
		return
	unit.hp -= amount
	var ev := _event(BattleEvent.Type.DAMAGED, unit)
	ev.source = source
	ev.amount = amount
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
