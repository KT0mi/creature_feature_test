
---
tags: [battle-system, pending, prototype]
created: 2026-11-17
status: headless prototype (branch claude/atb-prototype), not used by the battle scene
---
# Active Time Turns

Back to [[Battle System Overview]]. Context: making **build** matter more than "who goes first".

## Idea
Instead of teams alternating, every **unit** has its own schedule. After acting it waits
`delay = atb_base_delay + build × atb_build_factor` ticks; the unit due earliest acts next (ties: lower build, then a seeded tie-breaker). Lighter creatures act more often; a big build gap can give two turns in a row.

## Prototype (what exists)
- `CombatRules.turn_system`: **ALTERNATING** (default, unchanged) or **ACTIVE_TIME**. Each battle keeps the system it was created with (`BattleState.turn_system`).
- `CombatRules.atb_base_delay`, `atb_build_factor`, `turn_delay(unit)`.
- `BattleState`: `active_unit`, `clock`, `next_turn_at`, `tiebreak`, `turns_taken`; cloned with the state.
- `BattleRules`: only the active unit has legal actions; `end_turn()` ends that unit's turn and starts the next; `turn_order(n)` predicts the next n turns (for a future turn bar).
- Cooldowns and status ticks count the unit's **own** turns. A "round" = as many turns as there are units (draw limit, HUD).
- The AI needed no change.
- Balance script: `--turns alternating|atb`, `--atb-base N`, `--atb-factor F`; reports the lower-build side's share of turns, double turns per battle, and lower-build win rate by build difference.

```
godot --headless --path . --script res://debug/balance_sim.gd -- --battles 500 --seed 1 --turns atb --atb-base 20
```
Only the **ratio** base : factor matters (20 + 2×build behaves exactly like 10 + build).

## First results (500 battles, seed 1, current parts)
| System | Turns to lower build | Double turns / battle | Higher build wins | Lower build wins at diff 11–20 |
|---|---|---|---|---|
| Alternating | 52% | 0 | 69% | 11% |
| ATB 50 + build | 52% | 0.01 | 69% | 11% |
| ATB 20 + build | 54% | 0.17 | 68% | 13% |
| ATB 10 + build | 55% | 0.34 | 67% | 15% |

**Reading:** battles last under 4 rounds, so even a steep delay gives the lighter creature at most one extra turn, and heavy creatures' stats (more HP and damage from more parts) still dominate. ATB alone doesn't fix "higher build wins"; it needs either longer battles, smaller stat gains per part, or other build costs (see below).

## Not done yet
- Battle scene: turn-order bar, per-unit turns in the HUD (the scene still assumes team turns; 1v1 works).
- Cooldowns measured in clock ticks instead of own turns (option to test).
- Slow / Haste / Stun as statuses changing `next_turn_at`.
- Action-based delay (ending a turn early = acting sooner).

## Other build levers discussed
- Team build cap (roguelike point-buy).
- Push resistance and collision weight by build (benefits of being heavy).
- Movement limits (no JUMP, −1 range) above a build threshold; cooldown tax.