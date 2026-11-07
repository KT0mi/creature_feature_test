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
## Name of the sub-folder (next to a part's .tres) that holds its patterns.
const PATTERNS_SUBDIR := "patterns"
## The palette whose colors parts are DRAWN with (see CreaturePalette).
const KEY_PATH := "res://creatures/palette_key.tres"

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
## The key palette (colors used in the source art).
var key: CreaturePalette


func _ready() -> void:
	reload()


## (Re)scans everything. Safe to call again after adding files at runtime.
func reload() -> void:
	parts.clear()
	parts_by_type.clear()
	palettes.clear()
	palette_ids.clear()
	pattern_names.clear()

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

	print("PartRegistry: %d parts, %d palettes, patterns: %s."
		% [parts.size(), palettes.size(), pattern_names])


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
			if socket.accepts(p):
				out.append(p)
	return out


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
	var names: Array[StringName] = []
	for socket in def.sockets:
		if names.has(socket.name):
			push_error("%s: two sockets are called '%s'." % [where, socket.name])
		if socket.accepts_type.is_empty():
			push_error("%s: socket '%s' accepts no type, it can never be filled."
				% [where, socket.name])
		# copy_from must name a socket listed EARLIER (it's filled first).
		if socket.copy_from != &"" and not names.has(socket.copy_from):
			push_error("%s: socket '%s' copies '%s', which must be an earlier socket."
				% [where, socket.name, socket.copy_from])
		names.append(socket.name)

	var group_of := {}  # socket name -> group, to catch sockets in 2 groups
	for layout in def.layouts:
		if layout == null:
			push_error("%s: empty entry in layouts." % where)
			continue
		for socket_name in layout.sockets:
			var socket := def.get_socket(StringName(socket_name))
			if socket == null:
				push_error("%s: layout in group '%s' names unknown socket '%s'."
					% [where, layout.group, socket_name])
				continue
			if group_of.get(socket_name, layout.group) != layout.group:
				push_error("%s: socket '%s' is in groups '%s' and '%s'."
					% [where, socket_name, group_of[socket_name], layout.group])
			group_of[socket_name] = layout.group
			# A copy without its source would be filled with a random part,
			# so e.g. a "far eye only" layout would get a mismatched eye.
			if socket.copy_from != &"" and not layout.sockets.has(socket.copy_from):
				push_error("%s: a layout in group '%s' has '%s' but not its copy source '%s'."
					% [where, layout.group, socket_name, socket.copy_from])


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
