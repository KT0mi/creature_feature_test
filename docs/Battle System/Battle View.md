---
tags: [battle-system, plan]
created: 2026-11-14
---
# Battle View

Back to [[Battle System Overview]]

The view **shows** the battle and turns clicks into `BattleAction`s. It never changes the battle state itself; it only calls the [[Rules Engine]] and animates the events it gets back.

## Status
First playable version on branch `claude/battle-scene` (`res://battle/`). Open it from the creature lab (select 2 creatures, press **V**) or run `battle_scene.tscn` directly (F6) for a random match-up.

## Board: isometric
- 5×5 isometric board, like Into the Breach but flatter: one cell fits in a **166 × 83** rectangle (`BoardView.cell_size`, easy to change).
- Grid +x goes down-right on screen, +y goes down-left; cell (0,0) is the top corner.
- `BoardView.tile_texture`: put the tile art there (cell_size big, diamond centered). Without it, placeholder diamonds are drawn in code.
- **Pixel note:** with an odd height (83) half a cell is 41.5 px, so rows alternate 41/42 px (positions are floored). An even height (e.g. 166 × 84) avoids a possible 1 px unevenness in tile art.

## Facing on screen
Only left/right exist for sprites: grid RIGHT and UP look right on screen, DOWN and LEFT look left (`UnitView.ART_FACES_LEFT` if the art faces left). A small arrow on the ground shows the exact direction, in team color.

## Scene layout (as built)
```
BattleScene (Node2D, battle_scene.gd)   controller: input, AI turns, event playback
├── BoardView                            board, highlights, mouse → cell
├── Units (y-sorted)                     UnitView × n: sprite, HP bar, arrow, "!", selection
├── FX                                   floating texts
└── CanvasLayer / BattleHUD              turn + build, unit info, log, cards, End turn, result
```

## Controls
Click your creature → click a card (or 1–9) → click a highlighted cell. Hovering a target shows the walk **path** or the attack **area**. Aim-SELF cards (Tail Swipe): press the card again, or click any cell of the area. Right click / Esc: cancel. Space: end turn.

## Event playback
The rules apply an action instantly and return its events; the scene replays them in order (steps walked cell by cell, pushes faster, damage flash + numbers, statuses, reactions "!", deaths). Views follow the events, then snap to the real state. Hidden enemy statuses (e.g. traps) are not shown or logged.

## Original plan: scene layout
```
BattleScene (Node2D)
├── Board          the 5×5 grid, tile highlights
├── Units (y-sorted)
│   └── UnitView × n   baked creature sprite + facing arrow + HP bar
├── HUD (CanvasLayer)  cards of the selected unit, stats, build/initiative, end turn
└── BattleController   input + calls into the rules engine + plays events
```

## Board and sprites
- Creature sprites are side view, 30–128 px tall, and **never scaled** (pixel-perfect).
- Proposal: a top-down 5×5 board seen at a slight angle; rows further down the screen are closer to the camera and drawn on top (Godot **y-sort**).
- At the 960×540 viewport, tiles of about 64–80 px wide fit. Large creatures overlap the row behind them; y-sort keeps that correct.
- **Open:** does a creature's size matter in combat, or is it purely visual?

## Unit view
- `Sprite2D` with the creature's baked spritesheet (`CreatureBaker.bake`), playing its idle frames.
- `Baked.origin` is the creature's "feet" pixel: `sprite.position = tile_center - origin`.
- Facing:
  - left / right: `flip_h` on the sprite (pixel-perfect);
  - up / down: the sprite keeps its last left/right look, plus a **facing arrow** under the unit (shown for all 4 directions for clarity).
- Small HP bar, armed-reaction icon.

## Input flow
1. Click one of your units → its cards appear in the HUD (greyed out if on cooldown or not allowed by the 2-card budget).
2. Click a card → the board highlights its valid targets (`card.targets(...)`).
3. Hover a target → **preview**: the action is applied to a *copy* of the state, and the result is shown (damage numbers, where pushes end, reactions that would fire).
4. Click → the action is applied for real; its events are animated.
5. "End turn".

## Animations from events
Each `BattleEvent` type has a small animation: move (tween on whole pixels), turn (flip + arrow), push, collision shake, damage (flash + number), reaction (icon pop), death. They're played in the order the rules produced them. While they play, input is blocked.
