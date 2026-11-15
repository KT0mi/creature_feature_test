---
tags: [battle-system, plan]
created: 2026-11-14
---
# Combat Profile

Back to [[Battle System Overview]]

A creature's battle numbers are **derived from its genome**, the same way its image (baker) and name (namer) are. Nothing battle-related is stored in the genome itself.

```gdscript
var profile := CombatProfile.from_genome(genome, PartRegistry)
profile.stats   # phys_dmg, spc_dmg, hp, def, res
profile.build   # int, higher = worse
profile.deck    # Array[BattleCard]
```

## Stats
- The **torso's** `PartStats` are the **base**.
- Every other part's `PartStats` are **modifiers** (small: +1 def, -1 phys_dmg…), added on top.
- Same `PartStats` class for both; its meaning depends on the part's role.
- Paired parts (sockets with `copy_from`) **count twice** (two arms = two arm modifiers).

## Build
- Sum of `build_weight` of **every** part, the torso included, pairs counted twice.
- Higher build = worse. For now its only effect: the side with the **lower build acts first** (see [[Rules Engine#Initiative]]).
- This is the main counter to "dump as many parts as possible": the socket count already caps parts per creature, and build makes every extra part cost something.

## Deck
- Union of the cards added by every part (`PartDef.added_cards`).
- Paired parts add their cards **once** (two claws don't give two "Slash").
- **Open:** what if two *different* parts add the same card? Options: one copy; two copies; a stronger version. See [[Battle Open Questions]].
- **Open:** a maximum deck size, or let build handle it.

## Why derived, not saved
- Fusion, fusion recipes, `fusion_only` parts and rare parts change combat automatically, because they already change the part tree.
- Rebalancing a part instantly updates every creature, with no save migration. (Keep a save version number to know which rules a creature was made under.)

## Player-owned creatures
A small saved record per creature: **genome + progression** (nickname, run data…). The profile is rebuilt from the genome on load. HP isn't stored because every battle starts at full HP.

## Data structure fixes needed first
- `BattleCard` fields (`id`, `name`, `cooldown`) are plain `var`s: they must be `@export` to be saved in `.tres` files and shown in the inspector.
- `battle_card.gd` and `part_stats.gd` need `@tool` like the rest of `core/`, so the editor tools (part editor, previews) can use them.
- Cards should be **their own `.tres` files** in a card library (e.g. `creatures/cards/`), referenced by parts. Cards embedded inside a part's `.tres` are copied per part and can't be shared.
