@tool
## Gives a creature an ATTRIBUTE (a permanent StatusEffect) when a condition
## on its parts holds, checked when its CombatProfile is built.
## e.g. Blind: "no part of type eye" -> attribute blind.tres
##
## Lives as a .tres anywhere under res://creatures/attribute_recipes/.
## For conditions the fields can't express, make a script that
## `extends AttributeRecipe` and overrides matches().
class_name AttributeRecipe
extends Resource

enum Condition {
	NO_PART_OF_TYPE,   ## no part whose type is `value` (e.g. no eye -> Blind)
	HAS_PART_OF_TYPE,  ## at least one part of type `value`
	AT_LEAST,          ## `count` or more parts of type `value`
	AT_MOST,           ## `count` or fewer parts of type `value`
	HAS_TAG,           ## some part has the tag `value`
	NO_TAG,            ## no part has the tag `value`
	HAS_PART,          ## the part with id `value` is there
}

## The attribute to add (should be permanent).
@export var attribute: StatusEffect
@export var condition: Condition = Condition.NO_PART_OF_TYPE
## A part type, a tag or a part id, depending on the condition.
@export var value: StringName
## For AT_LEAST / AT_MOST.
@export var count: int = 1


## True if `genome` gets the attribute. Counts every part on the creature,
## both halves of pairs included (two eyes = 2), since this is about what
## the creature has, not about cards.
func matches(genome: Genome) -> bool:
	var parts := _all_parts(genome.root)
	var of_type := parts.filter(func(p: PartDef) -> bool: return p.type == value).size()
	match condition:
		Condition.NO_PART_OF_TYPE:
			return of_type == 0
		Condition.HAS_PART_OF_TYPE:
			return of_type > 0
		Condition.AT_LEAST:
			return of_type >= count
		Condition.AT_MOST:
			return of_type <= count
		Condition.HAS_TAG:
			return parts.any(func(p: PartDef) -> bool: return p.tags.has(value))
		Condition.NO_TAG:
			return not parts.any(func(p: PartDef) -> bool: return p.tags.has(value))
		Condition.HAS_PART:
			return parts.any(func(p: PartDef) -> bool: return p.id == value)
	return false


## Every PartDef in the tree (one entry per node).
static func _all_parts(node: PartNode) -> Array[PartDef]:
	var out: Array[PartDef] = [node.part]
	for child in node.children.values():
		out.append_array(_all_parts(child))
	return out
