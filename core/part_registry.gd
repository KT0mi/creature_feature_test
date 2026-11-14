@tool
## Autoload (singleton) named "PartRegistry". Registered in project.godot.
##
## On startup it scans res://creatures/parts/ and res://creatures/palettes/
## for .tres files and builds lookup tables by ID. Nothing else in the game
## should load parts by path: ask the registry by id or by type.
##
## Note: no `class_name` here on purpose. An autoload's name already makes it
## globally accessible, and a class_name with the same name would clash.
extends Node

const PARTS_DIR := "res://creatures/parts/"
const PALETTES_DIR := "res://creatures/palettes/"
const RECIPES_DIR := "res://creatures/recipes"
## Card library: one BattleCard .tres per card (any sub-folders). Script
## cards keep their .gd next to their .tres.
const CARDS_DIR := "res://creatures/cards/"
## Name of the sub-folder (next to a part's .tres) that holds its patterns.
const PATTERNS_SUBDIR := "patterns"
## The palette whose colors parts are DRAWN with (see CreaturePalette).
const KEY_PATH := "res://creatures/palette_key.tres"
## Optional naming settings (fixed names, pattern words, count rules...).
const NAMING_PATH := "res://creatures/naming/naming.tres"

## id (StringName) -> PartDef
var parts: Dictionary = {}
## type (StringName) -> Array of PartDef of that type
var parts_by_type: Dictionary = {}
## id (StringName) -> CreaturePalette
var palettes: Dictionary = {}
## Palette ids sorted alphabetically, so random picks are deterministic.
var palette_ids: Array[StringName] = []
## Every pattern name found on at least one part, sorted (deterministic).
var pattern_names: Array[StringName] = []
## Fusion recipes, indexed by the (unordered) pair of part ids:
## pair_key(a, b) -> Array of FusionRecipe, in file path order.
## Looking up a pair is a single dictionary access, however many recipes
## exist, so checking every socket during fusion is cheap.
var recipes: Dictionary = {}
## The key palette (colors used in the source art).
var key: CreaturePalette
## Naming settings (see CreatureNaming). Defaults if the file is missing.
var naming: CreatureNaming
## id (StringName) -> BattleCard, from the card library.
var cards: Dictionary = {}


func _ready() -> void:
	reload()

## (Re)scans everything. Safe to call again after adding files at runtime.
func reload() -> void:
	parts.clear()
	parts_by_type.clear()
	palettes.clear()
	palette_ids.clear()
	pattern_names.clear()
	recipes.clear()
	cards.clear()

	for path in _find_tres(PARTS_DIR):
		var res := load(path)
		if res is PartDef:
			_add_part(res, path)
		# Other .tres files in parts/ are ignored silently.

	for path in _find_tres(PALETTES_DIR):
		var res := load(path)
		if res is CreaturePalette:
			if not res.is_valid():
				push_error("Palette '%s' must have exactly %d colors: %s"
					% [res.id, CreaturePalette.TONES, path])
				continue
			if palettes.has(res.id):
				push_error("Duplicate palette id '%s' in %s" % [res.id, path])
				continue
			palettes[res.id] = res
			palette_ids.append(res.id)
	palette_ids.sort_custom(func(a, b): return String(a) < String(b))

	pattern_names.sort_custom(func(a, b): return String(a) < String(b))

	key = load(KEY_PATH) as CreaturePalette
	if key == null or not key.is_valid():
		push_error("Missing or invalid palette key at %s" % KEY_PATH)

	# Sort each type list by id. File-system order isn't guaranteed to be the
	# same on every OS, and generation must be deterministic for a given seed.
	for t in parts_by_type:
		parts_by_type[t].sort_custom(func(a, b): return String(a.id) < String(b.id))
	
	naming = null
	if ResourceLoader.exists(NAMING_PATH):
		naming = load(NAMING_PATH) as CreatureNaming
	if naming == null: naming = CreatureNaming.new()
	
	
	# Cards before the counterpart/card checks below, which use them.
	var card_paths := _find_tres(CARDS_DIR)
	card_paths.sort()
	for path in card_paths:
		var res := load(path)
		if res is BattleCard:
			_add_card(res, path)

	# Counterparts and cards can only be checked once every part is loaded.
	for def in parts.values():
		_validate_counterpart(def)
		_validate_part_cards(def)
	
	var recipe_paths := _find_tres(RECIPES_DIR)
	recipe_paths.sort()
	for path in recipe_paths:
		var res := load(path)
		if res is FusionRecipe and _validate_recipe(res, path):
			var k := pair_key(res.part_a, res.part_b)
			if not recipes.has(k):
				recipes[k] = []
			recipes[k].append(res)
	
	print("PartRegistry: %d parts, %d palettes, %d cards, %d recipe pairs, patterns: %s."
		% [parts.size(), palettes.size(), cards.size(), recipes.size(), pattern_names])

## BattleCard by id, or null.
func get_card(id: StringName) -> BattleCard:
	return cards.get(id)


## PartDef by id, or null.
func get_part(id: StringName) -> PartDef:
	return parts.get(id)


## All parts of a given type (empty array if none). Do not modify the result.
func get_parts_of_type(type: StringName) -> Array:
	return parts_by_type.get(type, [])


## All parts that are legal in `socket`, in deterministic order.
func candidates_for(socket: PartSocket) -> Array[PartDef]:
	var out: Array[PartDef] = []
	for type in socket.accepts_type:
		for p in get_parts_of_type(type):
			if not p.fusion_only and socket.accepts(p):
				out.append(p)
	return out

## Same key for (a, b) and (b, a).
static func pair_key(a: StringName, b: StringName) -> String:
	return "%s|%s" % ([a, b] if String(a) <= String(b) else [b, a])


## Recipes for two part ids (either order). Empty array if none.
func recipes_for(a: StringName, b: StringName) -> Array:
	return recipes.get(pair_key(a, b), [])

func _add_part(def: PartDef, path: String) -> void:
	if def.id == &"":
		push_error("PartDef without id: %s" % path)
		return
	if parts.has(def.id):
		push_error("Duplicate part id '%s' in %s" % [def.id, path])
		return
	if def.sheet == null:
		push_error("PartDef '%s' has no sheet: %s" % [def.id, path])
		return
	_validate_sockets(def, path)
	parts[def.id] = def
	_load_patterns(def, path.get_base_dir().path_join(PATTERNS_SUBDIR))
	if not parts_by_type.has(def.type):
		parts_by_type[def.type] = []
	parts_by_type[def.type].append(def)


## Startup checks for mistakes that would otherwise fail silently (a typo in
## a socket name just means "never filled"). Only reports errors; the part
## is still loaded so you can see the result in the lab.
func _validate_sockets(def: PartDef, path: String) -> void:
	var where := "Part '%s' (%s)" % [def.id, path]
	# Names of the sockets seen so far: rules may only point at these,
	# because sockets are filled top to bottom.
	var earlier: Array[StringName] = []
	for socket in def.sockets:
		if socket == null:
			push_error("%s: empty entry in sockets." % where)
			continue
		var socket_name := socket.name
		if earlier.has(socket_name):
			push_error("%s: two sockets are called '%s' (copy-pasted socket? use Make Unique)."
				% [where, socket_name])
		if socket.accepts_type.is_empty():
			push_error("%s: socket '%s' accepts no type, it can never be filled." % [where, socket_name])

		if socket.copy_from != &"":
			if not earlier.has(socket.copy_from):
				push_error("%s: socket '%s' copies '%s', which must be a socket listed above it."
					% [where, socket_name, socket.copy_from])
			if not socket.requires.is_empty() or not socket.excludes.is_empty():
				push_warning("%s: socket '%s' is a copy; its requires/excludes are ignored."
					% [where, socket_name])
		
		if socket.use_counterpart and socket.copy_from == &"":
			push_warning("%s: socket '%s' has use_counterpart but no copy_from; it does nothing."
				% [where, socket_name])
		
		for t in socket.type_weights:
			if not socket.accepts_type.has(t):
				push_warning("%s: socket %s has a type weight for %s, which it doesn't accept."
				% [where, socket_name, t])
			elif  socket.type_weights[t] < 0.0:
				push_error("%s: socket '%s' has a negative weight for '%s'."
					% [where, socket_name, t])
		
		for other in socket.requires:
			if not earlier.has(StringName(other)):
				push_error("%s: socket '%s' requires '%s', which must be a socket listed above it."
					% [where, socket_name, other])
		for other in socket.excludes:
			if not earlier.has(StringName(other)):
				push_error("%s: socket '%s' excludes '%s', which must be a socket listed above it."
					% [where, socket_name, other])
			if socket.requires.has(other):
				push_error("%s: socket '%s' both requires and excludes '%s', it can never be filled."
					% [where, socket_name, other])
		earlier.append(socket_name)

func _add_card(card: BattleCard, path: String) -> void:
	if card.id == &"":
		push_error("Card without id: %s" % path)
		return
	if cards.has(card.id):
		push_error("Duplicate card id '%s' in %s and %s"
			% [card.id, cards[card.id].resource_path, path])
		return
	cards[card.id] = card


## Checks the cards a part adds. Cards should be their own .tres in the
## card library: a card created INSIDE the part's .tres (embedded) is a
## separate copy per part, can't be shared, and is easy to break.
func _validate_part_cards(def: PartDef) -> void:
	for card in def.added_cards:
		if card == null:
			push_warning("Part '%s': empty entry in added_cards." % def.id)
		elif card.resource_path == "" or card.resource_path.contains("::"):
			push_warning("Part '%s': card '%s' is embedded in the part; save it as its own .tres in %s."
				% [def.id, card.id, CARDS_DIR])
		elif cards.get(card.id) != card:
			push_warning("Part '%s': card '%s' (%s) isn't in the card library %s."
				% [def.id, card.id, card.resource_path, CARDS_DIR])


## Checks that `def.counterpart` names an existing part of the same type.
## (A typo would otherwise silently fall back to copying the same part.)
func _validate_counterpart(def: PartDef) -> void:
	if def.counterpart == &"":
		return
	var other: PartDef = parts.get(def.counterpart)
	if other == null:
		push_error("Part '%s': counterpart '%s' doesn't exist." % [def.id, def.counterpart])
	elif other.type != def.type:
		push_error("Part '%s' (%s): counterpart '%s' is a %s."
			% [def.id, def.type, other.id, other.type])

## Fills def.patterns from the PNGs in `dir` (file name = pattern name).
## A pattern whose size doesn't match the part's sheet is rejected, because
## it's drawn 1:1 on top of the part.
func _load_patterns(def: PartDef, dir: String) -> void:
	def.patterns.clear()
	for entry in ResourceLoader.list_directory(dir):
		if not entry.ends_with(".png"):
			continue
		var tex := load(dir.path_join(entry)) as Texture2D
		if tex == null:
			continue
		if tex.get_size() != def.sheet.get_size():
			push_error("Pattern %s is %s but part '%s' sheet is %s; skipped."
				% [entry, tex.get_size(), def.id, def.sheet.get_size()])
			continue
		var pattern_name := StringName(entry.get_basename())
		def.patterns[pattern_name] = tex
		if not pattern_names.has(pattern_name):
			pattern_names.append(pattern_name)


## Recursively lists every .tres under `dir`.
## ResourceLoader.list_directory (Godot 4.4+) is used instead of DirAccess
## because it also works in exported games, where resources get renamed
## (.tres -> .tres.remap) and DirAccess would see the wrong names.
func _find_tres(dir: String) -> PackedStringArray:
	# A missing folder just returns an empty list.
	var out: PackedStringArray = []
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			out.append_array(_find_tres(dir.path_join(entry.trim_suffix("/"))))
		elif entry.ends_with(".tres"):
			out.append(dir.path_join(entry))
	return out


## Checks a recipe's part ids. Returns false (recipe skipped) if any of
## them doesn't exist.
func _validate_recipe(r: FusionRecipe, path: String) -> bool:
	for id in [r.part_a, r.part_b, r.result]:
		if not parts.has(id):
			push_error("Recipe %s: part '%s' doesn't exist; recipe skipped." % [path, id])
			return false
	var result_type: StringName = parts[r.result].type
	if result_type != parts[r.part_a].type and result_type != parts[r.part_b].type:
		push_warning("Recipe %s: result '%s' is a %s, unlike both inputs; it only "
			% [path, r.result, result_type] + "happens in sockets that accept %s." % result_type)
	return true
