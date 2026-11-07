## A connection point on a PartDef where a child part can be attached.
##
## Example: a torso has a "head" socket that accepts parts of type "head",
## an arm has a "hand" socket that accepts parts of type "hand", and so on.
## Sockets are what make the creature a *tree*
class_name PartSocket
extends Resource

## Name of the socket, unique inside its PartDef ("head", "arm_near", ...).
## Used as the key in PartNode.children.
@export var name: StringName

## Only parts whose PartDef.type is one of these can be plugged in here
## (e.g. ["eye"], or ["eye", "gem"] for a socket that takes either).
@export var accepts_type: PackedStringArray

## The child part must have ALL of these tags (optional).
@export var required_tags: PackedStringArray

## The child part must have NONE of these tags (optional).
@export var forbidden_tags: PackedStringArray

## Where the child's `attach` pixel lands, in the PARENT part's local pixel
## coordinates (top-left of the parent's frame is 0,0).
## One entry per parent frame. If there are fewer entries than frames, the
## last entry is reused, so a static socket only needs a single position.
@export var positions: Array[Vector2i] = [Vector2i.ZERO]

## Probability that random generation fills this socket. 1.0 = always.
@export_range(0.0, 1.0) var chance: float = 1.0

## Draw order relative to the parent. Positive = in front of the parent,
## negative = behind it. Accumulates down the tree (child z = parent z + this).
@export var z_offset: int = 1

## Tone shift applied to the whole subtree plugged in here.
## -1 makes far-side limbs one tone darker. 0 = unchanged.
@export var shade_shift: int = 0

## Draw the part in this socket (and everything attached to it) mirrored
## left-right. Pixel-perfect: it only reverses pixel columns. The part's
## attach pixel and its own socket positions are mirrored too, so the child
## still lands on `positions`. Flips accumulate: a flipped socket inside a
## flipped subtree draws unflipped.
## Typical use: the far eye in a 3/4 view, as a mirror of the near eye.
@export var flip_h: bool = false

## If set, this socket does not pick its own part: it gets a copy of
## whatever subtree is in the socket with this name (on the same part),
## e.g. eye_far.copy_from = "eye_near" so both eyes are always the same eye.
## The source socket must come BEFORE this one in the `sockets` list.
## If the source is empty, this socket is filled normally instead.
@export var copy_from: StringName = &""

## True if `part` is allowed to be plugged into this socket.
func accepts(part: PartDef) -> bool:
	# The part's type must be ANY of the accepted types. (has() compares the
	# StringName type with the Strings in the array by value.)
	if part == null or not accepts_type.has(part.type):
		return false
	for t in required_tags:
		if not part.tags.has(t):
			return false
	for t in forbidden_tags:
		if part.tags.has(t):
			return false
	return true


## Socket position for the given parent frame (falls back to the last entry).
func position_at(frame: int) -> Vector2i:
	if positions.is_empty():
		return Vector2i.ZERO
	return positions[mini(frame, positions.size() - 1)]
