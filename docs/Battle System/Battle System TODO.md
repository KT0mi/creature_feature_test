---
tags: [battle-system, todo]
created: 2026-11-14
---
# Battle System TODO

Back to [[Battle System Overview]]. One branch per phase.

## Phase 1: Data
- [x] Add `@tool` to `core/battle/battle_card.gd` and `core/battle/part_stats.gd`
- [x] Make `BattleCard` fields `@export` (id, display_name, description, kind, cooldown, pattern, effects)
- [x] `BattleCard` virtual functions: `targets`, `play`, `is_reaction`, `reacts_to`, `react` ([[Cards and Effects]])
- [x] `CardEffect` base + Damage, Push, MoveSelf, Heal
- [x] Card library folder `res://creatures/cards/`; registry indexes cards by id, reports duplicates
- [x] Parts reference card `.tres` files (not embedded cards)
- [x] `CombatProfile.from_genome()`: stats (torso base + modifiers, pairs ×2), build, deck (pairs ×1) ([[Combat Profile]])
- [x] Creature lab: show stats, build and deck of the selected creatures

### Phase 1b: Statuses (done on `claude/battle-data-structures-status-feature`)
- [x] `StatusEffect`, `StatusInstance`, `ReactionStatus`, `ApplyStatusEffect`
- [x] Attributes on parts and in `CombatProfile`
- [x] New events (turn start/end, attacked, HP lost, status applied/expired) and context API
- [ ] Write the real Poisoned / Poisonous statuses as `.tres` + scripts

## Phase 2: Rules engine (headless)
- [x] `BattleState`, `BattleUnit`, `BattleAction`, `BattleEvent`, `CombatRules` ([[Rules Engine]])
- [x] Grid helpers + pattern rotation by facing ([[Grid and Facing]])
- [x] `legal_actions()` with the 2-card budget (max 1 attack, any order) and cooldowns
- [x] `apply()` with the event queue
- [x] Status engine: apply/stack/remove, offer every event to every status (reactions and attributes included), automatic ticks, chain-depth limit
- [x] Apply attributes at battle start
- [x] Initiative by build (seeded tie-break), cooldown countdown, win check
- [ ] First cards: a basic step, a dash, a basic melee attack, a line attack, a push, **Backstep** (script card)
- [x] Simple AI (random, then greedy) ([[AI and Balance Testing]])
- [x] Headless balance script: win rate vs part count / build / cards

## Phase 3: Playable 1v1
- [ ] `BattleScene`: board, y-sorted unit views, facing arrows ([[Battle View]])
- [ ] Select unit → card → target; end turn
- [ ] Event animations (move, turn, push, damage, reaction, death)
- [ ] Battle HUD: cards with cooldowns, stats, initiative
- [ ] Start a battle from the creature lab with two selected creatures

## Phase 4: Feel
- [ ] Action previews (apply on a copy, show results)
- [ ] Greedy AI with difficulty settings
- [ ] Card editor in Creature Tools (paint patterns, preview 4 facings)
- [ ] Part editor: show a part's stats and cards

## Phase 5: Toward the roguelike
- [ ] Owned creatures (genome + progression) and team of up to 3
- [ ] 3v3 turn handling (per-unit budget, unit order)
- [ ] Passives on parts (always-armed reactions)
- [ ] Terrain / objectives (optional)
