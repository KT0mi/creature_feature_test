@tool
## A status a creature can have during battle: Poisoned, Weakened...
## Also used for ATTRIBUTES (permanent statuses that parts give, e.g.
## Poisonous) and for ARMED REACTIONS (see ReactionStatus).
##
## Like BattleCard, a status is a .tres (in res://creatures/statuses/) and
## can be:
##   DATA-ONLY   stat modifiers + a count that ticks down on its own;
##   SCRIPTED    a script that `extends StatusEffect` and overrides
##               reacts_to() / react() to do things when events happen,
##               e.g. Poisoned: "at the end of my turn, lose HP".
##
## The status's number ("Poisoned 2") is its COUNT, stored per creature in
## a StatusInstance. What the count means is up to the status (turns left,
## triggers left, intensity...); `tick_on` makes it count down by itself.
class_name StatusEffect
extends Resource

## What happens when a creature that already has this status gets it again.
enum StackRule {
	ADD,          ## counts add up: Poisoned 1 + Poisoned 2 = Poisoned 3
	KEEP_HIGHER,  ## the higher count stays
	REPLACE,      ## the new count replaces the old one
}

## When the count goes down by 1 by itself (removed at 0). The rules engine
## does this AFTER the status's own reaction to that event, so a status
## that acts at the end of the turn still acts on its last count.
enum Tick { NEVER, OWNER_TURN_START, OWNER_TURN_END }

## What the OPPONENT can see of this status on a creature.
enum Reveal {
	SHOWN,           ## name and count
	HIDDEN_DETAILS,  ## only that "something" is there (e.g. a reaction is ready)
	HIDDEN,          ## nothing
}

## Stable unique id.
@export var id: StringName
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D

## Permanent statuses are ATTRIBUTES: they never tick down and can't be
## removed. Parts give them (PartDef.added_attributes).
@export var permanent: bool = false
@export var stack_rule: StackRule = StackRule.ADD
@export var tick_on: Tick = Tick.NEVER
@export var reveal: Reveal = Reveal.SHOWN

## A number scripted statuses can use for their effect (e.g. Poisoned's
## damage per trigger), so the same script can make several statuses.
@export var power: int = 0

## Optional stat changes while the creature has this status (e.g. Weakened:
## phys_dmg -1). Applied once per status, whatever its count.
@export var stat_modifiers: PartStats


## True for armed reactions (ReactionStatus). Used to show the opponent
## that a reaction is ready.
func is_reaction() -> bool:
	return false


## Does this status act on `event`? `owner` has the status, `instance`
## holds its count and who applied it. Default: never (data-only status).
func reacts_to(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> bool:
	return false


## What it does when it acts. To use up a count, change instance.count (the
## rules engine removes statuses at 0) or call ctx.remove_status().
func react(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> void:
	pass


## Count after this status is applied again: `current` already on the
## creature, `added` the new amount.
func stacked_count(current: int, added: int) -> int:
	match stack_rule:
		StackRule.KEEP_HIGHER:
			return maxi(current, added)
		StackRule.REPLACE:
			return added
	return current + added
