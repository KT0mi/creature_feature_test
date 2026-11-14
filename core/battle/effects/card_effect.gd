@tool
## One step of what a data-only card does when played (deal damage, push,
## move...). A card's `effects` run in order. For anything these can't
## express, write a script card instead (see BattleCard).
class_name CardEffect
extends Resource


## Does the effect. `user` played the card on cell `target`.
func apply(_ctx: BattleContext, _user: BattleUnit, _target: Vector2i) -> void:
	pass


## Short text for card descriptions and tooltips, e.g. "Deal 3 physical".
func describe() -> String:
	return ""
