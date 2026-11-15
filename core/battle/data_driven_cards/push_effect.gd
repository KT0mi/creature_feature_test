@tool
## Pushes the unit on the target cell.
class_name PushEffect
extends CardEffect

enum Direction {
	AWAY_FROM_USER,    ## straight away from the user (only if in a straight line)
	USER_FACING,       ## the way the user is facing
	AWAY_FROM_CENTER,  ## straight away from the card's target cell, for area
					   ## attacks (a blast pushes outwards). The unit ON the
					   ## target is pushed away from the user instead.
}

@export var distance: int = 1
@export var direction: Direction = Direction.AWAY_FROM_USER


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	var victim := ctx.unit_at(target)
	if victim == null:
		return
	var dir := Grid.step(user.facing)
	match direction:
		Direction.AWAY_FROM_USER:
			if not _straight_away(target - user.position):
				return  # diagonal: no straight "away"
			dir = Grid.step(Grid.facing_of(target - user.position))
		Direction.AWAY_FROM_CENTER:
			var from_center := target - ctx.action_target
			if from_center == Vector2i.ZERO:
				from_center = target - user.position  # the center cell itself
			if not _straight_away(from_center):
				return
			dir = Grid.step(Grid.facing_of(from_center))
	ctx.push(user, victim, dir, distance)

## True if `offset` points in one of the 4 straight directions.
func _straight_away(offset: Vector2i) -> bool:
	return Grid.facing_of(offset) != -1

func describe() -> String:
	return "Push %d" % distance
