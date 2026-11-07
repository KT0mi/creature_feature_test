## Definition of ONE drawable creature part (a torso, a head, an arm...).
##
## Lives as a .tres next to its .png in res://creatures/parts/<type>/<id>/.
## PartDefs are static data shared by every creature; the per-creature tree
## is built from PartNode objects that point at these.
class_name PartDef
extends Resource

## Stable, unique identifier. Genomes store THIS, never file paths or array
## indices, so files can be moved/renamed without breaking saved creatures.
@export var id: StringName

## What kind of part this is ("torso", "head", "arm", "hand", "claw"...).
## Sockets match on this.
@export var type: StringName

## Free-form tags ("clawed", "aquatic", "armored"...). Sockets can require or
## forbid tags.
@export var tags: PackedStringArray

## Horizontal strip of animation frames, all the same size, tightly cropped
## to this part's art. Must be imported Lossless with no mipmaps so the
## colors stay exact (the palette pass matches colors exactly).
@export var sheet: Texture2D

## Number of frames in `sheet`. The frame width is sheet width / frame_count.
@export_range(1, 64) var frame_count: int = 1

## The pixel of THIS part (in its own frame coordinates) that is placed on
## the parent's socket position. For the root part (torso) it is the point
## the whole creature is anchored by.
@export var attach: Vector2i

## Where children can be attached to this part.
@export var sockets: Array[PartSocket] = []

## Relative probability of being picked during random generation.
@export var weight: float = 1.0

## Pattern overlays for this part: pattern name (StringName) -> Texture2D.
## NOT saved in the .tres: PartRegistry fills it at startup from the PNGs in
## the "patterns" folder next to this part's .tres, e.g.
##   creatures/parts/arm/arm_template/patterns/stripes.png  -> &"stripes"
## A pattern sheet must be exactly the same size as `sheet` (same frames,
## 1:1 pixels), so it's drawn at the part's position with no extra data.
var patterns: Dictionary = {}

# Cache of the frames cut out of `sheet` (not saved, filled on demand).
var _frame_images: Array[Image] = []
# Same for patterns: pattern name -> Array[Image].
var _pattern_frames: Dictionary = {}


## Size of one frame in pixels. Doesn't need to load the image data.
func get_frame_size() -> Vector2i:
	if sheet == null:
		return Vector2i.ZERO
	return Vector2i(sheet.get_width() / frame_count, sheet.get_height())


## Returns frame `frame` as an RGBA8 Image (cached).
## `frame` wraps around, so a 1-frame part works in a 4-frame animation.
func get_frame_image(frame: int) -> Image:
	if _frame_images.is_empty():
		_cut_frames()
	if _frame_images.is_empty():
		return null
	return _frame_images[frame % _frame_images.size()]


## Frame `frame` of the pattern called `pattern_name`, or null if this part
## has no such pattern. Wraps around like get_frame_image().
func get_pattern_frame_image(pattern_name: StringName, frame: int) -> Image:
	if not patterns.has(pattern_name):
		return null
	if not _pattern_frames.has(pattern_name):
		_pattern_frames[pattern_name] = _cut(patterns[pattern_name])
	var frames: Array[Image] = _pattern_frames[pattern_name]
	if frames.is_empty():
		return null
	return frames[frame % frames.size()]


## Finds a socket by name, or null.
func get_socket(socket_name: StringName) -> PartSocket:
	for s in sockets:
		if s.name == socket_name:
			return s
	return null


func _cut_frames() -> void:
	if sheet == null:
		push_error("PartDef '%s' has no sheet texture." % id)
		return
	_frame_images = _cut(sheet)


## Splits a horizontal strip texture into `frame_count` RGBA8 images.
## Used for both the part sheet and its pattern sheets.
func _cut(tex: Texture2D) -> Array[Image]:
	var out: Array[Image] = []
	var full := tex.get_image()
	# Imported textures can come back compressed; we need raw RGBA pixels.
	if full.is_compressed():
		full.decompress()
	full.convert(Image.FORMAT_RGBA8)
	var size := Vector2i(full.get_width() / frame_count, full.get_height())
	for i in frame_count:
		out.append(full.get_region(Rect2i(i * size.x, 0, size.x, size.y)))
	return out
