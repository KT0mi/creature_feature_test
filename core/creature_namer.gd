## Builds a creature's common name from its genome, e.g.
## "Giant Red Winged Catwurm".
##
##   main name   = head radical + torso radical ("Cat" + "wurm"), unless a
##                 FixedName in CreatureNaming covers that head + torso pair
##   adjectives  = candidates collected from the creature (size, palette,
##                 patterns, part adjectives, count rules). Some are picked
##                 at random, at most one per Category, and printed in
##                 Category order so the words always read in English order.
##
## The random pick is seeded with a hash of the genome's CONTENT (to_key),
## so two creatures that look the same always share a name.
class_name CreatureNamer
extends RefCounted

## Adjective categories, in the order they are printed (English adjective
## order: size, then color, then pattern, then features like "Winged").
## At most one word per category ends up in a name.
enum Category { SIZE, COLOR, PATTERN, FEATURE }


## One possible adjective for a creature.
class Candidate:
	var word: String
	var category: int
	var weight: float

	func _init(p_word: String, p_category: int, p_weight: float) -> void:
		word = p_word
		category = p_category
		weight = p_weight


## Full name of `genome`. `registry` is the PartRegistry autoload.
static func name_of(genome: Genome, registry: Node) -> String:
	if genome == null or genome.root == null:
		return ""
	var naming: CreatureNaming = registry.naming
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(genome.to_key())
	var words := pick_adjectives(collect_candidates(genome, registry), naming.max_words, rng)
	words.append(main_name(genome.root, naming))
	return " ".join(words)


## Head radical + torso radical, or an authored FixedName.
## Falls back step by step so a part with missing name data still gives
## something readable (and visibly "unfinished": the part's id).
static func main_name(root: PartNode, naming: CreatureNaming) -> String:
	var torso := root.part
	var head_node := _find_type(root, &"head")
	var head: PartDef = head_node.part if head_node else null

	var fixed := naming.fixed_name_for(head.id if head else &"", torso.id)
	if fixed != "":
		return fixed
	if head == null and torso.name_full != "":
		return torso.name_full

	# Front from the head, back from the torso; each falls back to the
	# other part's radical if the preferred one is empty.
	var front := head.name_front if head and head.name_front != "" else torso.name_front
	var back := torso.name_back if torso.name_back != "" else (head.name_back if head else "")
	var result := front + back
	if result == "":
		result = String(torso.id).capitalize()
	return result.left(1).to_upper() + result.substr(1)


## Every adjective that could describe this creature, in a fixed order.
## Duplicate words (e.g. "Winged" from both wings) are merged, keeping the
## highest weight.
static func collect_candidates(genome: Genome, registry: Node) -> Array[Candidate]:
	var naming: CreatureNaming = registry.naming
	var out: Array[Candidate] = []

	# Size, from the creature's height in pixels.
	var height := CreatureBaker.measure(genome.root).size.y
	if naming.small_word != "" and height <= naming.small_height:
		out.append(Candidate.new(naming.small_word, Category.SIZE, naming.size_weight))
	elif naming.large_word != "" and height >= naming.large_height:
		out.append(Candidate.new(naming.large_word, Category.SIZE, naming.size_weight))

	# Color, from the body palette.
	var palette: CreaturePalette = registry.palettes.get(genome.palette)
	if palette and palette.display_name != "":
		out.append(Candidate.new(palette.display_name, Category.COLOR, naming.color_weight))

	# Patterns.
	for gene in genome.patterns:
		out.append(Candidate.new(naming.pattern_word(gene.name), Category.PATTERN,
			naming.pattern_weight))

	# Part adjectives, and how many parts of each type there are.
	var type_counts := {}
	var stack: Array[PartNode] = [genome.root]
	while not stack.is_empty():
		var node: PartNode = stack.pop_back()
		var part := node.part
		type_counts[part.type] = type_counts.get(part.type, 0) + 1
		if part.name_adjective != "":
			out.append(Candidate.new(part.name_adjective, part.name_adjective_category,
				part.name_adjective_weight))
		# Children in socket order, so the walk is deterministic.
		for i in range(part.sockets.size() - 1, -1, -1):
			var child: PartNode = node.children.get(part.sockets[i].name)
			if child != null:
				stack.append(child)

	# Count rules, e.g. exactly 3 eyes -> "Three-eyed".
	for rule in naming.count_rules:
		if rule != null and type_counts.get(rule.type, 0) == rule.count and rule.word != "":
			out.append(Candidate.new(rule.word, Category.FEATURE, rule.weight))

	return _merge_duplicates(out)


## Picks the adjectives:
##   * n = how many categories have at least one candidate;
##   * between half of n (rounded up) and min(n, max_words) words are
##     picked, so simple creatures get short names and complex ones longer;
##   * each pick is weighted and skips categories already used;
##   * the result is sorted into Category order.
static func pick_adjectives(candidates: Array[Candidate], max_words: int,
		rng: RandomNumberGenerator) -> PackedStringArray:
	var categories := {}
	for c in candidates:
		if c.weight > 0.0:
			categories[c.category] = true
	var n := categories.size()
	if n == 0 or max_words <= 0:
		return PackedStringArray()
	var count := rng.randi_range(ceili(n / 2.0), mini(n, max_words))

	var picked: Array[Candidate] = []
	var used := {}
	for i in count:
		var options: Array[Candidate] = []
		var total := 0.0
		for c in candidates:
			if c.weight > 0.0 and not used.has(c.category):
				options.append(c)
				total += c.weight
		if options.is_empty():
			break
		var r := rng.randf() * total
		var choice: Candidate = options[-1]  # floating point safety net
		for c in options:
			r -= c.weight
			if r < 0.0:
				choice = c
				break
		picked.append(choice)
		used[choice.category] = true

	picked.sort_custom(func(a: Candidate, b: Candidate) -> bool: return a.category < b.category)
	var words := PackedStringArray()
	for c in picked:
		words.append(c.word)
	return words


## First node of `type` among root's direct children (in socket order).
static func _find_type(root: PartNode, type: StringName) -> PartNode:
	for socket in root.part.sockets:
		var child: PartNode = root.children.get(socket.name)
		if child != null and child.part.type == type:
			return child
	return null


static func _merge_duplicates(list: Array[Candidate]) -> Array[Candidate]:
	var out: Array[Candidate] = []
	var by_word := {}
	for c in list:
		if by_word.has(c.word):
			var existing: Candidate = by_word[c.word]
			existing.weight = maxf(existing.weight, c.weight)
		else:
			by_word[c.word] = c
			out.append(c)
	return out
