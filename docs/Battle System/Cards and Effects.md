---
tags: [battle-system, plan]
created: 2026-11-14
---
# Cards and Effects

Back to [[Battle System Overview]]

## The problem with "inspector-only" cards
Building every card out of inspector pieces (target pattern + list of effect resources) works well for simple cards, but it gets very limiting for cards with real logic, like **reactions** ("when an enemy steps next to me, step away"). Every new idea would need a new effect type plus inspector plumbing.

## The plan: a hybrid
**Every card is a `BattleCard` resource** (a `.tres` in the card library), but its *behavior* can come from two places:

1. **Data-only cards** (most cards): the base `BattleCard` with:
   - `kind`: move or attack
   - `cooldown`
   - `pattern`: offsets the card can target, authored facing right (see [[Grid and Facing]])
   - `effects`: a list of small effect resources (Damage, Push, Move self, Heal…)
2. **Script cards** (anything unusual): a GDScript class that **extends `BattleCard`** and overrides a few functions. The card's `.tres` simply uses that script. You write the logic in the script editor with full GDScript, not in the inspector.

Both kinds live in the same card library, are referenced by parts the same way, and look the same to the rules engine.

### What a card can override
```gdscript
@tool
class_name BattleCard
extends Resource

enum Kind { MOVE, ATTACK }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.ATTACK
@export var cooldown: int = 0
@export var pattern: Array[Vector2i] = []   # authored facing right
@export var effects: Array[CardEffect] = [] # used by the default behavior

## Cells this card can target right now. Default: `pattern` rotated to the
## unit's facing, inside the grid (plus blocking rules).
func targets(ctx: BattleContext, user: BattleUnit) -> Array[Vector2i]

## What happens when it's played on `target`. Default: run `effects`.
func play(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void

## Reactions only (see below).
func is_reaction() -> bool
func reacts_to(ctx: BattleContext, owner: BattleUnit, event: BattleEvent) -> bool
func react(ctx: BattleContext, owner: BattleUnit, event: BattleEvent) -> void
```
`BattleContext` is the card's only way to touch the battle: `ctx.move(unit, cell)`, `ctx.push(unit, dir, n)`, `ctx.damage(target, amount, type)`, `ctx.unit_at(cell)`, `ctx.is_enemy(a, b)`, `ctx.facing_of(unit)`… Every one of these produces [[Rules Engine#Events and triggers (needed for reactions)|events]], so animations, logs and other reactions all see them.

## Reactions
A reaction is a card that you **play on your turn to arm it**, and it **fires later**, during the opponent's turn, when its condition happens.

Lifecycle (proposal, to confirm in tests):
1. Played as one of your 2 cards (a reaction is still a move or an attack card, e.g. Backstep is a **move** card).
2. It becomes **armed** on the unit.
3. Every event during the battle is offered to armed reactions (`reacts_to`).
4. When it fires: `react` runs, then it's **disarmed**.
5. If it hasn't fired by the start of your next turn, it **expires**.
6. **Open:** cooldown starts when played, or when it fires?

### Example: Backstep
> Move. Reaction. When an enemy enters a cell next to this creature, step 1 cell directly away from it.

```gdscript
@tool
class_name BackstepCard
extends BattleCard

func is_reaction() -> bool:
	return true

func reacts_to(ctx: BattleContext, owner: BattleUnit, event: BattleEvent) -> bool:
	return event.type == BattleEvent.Type.MOVED \
		and ctx.is_enemy(event.unit, owner) \
		and Grid.is_orthogonally_adjacent(event.to, owner.position)

func react(ctx: BattleContext, owner: BattleUnit, event: BattleEvent) -> void:
	var away := owner.position - event.to   # unit vector away from the enemy
	ctx.move(owner, owner.position + away)  # does nothing if blocked or off-grid
```
In the inspector you then create `backstep.tres` with this script, and set its id, name, description and cooldown there.

## Passives (same mechanism, for free)
Parts could also have always-on **passive** effects ("Spiny: an enemy that hits this creature in melee takes 1 damage"). A passive is just a reaction that is **always armed** and never expires, attached to the part instead of played as a card. Not needed for the first version, but the event system supports it from day one.

## Effects (for data-only cards)
Small `CardEffect` resources, each with one job:

| Effect | Fields |
|---|---|
| `DamageEffect` | power, physical/special |
| `PushEffect` | direction (away from user / user's facing…), distance; collisions deal damage |
| `MoveSelfEffect` | (moves the user to the target cell) |
| `HealEffect` | amount |
| later: status effects | … |

If an effect gets too specific, write a script card instead.

## Authoring tools
- **Card editor** (later, in the Creature Tools plugin): paint a card's pattern by clicking cells on a grid, see it rotated in all 4 facings, edit the effect list. This removes most of the inspector pain for data-only cards.
- Script cards are edited in Godot's script editor as usual.
- The part editor can list the cards a part adds.

## Card library
- One `.tres` per card in `res://creatures/cards/` (sub-folders allowed), with script cards' `.gd` files next to them.
- The registry indexes cards by id and reports duplicate ids, like it does for parts.
