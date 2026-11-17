@tool
class_name StatusEffectBleeding
extends StatusEffect

func reacts_to(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> bool:
	return _event.type == BattleEvent.Type.TURN_ENDED and _event.unit == _owner

func react(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> void:
	_ctx.lose_hp(_owner, _instance.count)
	_instance.count -= 1
