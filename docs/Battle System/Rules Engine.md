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

## Turn structure
- Sides alternate. On its turn, each unit may play **up to 2 cards**, in **any order**:
  - 1 move + 1 attack, or 2 moves, or 1, or none.
  - Never 2 attacks.
- "End turn" passes to the other side.
- With 3v3 later: each unit of the active side gets its own 2-card budget during the side's turn (order of units chosen by the player).

## Initiative
- The side with the **lower total build** takes the first turn.
- Tie: decided by the battle's seeded RNG (so replays are exact).
- With teams: compare the **sum** of the team's builds (or the average; decide when 3v3 arrives).

## Cooldowns
- Playing a card sets its cooldown to `card.cooldown`.
- At the start of the **owner's** turn, every cooldown goes down by 1.
- Cooldown 0 = usable every turn; cooldown 1 = skip one turn; and so on.
- **Open** for reactions: does the cooldown start when the card is played, or when it triggers? See [[Cards and Effects#Reactions]].

## Damage (starting point, tune later)
```
physical: max(1, card_power + phys_dmg - def)
special:  max(1, card_power + spc_dmg - res)
```
Each attack card says whether it's physical or special. All formulas live in `CombatRules` so tuning never touches the rest of the code.

## Events and triggers (needed for reactions)
`apply` doesn't change the state in one go. It pushes events through a small **event queue**:
1. An effect produces an event (e.g. "enemy moved to (2,3)").
2. The event is applied to the state and logged.
3. Every armed **reaction** and **passive** gets a chance to respond (see [[Cards and Effects]]). Their own effects produce new events, which go into the queue.
4. Repeat until the queue is empty.

Safety rules so chains stay sane:
- A given reaction triggers at most once per action.
- A maximum chain depth (e.g. 8) stops infinite loops.
- Queue order is fixed (first in, first out), so results are deterministic.

## Winning
All units of one side at 0 HP. (Later maybe: turn limit, objectives.)
