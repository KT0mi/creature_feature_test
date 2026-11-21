@tool
## Gives grit (re-rolls for missed attacks) to the user or to the unit on
## the target cell. Capped at CombatRules.MAX_GRIT.
class_name GainGritEffect
extends CardEffect

@export var amount: int = 1
## True: the card's user gets it. False: the unit on the target cell.
@export var to_self: bool = true


func acts_on_user() -> bool:
	return to_self


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	var who := user if to_self else ctx.unit_at(target)
	if who != null:
		ctx.gain_grit(who, amount)


func describe() -> String:
	return "%s %d grit" % ["Gain" if to_self else "Give", amount]
