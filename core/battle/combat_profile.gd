@tool
class_name CombatProfile
extends RefCounted

##Stats
var phys_dmg: int
var spc_dmg: int
var hp: int
var def: int
var res: int
var build: int
var battle_cards : Array[BattleCard]

func from_genome(genome: Genome, registry: PartRegistry) -> CombatProfile:
	if genome == null or genome.root == null:
		push_warning("CombatProfile: attempted to get combat profile from invalid genome!")
		return null
	
	#Get base stats
	var torso : PartDef = genome.root.part
	phys_dmg = torso.stats.phys_dmg
	spc_dmg = torso.stats.spc_dmg
	hp = torso.stats.hp
	def = torso.stats.def
	res = torso.stats.res
	build = torso.stats.build_weight
	battle_cards.append_array(torso.added_cards)
	
	#Walking through the part tree to modify stats
	var stack: Array[PartNode] = []
	var root_node := genome.root
	var root_part := root_node.part
	for i in range(root_part.sockets.size() - 1, -1, -1):
		var child: PartNode = root_node.children.get(root_part.sockets[i].name)
		if child != null:
			stack.append(child)
	#Start iterating through child parts of the torso
	while not stack.is_empty():
		var node: PartNode = stack.pop_back()
		var part := node.part
		
		#Gather stats and modify
		var stats : PartStats = part.stats
		phys_dmg += stats.phys_dmg
		spc_dmg += stats.spc_dmg
		hp += stats.hp
		def += stats.def
		res += stats.res
		build += stats.build_weight
		battle_cards.append_array(part.added_cards)
		
		for i in range(part.sockets.size() - 1, -1, -1):
			var child: PartNode = node.children.get(part.sockets[i].name)
			if child != null:
				stack.append(child)
	
	return self
