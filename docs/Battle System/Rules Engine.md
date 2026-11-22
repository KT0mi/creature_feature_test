---
tags: [battle-system, plan]
created: 2026-11-14
---

# Rules Engine

Back to [[Battle System Overview]]

The rules are **plain GDScript objects** in `core/battle/` (no nodes, no scenes). They are deterministic: the same starting state + seed + actions always give the same battle.

## Pieces

| Piece | Holds / does |
|---|---|
| `BattleState` | grid, units, round number, whose turn, seeded RNG, event log, armed reactions |
| `BattleUnit` | `CombatProfile`, team, position, current HP, facing, per-card cooldowns, cards played this turn |
| `BattleAction` | "unit X plays card Y on target Z" (or "end turn") |
| `BattleEvent` | something that happened: moved, turned, pushed, collided, damaged, healed, reaction triggered, died… |
| `CombatRules` | formulas and constants to tune (damage, initiative tie-break…) |

## The two core functions
```gdscript
# Every action `unit` may take right now (cards x valid targets).
func legal_actions(state: BattleState, unit: BattleUnit) -> Array[BattleAction]

# Changes the state, returns what happened, in order.
func apply(state: BattleState, action: BattleAction) -> Array[BattleEvent]
```
- The view animates the returned events; the rules never wait for animations.
- **Previews**: run `apply` on a copy of the state and show the result (predicted damage, where pushes end).
- **AI** and **headless simulations** use the same two functions.

## Movement
Own moves and pushes go **cell by cell**; see [[Movement]].

## Turn structure (active time)
- Every **unit** has its own schedule: after its turn it waits `delay = 50 + build` ticks (`CombatRules.turn_delay`). The unit due earliest acts next; ties go to the lower build, then a seeded tie-breaker. See [[Active Time Turns]].
- On its turn a unit may play **up to 2 cards**, in **any order**: 1 move + 1 attack, 2 moves, 1, or none. Never 2 attacks.
- "End turn" ends that unit's turn; lighter creatures act more often and can get two turns in a row.
- With 3v3, units of both teams interleave in schedule order.

## Cooldowns
- Playing a card sets its cooldown to `card.cooldown`.
- At the start of the **owner's** turn, every cooldown goes down by 1.
- Cooldown 0 = usable every turn; cooldown 1 = skip one turn; and so on.
- **Open** for reactions: does the cooldown start when the card is played, or when it triggers? See [[Cards and Effects#Reactions]].

## Luck
Every attack rolls per victim for a **miss** and a **crit**, tilted towards the lighter creature; **grit** re-rolls misses. See [[Luck and Grit]].

## Damage (starting point, tune later)
```
physical: max(1, card_power + phys_dmg - def)
special:  max(1, card_power + spc_dmg - res)
```
Each attack card says whether it's physical or special. All formulas live in `CombatRules` so tuning never touches the rest of the code.

## Events and triggers (needed for reactions)
**Events resolve immediately (depth-first).** The moment something happens, its event is logged and every status on the board gets to react to it, **before** the code that caused it continues:
1. An effect changes the state (e.g. a unit steps into (2,3)) and emits the event.
2. Every status reacts right away, in a fixed order: units in order (their statuses in the order applied), then cell statuses row by row ([[Statuses and Attributes]]).
3. Whatever a reaction does is itself an event, one level deeper, and resolves the same way.
4. Only then does the original code continue, and it must re-check the board (the context functions do: alive? cell free?).

This is what makes **interruptions** possible: a trap stops a walk at the step that entered it, a dodge moves away before the hit lands ([[Movement]]).

Safety rules so chains stay sane:
- A status reacts at most `max_triggers_per_action` times (default **1**) per top-level call (`apply`, `end_turn`, `start`). Raise it for per-step effects.
- Events deeper than `MAX_CHAIN_DEPTH` (8) get no reactions.
- The reaction order is fixed, so results are deterministic (replays, AI).

> History: the first version used a first-in-first-out queue processed after the whole action. It couldn't interrupt anything, so it was replaced.

## Winning
All units of one side at 0 HP. (Later maybe: turn limit, objectives.)