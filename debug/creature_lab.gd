## Debug scene: a grid of generated creatures, to spot bad sockets and
## proportions quickly. Also a regression test: the same seed must always
## show the same grid.
##
## Controls
##   R            next seed (new random grid)      Shift+R  previous seed
##   Left click   select a creature (up to 2)
##   F            fuse the 2 selected: cell 1 = parent A, cell 2 = parent B,
##                every other cell = a child with a different fusion seed
##   Esc          clear selection / back to the random grid
##   P            print the selected creatures (name, stats, cards, genome IDs)
##                to the Output panel
##   Arrows/WASD  move the camera       Mouse wheel / +/-  zoom
extends Node2D

@export var columns := 6
@export var rows := 6
## Size of one grid cell in pixels. Should be >= CreatureGenerator.MAX_SIZE
## plus the outline padding so creatures never overlap.
@export var cell_size := Vector2i(136, 136)
## First seed shown when the scene starts.
@export var start_seed := 1
## Animation speed of the creatures.
@export var frames_per_second := 4.0
@export var camera_speed := 300.0

@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $HUD/Label

var generator: CreatureGenerator
var grid_seed := 0
## Genome shown in each cell (null for empty cells).
var genomes: Array[Genome] = []
## Sprite2D of each cell.
var sprites: Array[Sprite2D] = []
## Indices of selected cells (max 2).
var selected: Array[int] = []
## When fusing, the two parents; empty while showing a random grid.
var fusion_parents: Array[Genome] = []
var _anim_time := 0.0


func _ready() -> void:
	generator = CreatureGenerator.new(PartRegistry)
	grid_seed = start_seed
	# Start with the whole grid visible-ish at zoom 1 from the top-left.
	camera.position = Vector2(get_viewport_rect().size / 2.0)
	_build_random_grid()


func _process(delta: float) -> void:
	# Camera movement (debug only, so raw keys instead of the InputMap).
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D))
			- float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S))
			- float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	# Divided by zoom so panning feels the same speed at every zoom level.
	# (No rounding needed: "Snap 2D Transforms to Pixel" is on in the project.)
	camera.position += dir * camera_speed * delta / camera.zoom.x

	# Step every creature's animation in sync.
	_anim_time += delta
	var step := int(_anim_time * frames_per_second)
	for s in sprites:
		if s.hframes > 1:
			s.frame = step % s.hframes


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				grid_seed += -1 if event.shift_pressed else 1
				_build_random_grid()
			KEY_F:
				_fuse_selected()
			KEY_ESCAPE:
				if selected.is_empty() and not fusion_parents.is_empty():
					_build_random_grid()
				selected.clear()
				queue_redraw()
			KEY_P:
				for i in selected:
					var profile := CombatProfile.from_genome(genomes[i], PartRegistry)
					print("cell %d: %s\n  %s\n  cards: %s\n  %s" % [i,
						CreatureNamer.name_of(genomes[i], PartRegistry),
						profile.describe_stats(), profile.describe_cards(),
						JSON.stringify(genomes[i].to_dict())])
			KEY_EQUAL, KEY_KP_ADD:
				_zoom(2.0)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom(0.5)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_toggle_select(_cell_at(get_global_mouse_position()))
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(2.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(0.5)


## Zoom in powers of two. >= 1 stays pixel-perfect; < 1 is just for overview.
func _zoom(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.25, Vector2.ONE * 8.0)


# ------------------------------------------------------------------- grids

func _build_random_grid() -> void:
	fusion_parents.clear()
	selected.clear()
	var list: Array[Genome] = []
	for i in columns * rows:
		# Each cell gets its own seed derived from the grid seed, so a single
		# creature can be reproduced on its own with random_genome(seed).
		list.append(generator.random_genome(grid_seed * 1000 + i))
	_show(list)


func _fuse_selected() -> void:
	if selected.size() != 2:
		_update_hud("Select exactly 2 creatures to fuse.")
		return
	var a := genomes[selected[0]]
	var b := genomes[selected[1]]
	fusion_parents = [a, b]
	selected.clear()
	var list: Array[Genome] = [a, b]
	for i in columns * rows - 2:
		# Same parents, different fusion seed -> different children.
		list.append(generator.fuse_genomes(a, b, hash([a.seed, b.seed, i])))
	_show(list)


## Replaces the grid content with `list` (one genome per cell).
func _show(list: Array[Genome]) -> void:
	for s in sprites:
		s.queue_free()
	sprites.clear()
	genomes = list
	for i in list.size():
		var sprite := Sprite2D.new()
		sprite.centered = false
		var g := list[i]
		if g != null and g.root != null:
			var baked := CreatureBaker.bake(g, PartRegistry.palettes, PartRegistry.key)
			sprite.texture = baked.texture
			sprite.hframes = baked.frame_count
			# Center the frame inside its cell, on whole pixels.
			sprite.position = Vector2(_cell_origin(i) + (cell_size - baked.frame_size) / 2)
		add_child(sprite)
		sprites.append(sprite)
	queue_redraw()
	_update_hud()


# --------------------------------------------------------------- selection

func _toggle_select(index: int) -> void:
	if index < 0 or index >= genomes.size() or genomes[index] == null:
		return
	if selected.has(index):
		selected.erase(index)
	else:
		if selected.size() == 2:
			selected.pop_front()  # keep the 2 most recent clicks
		selected.append(index)
	queue_redraw()
	_update_hud()


func _cell_origin(index: int) -> Vector2i:
	return Vector2i(index % columns, index / columns) * cell_size


## Cell index under a world position, or -1.
func _cell_at(world: Vector2) -> int:
	var c := Vector2i((world / Vector2(cell_size)).floor())
	if c.x < 0 or c.y < 0 or c.x >= columns or c.y >= rows:
		return -1
	return c.y * columns + c.x


## Draws the cell borders, the selection and the fusion parents.
## _draw() of a parent renders BEHIND its children, so creatures stay on top.
func _draw() -> void:
	for i in columns * rows:
		draw_rect(Rect2(_cell_origin(i), cell_size), Color(1, 1, 1, 0.08), false)
	if not fusion_parents.is_empty():
		for i in 2:
			draw_rect(Rect2(_cell_origin(i), cell_size), Color(0.3, 0.6, 1.0, 0.25), true)
	for i in selected:
		draw_rect(Rect2(_cell_origin(i) + Vector2i.ONE, cell_size - Vector2i.ONE * 2),
			Color.YELLOW, false)


func _update_hud(extra: String = "") -> void:
	var lines: PackedStringArray = []
	if PartRegistry.parts.is_empty():
		lines.append("No parts found in %s" % PartRegistry.PARTS_DIR)
	elif fusion_parents.is_empty():
		lines.append("seed %d   R/Shift+R: seed   click: select   F: fuse" % grid_seed)
	else:
		lines.append("fusion of seeds %d x %d   Esc: back" % [fusion_parents[0].seed, fusion_parents[1].seed])
	lines.append("selected: %s   P: print   wheel/+/-: zoom   arrows: move" % [selected])
	# Names of the selected creatures.
	for i in selected:
		lines.append("  %d: %s" % [i, CreatureNamer.name_of(genomes[i], PartRegistry)])
		# Battle numbers derived from the parts (see CombatProfile).
		var profile := CombatProfile.from_genome(genomes[i], PartRegistry)
		lines.append("     %s" % profile.describe_stats())
		lines.append("     cards: %s" % profile.describe_cards())
	if extra != "":
		lines.append(extra)
	hud.text = "\n".join(lines)
