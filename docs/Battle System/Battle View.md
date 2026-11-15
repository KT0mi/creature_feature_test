---
tags: [battle-system, plan]
created: 2026-11-14
---
# Battle View

Back to [[Battle System Overview]]

The view **shows** the battle and turns clicks into `BattleAction`s. It never changes the battle state itself; it only calls the [[Rules Engine]] and animates the events it gets back.

## Scene layout
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
