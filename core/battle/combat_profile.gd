@tool
class_name CombatProfile
extends RefCounted

## Open design question: if two DIFFERENT parts add the same card, keep
## both copies (false) or only one (true)? Flip this to test both.
## (Copies from paired parts are always merged, whatever this says.)
static var merge_duplicate_cards := false

##Stats
var phys_dmg: int
var spc_dmg: int
var hp: int
var def: int
var res: int
var build: int
var battle_cards : Array[BattleCard] = []
var attributes: Array[StatusEffect] = []

static func from_genome(genome: Genome, _registry: Node = null) -> CombatProfile:
	if genome == null or genome.root == null:
		push_warning("CombatProfile: attempted to get combat profile from invalid genome!")
		return null
	var profile := CombatProfile.new()
	profile._add_node(genome.root, false)
	# A creature can't fight with 0 HP, whatever its parts subtract.
	profile.hp = maxi(profile.hp, 1)
	return profile

## Adds `node`'s part and then its children, in socket order.
## `in_copy`: this node sits in a copy socket (or below one), i.e. it's the
## second half of a pair: its stats count, its cards don't.
func _add_node(node: PartNode, in_copy: bool) -> void:
	var part := node.part
	if part.stats != null:
		phys_dmg += part.stats.phys_dmg
		spc_dmg += part.stats.spc_dmg
		hp += part.stats.hp
		def += part.stats.def
		res += part.stats.res
		build += part.stats.build_weight
	if not in_copy:
		for card in part.added_cards:
			_add_card(card)
		for attribute in part.added_attributes:
			_add_attribute(attribute)
	for socket in part.sockets:
		var child: PartNode = node.children.get(socket.name)
		if child != null:
			_add_node(child, in_copy or socket.copy_from != &"")


func _add_card(card: BattleCard) -> void:
	if card == null:
		return
	if merge_duplicate_cards:
		for existing in battle_cards:
			if existing.id == card.id:
				return
	battle_cards.append(card)

func _add_attribute(attribute: StatusEffect) -> void:
	if attribute == null:
		return
	if merge_duplicate_cards:
		for existing in attributes:
			if existing.id == attribute.id:
				return
	attributes.append(attribute)

func describe_attributes() -> String:
	var names := PackedStringArray()
	for a in attributes:
		names.append(a.name if a.name != "" else String(a.id))
	return ", ".join(names) if not names.is_empty() else "(none)"

## One-line summary, e.g. "PHY 3  SPC 1  HP 12  DEF 2  RES 1  BUILD 7".
func describe_stats() -> String:
	return "PHY %d  SPC %d  HP %d  DEF %d  RES %d  BUILD %d" % [phys_dmg, spc_dmg, hp, def, res, build]

## Card names, e.g. "Bite, Step, Step".
func describe_cards() -> String:
	var names := PackedStringArray()
	for card in battle_cards:
		names.append(card.name if card.name != "" else String(card.id))
	return ", ".join(names) if not names.is_empty() else "(no cards)"
