@tool
## Applies a status to the unit on the target cell, to the user, or to the
## target CELL itself (a trap).
## e.g. Venom Scratch = [DamageEffect 2, ApplyStatusEffect Poisoned 2].
class_name ApplyStatusEffect
extends CardEffect

enum Target {
	TARGET_UNIT,  ## the unit on the target cell (nothing if it's empty)
	SELF,         ## the card's user
	CELL,         ## the target cell itself (traps, burning ground...)
}

@export var status: StatusEffect
## The count to apply ("2" in Poisoned 2).
@export var amount: int = 1
## Who/what gets it. (Replaces the old `to_self` checkbox: true = SELF.)
@export var target_mode: Target = Target.TARGET_UNIT


func apply(ctx: BattleContext, user: BattleUnit, target: Vector2i) -> void:
	if status == null:
		return
	match target_mode:
		Target.CELL:
			ctx.apply_cell_status(user, target, status, amount)
		Target.SELF:
			ctx.apply_status(user, user, status, amount)
		_:
			var who := ctx.unit_at(target)
			if who != null:
				ctx.apply_status(user, who, status, amount)


func describe() -> String:
	if status == null:
		return ""
	var n := status.name if status.name != "" else String(status.id)
	var count := "" if status.permanent else " %d" % amount
	match target_mode:
		Target.CELL:
			return "Place %s%s" % [n, count]
		Target.SELF:
			return "Gain %s%s" % [n, count]
	return "Apply %s%s" % [n, count]
