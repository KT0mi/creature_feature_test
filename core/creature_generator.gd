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
## During fusion: chance, per layout group, to ignore the parents and
## re-roll the layout (e.g. a two-eyed line suddenly gets a third eye).
const MUTATION_LAYOUT := 0.05
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
## Sockets controlled by a layout group are filled exactly as the picked
## layout says; the others are rolled with their own `chance`.
func grow(part: PartDef, depth: int = 0) -> PartNode:
	var node := PartNode.new(part)
	if depth >= MAX_DEPTH:
		return node
	var chosen := _pick_layouts(part)
	for socket in part.sockets:
		if part.get_socket_group(socket.name) != &"":
			if not chosen.has(socket.name):
				continue  # not in the picked layout
		# Always roll, even when the socket can't be filled, so adding a new
		# part type later changes as few existing seeds as possible.
		elif rng.randf() >= socket.chance:
			continue
		if _copy_into(node, socket):
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
	var chosen := _fuse_layouts(node.part, a, b)
	for socket in node.part.sockets:
		# A layout-controlled socket is filled if and only if its layout was
		# chosen; `must_fill` makes sure it isn't left empty either.
		var must_fill := false
		if node.part.get_socket_group(socket.name) != &"":
			if not chosen.has(socket.name):
				continue
			must_fill = true
		if _copy_into(node, socket):
			continue
		var donors: Array[PartNode] = []
		for parent in [a, b]:
			# Iterate in the parent's socket order for determinism.
			for parent_socket in parent.part.sockets:
				var child: PartNode = parent.children.get(parent_socket.name)
				if child != null and socket.accepts(child.part):
					donors.append(child)
		if donors.is_empty():
			# Neither parent has anything for this socket: grow something new
			# if the layout requires it, otherwise only occasionally (this is
			# one way new traits appear).
			if must_fill or rng.randf() < socket.chance * MUTATION_FILL:
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
## Copy sockets (copy_from) aren't mutated themselves: they are re-copied
## from their source at the end, so a mutated near eye stays matched by the
## far eye.
func mutate(node: PartNode, depth: int = 0) -> void:
	for socket in node.part.sockets:
		if not node.children.has(socket.name):
			continue
		if socket.copy_from != &"" and node.children.has(socket.copy_from):
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
## `weight` property. Works for PartDef and SocketLayout (both have one).
func _weighted_pick(options: Array) -> Variant:
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


## Picks one layout per group of `part` and returns the socket names to fill,
## as a Dictionary used as a set (socket name -> true).
func _pick_layouts(part: PartDef) -> Dictionary:
	var chosen := {}
	for group in part.get_layout_groups():
		var layout: SocketLayout = _weighted_pick(part.get_layouts(group))
		for socket_name in layout.sockets:
			chosen[StringName(socket_name)] = true
	return chosen


## Like _pick_layouts, but for fusion: each group inherits the layout of a
## parent that has the SAME part (so a two-eyed head stays two-eyed), unless
## neither parent does or a MUTATION_LAYOUT roll says to re-roll.
func _fuse_layouts(part: PartDef, a: PartNode, b: PartNode) -> Dictionary:
	var chosen := {}
	for group in part.get_layout_groups():
		var options: Array[SocketLayout] = []
		for parent in [a, b]:
			if parent.part == part:
				var parent_layout := _layout_of(parent, group)
				if parent_layout != null:
					options.append(parent_layout)
		var layout: SocketLayout
		if options.is_empty() or rng.randf() < MUTATION_LAYOUT:
			layout = _weighted_pick(part.get_layouts(group))
		else:
			layout = options[rng.randi_range(0, options.size() - 1)]
		for socket_name in layout.sockets:
			chosen[StringName(socket_name)] = true
	return chosen


## The layout of `group` that matches which sockets `node` has filled, or
## null (e.g. a socket stayed empty because no part fit it).
func _layout_of(node: PartNode, group: StringName) -> SocketLayout:
	var filled := PackedStringArray()
	for socket in node.part.sockets:
		if node.part.get_socket_group(socket.name) == group and node.children.has(socket.name):
			filled.append(socket.name)
	for layout in node.part.get_layouts(group):
		if layout.matches(filled):
			return layout
	return null


## If `socket` has copy_from and that source socket is already filled on
## `node`, puts a copy of the source subtree in `socket` and returns true.
## Returns false when the socket must be filled normally.
func _copy_into(node: PartNode, socket: PartSocket) -> bool:
	if socket.copy_from == &"" or not node.children.has(socket.copy_from):
		return false
	var source: PartNode = node.children[socket.copy_from]
	if not socket.accepts(source.part):
		return false  # the copy wouldn't be legal here; fill normally
	node.children[socket.name] = source.duplicate_tree()
	return true


## Re-copies every filled copy socket of `node` from its source.
func _refresh_copies(node: PartNode) -> void:
	for socket in node.part.sockets:
		if node.children.has(socket.name):
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
