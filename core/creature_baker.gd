## Turns a Genome into a pixel-perfect spritesheet texture.
##
## Pipeline (all integer math, no scaling/rotation):
##   1. collect()  walk the part tree -> flat list of placed parts per frame
##   2. measure()  bounding box over ALL frames (so every frame of the sheet
##                 shares the same canvas and the creature doesn't jitter)
##   3. for each frame: sort by z; for each part: recolor it with the body
##      palette, lay its patterns on top (each with its own palette), then
##      blend the result onto the canvas
##   4. outline pass on the finished frame (1px around the silhouette)
##   5. pack frames into one horizontal strip, cache by genome key
##
## The palette pass happens PER PART before blending (not on the finished
## image), because shade_shift is per subtree: a far-side arm must be darkened
## but the torso pixels next to it must not. Patterns are also merged per part,
## so an arm in front of the torso correctly covers the torso's stripes.
class_name CreatureBaker
extends RefCounted

## Result of a bake.
class Baked:
	## Horizontal strip with `frame_count` frames of `frame_size` each.
	var texture: ImageTexture
	var frame_count: int = 1
	var frame_size: Vector2i
	## Where the root part's attach pixel ended up inside each frame.
	## Use it to stand the creature on the ground: sprite.position = ground - origin.
	var origin: Vector2i

## Padding around the bounding box so the outline fits.
const OUTLINE_PAD := 1

## If true, the outline also fills diagonal corners (8-neighbour, chunkier).
## False = 4-neighbour (only up/down/left/right), usually cleaner in pixel art.
static var outline_diagonals := false

## genome key -> Baked. It's only a cache: clear it whenever you like.
static var _cache: Dictionary = {}


## One placed part in one frame. Plain data, produced by collect().
class Placed:
	var part: PartDef
	var frame: int        # local frame of this part
	var pos: Vector2i     # top-left of the part, in creature space
	var z: int            # accumulated z (parent z + socket z_offset)
	var shade: int        # accumulated shade_shift
	var order: int        # tree walk order, breaks ties between equal z
	var flip: bool

## Number of frames a creature animation has: the longest part animation.
## Shorter parts loop (frame % their frame_count).
static func frame_count_of(root: PartNode) -> int:
	var n := root.part.frame_count
	for child in root.children.values():
		n = maxi(n, frame_count_of(child))
	return n


## Walks the tree and appends a Placed for every part, for creature frame
## `frame`. `anchor` is where THIS node's attach pixel goes.
##   child anchor = parent anchor - parent attach + socket position
## i.e. the socket position is in the parent's own pixel coordinates.
## `flip` = this node is drawn mirrored.
static func collect(node: PartNode, anchor: Vector2i, z: int, shade: int,
		flip: bool, frame: int, out: Array[Placed]) -> void:
	var def := node.part
	var local_frame := frame % def.frame_count
	var width := def.get_frame_size().x
	var attach := def.attach
	if flip:
		attach.x = width - 1 - attach.x
	var top_left := anchor - attach

	var p := Placed.new()
	p.part = def
	p.frame = local_frame
	p.pos = top_left
	p.z = z
	p.shade = shade
	p.order = out.size()
	p.flip = flip
	out.append(p)

	# Iterate in socket order (not dictionary order) so the result is stable.
	for socket in def.sockets:
		if not node.children.has(socket.name):
			continue
		var socket_pos := socket.position_at(local_frame)
		if flip:
			socket_pos.x = width - 1 - socket_pos.x
		# `flip != socket.flip_h`: a flip inside a flip cancels out.
		collect(node.children[socket.name], top_left + socket_pos,
			z + socket.z_offset, shade + socket.shade_shift,
			flip != socket.flip_h, frame, out)



## Bounding box (creature space) of the creature over all its frames,
## without the outline padding. The root attach pixel is at (0,0).
## Cheap: uses only frame sizes, never touches pixels. The generator uses it
## to reject creatures that are too big.
static func measure(root: PartNode) -> Rect2i:
	var box := Rect2i()
	var first := true
	for f in frame_count_of(root):
		var placed: Array[Placed] = []
		collect(root, Vector2i.ZERO, 0, 0, false, f, placed)
		for p in placed:
			var r := Rect2i(p.pos, p.part.get_frame_size())
			box = r if first else box.merge(r)
			first = false
	return box


## Bakes (or returns the cached bake of) a genome.
## `palettes`: id -> CreaturePalette, `key`: the palette the art is drawn with.
static func bake(genome: Genome, palettes: Dictionary, key: CreaturePalette) -> Baked:
	var cache_key := genome.to_key()
	if _cache.has(cache_key):
		return _cache[cache_key]

	var root := genome.root
	var frames := frame_count_of(root)
	var box := measure(root)
	var frame_size := box.size + Vector2i.ONE * OUTLINE_PAD * 2
	# Shift that moves creature space into canvas space (box corner -> pad).
	var offset := -box.position + Vector2i.ONE * OUTLINE_PAD

	var lookup := _build_key_lookup(key)
	var body: CreaturePalette = palettes.get(genome.palette)
	if body == null:
		push_warning("Genome palette '%s' not found; colors left as drawn." % genome.palette)
	var outline_color: Color = body.outline() if body else Color.BLACK
	# Resolve each pattern's palette once (null = draw the pattern unchanged).
	var pattern_palettes: Array[CreaturePalette] = []
	for gene in genome.patterns:
		pattern_palettes.append(palettes.get(gene.palette))

	var sheet := Image.create_empty(frame_size.x * frames, frame_size.y, false, Image.FORMAT_RGBA8)
	for f in frames:
		var canvas := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
		var placed: Array[Placed] = []
		collect(root, Vector2i.ZERO, 0, 0, false, f, placed)
		# Godot's sort isn't stable, so ties on z are broken by walk order.
		placed.sort_custom(func(a: Placed, b: Placed) -> bool:
			return a.z < b.z or (a.z == b.z and a.order < b.order))
		for p in placed:
			var img := _recolor(p.part.get_frame_image(p.frame), lookup, body, p.shade)
			for i in genome.patterns.size():
				var pattern := p.part.get_pattern_frame_image(genome.patterns[i].name, p.frame)
				if pattern != null:
					_overlay_pattern(img,
						_recolor(pattern, lookup, pattern_palettes[i], p.shade))
			# Mirror AFTER the patterns are laid on, so part and pattern
			# (drawn 1:1 in the same orientation) flip together.
			if p.flip:
				img.flip_x()
			canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), p.pos + offset)
		_add_outline(canvas, outline_color)
		sheet.blit_rect(canvas, Rect2i(Vector2i.ZERO, frame_size), Vector2i(f * frame_size.x, 0))

	var result := Baked.new()
	result.texture = ImageTexture.create_from_image(sheet)
	result.frame_count = frames
	result.frame_size = frame_size
	result.origin = offset
	_cache[cache_key] = result
	return result


static func clear_cache() -> void:
	_cache.clear()


## Maps every key color (as RGBA32 int) to its tone index (0..3).
static func _build_key_lookup(key: CreaturePalette) -> Dictionary:
	var lookup := {}
	if key == null:
		return lookup
	for tone in key.ramp.size():
		lookup[key.ramp[tone].to_rgba32()] = tone
	return lookup


## Returns a recolored copy of `src`.
## Key-colored pixels -> palette.tone(key tone + shade).
## Every other opaque pixel is an "organic" (teeth, eyes...) and is copied
## unchanged. With a null palette the image is returned as drawn.
static func _recolor(src: Image, lookup: Dictionary, palette: CreaturePalette,
		shade: int) -> Image:
	var img := src.duplicate() as Image
	if palette == null:
		return img
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var tone = lookup.get(c.to_rgba32())
			if tone == null:
				continue  # organic color, never recolored
			img.set_pixel(x, y, palette.tone(tone + shade))
	return img


## Copies the opaque pixels of `pattern` onto `part`, but ONLY where the part
## itself is opaque. Patterns are the same size as their part, so this is a
## pixel-for-pixel overlay, and a stray pattern pixel can never stick out of
## the part's silhouette. Organic pixels of the part (teeth, eyes) are covered
## too if the pattern paints over them, so leave those areas empty when
## drawing patterns.
static func _overlay_pattern(part: Image, pattern: Image) -> void:
	for y in mini(part.get_height(), pattern.get_height()):
		for x in mini(part.get_width(), pattern.get_width()):
			if part.get_pixel(x, y).a8 == 0:
				continue
			var c := pattern.get_pixel(x, y)
			if c.a8 != 0:
				part.set_pixel(x, y, c)


## Paints `color` on every transparent pixel that touches an opaque one.
## Reads from a copy so freshly painted outline pixels don't spread further.
static func _add_outline(canvas: Image, color: Color) -> void:
	var src := canvas.duplicate() as Image
	var w := src.get_width()
	var h := src.get_height()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if outline_diagonals:
		dirs.append_array([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a8 != 0:
				continue
			for d in dirs:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and src.get_pixelv(n).a8 != 0:
					canvas.set_pixel(x, y, color)
					break
