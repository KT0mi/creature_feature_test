## Inspector panel for a BattleCard: shows where it can be aimed and what
## it hits, and lets you edit `pattern` and `area` by clicking cells.
##
## BOARD (top): the real 5x5 board, top-down. The user (green, arrow = its
## facing) stands on a cell you choose (right-click a cell to move it) and
## faces the direction picked above the board.
##   blue    cells the card can target from there (`pattern` rotated to the
##           facing; movement cards: only cells it can reach on an empty
##           board, unreachable ones are crossed out)
##   orange  cells HIT when aiming at the hovered target (or the clicked
##           one, which stays pinned until clicked again); numbers = the
##           order they're hit in (matters for pushes)
##   X       the user's cell is in the area but hits_self is off
## Aim SELF cards show their area right away, around the user.
## Offsets falling off the board are dropped, as in battle.
##
## EDIT (bottom): `pattern` and `area` in authoring space: offsets around
## the user (pattern) or the target (area), facing / aiming RIGHT (->).
## Left-click a cell to add or remove it (undoable with Ctrl+Z).
##
## The board is drawn top-down: RIGHT here is "down-right" on the battle
## screen's isometric board, DOWN is "down-left", and so on.
@tool
extends VBoxContainer

const CardGrid := preload("res://addons/creature_tools/card/card_grid.gd")
const BASE_CARD_SCRIPT := preload("res://core/battle/battle_card.gd")

const PATTERN_COLOR := Color(0.3, 0.55, 1.0, 0.6)
const AREA_COLOR := Color(1.0, 0.5, 0.2, 0.85)
const ORIGIN_COLOR := Color(0.35, 0.85, 0.45, 0.35)
const WARNING_COLOR := Color(1, 0.45, 0.4)
const FACING_NAMES := ["Right", "Down", "Left", "Up"]

# Board settings are kept between panels (the inspector rebuilds this panel
# whenever an array changes size), so they don't reset on every edit.
static var _user_cell := Vector2i(2, 2)
static var _facing := 0
static var _pinned := Vector2i.ZERO
static var _has_pinned := false

var _card: BattleCard
var _undo: EditorUndoRedoManager  # null outside the editor: edits aren't undoable

var _info: Label
var _effects: Label
var _warnings: Label
var _facing_choice: OptionButton
var _board: CardGrid
var _pattern_grid: CardGrid
var _area_grid: CardGrid
var _pattern_note: Label
var _area_note: Label
var _hover := Vector2i.ZERO
var _has_hover := false
var _refresh_queued := false


func _init(card: BattleCard, undo: EditorUndoRedoManager = null) -> void:
	_card = card
	_undo = undo
	_build_ui()


func _ready() -> void:
	_card.changed.connect(_queue_refresh)
	# Edits in the regular inspector (typing an offset) don't emit `changed`.
	if Engine.is_editor_hint():
		EditorInterface.get_inspector().property_edited.connect(_on_property_edited)
	_refresh()


func _exit_tree() -> void:
	if _card.changed.is_connected(_queue_refresh):
		_card.changed.disconnect(_queue_refresh)
	if Engine.is_editor_hint() and EditorInterface.get_inspector().property_edited.is_connected(_on_property_edited):
		EditorInterface.get_inspector().property_edited.disconnect(_on_property_edited)


# ----------------------------------------------------------------------- UI

func _build_ui() -> void:
	var title := Label.new()
	title.text = "Card preview"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_effects = Label.new()
	_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effects.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	add_child(_effects)
	_warnings = Label.new()
	_warnings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warnings.add_theme_color_override("font_color", WARNING_COLOR)
	add_child(_warnings)

	# --- Board
	var board_row := HBoxContainer.new()
	var board_label := Label.new()
	board_label.text = "Board   facing"
	board_row.add_child(board_label)
	_facing_choice = OptionButton.new()
	for name in FACING_NAMES:
		_facing_choice.add_item(name)
	_facing_choice.item_selected.connect(func(i: int) -> void:
		_facing = i
		_has_pinned = false
		_refresh())
	board_row.add_child(_facing_choice)
	add_child(board_row)

	_board = CardGrid.new()
	_board.cells = Vector2i(Grid.SIZE, Grid.SIZE)
	_board.cell_px = 30
	_board.cell_hovered.connect(_on_board_hovered)
	_board.cell_clicked.connect(_on_board_clicked)
	add_child(_center(_board))
	var hint := Label.new()
	hint.text = "Hover / click a blue cell: what it hits. Right-click: move the user."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(hint)

	# --- Authoring grids
	add_child(HSeparator.new())
	var edit_label := Label.new()
	edit_label.text = "Edit (click to add / remove; -> = forward)"
	add_child(edit_label)
	var edit_row := HBoxContainer.new()
	edit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	edit_row.add_theme_constant_override("separation", 16)
	var pattern_box := _grid_box("Pattern (from the user)")
	_pattern_grid = pattern_box.get_meta("grid")
	_pattern_note = pattern_box.get_meta("note")
	_pattern_grid.cell_clicked.connect(func(cell: Vector2i, button: int) -> void:
		if button == MOUSE_BUTTON_LEFT:
			_toggle(&"pattern", cell))
	edit_row.add_child(pattern_box)
	var area_box := _grid_box("Area (from the target)")
	_area_grid = area_box.get_meta("grid")
	_area_note = area_box.get_meta("note")
	_area_grid.cell_clicked.connect(func(cell: Vector2i, button: int) -> void:
		if button == MOUSE_BUTTON_LEFT:
			_toggle(&"area", cell))
	edit_row.add_child(area_box)
	add_child(edit_row)


## A titled authoring grid with a note under it. The grid and the note are
## stored as metadata on the box so the caller can keep them.
func _grid_box(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	var grid := CardGrid.new()
	grid.cell_px = 18
	box.add_child(grid)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 120
	box.add_child(note)
	box.set_meta("grid", grid)
	box.set_meta("note", note)
	return box


func _center(control: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.add_child(control)
	return c


# ------------------------------------------------------------------ refresh

func _on_property_edited(_property: String) -> void:
	_queue_refresh()


## Several changes in one frame (e.g. undo) refresh only once.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	_facing_choice.select(_facing)
	_info.text = _info_text()
	var effects := _card.summary()
	_effects.text = effects if effects != "" else "(no effects)"
	var warnings := _warnings_list()
	_warnings.text = "\n".join(warnings)
	_warnings.visible = not warnings.is_empty()
	_refresh_board()
	_refresh_authoring()


## "Attack - aim CELL - 3 targets - area 5 cells - cooldown 1"
func _info_text() -> String:
	var parts := PackedStringArray()
	parts.append("Move" if _card.kind == BattleCard.Kind.MOVE else "Attack")
	if _card.is_reaction():
		parts.append("reaction")
	parts.append("aim SELF" if _card.aim == BattleCard.Aim.SELF else "aim CELL")
	if _uses_pattern():
		parts.append("%d target offset(s)" % _card.pattern.size())
	if _uses_area():
		parts.append("area %d cell(s)" % _card.area.size())
	if _card.cooldown > 0:
		parts.append("cooldown %d" % _card.cooldown)
	if _card.kind == BattleCard.Kind.ATTACK:
		parts.append("hits self" if _card.hits_self else "never self")
		parts.append("hits allies" if _card.hits_allies else "never allies")
	return "  -  ".join(parts)


## Things that are probably mistakes in the card's data.
func _warnings_list() -> PackedStringArray:
	var out := PackedStringArray()
	if _uses_pattern() and _card.pattern.is_empty():
		out.append("No pattern: this card can never be played (no cell to aim at).")
	if _uses_area() and _card.area.is_empty():
		out.append("Empty area: this attack hits nothing.")
	if _has_duplicates(_card.pattern):
		out.append("The pattern lists the same offset twice.")
	if _has_duplicates(_card.area):
		out.append("The area lists the same offset twice.")
	if _uses_pattern() and _card.pattern.has(Vector2i.ZERO):
		out.append("The pattern includes the user's own cell (0, 0).")
	if _card.get_script() != BASE_CARD_SCRIPT:
		out.append("Script card: shown from its pattern / area data; its script may target or hit differently.")
	return out


func _has_duplicates(list: Array[Vector2i]) -> bool:
	var seen := {}
	for v in list:
		if seen.has(v):
			return true
		seen[v] = true
	return false


## The pattern matters only for aim CELL cards (reactions with no pattern
## are played on their user).
func _uses_pattern() -> bool:
	return _card.aim == BattleCard.Aim.CELL and not (_card.is_reaction() and _card.pattern.is_empty())


## The area matters only for attacks (movement cards just go to the target).
func _uses_area() -> bool:
	return _card.kind == BattleCard.Kind.ATTACK and not _card.is_reaction()


# -------------------------------------------------------------------- board

func _refresh_board() -> void:
	_board.fills.clear()
	_board.crossed.clear()
	_board.highlighted.clear()
	_board.labels.clear()
	_board.unit_cell = _user_cell
	_board.unit_facing = _facing
	var user := _dummy_user()
	var targets := _board_targets(user)
	for cell in targets:
		_board.fills[cell] = PATTERN_COLOR
	# Unreachable movement targets: crossed out.
	for cell in _board_pattern_cells():
		if not targets.has(cell):
			_board.crossed.append(cell)

	# Which target's area to show: the pinned one, else the hovered one;
	# aim SELF (and pattern-less reactions) always target the user's cell.
	var target := Vector2i.ZERO
	var has_target := false
	if not _uses_pattern():
		target = _user_cell
		has_target = true
	elif _has_pinned and targets.has(_pinned):
		target = _pinned
		has_target = true
	elif _has_hover and targets.has(_hover):
		target = _hover
		has_target = true
	if has_target:
		_board.highlighted.append(target)
		if _uses_area():
			var hit := _affected_cells(user, target)
			for i in hit.size():
				_board.fills[hit[i]] = AREA_COLOR
				_board.labels[hit[i]] = i + 1
				if hit[i] == _user_cell and not _card.hits_self:
					_board.crossed.append(hit[i])
	_board.refresh()


## The pattern on the board: rotated to the facing, kept on the board.
func _board_pattern_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _uses_pattern():
		return out
	for offset in _card.pattern:
		var cell := _user_cell + Grid.rotate(offset, _facing)
		if Grid.in_bounds(cell) and not out.has(cell):
			out.append(cell)
	return out


## Cells the card can target on an EMPTY board (only the user on it).
## Same rules as BattleCard.targets(): movement cards need a free cell and,
## with a MoveSelfEffect, a path for its mode.
func _board_targets(user: BattleUnit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _uses_pattern():
		out.append(_user_cell)
		return out
	var is_free := func(c: Vector2i) -> bool: return Grid.in_bounds(c) and c != _user_cell
	var move := _card.move_effect() if _card.kind == BattleCard.Kind.MOVE else null
	for cell in _board_pattern_cells():
		if _card.kind == BattleCard.Kind.MOVE and not is_free.call(cell):
			continue
		if move != null and Grid.find_path(user.position, cell, move.mode, user.facing,
				is_free).is_empty():
			continue
		out.append(cell)
	return out


## Cells hit when aiming at `target`, in the order they're hit. Uses the
## card's own affected_cells() for plain data cards (exactly what the game
## does; it doesn't need the battle for them).
func _affected_cells(user: BattleUnit, target: Vector2i) -> Array[Vector2i]:
	if _card.get_script() == BASE_CARD_SCRIPT:
		return _card.affected_cells(null, user, target)
	# Script cards might read the battle in an override: use the data only.
	var dir := _card.aim_direction(user, target)
	var out: Array[Vector2i] = []
	for offset in _card.area:
		var cell := target + Grid.rotate(offset, dir)
		if Grid.in_bounds(cell) and not out.has(cell):
			out.append(cell)
	return out


## A unit that only has a position and a facing: enough for aim_direction()
## and affected_cells(). Never part of a battle.
func _dummy_user() -> BattleUnit:
	var user := BattleUnit.new()
	user.position = _user_cell
	user.facing = _facing
	return user


func _on_board_hovered(cell: Vector2i, has_cell: bool) -> void:
	_hover = cell
	_has_hover = has_cell
	if not _has_pinned:
		_refresh_board()


func _on_board_clicked(cell: Vector2i, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_user_cell = cell
		_has_pinned = false
	elif _has_pinned and _pinned == cell:
		_has_pinned = false  # click the pinned target again to unpin
	elif _board_targets(_dummy_user()).has(cell):
		_pinned = cell
		_has_pinned = true
	_refresh_board()


# ---------------------------------------------------------------- authoring

func _refresh_authoring() -> void:
	# Big enough for every offset, at least 7x7 and at most 17x17.
	var reach := 3
	var offsets: Array = []  # untyped: typed arrays can't be concatenated with +
	offsets.append_array(_card.pattern)
	offsets.append_array(_card.area)
	for v in offsets:
		reach = maxi(reach, maxi(absi(v.x), absi(v.y)) + 1)
	reach = mini(reach, 8)
	for grid in [_pattern_grid, _area_grid]:
		grid.cells = Vector2i.ONE * (reach * 2 + 1)
		grid.first_cell = -Vector2i.ONE * reach
		grid.fills.clear()

	# Pattern: around the user, who faces right.
	_pattern_grid.unit_cell = Vector2i.ZERO
	_pattern_grid.unit_facing = Grid.Facing.RIGHT
	for v in _card.pattern:
		_pattern_grid.fills[v] = PATTERN_COLOR
	_pattern_grid.disabled = not _uses_pattern() and not _card.is_reaction()
	_pattern_note.text = "aim SELF: not used" if _card.aim == BattleCard.Aim.SELF else \
		"%d offset(s)" % _card.pattern.size()

	# Area: around the target (yellow frame), aiming right.
	_area_grid.show_unit = false
	_area_grid.highlighted.clear()
	_area_grid.highlighted.append(Vector2i.ZERO)
	_area_grid.fills[Vector2i.ZERO] = ORIGIN_COLOR
	for v in _card.area:
		_area_grid.fills[v] = AREA_COLOR
	_area_grid.disabled = not _uses_area()
	if _card.kind == BattleCard.Kind.MOVE:
		_area_note.text = "movement card: not used"
	elif _card.is_reaction():
		_area_note.text = "reaction: not used"
	else:
		_area_note.text = "%d cell(s); yellow = target" % _card.area.size()
	_pattern_grid.refresh()
	_area_grid.refresh()


## Adds `offset` to the card's `property` (pattern / area), or removes it if
## it's there. Undoable in the editor.
func _toggle(property: StringName, offset: Vector2i) -> void:
	var old: Array[Vector2i] = _card.get(property).duplicate()
	var new: Array[Vector2i] = old.duplicate()
	if new.has(offset):
		new.erase(offset)
	else:
		new.append(offset)
	if _undo == null:
		_card.set(property, new)
		_card.emit_changed()
		return
	_undo.create_action("%s: toggle %s cell %s" % [_card.name, property, offset])
	_undo.add_do_property(_card, property, new)
	_undo.add_undo_property(_card, property, old)
	# The card doesn't emit `changed` by itself when a property is set, and
	# the inspector needs to redraw its arrays: done on do AND undo.
	for method in [&"emit_changed", &"notify_property_list_changed"]:
		_undo.add_do_method(_card, method)
		_undo.add_undo_method(_card, method)
	_undo.commit_action()
