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
## AIM vs AREA: `pattern` (with `aim`) says which cell the player picks;
## `area` says which cells get HIT around that pick. A normal attack hits
## only the picked cell (area = [(0, 0)]); Tail Swipe aims at its user
## (aim SELF) and hits the cells around it; a fireball aims 2-3 cells away
## and hits a plus shape there. The action is always "card + one cell", so
## the AI, previews and replays don't change for area attacks.
##
## Reactions: playing one ARMS it: the user gets a ReactionStatus that
## forwards every BattleEvent to this card's reacts_to(); when it returns
## true, react() runs and the status is removed. Unfired, it expires at the
## owner's next turn start. The opponent sees it according to
## `reaction_reveal`.
class_name BattleCard
extends Resource

## Movement cards and attack cards. Per turn a unit plays at most 2 cards,
## never 2 attacks.
enum Kind { MOVE, ATTACK }

## What the player picks when playing the card.
enum Aim {
	CELL,  ## a cell from `pattern`
	SELF,  ## nothing: the target is always the user's own cell (Tail Swipe)
}


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

@export var aim: Aim = Aim.CELL

## Cells this card can target (aim CELL), as offsets from the user,
## authored as if the user faced RIGHT. They're rotated to the user's
## facing (see Grid). e.g. a 2-cell line in front: (1, 0), (2, 0).
@export var pattern: Array[Vector2i] = []

## Cells HIT, as offsets from the target cell, authored as if aiming RIGHT.
## Rotated to the direction of the aim (the user's facing for aim SELF, or
## the direction from the user to the target), so cones and lines point
## where you aimed. Default [(0, 0)]: only the target cell.
## e.g. Tail Swipe (aim SELF): the 8 cells around (0, 0);
##      fireball: (0,0), (1,0), (-1,0), (0,1), (0,-1);
##      cone: (0,0), (1,-1), (1,0), (1,1).
## Ignored by movement cards (they only move to the target).
@export var area: Array[Vector2i] = [Vector2i.ZERO]

## Can the area hit the user itself (if it stands in it)?
@export var hits_self: bool = false
## Can the area hit the user's allies (friendly fire)? Enemies are always hit.
@export var hits_allies: bool = true

## What happens on the target cell, in order (data-only cards).
@export var effects: Array[CardEffect] = []

## Reactions only: what the opponent sees while it's armed. Default: that a
## reaction is ready, but not which one.
@export var reaction_reveal: StatusEffect.Reveal = StatusEffect.Reveal.HIDDEN_DETAILS

## Cells this card can target right now.
## Default: `pattern` rotated to the user's facing, kept on the board.
## Movement cards also need the cell to be free and, if the card has a
## MoveSelfEffect, a path to it for that effect's mode (e.g. a WALK can't
## go through units; a DASH needs a free straight line).
func targets(ctx: BattleContext, user: BattleUnit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	# A reaction with no pattern is played on its user (it just arms).
	# Aim SELF, or a reaction with no pattern: played on the user's own cell.
	if aim == Aim.SELF or (is_reaction() and pattern.is_empty()):
		out.append(user.position)
		return out
	var move_effect := move_effect() if kind == Kind.MOVE else null
	for offset in pattern:
		var cell := user.position + Grid.rotate(offset, user.facing)
		if not Grid.in_bounds(cell):
			continue
		if kind == Kind.MOVE and not ctx.is_free(cell):
			continue
		if move_effect != null and Grid.find_path(user.position, cell, move_effect.mode,
				user.facing, ctx.is_free).is_empty():
			continue
		out.append(cell)
	return out


## The card's first MoveSelfEffect, or null.
func move_effect() -> MoveSelfEffect:
	for effect in effects:
		if effect is MoveSelfEffect:
			return effect
	return null


## What happens when `user` plays this card on `target`.
## Default: reactions arm themselves on the user; other cards run `effects`
## on every affected cell, EFFECT BY EFFECT (all cells take the damage,
## then all cells are pushed...), cells in affected_cells() order. Cells
## whose unit the card may not hit (self, allies) are skipped; empty cells
## still get the effects (e.g. placing a trap on each cell).
func play(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	if is_reaction():
		ctx.apply_status(user, user, ReactionStatus.for_card(self), 1)
		return
	# Movement cards only use the target; attacks use their whole area.
	var cells: Array[Vector2i] = []
	if kind == Kind.MOVE:
		cells.append(target)
	else:
		cells = affected_cells(ctx, user, target)
	for effect in effects:
		if effect == null:
			continue
		for cell in cells:
			# Checked again for every effect: an earlier effect may have moved units
			if may_hit(ctx, user, ctx.unit_at(cell)):
				effect.apply(ctx, user, cell)


## Cells hit when `user` plays this card on `target`: `area` rotated to the
## aim and placed on the target, kept on the board, each once.
## Order: farthest from the target first (so outward pushes move the outer
## units before the inner ones bump into them), then row by row.
## Script cards may override it; it must only READ the board and give the
## same answer for the same board (the AI and previews rely on that).
func affected_cells(_ctx: BattleContext, user: BattleUnit, target: Vector2i) -> Array[Vector2i]:
	var dir := aim_direction(user, target)
	var out: Array[Vector2i] = []
	for offset in area:
		var cell := target + Grid.rotate(offset, dir)
		if Grid.in_bounds(cell) and not out.has(cell):
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(a.x - target.x) + absi(a.y - target.y)
		var db := absi(b.x - target.x) + absi(b.y - target.y)
		if da != db:
			return da > db
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## The direction `area` is rotated to: the user's facing for aim SELF (or a
## target that isn't in a straight line), else the direction of the aim.
func aim_direction(user: BattleUnit, target: Vector2i) -> Grid.Facing:
	if aim == Aim.CELL:
		var f := Grid.facing_of(target - user.position)
		if f != -1:
			return f
	return user.facing


## Units this card would hit on `target`, in affected_cells() order.
func victims(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for cell in affected_cells(ctx, user, target):
		var unit := ctx.unit_at(cell)
		if unit != null and may_hit(ctx, user, unit):
			out.append(unit)
	return out


## False if `unit` is the user (and hits_self is off) or an ally (and
## hits_allies is off). Empty cells (null) can always be affected.
func may_hit(ctx: BattleContext, user: BattleUnit, unit: BattleUnit) -> bool:
	if unit == null:
		return true
	if unit == user:
		return hits_self
	if not ctx.is_enemy(user, unit):
		return hits_allies
	return true

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
