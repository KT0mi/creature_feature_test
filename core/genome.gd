## Everything needed to rebuild a creature: the part tree + which palette each
## color region uses + the seed it came from.
##
## The baked image is only a cache of this; never save the image, save
## to_dict() and re-bake.
class_name Genome
extends RefCounted

## Root of the part tree (normally a torso).
var root: PartNode

## One palette id per CreaturePalette.Region (index 0 = primary...).
## Regions can come from different palettes, so a fused creature can have
## parent A's body color and parent B's accent color.
var region_palettes: Array[StringName] = [&"", &"", &""]

## Seed used to generate this creature (kept for reproducibility/debug).
var seed: int = 0


## Deterministic string that identifies how this creature LOOKS.
## Two genomes with the same key bake to the same image (used as cache key).
func to_key() -> String:
	return "%s|%s" % [root.to_key() if root else "", ",".join(region_palettes)]


## Deep copy.
func duplicate_genome() -> Genome:
	var g := Genome.new()
	g.root = root.duplicate_tree() if root else null
	g.region_palettes = region_palettes.duplicate()
	g.seed = seed
	return g


## Save format (IDs only), e.g. to store in a save file as JSON.
func to_dict() -> Dictionary:
	var pals: Array[String] = []
	for p in region_palettes:
		pals.append(String(p))
	return {"tree": root.to_dict() if root else {}, "palettes": pals, "seed": seed}


static func from_dict(data: Dictionary, parts_by_id: Dictionary) -> Genome:
	var g := Genome.new()
	g.root = PartNode.from_dict(data.get("tree", {}), parts_by_id)
	var pals: Array = data.get("palettes", [])
	for i in mini(pals.size(), g.region_palettes.size()):
		g.region_palettes[i] = StringName(pals[i])
	g.seed = data.get("seed", 0)
	return g
