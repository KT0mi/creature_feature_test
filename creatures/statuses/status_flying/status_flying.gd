@tool
class_name StatusEffectFlying
extends StatusEffect

func reacts_to(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> bool:
	return (_event.type == BattleEvent.Type.DAMAGED and _event.unit == _owner) or \
			(_event.type)

func react(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> void: pass
