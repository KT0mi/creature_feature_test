@tool
## Moves the card's user onto the target cell (used by movement cards).
class_name MoveSelfEffect
extends CardEffect

## How it gets there (see Grid.MoveMode):
##   WALK      step by step along a shortest path; steps can trigger traps
##             and reactions, which may stop it on the way
##   DASH      the same, but only in a straight line
##   JUMP      lands on the target without touching the cells in between
##   TELEPORT  just appears there (no steps at all)
## It also decides which cells a movement card can target: a path must
## exist (see BattleCard.targets).
@export var mode: Grid.MoveMode = Grid.MoveMode.WALK

## Turn the user to face the direction of its last step.
@export var face_movement: bool = true


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	ctx.move(user, target, mode, face_movement)


func describe() -> String:
	return ["Walk", "Dash", "Jump", "Teleport"][mode]
