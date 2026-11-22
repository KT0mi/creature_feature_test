@tool
class_name StatusEffectFlying
extends StatusEffect

func reacts_to(_ctx: BattleContext, owner: BattleUnit, _instance: StatusInstance,
		event: BattleEvent) -> bool:
	return (event.type == BattleEvent.Type.DAMAGED and event.unit == owner) \
		or (event.type == BattleEvent.Type.ATTACKED and event.unit == owner)

func react(ctx: BattleContext, owner: BattleUnit, instance: StatusInstance,
		event: BattleEvent) -> void:
	if event.type == BattleEvent.Type.DAMAGED:
		ctx.lose_hp(owner, CombatRules.collision_damage(owner))
		ctx.remove_status(owner, instance)
	else:
		ctx.remove_status(owner, instance)
