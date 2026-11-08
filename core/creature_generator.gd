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
## During fusion: chance to take a random body palette instead of a parent's.
const MUTATION_PALETTE := 0.05
## During fusion: chance to add, drop or repaint one pattern.
const MUTATION_PATTERN := 0.1
## Random generation: chance of having at least 1 pattern, and (if it has
## one) of having a 2nd. Up to Genome.MAX_PATTERNS.
const PATTERN_CHANCES: Array[float] = [0.5, 0.3]

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
	g.palette = _random_palette_id()
	for chance in PATTERN_CHANCES:
		if g.patterns.size() >= Genome.MAX_PATTERNS or rng.randf() >= chance:
			break
		_add_random_pattern(g)
	return g


## Builds a random subtree starting with `part` (recursive).
## Sockets are filled top to bottom:
##   * copy sockets mirror their source (filled only if the source is);
##   * other sockets are skipped if their requires/excludes aren't met,
##     otherwise rolled with their `chance`.
func grow(part: PartDef, depth: int = 0) -> PartNode:
	var node := PartNode.new(part)
	if depth >= MAX_DEPTH:
		return node
	for socket in part.sockets:
		if socket.copy_from != &"":
			_copy_into(node, socket)
			continue
		if not socket.conditions_met(node.children):
			continue
		# Roll even when no part fits the socket, so adding a new part type
		# later changes as few existing seeds as possible.
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
	# Body palette: from one parent (or rarely a random one).
	if rng.randf() < MUTATION_PALETTE:
		g.palette = _random_palette_id()
	else:
		g.palette = (a if rng.randf() < 0.5 else b).palette
	_fuse_patterns(g, a, b)
	return g


## Patterns of a child: as many as one of the parents had, picked from the
## patterns of BOTH parents (each keeps the palette it had on that parent).
## Then a small chance of a pattern mutation.
func _fuse_patterns(g: Genome, a: Genome, b: Genome) -> void:
	# Pool of all parent patterns, one per name (A's version wins ties).
	var pool: Array[Genome.PatternGene] = []
	var names: Array[StringName] = []
	for gene in a.patterns + b.patterns:
		if not names.has(gene.name):
			names.append(gene.name)
			pool.append(gene)
	var count := (a if rng.randf() < 0.5 else b).patterns.size()
	while g.patterns.size() < count and not pool.is_empty():
		var gene: Genome.PatternGene = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		g.patterns.append(gene.duplicate_gene())

	if rng.randf() < MUTATION_PATTERN:
		match rng.randi_range(0, 2):
			0:  # gain a pattern
				_add_random_pattern(g)
			1:  # lose a pattern
				if not g.patterns.is_empty():
					g.patterns.remove_at(rng.randi_range(0, g.patterns.size() - 1))
			2:  # repaint a pattern
				if not g.patterns.is_empty():
					var gene := g.patterns[rng.randi_range(0, g.patterns.size() - 1)]
					gene.palette = _random_palette_id(g.palette)


## Adds one random pattern the genome doesn't have yet, if possible.
## Its palette avoids the body palette (same colors = invisible pattern).
func _add_random_pattern(g: Genome) -> void:
	if g.patterns.size() >= Genome.MAX_PATTERNS:
		return
	var free: Array[StringName] = []
	for pattern_name in registry.pattern_names:
		if not g.has_pattern(pattern_name):
			free.append(pattern_name)
	if free.is_empty():
		return
	var pattern_name := free[rng.randi_range(0, free.size() - 1)]
	g.patterns.append(Genome.PatternGene.new(pattern_name, _random_palette_id(g.palette)))


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
		# Same rules as grow(): copies follow their source, and a socket whose
		# requires/excludes aren't met stays empty even if a parent could
		# donate something. This keeps fused children within the rules.
		if socket.copy_from != &"":
			_copy_into(node, socket)
			continue
		if not socket.conditions_met(node.children):
			continue
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
## Only already-filled sockets are touched, so which sockets are filled (and
## therefore requires/excludes) never changes here.
## Copy sockets aren't mutated themselves: they are re-copied from their
## source at the end, so a mutated near eye stays matched by the far eye.
func mutate(node: PartNode, depth: int = 0) -> void:
	for socket in node.part.sockets:
		if not node.children.has(socket.name):
			continue
		if socket.copy_from != &"":
			continue  # handled by _refresh_copies below
		if rng.randf() < MUTATION_REGROW:
			var candidates: Array[PartDef] = registry.candidates_for(socket)
			if not candidates.is_empty():
				node.children[socket.name] = grow(_weighted_pick(candidates), depth + 1)
				continue
		mutate(node.children[socket.name], depth + 1)
	_refresh_copies(node)


# ------------------------------------------------------------------- helpers

## Picks one item from `options` with probability proportional to its
## `weight` property.
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


## Sets copy socket `socket` on `node` to match its source: a copy of the
## source subtree if the source is filled (and the copy is legal in this
## socket), otherwise empty. Never picks a part of its own.
## With use_counterpart the copy is made of each part's counterpart instead.
func _copy_into(node: PartNode, socket: PartSocket) -> void:
	var source: PartNode = node.children.get(socket.copy_from)
	var copy: PartNode = null
	if source != null:
		copy = _counterpart_tree(source) if socket.use_counterpart else source.duplicate_tree()
	if copy != null and socket.accepts(copy.part):
		node.children[socket.name] = copy
	else:
		node.children.erase(socket.name)


## Copy of `node`'s subtree where every part that has a counterpart is
## replaced by it (near ear -> far ear, and e.g. a near earring on it ->
## far earring). Children keep their socket names; a child is dropped if
## the counterpart part has no socket with that name or the socket doesn't
## accept it.
func _counterpart_tree(node: PartNode) -> PartNode:
	var def := node.part
	if def.counterpart != &"":
		var other: PartDef = registry.get_part(def.counterpart)
		if other != null:
			def = other
	var copy := PartNode.new(def)
	for socket_name in node.children:
		var socket := def.get_socket(socket_name)
		if socket == null:
			continue
		var child := _counterpart_tree(node.children[socket_name])
		if socket.accepts(child.part):
			copy.children[socket_name] = child
	return copy


## Re-syncs every copy socket of `node` with its source (after mutation).
## Socket order guarantees a source is final before its copies are made.
func _refresh_copies(node: PartNode) -> void:
	for socket in node.part.sockets:
		if socket.copy_from != &"":
			_copy_into(node, socket)


## Random palette id. `exclude` is skipped when there is any other choice.
func _random_palette_id(exclude: StringName = &"") -> StringName:
	var ids: Array[StringName] = []
	for id in registry.palette_ids:
		if id != exclude:
			ids.append(id)
	if ids.is_empty():
		ids = registry.palette_ids  # only one palette exists: use it anyway
	if ids.is_empty():
		return &""
	return ids[rng.randi_range(0, ids.size() - 1)]
