@tool
## A battle action. Parts add cards to a creature's deck (PartDef.added_cards).
##
## Every card is a .tres in the card library (res://creatures/cards/). Its
## behavior comes from one of two places:
##
##   DATA-ONLY CARD   this class as is. `pattern` says which cells it can
##                    target, `effects` say what happens there. Made in the
##                    inspector; covers most cards.
##
##   SCRIPT CARD      a script that `extends BattleCard` and overrides
##                    targets() / play() and, for reactions, is_reaction() /
##                    reacts_to() / react(). The card's .tres uses that
##                    script. Use this for anything unusual (reactions...).
##
## Cards only act on the battle through BattleContext, never directly.
##
## Reactions: playing one ARMS it on the unit. Every BattleEvent is then
## offered to reacts_to(); when it returns true, react() runs and the card
## is disarmed. (Lifetime and cooldown details: phase 2.)
class_name BattleCard
extends Resource

## Movement cards and attack cards. Per turn a unit plays at most 2 cards,
## never 2 attacks.
enum Kind { MOVE, ATTACK }

## Stable unique id (stored nowhere else but used for cooldowns, dedupe
## and lookups). Never reuse an id for a different card.
@export var id: StringName
## Name shown to the player.
@export var name: String
@export_multiline var description: String
@export var kind: Kind = Kind.ATTACK

## Number of the owner's turns this card is inactive for after use.
## 0 = usable every turn.
@export var cooldown: int = 0

## Cells this card can target, as offsets from the user, authored as if the
## user faced RIGHT. They're rotated to the user's facing (see Grid).
## e.g. a 2-cell line in front: (1, 0), (2, 0).
@export var pattern: Array[Vector2i] = []

## What happens on the target cell, in order (data-only cards).
@export var effects: Array[CardEffect] = []


## Cells this card can target right now.
## Default: `pattern` rotated to the user's facing, kept on the board.
## Movement cards also need the cell to be free.
func targets(ctx: BattleContext, user: BattleUnit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in pattern:
		var cell := user.position + Grid.rotate(offset, user.facing)
		if not Grid.in_bounds(cell):
			continue
		if kind == Kind.MOVE and not ctx.is_free(cell):
			continue
		out.append(cell)
	return out


## What happens when `user` plays this card on `target`.
## Default: runs `effects` in order.
func play(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	for effect in effects:
		if effect != null:
			effect.apply(ctx, user, target)


## True for reaction cards. Default: false.
func is_reaction() -> bool:
	return false


## Reactions: does this armed card fire for `event`? `owner` is the unit
## it's armed on. Default: never.
func reacts_to(_ctx: BattleContext, _owner: BattleUnit, _event: BattleEvent) -> bool:
	return false


## Reactions: what happens when it fires.
func react(_ctx: BattleContext, _owner: BattleUnit, _event: BattleEvent) -> void:
	pass


## Text for tooltips: the description if written, else built from effects.
func summary() -> String:
	if description != "":
		return description
	var parts := PackedStringArray()
	for effect in effects:
		if effect != null and effect.describe() != "":
			parts.append(effect.describe())
	return ", ".join(parts)
