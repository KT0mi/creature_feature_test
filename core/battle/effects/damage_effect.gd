@tool
## Damages the unit on the target cell (nothing happens on an empty cell).
class_name DamageEffect
extends CardEffect

## Physical uses the user's phys_dmg against the target's def;
## special uses spc_dmg against res.
enum Type { PHYSICAL, SPECIAL }

@export var power: int = 1
@export var type: Type = Type.PHYSICAL


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	var victim := ctx.unit_at(target)
	if victim != null:
		ctx.damage(user, victim, power, type)


func describe() -> String:
	return "Deal %d %s" % [power, "physical" if type == Type.PHYSICAL else "special"]
