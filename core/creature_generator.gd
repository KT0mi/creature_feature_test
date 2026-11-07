## Random generation (grow) and fusion (fuse + mutate) of genomes.
##
## Everything goes through ONE RandomNumberGenerator seeded by the caller, and
## parts/palettes are always iterated in a fixed (sorted) order, so the same
## seed + same parts folder = the same creature, every time.
class_name CreatureGenerator
extends RefCounted

## Type of the part every creature starts from.
const ROOT_TYPE := &"torso"
## Safety limit for tree depth (torso > arm > hand > claw > spike ... ).
const MAX_DEPTH := 8
## Soft cap for the finished creature (without outline). Generation and
## fusion retry when a result is bigger. Raise it for bosses etc.
## (Your template biped is ~32x103 px, so 96x96 from the notes was too small.)
const MAX_SIZE := Vector2i(128, 128)
## How many times to retry before giving up and accepting an oversized result.
const MAX_ATTEMPTS := 20
## During fusion: chance to fill a socket that NEITHER parent could fill.
const MUTATION_FILL := 0.25
## During fusion: chance, per node, to regrow that subtree from scratch.
const MUTATION_REGROW := 0.05
## During fusion: chance, per color region, to take a random palette.
const MUTATION_PALETTE := 0.05

var rng := RandomNumberGenerator.new()
## The PartRegistry autoload (passed in so this class is easy to test).
var registry: Node


func _init(p_registry: Node, p_seed: int = 0) -> void:
	registry = p_registry
	rng.seed = p_seed


# ---------------------------------------------------------------- generation

## A brand new random creature. Returns null if there is no root part.
func random_genome(p_seed: int) -> Genome:
	rng.seed = p_seed
	var roots: Array = registry.get_parts_of_type(ROOT_TYPE)
	if roots.is_empty():
		return null
	var g := Genome.new()
	g.seed = p_seed
	for attempt in MAX_ATTEMPTS:
		g.root = grow(_weighted_pick(roots))
		if fits(g.root):
			break
	for region in 3:
		g.region_palettes[region] = _random_palette_id()
	return g


## Builds a random subtree starting with `part` (recursive).
func grow(part: PartDef, depth: int = 0) -> PartNode:
	var node := PartNode.new(part)
	if depth >= MAX_DEPTH:
		return node
	for socket in part.sockets:
		# Always roll, even when the socket can't be filled, so adding a new
		# part type later changes as few existing seeds as possible.
		if rng.randf() >= socket.chance:
			continue
		var candidates: Array[PartDef] = registry.candidates_for(socket)
		if candidates.is_empty():
			continue
		node.children[socket.name] = grow(_weighted_pick(candidates), depth + 1)
	return node


## True if the creature is within MAX_SIZE.
func fits(root: PartNode) -> bool:
	var size := CreatureBaker.measure(root).size
	return size.x <= MAX_SIZE.x and size.y <= MAX_SIZE.y


# -------------------------------------------------------------------- fusion

## Fuses two genomes into a child. Different seeds give different children.
func fuse_genomes(a: Genome, b: Genome, p_seed: int) -> Genome:
	rng.seed = p_seed
	var g := Genome.new()
	g.seed = p_seed
	for attempt in MAX_ATTEMPTS:
		g.root = fuse(a.root, b.root)
		mutate(g.root)
		if fits(g.root):
			break
	# Colors: each region independently from one parent (or rarely random).
	for region in 3:
		if rng.randf() < MUTATION_PALETTE:
			g.region_palettes[region] = _random_palette_id()
		else:
			g.region_palettes[region] = (a if rng.randf() < 0.5 else b).region_palettes[region]
	return g


## Tree crossover. `a` and `b` must be legal in the same socket (same type).
## For every socket of the chosen part, "donors" are the children of EITHER
## parent that fit that socket, matched by type, not by socket name. So a
## 4-armed parent can donate to a 2-armed child, and a "claw" socket can take
## a claw that sat in a socket called "talon".
func fuse(a: PartNode, b: PartNode, depth: int = 0) -> PartNode:
	var node := PartNode.new(a.part if rng.randf() < 0.5 else b.part)
	if depth >= MAX_DEPTH:
		return node
	for socket in node.part.sockets:
		var donors: Array[PartNode] = []
		for parent in [a, b]:
			# Iterate in the parent's socket order for determinism.
			for parent_socket in parent.part.sockets:
				var child: PartNode = parent.children.get(parent_socket.name)
				if child != null and socket.accepts(child.part):
					donors.append(child)
		if donors.is_empty():
			# Neither parent has anything for this socket: occasionally grow
			# something new (this is one way new traits appear).
			if rng.randf() < socket.chance * MUTATION_FILL:
				var candidates: Array[PartDef] = registry.candidates_for(socket)
				if not candidates.is_empty():
					node.children[socket.name] = grow(_weighted_pick(candidates), depth + 1)
			continue
		if donors.size() >= 2 and rng.randf() < 0.5:
			# Mix inside: e.g. arm from A, hand from B, claws from either.
			var i := rng.randi_range(0, donors.size() - 1)
			var j := rng.randi_range(0, donors.size() - 2)
			if j >= i:
				j += 1  # pick two DIFFERENT donors
			node.children[socket.name] = fuse(donors[i], donors[j], depth + 1)
		else:
			# Take a whole subtree (copied, so parents are never modified).
			var pick := donors[rng.randi_range(0, donors.size() - 1)]
			node.children[socket.name] = pick.duplicate_tree()
	return node


## Small random changes, in place: occasionally replaces a child subtree
## with a freshly grown one (any part legal in that socket).
func mutate(node: PartNode, depth: int = 0) -> void:
	for socket in node.part.sockets:
		if not node.children.has(socket.name):
			continue
		if rng.randf() < MUTATION_REGROW:
			var candidates: Array[PartDef] = registry.candidates_for(socket)
			if not candidates.is_empty():
				node.children[socket.name] = grow(_weighted_pick(candidates), depth + 1)
				continue
		mutate(node.children[socket.name], depth + 1)


# ------------------------------------------------------------------- helpers

## Picks one PartDef with probability proportional to its weight.
func _weighted_pick(options: Array) -> PartDef:
	var total := 0.0
	for p in options:
		total += maxf(p.weight, 0.0)
	if total <= 0.0:
		return options[rng.randi_range(0, options.size() - 1)]
	var r := rng.randf() * total
	for p in options:
		r -= maxf(p.weight, 0.0)
		if r < 0.0:
			return p
	return options[-1]  # floating point safety net


func _random_palette_id() -> StringName:
	var ids: Array[StringName] = registry.palette_ids
	if ids.is_empty():
		return &""
	return ids[rng.randi_range(0, ids.size() - 1)]
