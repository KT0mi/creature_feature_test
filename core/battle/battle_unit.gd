@tool
## One creature on the battle board: its CombatProfile plus everything that
## changes during a battle (position, HP, facing, cooldowns, armed
## reactions). Plain data; the rules engine changes it.
## Statuses include attributes (permanent, from parts) and armed reactions
## (ReactionStatus), so "does it have a reaction ready?" is computed from
## them (has_reaction_ready) rather than stored separately.
class_name BattleUnit
extends RefCounted

var profile: CombatProfile
## Display name (from CreatureNamer), for logs and the HUD.
var display_name: String = ""
## 0 = player side, 1 = enemy side.
var team: int = 0
var position: Vector2i
var facing: Grid.Facing = Grid.Facing.RIGHT
var hp: int = 0
## deck slot (index in profile.battle_cards) -> turns left before it can be
## played again. Missing or 0 = ready. Per SLOT, not per card id, so two
## copies of the same card cool down independently.
var cooldowns: Dictionary = {}
## Grit: re-rolls for missed attacks (0..CombatRules.MAX_GRIT).
var grit: int = CombatRules.START_GRIT
## Statuses, attributes and armed reactions currently on this unit.
var statuses: Array[StatusInstance] = []
## Cards played this turn, to enforce the 2-card budget (max 1 attack).
var played_this_turn: Array[BattleCard] = []


func _init(p_profile: CombatProfile = null, p_team: int = 0) -> void:
	profile = p_profile
	team = p_team
	if profile:
		hp = profile.hp  # every battle starts at full HP

func is_alive() -> bool:
	return hp > 0

## True if the card in deck slot `slot` is off cooldown.
func is_slot_ready(slot: int) -> bool:
	return cooldowns.get(slot, 0) <= 0

## The unit's cards (its deck), by slot.
func deck() -> Array[BattleCard]:
	return profile.battle_cards

## The StatusInstance of status `id`, or null.
func get_status(id: StringName) -> StatusInstance:
	for s in statuses:
		if s.status.id == id:
			return s
	return null


func has_status(id: StringName) -> bool:
	return get_status(id) != null


## True if an armed reaction is waiting to fire. The battle view shows this
## to the opponent (as "!" or similar) unless the reaction is fully HIDDEN.
func has_reaction_ready() -> bool:
	for s in statuses:
		if s.status.is_reaction():
			return true
	return false


## What a unit of team `viewer_team` can see of this unit's statuses.
## Own team: everything. Opponents: SHOWN statuses in full; HIDDEN_DETAILS
## ones come back too, and the view must only show "something is there"
## (e.g. "reaction ready") for them; HIDDEN ones are left out.
func statuses_visible_to(viewer_team: int) -> Array[StatusInstance]:
	if viewer_team == team:
		return statuses.duplicate()
	var out: Array[StatusInstance] = []
	for s in statuses:
		if s.status.reveal != StatusEffect.Reveal.HIDDEN:
			out.append(s)
	return out


## Stat `stat` ("phys_dmg", "def"...) with status modifiers applied: the
## profile value plus each status's stat_modifiers (once per status).
func effective_stat(stat: StringName) -> int:
	var value: int = profile.get(stat)
	for s in statuses:
		if s.status.stat_modifiers != null:
			value += s.status.stat_modifiers.get(stat)
	# Overrides win over everything (the last status applied wins if two
	# set the same stat).
	for s in statuses:
		if s.status.stat_overrides.has(stat):
			value = s.status.stat_overrides[stat]
	return value

## Sum of a luck field ("miss_chance", "crit_chance", "crit_damage") over
## all of this unit's statuses (attributes included).
func luck_modifier(field: StringName) -> float:
	var total := 0.0
	for s in statuses:
		total += s.status.get(field)
	return total

func label() -> String:
	return display_name if display_name != "" else "unit(team %d)" % team
