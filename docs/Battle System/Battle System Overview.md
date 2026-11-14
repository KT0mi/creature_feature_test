---
tags: [battle-system, plan, moc]
created: 2026-11-14
status: planning
---
# Battle System Overview

Hub note for the battle system. Nothing here is implemented yet; this is the agreed plan.

## Goal
A fast, small-scale, grid-based, turn-based battle (a bit like *Into the Breach*, but quicker), inside a **roguelike mode** where the player develops a team of mutants.

- Grid: **5×5** (for now).
- Teams: up to **3v3** eventually, **1v1 first**. 1v1 must already feel fast and fun.
- **Straight alternating turns** (no enemy intents/telegraphing).
- Every battle starts at **full HP**.
- Creatures fight with **stats** and **cards**, both coming from their **parts**.

## Decisions so far

| Topic | Decision |
|---|---|
| Team size | 1v1 now, up to 3v3 later |
| Turn style | Straight alternating; some cards are **reactions** |
| Facing | 4 directions (left, right, up, down); patterns rotate in 90° steps |
| Cards per turn | Up to 2: move + attack, or move + move, or fewer. **Any order** |
| Paired parts | Count **twice** for stats/build, **once** for cards |
| Deck size / duplicate cards from different parts | **Open**, decide after tests |
| HP between battles | Full HP at the start of every battle |
| Statuses | Applied by cards, react to events; attributes = permanent statuses from parts |
| Visible reactions | Opponent sees that a reaction is ready (not which), per card |
| Anti "part dump" | **Build**: sum of every part's build weight. Higher build loses first-turn advantage |

## Architecture in one picture
```
Genome ──► CombatProfile (stats, build, deck)        [derived, never saved]
                │
                ▼
BattleState + Rules engine (pure GDScript, seeded)   [model: no nodes]
                │  BattleEvents (moved, pushed, damaged, reacted, died…)
                ▼
BattleScene (grid view, unit sprites, HUD, input)    [view: Godot scenes]
```
The **model** never waits for the **view**: it applies an action and returns a list of events; the view animates them. That makes headless balance simulations, previews, AI and replays possible.

## Notes
- [[Combat Profile]]: how stats, build and deck come from the genome
- [[Rules Engine]]: state, turn structure, initiative, cooldowns, damage, events
- [[Grid and Facing]]: the 5×5 board, 4-way facing, pattern rotation
- [[Cards and Effects]]: card data, effects, script cards, **reactions**, passives
- [[Statuses and Attributes]]: Poisoned-like statuses, permanent attributes, armed reactions as statuses
- [[Battle View]]: scenes, sprites on the board, HUD, animations
- [[AI and Balance Testing]]: enemy AI, headless auto-battles
- [[Integration with Creature Systems]]: how it plugs into parts, fusion, baker, tools
- [[Battle Open Questions]]
- [[Battle System TODO]]
