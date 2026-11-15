@tool
## Applies a status to the unit on the target cell (or to the user).
## e.g. Venom Scratch = [DamageEffect 2, ApplyStatusEffect Poisoned 2].
class_name ApplyStatusEffect
extends CardEffect

@export var status: StatusEffect
## The count to apply ("2" in Poisoned 2).
@export var amount: int = 1
## True: the user gets it. False: the unit on the target cell does.
@export var to_self: bool = false


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	if status == null:
		return
	var who := user if to_self else ctx.unit_at(target)
	if who != null:
		ctx.apply_status(user, who, status, amount)


func describe() -> String:
	if status == null:
		return ""
	var n := status.name if status.name != "" else String(status.id)
	return "%s %s%s" % ["Gain" if to_self else "Apply", n, "" if status.permanent else " %d" % amount]
