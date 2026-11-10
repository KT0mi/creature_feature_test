## An authored fusion result: when parts `part_a` and `part_b` meet in the
## same socket during a fusion (one from each parent), the child gets
## `result` there with probability `chance`.
## e.g. arm_catfolk + arm_ratfolk -> arm_ratfolk_spiny, chance 0.15.
##
## Lives as a .tres anywhere under res://creatures/recipes/.
## Order doesn't matter: a + b is the same recipe as b + a.
## The result's children are fused from both parents' parts, as usual.
## Tip: mark the result PartDef as fusion_only so it can ONLY come from here.
class_name FusionRecipe
extends Resource

## Part id from one parent.
@export var part_a: StringName
## Part id from the other parent (can be the same as part_a).
@export var part_b: StringName
## Part id the child gets. Must be accepted by the socket it lands in
## (normally the same type as part_a / part_b).
@export var result: StringName
## Probability that the recipe happens when the two parts meet. If it
## doesn't, the fusion continues normally (50% mix / 50% take one side).
@export_range(0.0, 1.0) var chance: float = 1.0
