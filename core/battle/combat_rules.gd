@tool
##The numbers and formulas of combat. static
class_name CombatRules
extends RefCounted

const MAX_CARDS_PER_TURN := 2
const MAX_ATTACKS_PER_TURN := 1

const MAX_CHAIN_DEPTH := 8

const MAX_ROUNDS := 50

const TURN_TO_ATTACK := true

## How turns are given out (a battle keeps the system it was created with):
##   ALTERNATING   teams take turns; the side with the lower build starts.
##   ACTIVE_TIME   (prototype) each UNIT has its own schedule: after acting
##                 it waits turn_delay() ticks, so a lighter creature (lower
##                 build) acts more often, and a large build difference can
##                 give it two turns in a row.
enum TurnSystem { ALTERNATING, ACTIVE_TIME }

## Turn system for NEW battles. A static var (not a const) so the balance
## script can switch it to compare both.
static var turn_system: TurnSystem = TurnSystem.ALTERNATING

## ACTIVE_TIME delay: atb_base_delay + build * atb_build_factor ticks.
## e.g. 50 + build: build 10 -> 60 ticks, build 40 -> 90 ticks, so the
## lighter creature takes 3 turns for every 2 of the heavier one.
## Static vars so the balance script can tune them (--atb-base, --atb-factor).
static var atb_base_delay: int = 50
static var atb_build_factor: float = 1.0


## Ticks a unit waits between two of its turns (ACTIVE_TIME). At least 1.
static func turn_delay(unit: BattleUnit) -> int:
	return maxi(1, roundi(atb_base_delay + unit.profile.build * atb_build_factor))

## Damage taken by a pushed unit that hits the board edge or another unit
## (the other unit takes it too). Not an attack: ignores def/res.
## A quarter of the pusher's physical damage, rounded up; 0 if nothing
## pushed it (a trap...).
static func collision_damage(source: BattleUnit) -> int:
	if source == null:
		return 0
	return ceili(source.effective_stat(&"phys_dmg") * 0.25)


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
