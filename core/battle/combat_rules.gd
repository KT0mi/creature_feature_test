@tool
##The numbers and formulas of combat. static
class_name CombatRules
extends RefCounted

const MAX_CARDS_PER_TURN := 2
const MAX_ATTACKS_PER_TURN := 1

const MAX_CHAIN_DEPTH := 8

const MAX_ROUNDS := 50

const TURN_TO_ATTACK := true

## TURNS (active time): each UNIT has its own schedule. After acting it
## waits turn_delay() ticks, so a lighter creature (lower build) acts more
## often, and a large build difference can give it two turns in a row.
## Ties: lower build first, then a seeded tie-breaker.
##
## Delay: atb_base_delay + build * atb_build_factor ticks.
## e.g. 50 + build: build 10 -> 60 ticks, build 40 -> 90 ticks, so the
## lighter creature takes 3 turns for every 2 of the heavier one.
## Static vars so the balance script can tune them (--atb-base, --atb-factor).
static var atb_base_delay: int = 50
static var atb_build_factor: float = 1.0


## LUCK: every attack rolls, per victim, whether it MISSES (no effect on
## that victim at all) and, if it hits, whether it CRITS (damage x the
## attacker's crit multiplier). Build tilts the odds towards the underdog:
##   miss% = base_miss + miss_per_build x (attacker build - victim build, if > 0)
##   crit% = base_crit + crit_per_build x (victim build - attacker build, if > 0)
## plus the attacker's status modifiers (StatusEffect luck fields), clamped
## to 0..max. Static vars so the balance script can tune them.
static var base_miss_chance: float = 0.05
static var miss_per_build: float = 0.01
static var max_miss_chance: float = 0.5
static var base_crit_chance: float = 0.05
static var crit_per_build: float = 0.01
static var max_crit_chance: float = 0.5
## Crit damage multiplier before status modifiers.
static var base_crit_damage: float = 1.5

## GRIT: a resource spent BEFORE an attack for ADVANTAGE: each victim is
## rolled twice and the better result counts (crit > hit > miss). It's
## spent whatever the result: a gamble. A creature gains 1 grit whenever
## one of its attacks misses (an olive branch), and cards can give grit.
## Never more than MAX_GRIT.
const MAX_GRIT := 3
const START_GRIT := 0


## Chance (0..1) that `attacker`'s attack misses `victim`.
static func miss_chance(attacker: BattleUnit, victim: BattleUnit) -> float:
	var gap := maxi(0, attacker.profile.build - victim.profile.build)
	return clampf(base_miss_chance + miss_per_build * gap 
		+ attacker.luck_modifier(&"miss_chance")
		+ victim.luck_modifier(&"incoming_miss_chance"),
		0.0, max_miss_chance)


## Chance (0..1) that a HIT from `attacker` on `victim` is critical.
static func crit_chance(attacker: BattleUnit, victim: BattleUnit) -> float:
	var gap := maxi(0, victim.profile.build - attacker.profile.build)
	return clampf(base_crit_chance + crit_per_build * gap 
		+ attacker.luck_modifier(&"crit_chance")
		+ victim.luck_modifier(&"incoming_crit_chance"),
		0.0, max_crit_chance)


## Damage multiplier of `attacker`'s crits (at least 1).
static func crit_damage(attacker: BattleUnit) -> float:
	return maxf(1.0, base_crit_damage + attacker.luck_modifier(&"crit_damage"))


## Odds of each result of `attacker`'s attack on `victim`, as
## {miss, hit, crit} (sum 1). With `advantage` (grit), the better of two
## rolls counts:
##   miss = miss1^2,  crit = 1 - (1 - crit1)^2,  hit = the rest
## where crit1 = (1 - miss) x crit chance is one roll's crit chance.
static func outcome_odds(attacker: BattleUnit, victim: BattleUnit, advantage: bool) -> Dictionary:
	var miss := miss_chance(attacker, victim)
	var crit := (1.0 - miss) * crit_chance(attacker, victim)
	if advantage:
		miss = miss * miss
		crit = 1.0 - (1.0 - crit) * (1.0 - crit)
	return {"miss": miss, "hit": 1.0 - miss - crit, "crit": crit}


## Average damage multiplier of an attack (the AI's expected values):
## hit x 1 + crit x crit damage (a miss deals 0).
static func expected_factor(attacker: BattleUnit, victim: BattleUnit, advantage: bool) -> float:
	var odds := outcome_odds(attacker, victim, advantage)
	return odds.hit + odds.crit * crit_damage(attacker)

## Ticks a unit waits between two of its turns. At least 1.
static func turn_delay(unit: BattleUnit) -> int:
	return maxi(1, roundi(atb_base_delay + unit.profile.build * atb_build_factor))

## Damage taken by a pushed unit that hits the board edge or another unit
## (the other unit takes it too). Not an attack: ignores def/res.
## A quarter of the victims build, rounded up.
static func collision_damage(source: BattleUnit) -> int:
	return ceili(source.effective_stat(&"build") * 0.25)


#Damage calculation
#Min damage is 10% of expected damage (defaults to 1 if 10% is lower)
static func attack_damage(power: int, type: DamageEffect.Type,
		attacker: BattleUnit, defender: BattleUnit) -> int:
	var dmg : int
	if type == DamageEffect.Type.SPECIAL:
		dmg = power + attacker.effective_stat(&"spc_dmg")
		return maxi(maxi(1,floori(dmg * 0.1)), dmg - defender.effective_stat(&"res"))
	dmg = power + attacker.effective_stat(&"phys_dmg")
	return maxi(maxi(1, floori(dmg * 0.1)), dmg - defender.effective_stat(&"def"))
