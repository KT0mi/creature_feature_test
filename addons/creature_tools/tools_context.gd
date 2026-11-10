## State shared by all creature tools in the editor.
##
## The PartRegistry autoload only exists while the GAME runs, so the editor
## tools keep their own registry instance (same script, never added to the
## scene tree). It's (re)loaded lazily: mark_dirty() when files change, and
## the next registry() call rescans.
@tool
extends RefCounted

const RegistryScript := preload("res://core/part_registry.gd")

var _registry: Node
var _dirty := true


## The editor's registry, rescanned first if files changed since last time.
func registry() -> Node:
	if _registry == null:
		_registry = RegistryScript.new()
	if _dirty:
		_registry.reload()
		CreatureBaker.clear_cache()
		_dirty = false
	return _registry


## Call when files on disk changed; the next registry() call rescans.
func mark_dirty() -> void:
	_dirty = true


## Frees the registry node (it's not in the tree, so nothing else would).
func free_registry() -> void:
	if _registry != null:
		_registry.free()
		_registry = null


## One sample creature per torso (fusion_only torsos skipped), grown from a
## fixed seed so the previews stay the same while you edit. Every sample
## gets `palette_id` as its body palette and no patterns.
func sample_genomes(palette_id: StringName, seed: int) -> Array[Genome]:
	var reg := registry()
	var gen := CreatureGenerator.new(reg)
	var out: Array[Genome] = []
	var torsos: Array = reg.get_parts_of_type(CreatureGenerator.ROOT_TYPE)
	for i in torsos.size():
		var torso: PartDef = torsos[i]
		if torso.fusion_only:
			continue
		gen.rng.seed = hash([seed, torso.id])
		var g := Genome.new()
		g.root = gen.grow(torso)
		g.palette = palette_id
		g.seed = seed
		out.append(g)
	return out
