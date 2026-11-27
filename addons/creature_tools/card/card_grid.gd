## A square grid of cells drawn top-down, used by the card preview panel.
## It only DRAWS what it's told (cell colors, a unit with an arrow, a
## highlighted cell, crossed-out cells) and reports the mouse: which cell
## is hovered, which one was clicked. It knows nothing about cards.
##
## Cells are in "grid space": the top-left cell is `first_cell`, x grows to
## the right and y grows DOWN (same as Grid: Facing.DOWN is (0, 1)).
@tool
extends Control

## The mouse moved onto another cell; `has_cell` is false when it left the grid.
signal cell_hovered(cell: Vector2i, has_cell: bool)
## A cell was clicked (MOUSE_BUTTON_LEFT / MOUSE_BUTTON_RIGHT).
signal cell_clicked(cell: Vector2i, button: int)

const GRID_LINE := Color(1, 1, 1, 0.18)
const EMPTY_CELL := Color(0, 0, 0, 0.25)
const UNIT_COLOR := Color(0.35, 0.85, 0.45)
const HIGHLIGHT := Color(1.0, 0.9, 0.3)
const CROSS := Color(1, 1, 1, 0.8)

## Grid size in cells, and the grid-space coordinate of the top-left cell.
var cells := Vector2i(5, 5)
var first_cell := Vector2i.ZERO
## Size of one cell, in pixels.
var cell_px := 22

## cell -> fill Color. Cells not listed are drawn empty.
var fills: Dictionary = {}
## The unit (user) drawn as a circle with an arrow; hidden if show_unit is off.
var show_unit := true
var unit_cell := Vector2i.ZERO
## Direction of the arrow (a Grid.Facing).
var unit_facing: int = 0
## Cells drawn with a yellow frame (e.g. the target).
var highlighted: Array[Vector2i] = []
## Cells drawn with an X (e.g. "in the area, but not hit").
var crossed: Array[Vector2i] = []
## Text drawn small in a corner of a cell: cell -> String (e.g. hit order).
var labels: Dictionary = {}
## Greyed out and ignores the mouse (e.g. a part of the card that's unused).
var disabled := false

var _hover := Vector2i.ZERO
var _has_hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Call after changing the fields above: resizes and redraws.
func refresh() -> void:
	custom_minimum_size = Vector2(cells * cell_px) + Vector2.ONE
	queue_redraw()


func _draw() -> void:
	var dim := 0.35 if disabled else 1.0
	for y in cells.y:
		for x in cells.x:
			var cell := first_cell + Vector2i(x, y)
			var rect := _rect_of(cell)
			var fill: Color = fills.get(cell, EMPTY_CELL)
			draw_rect(rect, Color(fill, fill.a * dim))
			draw_rect(rect, GRID_LINE, false, 1.0)
			if crossed.has(cell):
				var r := rect.grow(-cell_px * 0.25)
				draw_line(r.position, r.end, Color(CROSS, CROSS.a * dim), 2.0)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y),
					Color(CROSS, CROSS.a * dim), 2.0)
			if labels.has(cell):
				draw_string(get_theme_default_font(), rect.position + Vector2(2, 9),
					str(labels[cell]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9 * dim))
	for cell in highlighted:
		if _contains(cell):
			draw_rect(_rect_of(cell).grow(-1), Color(HIGHLIGHT, dim), false, 2.0)
	if show_unit and _contains(unit_cell):
		_draw_unit(_rect_of(unit_cell), dim)
	if _has_hover and not disabled:
		draw_rect(_rect_of(_hover).grow(-1), Color(1, 1, 1, 0.6), false, 1.0)


## The unit: a circle with an arrow pointing to its facing.
func _draw_unit(rect: Rect2, dim: float) -> void:
	var center := rect.get_center()
	var radius := cell_px * 0.26
	draw_circle(center, radius, Color(UNIT_COLOR, dim))
	# A white arrowhead from the circle's center to the cell's edge.
	var dir := Vector2(Grid.STEPS[unit_facing])
	var tip := center + dir * cell_px * 0.5
	var side := Vector2(-dir.y, dir.x) * cell_px * 0.22
	draw_colored_polygon(PackedVector2Array([tip, center + side, center - side]), Color(1, 1, 1, dim))


func _rect_of(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell - first_cell) * cell_px, Vector2.ONE * cell_px)


func _contains(cell: Vector2i) -> bool:
	var local := cell - first_cell
	return local.x >= 0 and local.y >= 0 and local.x < cells.x and local.y < cells.y


func _cell_at(pos: Vector2) -> Vector2i:
	return first_cell + Vector2i((pos / cell_px).floor())


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		var inside := _contains(cell)
		if inside != _has_hover or cell != _hover:
			_hover = cell
			_has_hover = inside
			cell_hovered.emit(cell, inside)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(event.position)
		if _contains(cell) and (event.button_index == MOUSE_BUTTON_LEFT
				or event.button_index == MOUSE_BUTTON_RIGHT):
			cell_clicked.emit(cell, event.button_index)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _has_hover:
		_has_hover = false
		cell_hovered.emit(_hover, false)
		queue_redraw()
