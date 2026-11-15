@tool
## Heals the user, or the unit on the target cell.
class_name HealEffect
extends CardEffect

@export var amount: int = 1
## True: heal the card's user. False: heal the unit on the target cell.
@export var heal_self: bool = true


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	var who := user if heal_self else ctx.unit_at(target)
	if who != null:
		ctx.heal(who, amount)


func describe() -> String:
	return "Heal %d" % amount
