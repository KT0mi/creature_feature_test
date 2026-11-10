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

## Only parts whose PartDef.type equals this can be plugged in here.
@export var accepts_type: PackedStringArray

## Optional: how likely each accepted TYPE is, relative to the others,
## when this socket picks a new part. e.g. accepts_type = ["arm", "wing"]
## with type_weights = {arm: 1.0, wing: 0.1} gives a wing about 1 time in 11.
## A type that isn't listed here counts as 1.0. Leave it empty for "all
## types equally likely". The parts' own `weight` then picks WHICH part of
## the chosen type, so rarity per socket doesn't touch the part's weight.
## Only used when a part is newly picked (generation, mutation, filling an
## empty socket in fusion); parts inherited through fusion ignore it.
@export var type_weights: Dictionary[StringName, float] = {}

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

## Draw the part in this socket (and everything attached to it) mirrored.
@export var flip_h := false

@export_group("Conditionals")

## Makes this socket a COPY of an earlier socket on the same part, e.g.
## eye_far.copy_from = "eye_near". A copy socket never picks its own part:
##   * filled exactly when the source is filled, with an identical subtree
##     (so a pair of eyes is one decision and always matches);
##   * empty when the source is empty.
## Its `chance`, `requires` and `excludes` are ignored (the source decides).
## Combine with flip_h for the mirrored far side.
@export var copy_from: StringName = &""

## Only used with copy_from. Instead of an identical copy of the source,
## place the COUNTERPART of each part in the copied subtree (see
## PartDef.counterpart): the near ear in the source socket gives its far ear
## here. Parts without a counterpart are copied as they are.
@export var use_counterpart: bool = false

## Only rolled if ALL of these sockets (listed earlier on the same part) are
## already filled. e.g. eye_2.requires = ["eye_1"]: a second pair of eyes
## only appears on creatures that have the first pair.
@export var requires: PackedStringArray

## Never filled if ANY of these sockets (listed earlier on the same part) is
## filled. e.g. eye_cyclops.excludes = ["eye_1"]: a single central eye only
## on creatures without the normal pair.
@export var excludes: PackedStringArray


## Weight of an accepted type in this socket (1.0 if not listed).
func type_weight(type: StringName) -> float:
	return maxf(type_weights.get(type, 1.0), 0.0)


## True if `part` is allowed to be plugged into this socket.
func accepts(part: PartDef) -> bool:
	if part == null or not accepts_type.has(part.type):
		return false
	for t in required_tags:
		if not part.tags.has(t):
			return false
	for t in forbidden_tags:
		if part.tags.has(t):
			return false
	return true

## True if `requires` and `excludes` allow this socket, given which sockets
## of the same part are already filled (`filled`: socket name -> child).
func conditions_met(filled: Dictionary) -> bool:
	for socket_name in requires:
		if not filled.has(StringName(socket_name)):
			return false
	for socket_name in excludes:
		if filled.has(StringName(socket_name)):
			return false
	return true

## Socket position for the given parent frame (falls back to the last entry).
func position_at(frame: int) -> Vector2i:
	if positions.is_empty():
		return Vector2i.ZERO
	return positions[mini(frame, positions.size() - 1)]
