---
tags: [visuals, shaders]
created: 2026-11-22
status: implemented (branch claude/shaders-and-materials)
---
# Scrolling Background

A scrolling checkerboard behind the creature lab and the battle scene.

## Where
- Shader: `res://shaders/scrolling_checker.gdshader`
- Node: `ScrollingBackground` (`res://core/view/scrolling_background.gd`), a full-screen `ColorRect` in a `CanvasLayer` with layer −10 (so cameras don't move it and it's behind everything).
- Already in `debug/creature_lab.tscn` and `scenes/battle_scene.tscn` as **Background / ScrollingBackground**: select it to change it in the inspector.

## Settings
| Setting | Meaning |
|---|---|
| `square_size` | size of a square, in screen pixels |
| `scroll_speed` | pixels per second (0 = still) |
| `scroll_angle` | direction in degrees: 0 right, 90 down, 45 down-right… |
| `color_a`, `color_b` | the two square colors |

## Pixel-perfect
- The shader works on whole pixels of the game's base resolution (before the integer upscale).
- The scroll position is kept as a float, but only its whole-pixel part goes to the shader: the pattern moves one pixel at a time on the pixel grid, even at slow or diagonal speeds.
