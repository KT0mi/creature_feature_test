@tool
## "Unit number `unit_index` plays the card in deck slot `slot` on cell
## `target`." Units are referred to by INDEX (not object) so the same action
## works on a cloned battle (AI simulation, previews).
class_name BattleAction
extends RefCounted

var unit_index: int
## Index into the unit's profile.battle_cards.
var slot: int
var target: Vector2i
## Attacks: spend 1 grit for ADVANTAGE (each victim rolled twice, the
## better result counts). Spent whether the attack then hits or not;
## ignored if the user has no grit, the card isn't an attack, or it has no
## victims. Not part of what makes an action legal.
var use_grit: bool = false


func _init(p_unit_index: int = 0, p_slot: int = 0, p_target: Vector2i = Vector2i.ZERO) -> void:
	unit_index = p_unit_index
	slot = p_slot
	target = p_target


func _to_string() -> String:
	return "unit %d plays slot %d on %s" % [unit_index, slot, target]
