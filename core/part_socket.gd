## A connection point on a PartDef where a child part can be attached.
##
## Example: a torso has a "head" socket that accepts parts of type "head",
## an arm has a "hand" socket that accepts parts of type "hand", and so on.
## Sockets are what make the creature a *tree* instead of a fixed slot list:
## claws only exist if the hand that was picked has a "claw" socket.
class_name PartSocket
extends Resource

## Name of the socket, unique inside its PartDef ("head", "arm_near", ...).
## Used as the key in PartNode.children.
@export var name: StringName

## Only parts whose PartDef.type equals this can be plugged in here.
@export var accepts_type: StringName

## The child part must have ALL of these tags (optional).
@export var required_tags: PackedStringArray

## The child part must have NONE of these tags (optional).
@export var forbidden_tags: PackedStringArray

## Where the child's `attach` pixel lands, in the PARENT part's local pixel
## coordinates (top-left of the parent's frame is 0,0).
## One entry per parent frame. If there are fewer entries than frames, the
## last entry is reused, so a static socket only needs a single position.
@export var positions: Array[Vector2i] = [Vector2i.ZERO]

## Draw order relative to the parent. Positive = in front of the parent,
## negative = behind it. Accumulates down the tree (child z = parent z + this).
@export var z_offset: int = 1

## Probability that random generation fills this socket. 1.0 = always.
@export_range(0.0, 1.0) var chance: float = 1.0

## Tone shift applied to the whole subtree plugged in here.
## -1 makes far-side limbs one tone darker. 0 = unchanged.
@export var shade_shift: int = 0


## True if `part` is allowed to be plugged into this socket.
func accepts(part: PartDef) -> bool:
	if part == null or part.type != accepts_type:
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
