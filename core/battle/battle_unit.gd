@tool
## One creature on the battle board: its CombatProfile plus everything that
## changes during a battle (position, HP, facing, cooldowns, armed
## reactions). Plain data; the rules engine (phase 2) changes it.
class_name BattleUnit
extends RefCounted

var profile: CombatProfile
## Display name (from CreatureNamer), for logs and the HUD.
var display_name: String = ""
## 0 = player side, 1 = enemy side.
var team: int = 0
var position: Vector2i
var facing: Grid.Facing = Grid.Facing.RIGHT
var hp: int = 0
## card id (StringName) -> turns left before it can be played again.
## Missing or 0 = ready.
var cooldowns: Dictionary = {}
## Reaction cards played and not yet fired or expired.
var armed: Array[BattleCard] = []
## Cards played this turn, to enforce the 2-card budget (max 1 attack).
var played_this_turn: Array[BattleCard] = []


func _init(p_profile: CombatProfile = null, p_team: int = 0) -> void:
	profile = p_profile
	team = p_team
	if profile:
		hp = profile.hp  # every battle starts at full HP


func is_alive() -> bool:
	return hp > 0


## True if `card` is off cooldown.
func is_ready(card: BattleCard) -> bool:
	return cooldowns.get(card.id, 0) <= 0


func label() -> String:
	return display_name if display_name != "" else "unit(team %d)" % team
