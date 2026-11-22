---
tags: [battle-system]
created: 2026-11-21
status: implemented (grit as advantage: branch claude/grit-advantage)
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

## Grit (advantage)
- 0–3 per creature (`CombatRules.MAX_GRIT`), starts at 0.
- **Use before an attack** (`BattleAction.use_grit`): 1 grit is spent **up front, whatever happens**: a gamble. Every victim of that attack is rolled **twice** and the **better** result counts: crit > hit > miss. So a hit on the first roll and a crit on the second = a crit. One grit covers the whole attack (all victims of an area attack). Not spent if the attack has no victims. Events `GRIT_USED`, `GRIT_CHANGED`.
- Odds with advantage (per victim), from one roll's miss *m* and crit *c* (= (1 − m) × crit chance):
  - miss = m², crit = 1 − (1 − c)², hit = the rest.
  - e.g. 50% miss / 20% crit chance → 25% miss, 19% crit (measured over 1000 rolls: 25% / 19%).
- **Olive branch:** every final miss gives the attacker +1 grit (also after a grit roll that still missed).
- **Cards:** `GainGritEffect` (amount, to self or to the target).
- **Battle scene:** the toggle "Grit on next attack (n/max)" (off by default) applies to the next attack, then switches itself off; the hint shows the odds with grit when it's on.
- **AI:** tries every attack with and without grit, and values each banked grit at `BattleAI.GRIT_VALUE` (2 HP), so it spends grit only when the expected gain is bigger (e.g. at high miss chances).

## AI
The AI simulates options on clones; a clone has the same RNG position, so real rolls would let it foresee them. Simulations run in **EXPECTED** luck mode: no rolls, every attack hits, damage × expected value `hit + crit × mult` (with the advantage odds if grit is used; the grit is spent in the simulation too).

## Battle scene
- Hovering a target shows **Hit % / Crit % (×mult)** in the hint.
- Floating "Miss", "−N CRIT!", "Grit! (advantage)", "±1 grit"; grit in the unit info and on the toggle.

## First results (500 battles, seed 1)
| | Higher build wins | Lower build wins, diff 21–40 | diff 41+ |
|---|---|---|---|
| Luck off (`--luck off`) | 71% | 8% | 9% |
| Luck on | 64% | 23% | 45% (22 battles) |

Misses ≈ 10% and crits ≈ 11% of attacks.

## Attribute recipes
Attributes from conditions on the whole creature, checked when the `CombatProfile` is built: `AttributeRecipe` resources in `res://creatures/recipes/attribute_recipes/`.
- Conditions: no part of type X, has a part of type X, at least / at most N parts of type X (both halves of pairs count), has / lacks a tag, has a part id. Scripts can override `matches(genome)`.
- Example: **Blind** = a permanent StatusEffect (miss +0.2, crit damage +0.5) + a recipe "no part of type `eye`".