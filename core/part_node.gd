@tool
## One node of a creature's part tree: "this PartDef, with these children".
##
## The whole tree (starting at the torso) is the shape half of a creature's
## genome. Children are keyed by the name of the parent's socket they sit in.
class_name PartNode
extends RefCounted

## The part drawn at this node.
var part: PartDef

## socket name (StringName) -> PartNode plugged into that socket.
var children: Dictionary = {}


func _init(p_part: PartDef = null) -> void:
	part = p_part


## Deep copy. Used by fusion so two creatures never share (and accidentally
## mutate) the same nodes.
func duplicate_tree() -> PartNode:
	var copy := PartNode.new(part)
	for socket_name in children:
		copy.children[socket_name] = children[socket_name].duplicate_tree()
	return copy


## Number of nodes in this subtree (handy for debugging / limits).
func count() -> int:
	var n := 1
	for child in children.values():
		n += child.count()
	return n


## Deterministic text form, e.g. "torso_a(head:head_b,arm_near:arm_c(hand:hand_d))".
## Children are listed in the parent's socket order so the same tree always
## produces the same string. Used as a cache key and for printing.
func to_key() -> String:
	var parts: PackedStringArray = []
	for socket in part.sockets:
		if children.has(socket.name):
			parts.append("%s:%s" % [socket.name, children[socket.name].to_key()])
	if parts.is_empty():
		return String(part.id)
	return "%s(%s)" % [part.id, ",".join(parts)]


## Save format: only IDs, so it survives renaming/moving files.
## { "id": "torso_a", "children": { "head": {...}, ... } }
func to_dict() -> Dictionary:
	var kids := {}
	for socket_name in children:
		kids[String(socket_name)] = children[socket_name].to_dict()
	return {"id": String(part.id), "children": kids}


## Rebuilds a tree saved with to_dict(). Parts or sockets that no longer
## exist are skipped with a warning instead of crashing.
static func from_dict(data: Dictionary, parts_by_id: Dictionary) -> PartNode:
	var def: PartDef = parts_by_id.get(StringName(data.get("id", "")))
	if def == null:
		push_warning("Unknown part id '%s', skipping subtree." % data.get("id"))
		return null
	var node := PartNode.new(def)
	var kids: Dictionary = data.get("children", {})
	for socket_name in kids:
		if def.get_socket(StringName(socket_name)) == null:
			push_warning("Part '%s' has no socket '%s' anymore." % [def.id, socket_name])
			continue
		var child := from_dict(kids[socket_name], parts_by_id)
		if child != null:
			node.children[StringName(socket_name)] = child
	return node
