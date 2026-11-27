@tool
## Flying: attacks on the owner miss more often (incoming_miss_chance in
## the .tres). If the owner is DAMAGED while flying, it's knocked down:
## it takes collision damage (from its own build) and loses Flying.
##
## Only DAMAGED grounds it, not ATTACKED: ATTACKED is sent BEFORE the
## attack's miss roll, so losing Flying there would remove the dodge right
## before it could count. A missed attack doesn't touch it.
class_name StatusEffectFlying
extends StatusEffect

func reacts_to(_ctx: BattleContext, owner: BattleUnit, _instance: StatusInstance,
		event: BattleEvent) -> bool:
	return event.type == BattleEvent.Type.DAMAGED and event.unit == owner

func react(ctx: BattleContext, owner: BattleUnit, instance: StatusInstance,
		_event: BattleEvent) -> void:
	# The fall: lose_hp sends HP_LOST, not DAMAGED, so it doesn't trigger
	# this status again or "when attacked" reactions.
	ctx.lose_hp(owner, CombatRules.collision_damage(owner))
	ctx.remove_status(owner, instance)
