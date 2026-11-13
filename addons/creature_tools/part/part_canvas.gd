## The drawing area of the part editor: the part's frame at an integer zoom,
## example children in their sockets, and markers for the attach pixel and
## every socket.
##
## It only DRAWS and reports mouse input in part pixels; the part editor
## screen decides what a click means and changes the data.
##   Left click / drag   reported via pixel_pressed / pixel_dragged / released
##   Middle drag         pan        Mouse wheel   zoom (around the cursor)
@tool
extends Control

## Left button went down on part pixel `pixel` (may be outside the frame).
signal pixel_pressed(pixel: Vector2i)
## Mouse moved to `pixel` while the left button is held.
signal pixel_dragged(pixel: Vector2i)
## Left button released.
signal released()

## Selection codes shared with the editor screen.
const SELECT_NONE := -2
const SELECT_ATTACH := -1

const ATTACH_COLOR := Color(1.0, 0.25, 0.25)
const SELECTED_COLOR := Color(1.0, 0.9, 0.2)
## One color per socket index, cycling.
const SOCKET_COLORS: Array[Color] = [
	Color(0.3, 0.7, 1.0), Color(0.4, 1.0, 0.5), Color(1.0, 0.55, 0.9),
	Color(1.0, 0.65, 0.3), Color(0.6, 0.5, 1.0), Color(0.3, 1.0, 0.95)]

## The part being drawn (null = nothing).
var part: PartDef
## Frame of the part being shown/edited.
var frame := 0
## Screen pixels per art pixel.
var zoom := 8
## Screen position of the part's pixel (0, 0).
var origin := Vector2(48, 48)
## Selected marker: SELECT_ATTACH, a socket index, or SELECT_NONE.
var selection := SELECT_NONE
## Example parts to draw, prepared by the editor screen. Each entry:
##   { "part": PartDef, "frame": int, "pos": Vector2i (top-left in part
##     pixels), "flip": bool, "z": int, "socket": int }
var examples: Array[Dictionary] = []
## Draw examples semi-transparent, so the part under them stays visible.
var examples_alpha := 1.0

var _panning := false
var _dragging := false
## "Mouse not over the canvas" value for _hover.
const NO_HOVER := Vector2i(-9999, -9999)
var _hover := NO_HOVER


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixels
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP


## Color used for socket `index`'s marker and list entry.
static func socket_color(index: int) -> Color:
	return SOCKET_COLORS[index % SOCKET_COLORS.size()]


## Part pixel under a position in this control's coordinates.
func pixel_at(local_pos: Vector2) -> Vector2i:
	return Vector2i(((local_pos - origin) / zoom).floor())


## Centers the part in the control at a zoom that fits it.
func frame_part() -> void:
	if part == null or part.sheet == null:
		return
	var size_px := Vector2(part.get_frame_size())
	# Leave room around the part for children that stick out.
	var fit := mini(int(size.x / (size_px.x * 2.0)), int(size.y / (size_px.y * 2.0)))
	zoom = clampi(fit, 2, 16)
	origin = ((size - size_px * zoom) / 2.0).floor()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = NO_HOVER
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
				if event.pressed:
					grab_focus()
					pixel_pressed.emit(pixel_at(event.position))
				else:
					released.emit()
				accept_event()
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				accept_event()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			origin += event.relative
			queue_redraw()
		var pixel := pixel_at(event.position)
		if pixel != _hover:
			_hover = pixel
			queue_redraw()
			if _dragging:
				pixel_dragged.emit(pixel)


## Zoom by one step, keeping the pixel under the mouse in place.
func _zoom_at(mouse: Vector2, step: int) -> void:
	var new_zoom := clampi(zoom + step * maxi(1, zoom / 4), 1, 48)
	if new_zoom == zoom:
		return
	var art_pos := (mouse - origin) / zoom
	zoom = new_zoom
	origin = (mouse - art_pos * zoom).floor()
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.14, 0.17))
	if part == null:
		_draw_message("Select a PartDef (.tres) in the FileSystem to edit it here.")
		return
	if part.sheet == null:
		_draw_message("This part has no sheet texture yet. Set it in the inspector.")
		return

	var frame_size := part.get_frame_size()
	var part_rect := Rect2(origin, Vector2(frame_size * zoom))
	_draw_checker(part_rect)

	# Same stacking rule as the baker: lower z first; the parent (z = 0)
	# goes before children with the same z.
	var behind := examples.filter(func(e): return e.z < 0)
	var in_front := examples.filter(func(e): return e.z >= 0)
	behind.sort_custom(func(a, b): return a.z < b.z)
	in_front.sort_custom(func(a, b): return a.z < b.z)
	for e in behind:
		_draw_part(e.part, e.frame, e.pos, e.flip, examples_alpha)
	_draw_part(part, frame, Vector2i.ZERO, false, 1.0)
	for e in in_front:
		_draw_part(e.part, e.frame, e.pos, e.flip, examples_alpha)

	if zoom >= 6:
		_draw_grid(part_rect, frame_size)
	draw_rect(part_rect, Color(1, 1, 1, 0.35), false, 1.0)

	# Markers on top of everything.
	for i in part.sockets.size():
		var socket := part.sockets[i]
		if socket == null:
			continue
		var color := SELECTED_COLOR if selection == i else socket_color(i)
		_draw_marker(socket.position_at(frame), color, String(socket.name),
			socket.copy_from != &"", selection == i)
	_draw_marker(part.attach, SELECTED_COLOR if selection == SELECT_ATTACH else ATTACH_COLOR,
		"attach", false, selection == SELECT_ATTACH)

	# Coordinates of the pixel under the mouse.
	var font := get_theme_default_font()
	var where := "pixel %d, %d   " % [_hover.x, _hover.y] if _hover != NO_HOVER else ""
	draw_string(font, Vector2(8, size.y - 8), "%szoom %dx   frame %d/%d"
		% [where, zoom, frame + 1, part.frame_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))


## Draws frame `part_frame` of `def` with its top-left on part pixel `pos`.
## Flipped parts are drawn mirrored (same as the baker's flip_h).
func _draw_part(def: PartDef, part_frame: int, pos: Vector2i, flip: bool, alpha: float) -> void:
	if def == null or def.sheet == null:
		return
	var fs := def.get_frame_size()
	var src := Rect2(Vector2((part_frame % def.frame_count) * fs.x, 0), Vector2(fs))
	var dest_size := Vector2(fs * zoom)
	var top_left := origin + Vector2(pos * zoom)
	var tint := Color(1, 1, 1, alpha)
	if flip:
		# Mirror around the drawn rect: move to its right edge, scale x by -1.
		draw_set_transform(top_left + Vector2(dest_size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(def.sheet, Rect2(Vector2.ZERO, dest_size), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(def.sheet, Rect2(top_left, dest_size), src, tint)


## A box around one pixel, with a label. Copy sockets get a dotted look.
func _draw_marker(pixel: Vector2i, color: Color, label: String, is_copy: bool, selected: bool) -> void:
	var rect := Rect2(origin + Vector2(pixel * zoom), Vector2.ONE * zoom)
	var width := 3.0 if selected else 2.0
	if is_copy:
		draw_dashed_line(rect.position, rect.position + Vector2(rect.size.x, 0), color, width, 3.0)
		draw_dashed_line(rect.position + Vector2(0, rect.size.y), rect.end, color, width, 3.0)
		draw_dashed_line(rect.position, rect.position + Vector2(0, rect.size.y), color, width, 3.0)
		draw_dashed_line(rect.position + Vector2(rect.size.x, 0), rect.end, color, width, 3.0)
	else:
		draw_rect(rect.grow(1), color, false, width)
	var font := get_theme_default_font()
	var text_pos := rect.position + Vector2(rect.size.x + 4, -2)
	# Dark outline behind the label so it reads on any color.
	draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _draw_checker(rect: Rect2) -> void:
	draw_rect(rect, Color(0.32, 0.32, 0.36))
	var cell := float(maxi(zoom, 4))
	var y := 0
	while y * cell < rect.size.y:
		var x := (y % 2)
		while x * cell < rect.size.x:
			var r := Rect2(rect.position + Vector2(x, y) * cell, Vector2.ONE * cell).intersection(rect)
			draw_rect(r, Color(0.4, 0.4, 0.45))
			x += 2
		y += 1


func _draw_grid(rect: Rect2, frame_size: Vector2i) -> void:
	var c := Color(0, 0, 0, 0.18)
	for x in range(1, frame_size.x):
		var sx := rect.position.x + x * zoom
		draw_line(Vector2(sx, rect.position.y), Vector2(sx, rect.end.y), c)
	for y in range(1, frame_size.y):
		var sy := rect.position.y + y * zoom
		draw_line(Vector2(rect.position.x, sy), Vector2(rect.end.x, sy), c)


func _draw_message(text: String) -> void:
	draw_string(get_theme_default_font(), Vector2(16, 32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
