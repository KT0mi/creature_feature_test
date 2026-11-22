---
tags: [visuals, shaders, creatures]
created: 2026-11-22
status: implemented (branch claude/shaders-and-materials)
---
# Materials

What a creature is **made of**. A rare, strong override of its look (and optionally its battle traits), meant for roguelike upgrades.

## How it works
- `Genome.material`: a material id, or empty for none. Saved with the genome (`to_dict`).
- With a material:
  - the material's **palette** recolors every part (the genome's palette and **patterns** are ignored);
  - the outline can be **forced** to a color (`override_outline`, `outline_color`);
  - the sprite gets the material's **shader** (`shader`, `shader_parameters`);
  - the material's **attribute** is added to the creature's `CombatProfile`;
  - the name uses the material's word as its color ("Golden Catfolk").
- Fusion: if a parent has a material, the child takes one parent's material at random (so about half the children of a Gold × plain fusion are Gold). Ordinary fusions are unchanged.
- Random generation never gives a material.
- Creature lab: **M** cycles the selected creatures through the materials (preview only).

## Files
- `CreatureMaterial` resource: `res://core/creature_material.gd`; materials live in `res://creatures/materials/`.
- Shaders: `res://shaders/material_gold.gdshader`, `res://shaders/material_void.gdshader`.
- New on statuses: `stat_overrides` (stat name → value, wins over everything), used by Slime.

## The three materials
| Material | Palette | Outline | Shader | Attribute |
|---|---|---|---|---|
| **Gold** | `palette_golden` | palette | glint band sweeping diagonally + sparkle pixels | (none yet) |
| **Slime** | `palette_slime` (translucent) | palette | (none) | **Slime**: def set to 999, res set to 0 |
| **Void** | near-black (embedded in the material, so random creatures can't roll it) | forced **white** | starfield: stars drift and twinkle inside the dark body | (none yet) |

## Shader settings (in `shader_parameters`, or the shader's defaults)
- **Gold**: `glint_color`, `glint_strength`, `glint_width` (px), `slope` (1 = 45°), `sweep_time`, `pause_time` (s), `sparkle_density`, `sparkle_rate`, `fps`, `min_luma` (darker pixels, e.g. the outline, untouched).
- **Void**: `star_color`, `dim_star_color`, `star_density`, `drift` (px/s), `twinkle_rate`, `fps`, `space_luma` (only darker pixels show stars, so the white outline stays clean).
- Both get `frame_size` from the game, so effects stay inside each animation frame.

## Pixel-perfect
Effects are computed on whole texture pixels and time advances in fixed steps (`fps`), so glints and stars move one pixel at a time. Both shaders start from the sprite's color including modulate, so damage flashes and fades still work.

## Ideas
- Gold attribute (e.g. +crit damage, or grit on kills), Void attribute (e.g. miss chance against it).
- More materials: Glass (translucent + refraction-like pixel shifts), Stone, Fire.
