# Creature parts: getting started

This explains how the skeleton in `core/` and `debug/` works and how to turn
your `.ase` creatures into parts it can use.

## What's here

| File | What it does |
|---|---|
| `core/part_socket.gd` | `PartSocket`: a connection point on a part (position per frame, accepted type, tags, z, chance, shade shift). |
| `core/part_def.gd` | `PartDef`: one part (id, type, tags, sheet, frame count, `attach` pixel, sockets, weight). One `.tres` per part. |
| `core/part_node.gd` | `PartNode`: a node in a creature's part tree. Saves and loads by **id only**. |
| `core/genome.gd` | `Genome`: the part tree, the body palette id, up to 2 patterns (name + palette), and the seed. This is what you save. |
| `core/creature_palette.gd` | `CreaturePalette`: one 4-tone ramp, darkest to lightest. Index 0 is also the outline color. |
| `core/part_registry.gd` | Autoload `PartRegistry`: scans `creatures/parts/` and `creatures/palettes/` at startup. |
| `core/creature_baker.gd` | `CreatureBaker`: genome to spritesheet (collect, bounding box, recolor, blend, outline, cache). |
| `core/creature_generator.gd` | `CreatureGenerator`: `random_genome()`/`grow()`, `fuse_genomes()`/`fuse()`, `mutate()`. |
| `debug/creature_lab.tscn` | Grid of creatures. Set as the main scene, so press F5. |
| `creatures/parts/*/*_template/` | Rough parts cut from `creature_template_circle_biped.ase` so the lab has something to show. Each has placeholder `patterns/stripes.png` and `patterns/spots.png` (the head has no spots, on purpose). |
| `creatures/palette_key.tres` | The colors you **draw** with, and what each one means (see below). |
| `creatures/palettes/*.tres` | The colors creatures are **shown** with. |

## Lab controls

`R` / `Shift+R` change the seed. Left click selects a creature (up to 2).
`F` fuses the two selected: the first two cells show the parents and every
other cell shows a different child. `Esc` goes back. `P` prints the selected
genomes. Use the mouse wheel or `+`/`-` to zoom, and the arrow keys or WASD to move.

## How colors work

Every palette is **4 tones, darkest to lightest**:

| Index | Key color (what you draw with) | Meaning |
|---|---|---|
| 0 | `#000000` | Outline and hard shadow. The generated outline uses this tone. |
| 1 | `#202020` | Shadow |
| 2 | `#7b797b` | Base |
| 3 | `#acaaac` | Light |

- `creatures/palette_key.tres` holds these 4 key colors. When baking, every
  key-colored pixel of every part becomes the same index in the creature's
  **body palette**. All parts use that one palette.
- **Any color that isn't in the key is an "organic"** (teeth, white of the
  eyes, highlights) and is never changed. Your `#ffffff` teeth are organics
  now, so they stay white.
- A palette with anything other than 4 colors is rejected at startup with an error.

## Patterns

A pattern is an overlay drawn on top of a part, with its **own palette**.

- File layout: `creatures/parts/<type>/<id>/patterns/<pattern_name>.png`, e.g.
  `creatures/parts/arm/arm_template/patterns/stripes.png`. No `.tres` is
  needed: the registry finds the PNGs, and **the file name is the pattern name**.
- The PNG must be **the same size as the part's sheet** (same frames, 1:1),
  so it's drawn at the part's position. Wrong sizes are rejected with an error.
- Draw it with the same 4 key colors. They become the tones of the pattern's
  palette, so a stripe can keep the part's shading (dark on the shadow side).
  Organic colors in a pattern are kept as they are.
- Pattern pixels only show where the part itself is opaque, so they never
  stick out of the silhouette. Leave the teeth/eye areas empty in patterns,
  or the pattern will cover them.
- The genome holds up to 2 patterns, each `(name, palette)`. Every part that
  has a PNG with that name draws it, and parts without one skip it. Patterns
  are merged into each part before the parts are stacked, so an arm in front
  covers the torso's stripes. The far-side `shade_shift` darkens the pattern too.
- Generation: 50% chance of a first pattern, then 30% of a second
  (`CreatureGenerator.PATTERN_CHANCES`). A pattern's palette is never the
  body palette, since that would make it invisible.
- Fusion: the child's body palette comes from one parent. It gets as many
  patterns as one of the parents had, picked from both parents' patterns.
  Sometimes it gains, loses or repaints one (`MUTATION_PATTERN`).

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
- **Palettes are shared**: any palette can be a body palette or a pattern
  palette. If you later want some only for patterns, add a flag to `CreaturePalette`.
- **Outline**: 4-neighbour by default. Set `CreatureBaker.outline_diagonals = true`
  for the chunkier 8-neighbour version.
- **Next steps** (notes §12): add your other two creatures as parts. The lab
  only gets interesting with 2+ parts per type, since right now every
  creature has the same shape. Then add idle frames: a 2–4 frame torso strip
  with one socket position per frame makes everything attached to it bob along.
