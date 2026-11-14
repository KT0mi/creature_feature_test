@tool
## Something that happened in a battle: a unit moved, got pushed, took
## damage... The rules engine (phase 2) produces these in order; the battle
## view animates them, the log records them, and armed reactions react to
## them (see BattleCard.reacts_to).
##
## Plain data. Fields that don't apply to a type are left at their defaults.
class_name BattleEvent
extends RefCounted

enum Type {
	MOVED,     ## unit went from `from` to `to` by its own move
	TURNED,    ## unit's facing changed to `amount` (a Grid.Facing)
	PUSHED,    ## unit was pushed from `from` to `to` by `source`
	COLLIDED,  ## unit was pushed into something at `to` (and stopped)
	DAMAGED,   ## unit lost `amount` HP, dealt by `source`
	HEALED,    ## unit gained `amount` HP
	CARD_PLAYED, ## `source` played `card` on cell `to`
	REACTED,   ## `card` (a reaction armed on `unit`) fired
	DIED,      ## unit reached 0 HP
}

var type: Type
## The unit the event is about.
var unit: BattleUnit
## Who caused it (attacker, pusher, card user), if anyone.
var source: BattleUnit
var from: Vector2i
var to: Vector2i
## Damage, healing, or a Grid.Facing for TURNED.
var amount: int = 0
## The card involved (CARD_PLAYED, REACTED), if any.
var card: BattleCard


func _init(p_type: Type = Type.MOVED, p_unit: BattleUnit = null) -> void:
	type = p_type
	unit = p_unit


## Short readable form for logs, e.g. "DAMAGED Catwurm 3".
func describe() -> String:
	var who := unit.label() if unit else "?"
	match type:
		Type.MOVED, Type.PUSHED:
			return "%s %s %s -> %s" % [Type.keys()[type], who, from, to]
		Type.DAMAGED, Type.HEALED:
			return "%s %s %d" % [Type.keys()[type], who, amount]
		Type.CARD_PLAYED, Type.REACTED:
			return "%s %s %s" % [Type.keys()[type], who, card.id if card else &"?"]
	return "%s %s" % [Type.keys()[type], who]
