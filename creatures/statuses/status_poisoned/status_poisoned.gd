@tool
class_name StatusEffectPoisoned
extends StatusEffect

func reacts_to(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> bool:
	return _event.type == BattleEvent.Type.TURN_ENDED and _event.unit == _owner

#Lose 20% of Enemy's Special Damage of your health
func react(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> void:
	_ctx.lose_hp(_owner, _instance.source.effective_stat("spc_damage"))
	_instance.count -= 1
