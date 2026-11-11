@tool
##Definition of 1 drawable part of a creature (head, torso, arm, etc.)
##lives in res://creatures/parts/<type>/<id>
class_name PartDef
extends Resource

##Unique id
@export var id: StringName

##What kind of part this is (e.g. head, torso, arm, etc.)
@export var type: StringName

##Tags used by sockets to whitelist or blacklist certain parts
@export var tags: PackedStringArray

## Horizontal strip of animation frames, all the same size, tightly cropped
## to this part's art. Must be imported Lossless with no mipmaps so the
## colors stay exact (the palette pass matches colors exactly).
@export var sheet: Texture2D

## Number of frames in `sheet`. The frame width is sheet width / frame_count.
@export_range(1, 64) var frame_count: int = 1

##The pixel coordinate of this part that attaches to the socket
@export var attach: Vector2i

##Where children parts may be attached to this part.
@export var sockets: Array[PartSocket] = []

## Id of the OTHER version of this same part, for parts drawn differently
## on the near and far side (e.g. ear_catfolk_near <-> ear_catfolk_far).
## A socket with copy_from + use_counterpart places this part instead of an
## identical copy, so the pair always matches but each side has its own art.
## Leave empty for parts that are the same on both sides (or just flipped).
@export var counterpart: StringName = &""


## If true, this part is never picked by random generation, mutation or
## fusion fill-ins: it can only appear through a FusionRecipe.
@export var fusion_only: bool = false

## Relative probability of being picked during random generation.
@export var weight: float = 1.0

## Pattern overlays for this part: pattern name (StringName) -> Texture2D.
## NOT saved in the .tres: PartRegistry fills it at startup from the PNGs in
## the "patterns" folder next to this part's .tres, e.g.
##   creatures/parts/arm/arm_template/patterns/stripes.png  -> &"stripes"
## A pattern sheet must be exactly the same size as `sheet` (same frames,
## 1:1 pixels), so it's drawn at the part's position with no extra data.
var patterns: Dictionary = {}

@export_group("Naming")
## Radical used at the FRONT of the main name when this part is the head,
## e.g. "Cat" (head) + "wurm" (torso) = "Catwurm".
@export var name_front: String = ""
## Radical used at the BACK of the main name when this part is the torso.
@export var name_back: String = ""
## Whole main name for a torso with no head (e.g. "Pyramite"). Optional.
@export var name_full: String = ""
## Optional adjective this part adds to the name pool, e.g. "Winged".
@export var name_adjective: String = ""
## Where the adjective goes in the name (English order).
@export var name_adjective_category: CreatureNamer.Category = CreatureNamer.Category.FEATURE
## How likely the adjective is to be picked, relative to other candidates.
@export var name_adjective_weight: float = 1.0
@export_group("")

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
