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

### Phase 2b: Depth-first events and movement (branch `claude/rules-engine-depth-refactor`)
- [x] Events resolve immediately (depth-first), `max_triggers_per_action`
- [x] `MOVE_STARTED` / `STEPPED` / `MOVED`, interruption, `stop_move`
- [x] Move modes WALK / DASH / JUMP / TELEPORT with deterministic shortest paths
- [x] Pushes step cell by cell (forced steps)
- [x] Statuses on cells (traps), reveal and ticks
- [ ] Set **Cat Jump**'s move mode to JUMP
- [ ] Write a real trap card + status
- [ ] AI: score the board after `end_turn()` too (it can't see end-of-turn damage yet)

### Phase 2c: Area attacks (branch `claude/aoe-cards`)
- [x] `aim` (CELL / SELF), `area`, `hits_self`, `hits_allies`
- [x] One ATTACKED per victim, effect-by-effect resolution, farthest-first order
- [x] PushEffect AWAY_FROM_CENTER
- [ ] Make a Tail Swipe card for a tail part

## Phase 3: Playable 1v1
- [x] `BattleScene`: board, y-sorted unit views, facing arrows ([[Battle View]])
- [x] Select unit → card → target; end turn
- [x] Event animations (move, turn, push, damage, reaction, death)
- [x] Battle HUD: cards with cooldowns, stats, initiative
- [x] Start a battle from the creature lab with two selected creatures

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
