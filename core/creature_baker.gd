## Turns a Genome into a pixel-perfect spritesheet texture.
##
## Pipeline (all integer math, no scaling/rotation):
##   1. collect()  walk the part tree -> flat list of placed parts per frame
##   2. measure()  bounding box over ALL frames (so every frame of the sheet
##                 shares the same canvas and the creature doesn't jitter)
##   3. for each frame: sort by z, recolor each part, blend it onto the canvas
##   4. outline pass on the finished frame (1px around the silhouette)
##   5. pack frames into one horizontal strip, cache by genome key
##
## The palette pass happens PER PART before blending (not on the finished
## image), because shade_shift is per subtree: a far-side arm must be darkened
## but the torso pixels next to it must not.
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
static func collect(node: PartNode, anchor: Vector2i, z: int, shade: int,
		frame: int, out: Array[Placed]) -> void:
	var def := node.part
	var local_frame := frame % def.frame_count
	var top_left := anchor - def.attach

	var p := Placed.new()
	p.part = def
	p.frame = local_frame
	p.pos = top_left
	p.z = z
	p.shade = shade
	p.order = out.size()
	out.append(p)

	# Iterate in socket order (not dictionary order) so the result is stable.
	for socket in def.sockets:
		if not node.children.has(socket.name):
			continue
		collect(node.children[socket.name], top_left + socket.position_at(local_frame),
			z + socket.z_offset, shade + socket.shade_shift, frame, out)


## Bounding box (creature space) of the creature over all its frames,
## without the outline padding. The root attach pixel is at (0,0).
## Cheap: uses only frame sizes, never touches pixels. The generator uses it
## to reject creatures that are too big.
static func measure(root: PartNode) -> Rect2i:
	var box := Rect2i()
	var first := true
	for f in frame_count_of(root):
		var placed: Array[Placed] = []
		collect(root, Vector2i.ZERO, 0, 0, f, placed)
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
	# Number of tones per region in the key, used to rescale tone indices.
	var key_lens := PackedInt32Array()
	for region in 3:
		key_lens.append(key.get_ramp(region).size() if key else 0)
	var ramps := _genome_ramps(genome, palettes)
	var outline_color := _outline_color(genome, palettes)

	var sheet := Image.create_empty(frame_size.x * frames, frame_size.y, false, Image.FORMAT_RGBA8)
	for f in frames:
		var canvas := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
		var placed: Array[Placed] = []
		collect(root, Vector2i.ZERO, 0, 0, f, placed)
		# Godot's sort isn't stable, so ties on z are broken by walk order.
		placed.sort_custom(func(a: Placed, b: Placed) -> bool:
			return a.z < b.z or (a.z == b.z and a.order < b.order))
		for p in placed:
			var img := _recolor(p.part.get_frame_image(p.frame), lookup, key_lens, ramps, p.shade)
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


## Maps every key color (as RGBA32 int) to [region, tone].
static func _build_key_lookup(key: CreaturePalette) -> Dictionary:
	var lookup := {}
	if key == null:
		return lookup
	for region in 3:
		var ramp := key.get_ramp(region)
		for tone in ramp.size():
			lookup[ramp[tone].to_rgba32()] = Vector2i(region, tone)
	return lookup


## The three ramps this genome uses, one per region.
static func _genome_ramps(genome: Genome, palettes: Dictionary) -> Array[PackedColorArray]:
	var out: Array[PackedColorArray] = []
	for region in 3:
		var pal: CreaturePalette = palettes.get(genome.region_palettes[region])
		out.append(pal.get_ramp(region) if pal else PackedColorArray())
	return out


static func _outline_color(genome: Genome, palettes: Dictionary) -> Color:
	var pal: CreaturePalette = palettes.get(genome.region_palettes[CreaturePalette.Region.PRIMARY])
	return pal.outline if pal else Color.BLACK


## Returns a recolored copy of `src`.
## Key-colored pixels -> genome ramp color (tone + shade, clamped to the ramp).
## Other opaque pixels (fixed colors) are copied unchanged.
## If a region's ramp is empty in the genome, its pixels are left unchanged.
static func _recolor(src: Image, lookup: Dictionary, key_lens: PackedInt32Array,
		ramps: Array[PackedColorArray], shade: int) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var hit = lookup.get(c.to_rgba32())
			if hit == null:
				continue  # fixed color (eyes, teeth...)
			var ramp: PackedColorArray = ramps[hit.x]
			if ramp.is_empty():
				continue
			# Map the key tone to the genome ramp. If the ramps have different
			# lengths, scale the index so dark stays dark and light stays light.
			var key_len: int = key_lens[hit.x]
			var tone: int = hit.y
			if key_len > 1 and ramp.size() != key_len:
				tone = roundi(float(tone) * (ramp.size() - 1) / (key_len - 1))
			tone = clampi(tone + shade, 0, ramp.size() - 1)
			img.set_pixel(x, y, ramp[tone])
	return img


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
