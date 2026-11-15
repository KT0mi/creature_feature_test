@tool
##The numbers and formulas of combat. static
class_name CombatRules
extends RefCounted

const MAX_CARDS_PER_TURN := 2
const MAX_ATTACKS_PER_TURN := 1

const MAX_CHAIN_DEPTH := 8

const MAX_ROUNDS := 50

const TURN_TO_ATTACK := true

#Damage calculation
static func attack_damage(power: int, type: DamageEffect.Type,
		attacker: BattleUnit, defender: BattleUnit) -> int:
	if type == DamageEffect.Type.SPECIAL:
		return maxi(1, power + attacker.effective_stat(&"spc_dmg") - defender.effective_stat(&"res"))
	return maxi(1, power + attacker.effective_stat(&"phys_dmg") - defender.effective_stat(&"def"))

##Which team acts first: the lower total build.
##A tie is broken with battle seeded RNG, so replays stay exact.
static func first_team(units: Array[BattleUnit], rng: RandomNumberGenerator) -> int:
	var build := [0, 0]
	for u in units:
		if u.is_alive():
			build[u.team] += u.profile.build
	if build[0] == build[1]:
		return rng.randi_range(0,1)
	return 0 if build[0] < build[1] else 1
