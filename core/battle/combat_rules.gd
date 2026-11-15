@tool
## The numbers and formulas of combat, in one place so tuning never touches
## the rest of the code. Everything is static.
class_name CombatRules
extends RefCounted

## Per turn, each unit plays at most this many cards...
const MAX_CARDS_PER_TURN := 2
## ...of which at most this many attacks.
const MAX_ATTACKS_PER_TURN := 1
## Damage taken by a pushed unit that hits the board edge or another unit
## (the other unit takes it too). Not an attack: ignores def/res.
const COLLISION_DAMAGE := 1
## A reaction triggered by a reaction triggered by... stops here.
const MAX_CHAIN_DEPTH := 8
## Battles longer than this many rounds end in a draw (headless safety).
const MAX_ROUNDS := 50
## Does playing an attack turn the user towards a straight-line target?
## (Open design question; flip to test.)
const TURN_TO_ATTACK := true


## Damage of an attack after stats. Always at least 1.
static func attack_damage(power: int, type: DamageEffect.Type, attacker: BattleUnit,
		defender: BattleUnit) -> int:
	if type == DamageEffect.Type.SPECIAL:
		return maxi(1, power + attacker.effective_stat(&"spc_dmg") - defender.effective_stat(&"res"))
	return maxi(1, power + attacker.effective_stat(&"phys_dmg") - defender.effective_stat(&"def"))


## Which team acts first: the LOWER total build (of living units). A tie is
## broken with the battle's seeded RNG, so replays stay exact.
static func first_team(units: Array[BattleUnit], rng: RandomNumberGenerator) -> int:
	var build := [0, 0]
	for u in units:
		if u.is_alive():
			build[u.team] += u.profile.build
	if build[0] == build[1]:
		return rng.randi_range(0, 1)
	return 0 if build[0] < build[1] else 1
