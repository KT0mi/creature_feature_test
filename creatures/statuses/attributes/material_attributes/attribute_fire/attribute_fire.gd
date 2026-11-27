@tool
class_name StatusEffectFire
extends StatusEffect

const burning = preload("res://creatures/statuses/status_burning/status_burning.tres")

func reacts_to(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> bool:
	return _event.type == BattleEvent.Type.ATTACKED and _event.source == _owner
	
func react(_ctx: BattleContext, _owner: BattleUnit, _instance: StatusInstance,
		_event: BattleEvent) -> void:
	_ctx.apply_status(_owner, _event.unit, burning, 1)
