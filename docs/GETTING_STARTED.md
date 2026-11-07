# Creature parts: getting started

This explains how the skeleton in `core/` and `debug/` works and how to turn
your `.ase` creatures into parts it can use.

## What's here

| File | What it does |
|---|---|
| `core/part_socket.gd` | `PartSocket`: a connection point on a part (position per frame, accepted type, tags, z, chance, shade shift). |
| `core/part_def.gd` | `PartDef`: one part (id, type, tags, sheet, frame count, `attach` pixel, sockets, weight). One `.tres` per part. |
| `core/part_node.gd` | `PartNode`: a node in a creature's part tree. Saves and loads by **id only**. |
| `core/genome.gd` | `Genome`: the part tree, one palette id per color region, and the seed. This is what you save. |
| `core/creature_palette.gd` | `CreaturePalette`: primary, secondary and accent ramps (dark to light) plus the outline color. |
| `core/part_registry.gd` | Autoload `PartRegistry`: scans `creatures/parts/` and `creatures/palettes/` at startup. |
| `core/creature_baker.gd` | `CreatureBaker`: genome to spritesheet (collect, bounding box, recolor, blend, outline, cache). |
| `core/creature_generator.gd` | `CreatureGenerator`: `random_genome()`/`grow()`, `fuse_genomes()`/`fuse()`, `mutate()`. |
| `debug/creature_lab.tscn` | Grid of creatures. Set as the main scene, so press F5. |
| `creatures/parts/*/*_template/` | Rough parts cut from `creature_template_circle_biped.ase` so the lab has something to show. |
| `creatures/palette_key.tres` | The colors you **draw** with, and what each one means (see below). |
| `creatures/palettes/*.tres` | The colors creatures are **shown** with. |

## Lab controls

`R` / `Shift+R` change the seed. Left click selects a creature (up to 2).
`F` fuses the two selected: the first two cells show the parents and every
other cell shows a different child. `Esc` goes back. `P` prints the selected
genomes. Use the mouse wheel or `+`/`-` to zoom, and the arrow keys or WASD to move.

## How colors work (differs from the notes)

The notes proposed encoding tone in the R channel and region in the G channel.
That would force you to draw in strange marker colors. Instead:

- `creatures/palette_key.tres` lists the colors you actually paint with, as
  ramps per region. Right now: **primary = `#202020 #7b797b #acaaac #ffffff`**
  (your grayscale ramp). Secondary and accent are empty until you pick
  colors for them in `pallete_1`.
- When baking, a pixel in a key color becomes the color at the same region
  and tone in the creature's palette. **Any color that isn't in the key is
  "fixed"** and never recolored (eyes, teeth...).
- The genome picks a palette **per region**, so a fused creature can have
  A's body color and B's accent color.

**Problem in the template:** the teeth are `#ffffff`, which is also the 4th
tone of the primary ramp, so they get recolored (green teeth). Fix: draw the
teeth with a color that is *not* in the key (e.g. `#f4f4f4`), or remove
`#ffffff` from the key if it is only meant for teeth and eyes.

## Turning an `.ase` creature into parts

For each layer (torso, head, arm, leg...):

1. In LibreSprite, hide every other layer and **export the layer as a PNG,
   trimmed** (crop to its content). If the part is animated, export a
   horizontal spritesheet with all frames the same size.
2. Save it as `creatures/parts/<type>/<id>/<id>.png`, e.g.
   `creatures/parts/head/head_horned/head_horned.png`.
3. In Godot: right-click the folder, **Create New > Resource > PartDef**,
   and save as `<id>.tres` in the same folder. Fill in:
   - `id` (unique), `type`, `sheet` (the PNG), `frame_count`
   - `attach`: the pixel of this part that sits on the parent's socket,
     in the part's own (trimmed) coordinates. For a head that's usually the
     neck (bottom middle); for a limb, the shoulder or hip (top middle).
   - `sockets` (for parts that hold others): `name`, `accepts_type`,
     `positions` (one `Vector2i` per frame, or just one if the part doesn't
     move), `z_offset` (+1 in front, -1 behind), `shade_shift`, `chance`.

### Finding socket coordinates

Socket position (in the parent's trimmed coordinates) =
**where the child's attach pixel was in the full `.ase` canvas − where the
parent's trimmed image starts in the full canvas.**

Example from the template (full canvas 128x128):

- The torso layer starts at (47, 29). The head layer starts at (51, 10) and its
  attach (neck) is (12, 23), so the neck is at (51+12, 10+23) = (63, 33).
- The torso's `head` socket is (63−47, 33−29) = **(16, 4)**.

A marker layer in the `.ase` (one red pixel for each part's attach, one blue
pixel for each socket) makes these numbers easy to read off from LibreSprite's
cursor position. Later, an import plugin can read those markers for you.

## Template parts as set up

| Part | Size | attach | Sockets (position, z) |
|---|---|---|---|
| `torso_template` | 32x65 | (16,64) | head (16,4) +1 · arm_near (5,16) +1 · arm_far (29,16) −1 · leg_near (10,60) +1 · leg_far (23,60) −1 |
| `head_template` | 24x24 | (12,23) | none |
| `arm_template` | 14x41 | (7,2) | none |
| `leg_template` | 12x33 | (6,1) | none |

Both arms in the template were the same image, and so were both legs, so one
part each is enough. With `shade_shift = 0` it reassembles exactly like the
`.ase`. Set `arm_far`/`leg_far` to `shade_shift = -1` if you want the far
side darker.

## Things to decide or notice

- **Size cap**: `CreatureGenerator.MAX_SIZE` is 128x128. The template is
  38x111 px, so the 96x96 from the notes was too small.
- **View**: the template is front-facing, but the notes say side view. The
  system works the same for both. Pick one before drawing more.
- **Light direction**: your reference has light from the **top right**.
  Keep it the same on every part.
- **Outline**: 4-neighbour by default. Set `CreatureBaker.outline_diagonals = true`
  for the chunkier 8-neighbour version.
- **Next steps** (notes §12): add your other two creatures as parts. The lab
  only gets interesting with 2+ parts per type, since right now every
  creature has the same shape. Then add idle frames: a 2–4 frame torso strip
  with one socket position per frame makes everything attached to it bob along.
