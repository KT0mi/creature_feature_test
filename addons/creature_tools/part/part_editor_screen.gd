## The "Parts" main screen: edits the sockets and attach point of a PartDef
## visually. Opened automatically when a PartDef is selected.
##
##   left    part info, attach, socket list (add / duplicate / delete /
##           reorder) and a compact form for the selected socket
##   right   PartCanvas: the sprite, example children, draggable markers
##
## Every change goes through the editor's undo/redo (Ctrl+Z works). Changes
## live in memory until "Save" (or Ctrl+S on the resource in the inspector).
## Fields the screen doesn't show (naming, weight, tags...) stay editable
## in the normal inspector, which remains visible next to this screen.
@tool
extends HSplitContainer

const PartCanvas := preload("res://addons/creature_tools/part/part_canvas.gd")

## "(none)" entry in dropdowns.
const NONE := "(none)"

var part: PartDef

var _context            # ToolsContext
var _undo               # EditorUndoRedoManager, or null when run outside the editor (tests)
var _canvas: PartCanvas
var _title: Label
var _status: Label
var _frame_spin: SpinBox
var _attach_button: Button
var _socket_list: ItemList
var _form: VBoxContainer
var _alpha_check: CheckBox
var _unsaved := false
# Socket (PartSocket) -> id of the part shown in it as an example. Editor
# only, never saved. Missing entry = first part the socket accepts.
var _example_choice: Dictionary = {}
# Value of the dragged property when a drag started, for one undo step.
var _drag_start: Variant = null


func _init(context, undo_manager) -> void:
	_context = context
	_undo = undo_manager
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


## Shows `def` in the editor (called by the plugin when a PartDef is selected).
func edit(def: PartDef) -> void:
	if def == part:
		return
	part = def
	_canvas.part = def
	_canvas.selection = PartCanvas.SELECT_NONE
	_canvas.frame = 0
	_unsaved = false
	_refresh()
	_canvas.frame_part.call_deferred()


## Re-reads the part after something else changed it (the inspector, a
## re-imported PNG...). Doesn't mark it unsaved.
func refresh_from_data() -> void:
	if part != null:
		_canvas.frame = mini(_canvas.frame, part.frame_count - 1)
		_refresh()


# ----------------------------------------------------------------------- UI

func _build_ui() -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	add_child(left)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	left.add_child(_title)

	var top_row := HBoxContainer.new()
	var save := Button.new()
	save.text = "Save"
	save.tooltip_text = "Save this part's .tres"
	save.pressed.connect(_save)
	top_row.add_child(save)
	var rescan := Button.new()
	rescan.text = "Rescan parts"
	rescan.tooltip_text = "Reload parts from disk (for example choices)"
	rescan.pressed.connect(func(): _context.mark_dirty(); _refresh())
	top_row.add_child(rescan)
	var fit := Button.new()
	fit.text = "Fit view"
	fit.pressed.connect(func(): _canvas.frame_part())
	top_row.add_child(fit)
	left.add_child(top_row)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	left.add_child(_status)

	var frame_row := HBoxContainer.new()
	frame_row.add_child(_label("Frame"))
	_frame_spin = SpinBox.new()
	_frame_spin.min_value = 1
	_frame_spin.tooltip_text = "Socket positions are edited for this frame"
	_frame_spin.value_changed.connect(func(v): _canvas.frame = int(v) - 1; _refresh())
	frame_row.add_child(_frame_spin)
	_alpha_check = CheckBox.new()
	_alpha_check.text = "See-through examples"
	_alpha_check.toggled.connect(func(on): _canvas.examples_alpha = 0.5 if on else 1.0; _canvas.queue_redraw())
	frame_row.add_child(_alpha_check)
	left.add_child(frame_row)

	_attach_button = Button.new()
	_attach_button.toggle_mode = true
	_attach_button.tooltip_text = "Select, then click or drag on the canvas to move the attach pixel"
	_attach_button.pressed.connect(func(): _select(PartCanvas.SELECT_ATTACH))
	left.add_child(_attach_button)

	left.add_child(_label("Sockets (filled top to bottom)"))
	_socket_list = ItemList.new()
	_socket_list.custom_minimum_size = Vector2(0, 150)
	_socket_list.item_selected.connect(func(i): _select(i))
	left.add_child(_socket_list)

	var list_buttons := HBoxContainer.new()
	for spec in [["+ Add", _add_socket], ["Duplicate", _duplicate_socket],
			["Delete", _delete_socket], ["▲", func(): _move_socket(-1)], ["▼", func(): _move_socket(1)]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		list_buttons.add_child(b)
	left.add_child(list_buttons)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	left.add_child(scroll)

	_canvas = PartCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.pixel_pressed.connect(_on_pixel_pressed)
	_canvas.pixel_dragged.connect(_on_pixel_dragged)
	_canvas.released.connect(_on_released)
	add_child(_canvas)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


## Updates everything from the data (after any change, undo or redo).
func _refresh() -> void:
	if part == null:
		_title.text = "No part selected"
		_status.text = "Select a PartDef .tres in the FileSystem."
		_socket_list.clear()
		_clear_form()
		_canvas.queue_redraw()
		return
	_title.text = "%s  (%s)%s" % [part.id, part.type, "  *" if _unsaved else ""]
	_status.text = "Unsaved changes. Press Save." if _unsaved else \
		"Click a marker to select it; click or drag to move it. Middle drag: pan. Wheel: zoom."
	_frame_spin.max_value = part.frame_count
	_frame_spin.set_value_no_signal(_canvas.frame + 1)
	_attach_button.text = "Attach pixel: (%d, %d)" % [part.attach.x, part.attach.y]
	_attach_button.set_pressed_no_signal(_canvas.selection == PartCanvas.SELECT_ATTACH)

	_socket_list.clear()
	for i in part.sockets.size():
		var s := part.sockets[i]
		var text := "%s   [%s]" % [s.name, ", ".join(s.accepts_type)]
		if s.copy_from != &"":
			text += "   = %s%s" % [s.copy_from, " (counterpart)" if s.use_counterpart else ""]
		_socket_list.add_item(text)
		_socket_list.set_item_custom_fg_color(i, PartCanvas.socket_color(i))
	if _canvas.selection >= 0 and _canvas.selection < part.sockets.size():
		_socket_list.select(_canvas.selection)
	elif _canvas.selection >= 0:
		_canvas.selection = PartCanvas.SELECT_NONE

	_build_form()
	_update_examples()
	_canvas.queue_redraw()


func _select(index: int) -> void:
	_canvas.selection = index
	if index < 0:
		_socket_list.deselect_all()
	_refresh()


# ------------------------------------------------------------- socket form

func _clear_form() -> void:
	for c in _form.get_children():
		c.queue_free()


## Compact form for the selected socket. Text fields apply on Enter or
## when they lose focus; everything else applies immediately.
func _build_form() -> void:
	_clear_form()
	var i := _canvas.selection
	if i < 0 or i >= part.sockets.size():
		return
	var s := part.sockets[i]

	_text_row("Name", String(s.name), func(t): _set_socket(s, "name", StringName(t.strip_edges())))
	_text_row("Accepts types", ", ".join(s.accepts_type),
		func(t): _set_socket(s, "accepts_type", _csv(t)), "e.g. arm, wing")
	_text_row("Type weights", _weights_text(s.type_weights),
		func(t): _set_socket(s, "type_weights", _parse_weights(t)), "e.g. wing=0.1 (others = 1)")
	_text_row("Required tags", ", ".join(s.required_tags), func(t): _set_socket(s, "required_tags", _csv(t)))
	_text_row("Forbidden tags", ", ".join(s.forbidden_tags), func(t): _set_socket(s, "forbidden_tags", _csv(t)))

	# Position for the current frame (the canvas edits the same value).
	var pos := s.position_at(_canvas.frame)
	var pos_row := HBoxContainer.new()
	pos_row.add_child(_label("Position"))
	for axis in 2:
		var spin := SpinBox.new()
		spin.min_value = -512
		spin.max_value = 512
		spin.value = pos[axis]
		spin.value_changed.connect(func(v):
			var p := s.position_at(_canvas.frame)
			p[axis] = int(v)
			_set_socket(s, "positions", _positions_with(s, p)))
		pos_row.add_child(spin)
	_form.add_child(pos_row)
	if part.frame_count > 1:
		var info := _label("%d position(s) stored for %d frames (missing frames reuse the last)."
			% [s.positions.size(), part.frame_count])
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 11)
		_form.add_child(info)
		var same := Button.new()
		same.text = "Use this position for all frames"
		same.pressed.connect(func():
			var one: Array[Vector2i] = [s.position_at(_canvas.frame)]
			_set_socket(s, "positions", one))
		_form.add_child(same)

	_spin_row("Chance", s.chance, 0.0, 1.0, 0.01, func(v): _set_socket(s, "chance", v))
	_spin_row("Z offset", s.z_offset, -20, 20, 1, func(v): _set_socket(s, "z_offset", int(v)))
	_spin_row("Shade shift", s.shade_shift, -3, 3, 1, func(v): _set_socket(s, "shade_shift", int(v)))
	_check_row("Flip horizontally", s.flip_h, func(on): _set_socket(s, "flip_h", on))

	# copy_from: only sockets listed above this one are valid sources.
	var earlier := PackedStringArray([NONE])
	for j in i:
		earlier.append(String(part.sockets[j].name))
	_option_row("Copy from", earlier, String(s.copy_from) if s.copy_from != &"" else NONE,
		func(t): _set_socket(s, "copy_from", &"" if t == NONE else StringName(t)))
	_check_row("Use counterpart", s.use_counterpart, func(on): _set_socket(s, "use_counterpart", on))
	_text_row("Requires", ", ".join(s.requires), func(t): _set_socket(s, "requires", _csv(t)),
		"sockets above, comma separated")
	_text_row("Excludes", ", ".join(s.excludes), func(t): _set_socket(s, "excludes", _csv(t)),
		"sockets above, comma separated")

	# Example child (editor only, not saved).
	_form.add_child(HSeparator.new())
	if s.copy_from != &"":
		_form.add_child(_label("Example: mirrors '%s'" % s.copy_from))
	else:
		var choices := PackedStringArray([NONE])
		for p in _accepted_parts(s):
			choices.append(String(p.id))
		var current: String = _example_choice.get(s, choices[1] if choices.size() > 1 else NONE)
		_option_row("Example", choices, current, func(t):
			_example_choice[s] = t
			_update_examples()
			_canvas.queue_redraw())


func _text_row(caption: String, value: String, apply: Callable, hint := "") -> void:
	var row := HBoxContainer.new()
	var l := _label(caption)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = hint
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Apply on Enter or when leaving the field, only if the text changed.
	var commit := func(_x = null):
		if edit.text != value:
			apply.call(edit.text)
	edit.text_submitted.connect(commit)
	edit.focus_exited.connect(commit)
	row.add_child(edit)
	_form.add_child(row)


func _spin_row(caption: String, value: float, lo: float, hi: float, step: float, apply: Callable) -> void:
	var row := HBoxContainer.new()
	var l := _label(caption)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(apply)
	row.add_child(spin)
	_form.add_child(row)


func _check_row(caption: String, value: bool, apply: Callable) -> void:
	var check := CheckBox.new()
	check.text = caption
	check.button_pressed = value
	check.toggled.connect(apply)
	_form.add_child(check)


func _option_row(caption: String, items: PackedStringArray, current: String, apply: Callable) -> void:
	var row := HBoxContainer.new()
	var l := _label(caption)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		option.add_item(item)
	option.select(maxi(items.find(current), 0))
	option.item_selected.connect(func(idx): apply.call(option.get_item_text(idx)))
	row.add_child(option)
	_form.add_child(row)


# -------------------------------------------------------- canvas interaction

## Click: select the marker under the mouse, or move the selected one there.
func _on_pixel_pressed(pixel: Vector2i) -> void:
	if part == null:
		return
	var hit := _marker_at(pixel)
	if hit != PartCanvas.SELECT_NONE and hit != _canvas.selection:
		_select(hit)
	if _canvas.selection == PartCanvas.SELECT_NONE:
		return
	_drag_start = _dragged_value()
	_move_selected(pixel)


func _on_pixel_dragged(pixel: Vector2i) -> void:
	if _drag_start != null:
		_move_selected(pixel)


## End of a drag: record ONE undo step from the start to the final value.
func _on_released() -> void:
	if _drag_start == null:
		return
	var final_value: Variant = _dragged_value()
	var start: Variant = _drag_start
	_drag_start = null
	if final_value == start:
		return
	_apply_dragged(start)  # back to the start so the undo step is exact
	if _canvas.selection == PartCanvas.SELECT_ATTACH:
		_commit("Move attach pixel", part, "attach", final_value)
	else:
		_commit("Move socket", part.sockets[_canvas.selection], "positions", final_value)


## While dragging the data changes directly (no undo entries per pixel).
func _move_selected(pixel: Vector2i) -> void:
	if _canvas.selection == PartCanvas.SELECT_ATTACH:
		_apply_dragged(pixel)
	elif _canvas.selection >= 0:
		_apply_dragged(_positions_with(part.sockets[_canvas.selection], pixel))
	_attach_button.text = "Attach pixel: (%d, %d)" % [part.attach.x, part.attach.y]
	_update_examples()
	_canvas.queue_redraw()


func _dragged_value() -> Variant:
	if _canvas.selection == PartCanvas.SELECT_ATTACH:
		return part.attach
	return part.sockets[_canvas.selection].positions.duplicate()


func _apply_dragged(value: Variant) -> void:
	if _canvas.selection == PartCanvas.SELECT_ATTACH:
		part.attach = value
	else:
		part.sockets[_canvas.selection].positions = value


## Marker on `pixel`: the selected one first, then sockets, then attach.
func _marker_at(pixel: Vector2i) -> int:
	var sel := _canvas.selection
	if sel >= 0 and sel < part.sockets.size() and part.sockets[sel].position_at(_canvas.frame) == pixel:
		return sel
	for i in part.sockets.size():
		if part.sockets[i].position_at(_canvas.frame) == pixel:
			return i
	if part.attach == pixel:
		return PartCanvas.SELECT_ATTACH
	return PartCanvas.SELECT_NONE


# ------------------------------------------------------------ socket list

func _add_socket() -> void:
	if part == null:
		return
	var s := PartSocket.new()
	s.name = _unique_name("socket")
	var pos: Array[Vector2i] = [part.get_frame_size() / 2]
	s.positions = pos
	var list := _sockets_copy()
	list.append(s)
	_commit("Add socket", part, "sockets", list)
	_select(list.size() - 1)


## Duplicates the selected socket as a NEW, independent resource (no
## shared sub-resource, unlike copy-pasting in the inspector).
func _duplicate_socket() -> void:
	var i := _canvas.selection
	if i < 0:
		return
	var s := part.sockets[i].duplicate() as PartSocket
	# Containers are copied explicitly so nothing is shared with the original.
	s.positions = part.sockets[i].positions.duplicate()
	s.type_weights = part.sockets[i].type_weights.duplicate()
	s.name = _unique_name(String(part.sockets[i].name) + "_copy")
	var list := _sockets_copy()
	list.insert(i + 1, s)
	_commit("Duplicate socket", part, "sockets", list)
	_select(i + 1)


func _delete_socket() -> void:
	var i := _canvas.selection
	if i < 0:
		return
	var list := _sockets_copy()
	list.remove_at(i)
	_commit("Delete socket", part, "sockets", list)
	_select(mini(i, list.size() - 1) if not list.is_empty() else PartCanvas.SELECT_NONE)


## Moves the selected socket up (-1) or down (+1). Order matters: rules can
## only point at sockets above.
func _move_socket(direction: int) -> void:
	var i := _canvas.selection
	var j := i + direction
	if i < 0 or j < 0 or j >= part.sockets.size():
		return
	var list := _sockets_copy()
	var tmp := list[i]
	list[i] = list[j]
	list[j] = tmp
	_commit("Move socket", part, "sockets", list)
	_select(j)


func _sockets_copy() -> Array[PartSocket]:
	var list: Array[PartSocket] = []
	list.assign(part.sockets)
	return list


func _unique_name(base: String) -> StringName:
	var taken := {}
	for s in part.sockets:
		taken[String(s.name)] = true
	var candidate := base
	var n := 2
	while taken.has(candidate):
		candidate = "%s_%d" % [base, n]
		n += 1
	return StringName(candidate)


# --------------------------------------------------------------- examples

## Every part (fusion_only included) that this socket accepts.
func _accepted_parts(s: PartSocket) -> Array[PartDef]:
	var out: Array[PartDef] = []
	var reg: Node = _context.registry()
	for type in s.accepts_type:
		for p in reg.get_parts_of_type(type):
			if s.accepts(p):
				out.append(p)
	return out


## The example part shown in socket `s`, or null. Copy sockets show their
## source's example (swapped for its counterpart if use_counterpart is on).
func _example_for(s: PartSocket, depth := 0) -> PartDef:
	if s.copy_from != &"":
		var source := part.get_socket(s.copy_from)
		if source == null or depth > 8:
			return null
		var example := _example_for(source, depth + 1)
		if example != null and s.use_counterpart and example.counterpart != &"":
			var other: PartDef = _context.registry().get_part(example.counterpart)
			if other != null:
				example = other
		return example
	var choice: String = _example_choice.get(s, "")
	if choice == NONE:
		return null
	var accepted := _accepted_parts(s)
	for p in accepted:
		if String(p.id) == choice:
			return p
	return accepted[0] if not accepted.is_empty() else null


## Builds the list of example children the canvas draws (one level deep).
func _update_examples() -> void:
	var list: Array[Dictionary] = []
	if part != null:
		for i in part.sockets.size():
			var s := part.sockets[i]
			var child := _example_for(s)
			if child == null or child.sheet == null:
				continue
			var attach := child.attach
			if s.flip_h:
				attach.x = child.get_frame_size().x - 1 - attach.x  # same as the baker
			list.append({"part": child, "frame": _canvas.frame % child.frame_count,
				"pos": s.position_at(_canvas.frame) - attach, "flip": s.flip_h,
				"z": s.z_offset, "socket": i})
	_canvas.examples = list


# ---------------------------------------------------------- data changes

## Sets one property through the editor's undo/redo, then refreshes.
func _commit(action: String, target: Object, property: String, value: Variant) -> void:
	if _undo == null:
		target.set(property, value)  # outside the editor (tests): no history
		_after_change()
		return
	_undo.create_action(action, UndoRedo.MERGE_DISABLE, part)
	_undo.add_do_property(target, property, value)
	_undo.add_undo_property(target, property, target.get(property))
	_undo.add_do_method(self, "_after_change")
	_undo.add_undo_method(self, "_after_change")
	_undo.commit_action()


func _set_socket(s: PartSocket, property: String, value: Variant) -> void:
	if s.get(property) == value:
		return
	_commit("Change socket %s" % property.replace("_", " "), s, property, value)


func _after_change() -> void:
	_unsaved = true
	part.emit_changed()
	_refresh.call_deferred()  # deferred: the form that triggered this may be rebuilt


func _save() -> void:
	if part == null:
		return
	if part.resource_path == "":
		_status.text = "This part isn't a saved .tres file yet; save it from the inspector."
		return
	var err := ResourceSaver.save(part, part.resource_path)
	if err != OK:
		_status.text = "Save failed (error %d)." % err
		return
	_unsaved = false
	_refresh()


## `s.positions` with the CURRENT frame's entry set to `pos`. A single
## stored position stays single when editing frame 1; editing a later frame
## grows the list (copying the last entry) up to that frame.
func _positions_with(s: PartSocket, pos: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	list.assign(s.positions)
	if list.is_empty():
		list.append(pos)
	while list.size() <= _canvas.frame:
		list.append(list[-1])
	list[_canvas.frame] = pos
	return list


static func _csv(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for piece in text.split(",", false):
		var t := piece.strip_edges()
		if t != "":
			out.append(t)
	return out


static func _weights_text(weights: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in weights:
		parts.append("%s=%s" % [k, weights[k]])
	return ", ".join(parts)


## "wing=0.1, arm=1" -> {wing: 0.1, arm: 1.0}. Malformed pieces are skipped.
static func _parse_weights(text: String) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	for piece in _csv(text):
		var kv := piece.split("=")
		if kv.size() == 2 and kv[1].strip_edges().is_valid_float():
			out[StringName(kv[0].strip_edges())] = kv[1].strip_edges().to_float()
	return out
