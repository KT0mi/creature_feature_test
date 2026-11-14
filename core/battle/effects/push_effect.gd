@tool
## Pushes the unit on the target cell.
class_name PushEffect
extends CardEffect

enum Direction {
	AWAY_FROM_USER,  ## straight away from the user (only if in a straight line)
	USER_FACING,     ## the way the user is facing
}

@export var distance: int = 1
@export var direction: Direction = Direction.AWAY_FROM_USER


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	var victim := ctx.unit_at(target)
	if victim == null:
		return
	var dir := Grid.step(user.facing)
	if direction == Direction.AWAY_FROM_USER:
		var facing := Grid.facing_of(target - user.position)
		if facing == -1:
			return  # diagonal target: no straight "away"
		dir = Grid.step(facing)
	ctx.push(user, victim, dir, distance)


func describe() -> String:
	return "Push %d" % distance
