@tool
## One creature on the battle board: its CombatProfile plus everything that
## changes during a battle (position, HP, facing, cooldowns, statuses).
## Plain data; the rules engine (phase 2) changes it.
##
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
## card id (StringName) -> turns left before it can be played again.
## Missing or 0 = ready.
var cooldowns: Dictionary = {}
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


## True if `card` is off cooldown.
func is_ready(card: BattleCard) -> bool:
	return cooldowns.get(card.id, 0) <= 0


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
	return value


func label() -> String:
	return display_name if display_name != "" else "unit(team %d)" % team
