---
tags: [battle-system, plan]
created: 2026-11-14
status: data structures done (branch claude/battle-data-structures-status-feature)
---
# Statuses and Attributes

Back to [[Battle System Overview]]

## One mechanism for three things
Statuses, attributes and armed reactions are all **things attached to a unit that react to battle events** ([[Rules Engine#Events and triggers (needed for reactions)]]).

| Thing | Example | Listens for | Does |
|---|---|---|---|
| Status | Poisoned 2 | end of its owner's turn | loses (x − res) HP, count −1, gone at 0 |
| Attribute | Poisonous | its owner being **attacked** | applies Poisoned 1 to the attacker |
| Armed reaction | Backstep | an enemy stepping next to it | steps away, then removed |

## StatusEffect (authored, `res://creatures/statuses/`)
Same **hybrid** as cards ([[Cards and Effects]]): data-only, or a script that `extends StatusEffect` and overrides `reacts_to()` / `react()`.

| Field | Meaning |
|---|---|
| `id`, `name`, `description`, `icon` | |
| `permanent` | true = **attribute**: never ticks down, can't be removed |
| `stack_rule` | applied again: **ADD** counts (default), **KEEP_HIGHER**, **REPLACE** |
| `tick_on` | count −1 by itself at the owner's turn start/end (after the status acted) |
| `reveal` | what the **opponent** sees: SHOWN, HIDDEN_DETAILS ("something is there"), HIDDEN |
| `power` | a number scripts can use (e.g. Poisoned's x), so one script makes several statuses |
| `stat_modifiers` | a `PartStats` added while the status is on (e.g. Weakened: phys −1) |

The number in "Poisoned 2" is the **count**, stored per unit in a `StatusInstance` (with who applied it). What the count means is up to the status: turns, triggers, intensity.

## Attributes
- Parts have **Added Attributes** (next to Added Cards): permanent `StatusEffect`s.
- `CombatProfile.attributes` collects them like cards (pairs once; `merge_duplicate_cards` applies too).
- The battle applies them to the unit at the start.

## Armed reactions
- Playing a reaction card gives its user a `ReactionStatus`: it forwards events to the card's `reacts_to` / `react`, removes itself when it fires, and expires at the owner's next turn.
- **Showing it to the enemy:** `BattleUnit.has_reaction_ready()` is computed from the unit's statuses (no separate flag to keep in sync). The card's `reaction_reveal` decides what the opponent sees; default **HIDDEN_DETAILS** ("a reaction is ready", not which one).
- `BattleUnit.statuses_visible_to(team)` gives what a team may see.

## Cards that apply statuses
Data-only, with `ApplyStatusEffect` (status, amount, target or self):
> **Venom Scratch** = `DamageEffect 2` + `ApplyStatusEffect Poisoned 2`

## Rules decided (defaults, can change after tests)
- Stacking: per status, **ADD** by default.
- Poison-like HP loss uses `lose_hp`: **not an attack**, so "when attacked" reactions don't fire (no Poisoned/Poisonous loops).
- Poisoned's x is set on the status (`power`).
- Paired parts give their attribute **once**.

## Example scripts
```gdscript
# Poisoned: "At the end of your turn lose (power - res) HP", count = triggers.
@tool
class_name PoisonedStatus
extends StatusEffect

func reacts_to(ctx, owner, instance, event) -> bool:
	return event.type == BattleEvent.Type.TURN_ENDED and event.unit == owner

func react(ctx, owner, instance, event) -> void:
	ctx.lose_hp(owner, maxi(0, power - owner.effective_stat(&"res")))
	instance.count -= 1
	if instance.count <= 0:
		ctx.remove_status(owner, instance)
```
```gdscript
# Poisonous (attribute): "Whenever a creature attacks you, it gets Poisoned 1".
@tool
class_name PoisonousAttribute
extends StatusEffect

@export var poisoned: StatusEffect

func reacts_to(ctx, owner, instance, event) -> bool:
	return event.type == BattleEvent.Type.ATTACKED and event.unit == owner and event.source != null

func react(ctx, owner, instance, event) -> void:
	ctx.apply_status(owner, event.source, poisoned, 1)
```
