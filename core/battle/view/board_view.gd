##Isometric 5x5 grid.
class_name BoardView
extends Node2D

## Size of the rectangle one isometric cell (diamond) fits in.
@export var cell_size := Vector2i(166, 83)

## Optional tile art, cell_size big, with the diamond centered. Leave empty
## for placeholder diamonds drawn in code.
@export var tile_texture: Texture2D


const COLOR_LIGHT := Color(0.33, 0.36, 0.42)
const COLOR_DARK := Color(0.28, 0.31, 0.37)
const COLOR_EDGE := Color(0.12, 0.13, 0.16)
const COLOR_HOVER := Color(1.0, 0.9, 0.3)

## What a highlighted cell means (colors below).
enum Mark { MOVE, TARGET, AREA, PATH, SELECTED }
const MARK_COLORS := {
	Mark.MOVE: Color(0.3, 0.6, 1.0, 0.45),
	Mark.TARGET: Color(1.0, 0.55, 0.2, 0.45),
	Mark.AREA: Color(1.0, 0.2, 0.2, 0.5),
	Mark.PATH: Color(0.4, 0.9, 1.0, 0.55),
	Mark.SELECTED: Color(1.0, 1.0, 1.0, 0.3),
}


## cell (Vector2i) -> Mark. Set with set_marks(); several layers merge,
## later ones on top.
var _marks: Array[Dictionary] = []
var _hover := Vector2i(-1, -1)
## cell -> text drawn on the cell (e.g. a trap symbol), set by the scene.
var cell_labels: Dictionary = {}



# --------------------------------------------------------------- geometry

## Screen position (relative to this node) of the TOP corner of `cell`.
func cell_top(cell: Vector2i) -> Vector2:
	return Vector2(floori((cell.x - cell.y) * cell_size.x / 2.0),
		floori((cell.x + cell.y) * cell_size.y / 2.0))


## Center of `cell`: where a creature's feet go.
func cell_center(cell: Vector2i) -> Vector2:
	return cell_top(cell) + Vector2(0, floori(cell_size.y / 2.0))

## The grid cell under `local` (a position relative to this node), or
## (-1, -1) if it's off the board.
func cell_at(local: Vector2) -> Vector2i:
	# Inverse of cell_top: x - y = 2 px / W, x + y = 2 py / H.
	var u := local.x / (cell_size.x / 2.0)
	var v := local.y / (cell_size.y / 2.0)
	var cell := Vector2i(floori((u + v) / 2.0), floori((v - u) / 2.0))
	return cell if Grid.in_bounds(cell) else Vector2i(-1, -1)


## Size of the whole board's bounding box, and its top-left corner
## relative to this node (the board is centered on x = 0).
func board_rect() -> Rect2:
	var w := Grid.SIZE * cell_size.x
	var h := Grid.SIZE * cell_size.y
	return Rect2(-w / 2.0, 0, w, h)


## The 4 corners of `cell`'s diamond (top, right, bottom, left).
func diamond(cell: Vector2i) -> PackedVector2Array:
	var top := cell_top(cell)
	var hw := cell_size.x / 2.0
	var hh := cell_size.y / 2.0
	return PackedVector2Array([top, top + Vector2(hw, hh), top + Vector2(0, cell_size.y),
		top + Vector2(-hw, hh)])


# ------------------------------------------------------------- highlights

## Replaces all highlights with `layers` (each a Dictionary cell -> Mark,
## drawn in order).
func set_marks(layers: Array[Dictionary]) -> void:
	_marks = layers
	queue_redraw()


func clear_marks() -> void:
	_marks = []
	queue_redraw()


func set_hover(cell: Vector2i) -> void:
	if cell != _hover:
		_hover = cell
		queue_redraw()



# ---------------------------------------------------------------- drawing

func _draw() -> void:
	for y in Grid.SIZE:
		for x in Grid.SIZE:
			var cell := Vector2i(x, y)
			if tile_texture:
				draw_texture(tile_texture, cell_top(cell) - Vector2(cell_size.x / 2.0, 0).floor())
			else:
				var color := COLOR_LIGHT if (x + y) % 2 == 0 else COLOR_DARK
				draw_colored_polygon(diamond(cell), color)
				_outline(cell, COLOR_EDGE, 1.0)
	for layer in _marks:
		for cell in layer:
			draw_colored_polygon(_inset(cell, 3.0), MARK_COLORS[layer[cell]])
	var font := ThemeDB.fallback_font
	for cell in cell_labels:
		var c := cell_center(cell)
		draw_string(font, c + Vector2(-20, 6), String(cell_labels[cell]),
			HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color(1, 1, 1, 0.85))
	if Grid.in_bounds(_hover):
		_outline(_hover, COLOR_HOVER, 2.0)


func _outline(cell: Vector2i, color: Color, width: float) -> void:
	var d := diamond(cell)
	d.append(d[0])
	draw_polyline(d, color, width)


## The diamond shrunk by `px` pixels, so neighbouring highlights stay apart.
func _inset(cell: Vector2i, px: float) -> PackedVector2Array:
	var d := diamond(cell)
	var c := cell_center(cell)
	var out := PackedVector2Array()
	for p in d:
		out.append(p + (c - p).normalized() * px)
	return out
