---
tags: [battle-system]
created: 2026-11-21
status: implemented (branch claude/luck-and-grit)
---
# Luck and Grit

Back to [[Battle System Overview]]. Why: see [[Luck as Gameplay and Balancing Method]] (David and Goliath).

## Rolls
Every attack rolls **per victim**, after the `ATTACKED` reactions:
1. **Miss?** A missed victim is untouched by **every** effect of the card (no damage, push, status). Event `MISSED`.
2. If it hits: **crit?** The attack's damage × the attacker's crit multiplier (1.5 by default). `DAMAGED` with `critical = true`.

Build tilts the odds towards the lighter creature (`CombatRules`, tunable):
| | Formula | Cap |
|---|---|---|
| Miss | 5% + 1% per build point the attacker is **heavier** than the victim | 50% |
| Crit | 5% + 1% per build point the attacker is **lighter** than the victim | 50% |
| Crit damage | 1.5× | min 1× |

Statuses (and attributes) change them with the **Luck** fields on `StatusEffect`: `miss_chance`, `crit_chance`, `crit_damage` (added; e.g. Blind: miss +0.2, crit damage +0.5).

All rolls use the battle's seeded RNG, so replays stay exact.

## Grit
- 0–2 per creature (`CombatRules.MAX_GRIT`), starts at 0.
- **Re-roll:** if an attack misses and the action uses grit, 1 grit is spent to roll that miss again, while grit lasts (`REROLLED`, `GRIT_CHANGED`). Decided **before** the roll: the battle scene's toggle "Use grit on a miss" (on by default); the AI always allows it. Grit is only spent on a miss.
- **Olive branch:** every final miss gives the attacker +1 grit.
- **Cards:** `GainGritEffect` (amount, to self or to the target).

## AI
The AI simulates options on clones; a clone has the same RNG position, so real rolls would let it foresee them. Simulations run in **EXPECTED** luck mode: no rolls, every attack hits, damage × expected value `(1 − miss) × (1 + crit × (mult − 1))`.

## Battle scene
- Hovering a target shows **Hit % / Crit % (×mult)** in the hint.
- Floating "Miss", "−N CRIT!", "Re-roll!", "±1 grit"; grit in the unit info and on the toggle.

## First results (500 battles, seed 1)
| | Higher build wins | Lower build wins, diff 21–40 | diff 41+ |
|---|---|---|---|
| Luck off (`--luck off`) | 71% | 8% | 9% |
| Luck on | 64% | 23% | 45% (22 battles) |

Misses ≈ 10% and crits ≈ 11% of attacks.

## Attribute recipes
Attributes from conditions on the whole creature, checked when the `CombatProfile` is built: `AttributeRecipe` resources in `res://creatures/attribute_recipes/`.
- Conditions: no part of type X, has a part of type X, at least / at most N parts of type X (both halves of pairs count), has / lacks a tag, has a part id. Scripts can override `matches(genome)`.
- Example: **Blind** = a permanent StatusEffect (miss +0.2, crit damage +0.5) + a recipe "no part of type `eye`".
