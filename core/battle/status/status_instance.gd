@tool
## One status on one creature during a battle: which status, its count, and
## who applied it. (The StatusEffect itself is shared by every creature.)
class_name StatusInstance
extends RefCounted

var status: StatusEffect
## The number in "Poisoned 2". Meaning depends on the status.
var count: int = 1
## Who applied it (null for attributes). Held as a WEAK reference: the unit
## holds its statuses, so a strong reference back (e.g. a reaction the unit
## applied to itself) would be a cycle and neither would ever be freed.
var source: BattleUnit:
	get:
		return _source.get_ref() if _source else null
	set(value):
		_source = weakref(value) if value else null

var _source: WeakRef


func _init(p_status: StatusEffect = null, p_count: int = 1, p_source: BattleUnit = null) -> void:
	status = p_status
	count = p_count
	source = p_source


## e.g. "Poisoned 2", or just "Poisonous" for attributes.
func label() -> String:
	var n := status.name if status.name != "" else String(status.id)
	return n if status.permanent else "%s %d" % [n, count]
