@tool
## Moves the card's user onto the target cell (used by movement cards).
class_name MoveSelfEffect
extends CardEffect

## Also turn the user to face the direction it moved (if it's straight).
@export var face_movement: bool = true


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	var start := user.position
	if ctx.move(user, target) and face_movement:
		var facing := Grid.facing_of(target - start)
		if facing != -1:
			ctx.turn(user, facing)


func describe() -> String:
	return "Move"
