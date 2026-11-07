## One allowed combination of sockets on a part, e.g. "two eyes".
##
## Some sockets shouldn't be rolled independently. With three eye sockets in
## a triangle (eye_near, eye_far, eye_third) independent chances could give
## "third eye + near eye", which looks wrong. Instead, the part lists the
## combinations that ARE allowed, and generation picks one of them:
##
##   group "eyes": [eye_near]                      weight 1
##                 [eye_near, eye_far]             weight 6
##                 [eye_near, eye_far, eye_third]  weight 1
##                 [eye_third]                     weight 0.5
##
## Rules:
##   * Every socket named in any layout of a group is controlled by that
##     group: exactly the sockets of the picked layout are filled, and their
##     own `chance` is ignored. Sockets not named in any layout (arms,
##     legs...) keep using `chance` as before.
##   * A layout with no sockets is allowed: it means "none" (no eyes).
##   * A part can have several groups ("eyes", "horns"...); one layout is
##     picked per group, independently.
##   * A socket must not appear in two different groups.
class_name SocketLayout
extends Resource

## Which group this layout belongs to. Layouts with the same group on the
## same part compete with each other.
@export var group: StringName = &"eyes"

## Names of the sockets that get filled when this layout is picked.
@export var sockets: PackedStringArray

## Relative probability of this layout within its group.
@export var weight: float = 1.0


## True if this layout fills exactly the sockets in `filled` (order ignored).
func matches(filled: PackedStringArray) -> bool:
	if filled.size() != sockets.size():
		return false
	for s in filled:
		if not sockets.has(s):
			return false
	return true
