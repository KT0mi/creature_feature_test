##Data required to rebuild a creature: the part tree, palettes, patterns and the seed.
##The baked image is a cache of this genome, therefore do not save the image but this to_dict() and rebake.
class_name Genome
extends RefCounted

## Most patterns a creature can carry at once (more gets visually noisy).
const MAX_PATTERNS := 2

## One pattern on a creature: WHICH pattern (by name, e.g. "stripes") and
## which palette its pixels use. Every part that has a pattern with this name
## in its patterns/ folder draws it; parts without one just skip it.
class PatternGene:
	var name: StringName
	var palette: StringName

	func _init(p_name: StringName = &"", p_palette: StringName = &"") -> void:
		name = p_name
		palette = p_palette

	func duplicate_gene() -> PatternGene:
		return PatternGene.new(name, palette)

## Root of the part tree (normally a torso).
var root: PartNode

## Id of the CreaturePalette used by ALL parts (and for the outline).
var palette: StringName = &""

## Pattern overlays, drawn in this order (later ones on top). At most
## MAX_PATTERNS, and never two with the same name.
var patterns: Array[PatternGene] = []

## Seed used to generate this creature (kept for reproducibility/debug).
var seed: int = 0

## True if this genome already has a pattern called `pattern_name`.
func has_pattern(pattern_name: StringName) -> bool:
	for p in patterns:
		if p.name == pattern_name:
			return true
	return false

## Deterministic string that identifies how this creature LOOKS.
## Two genomes with the same key bake to the same image (used as cache key).
## e.g. "torso_a(head:head_b)|stone|stripes:moss,spots:ember"
func to_key() -> String:
	var pats: PackedStringArray = []
	for p in patterns:
		pats.append("%s:%s" % [p.name, p.palette])
	return "%s|%s|%s" % [root.to_key() if root else "", palette, ",".join(pats)]
	
## Deep copy.
func duplicate_genome() -> Genome:
	var g := Genome.new()
	g.root = root.duplicate_tree() if root else null
	g.palette = palette
	for p in patterns:
		g.patterns.append(p.duplicate_gene())
	g.seed = seed
	return g

## Save format (IDs only), e.g. to store in a save file as JSON:
## { "tree": {...}, "palette": "stone",
##   "patterns": [{"name": "stripes", "palette": "moss"}], "seed": 3 }
func to_dict() -> Dictionary:
	var pats: Array[Dictionary] = []
	for p in patterns:
		pats.append({"name": String(p.name), "palette": String(p.palette)})
	return {
		"tree": root.to_dict() if root else {},
		"palette": String(palette),
		"patterns": pats,
		"seed": seed,
	}


static func from_dict(data: Dictionary, parts_by_id: Dictionary) -> Genome:
	var g := Genome.new()
	g.root = PartNode.from_dict(data.get("tree", {}), parts_by_id)
	g.palette = StringName(data.get("palette", ""))
	for p in data.get("patterns", []):
		if g.patterns.size() >= MAX_PATTERNS:
			break
		g.patterns.append(PatternGene.new(StringName(p.get("name", "")), StringName(p.get("palette", ""))))
	g.seed = data.get("seed", 0)
	return g
