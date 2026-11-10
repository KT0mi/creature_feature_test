## Inspector panel for a CreaturePalette: its 4 tones as swatches, and sample
## creatures baked with it, updating live while you edit the colors.
##
## Modes:
##   As body     every sample creature uses this palette for its body.
##   As pattern  samples use another palette for the body, and this one for
##               a chosen pattern, to check the contrast between the two.
@tool
extends VBoxContainer

const CreaturePreview := preload("res://addons/creature_tools/preview/creature_preview.gd")

## Id used for the edited palette while previewing, if it has no id yet.
const UNSAVED_ID := &"__palette_preview__"
const TONE_LABELS := ["0 outline", "1 shadow", "2 base", "3 light"]

var _context
var _palette: CreaturePalette

var _swatches: Array[ColorRect] = []
var _warning: Label
var _mode: OptionButton
var _body_choice: OptionButton
var _pattern_choice: OptionButton
var _seed: SpinBox
var _zoom: SpinBox
var _preview: CreaturePreview
var _refresh_queued := false


func _init(context, palette: CreaturePalette) -> void:
	_context = context
	_palette = palette
	_build_ui()


func _ready() -> void:
	# `changed` fires on every color edit (see CreaturePalette.ramp setter).
	_palette.changed.connect(_queue_refresh)
	_fill_choices()
	_refresh()


func _exit_tree() -> void:
	if _palette.changed.is_connected(_queue_refresh):
		_palette.changed.disconnect(_queue_refresh)


# ----------------------------------------------------------------------- UI

func _build_ui() -> void:
	var title := Label.new()
	title.text = "Palette preview"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	# The 4 tones with their role.
	var swatch_row := HBoxContainer.new()
	for i in CreaturePalette.TONES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(0, 20)
		column.add_child(swatch)
		var label := Label.new()
		label.text = TONE_LABELS[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		column.add_child(label)
		swatch_row.add_child(column)
		_swatches.append(swatch)
	add_child(swatch_row)

	_warning = Label.new()
	_warning.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_warning)

	# Mode + pattern options.
	var mode_row := HBoxContainer.new()
	_mode = OptionButton.new()
	_mode.add_item("As body")
	_mode.add_item("As pattern")
	_mode.item_selected.connect(func(_i): _update_mode_visibility(); _refresh())
	mode_row.add_child(_mode)
	_pattern_choice = OptionButton.new()
	_pattern_choice.tooltip_text = "Pattern drawn with this palette"
	_pattern_choice.item_selected.connect(func(_i): _refresh())
	mode_row.add_child(_pattern_choice)
	_body_choice = OptionButton.new()
	_body_choice.tooltip_text = "Body palette under the pattern"
	_body_choice.item_selected.connect(func(_i): _refresh())
	mode_row.add_child(_body_choice)
	add_child(mode_row)

	# Seed, zoom, rescan.
	var options_row := HBoxContainer.new()
	options_row.add_child(_label("Seed"))
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 99999
	_seed.tooltip_text = "Change to see other sample creatures"
	_seed.value_changed.connect(func(_v): _refresh())
	options_row.add_child(_seed)
	options_row.add_child(_label("Zoom"))
	_zoom = SpinBox.new()
	_zoom.min_value = 1
	_zoom.max_value = 4
	_zoom.value = 2
	_zoom.value_changed.connect(func(v): _preview.zoom = int(v))
	options_row.add_child(_zoom)
	var rescan := Button.new()
	rescan.text = "Rescan parts"
	rescan.tooltip_text = "Reload parts and palettes from disk"
	rescan.pressed.connect(func(): _context.mark_dirty(); _fill_choices(); _refresh())
	options_row.add_child(rescan)
	add_child(options_row)

	_preview = CreaturePreview.new()
	_preview.zoom = 2
	add_child(_preview)
	_update_mode_visibility()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


## Fills the body-palette and pattern dropdowns from the registry.
func _fill_choices() -> void:
	var reg: Node = _context.registry()
	_body_choice.clear()
	for id in reg.palette_ids:
		if id != _palette.id:
			_body_choice.add_item(String(id))
	_pattern_choice.clear()
	for pattern_name in reg.pattern_names:
		_pattern_choice.add_item(String(pattern_name))


func _update_mode_visibility() -> void:
	var as_pattern := _mode.selected == 1
	_body_choice.visible = as_pattern
	_pattern_choice.visible = as_pattern


# ------------------------------------------------------------------ preview

## Several edits can arrive in one frame (e.g. dragging in the color picker);
## refresh once at the end of the frame instead of for each.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	for i in _swatches.size():
		_swatches[i].color = _palette.tone(i)
	_warning.text = "" if _palette.is_valid() else \
		"This palette has %d colors; it needs exactly %d (the registry skips it)." \
		% [_palette.ramp.size(), CreaturePalette.TONES]

	var reg: Node = _context.registry()
	# The palette as it is NOW in the inspector (possibly unsaved), under
	# its own id or a temporary one.
	var preview_id: StringName = _palette.id if _palette.id != &"" else UNSAVED_ID
	var palettes: Dictionary = reg.palettes.duplicate()
	palettes[preview_id] = _palette

	var genomes: Array[Genome]
	if _mode.selected == 1 and _pattern_choice.item_count > 0 and _body_choice.item_count > 0:
		var pattern_name := StringName(_pattern_choice.get_item_text(_pattern_choice.selected))
		var body := StringName(_body_choice.get_item_text(_body_choice.selected))
		genomes = _with_pattern(_context.sample_genomes(body, int(_seed.value)), pattern_name, preview_id)
	else:
		genomes = _context.sample_genomes(preview_id, int(_seed.value))

	var captions := PackedStringArray()
	for g in genomes:
		captions.append(String(g.root.part.id))
	# Bakes are cached by genome content, which doesn't include the colors,
	# so the cache must be cleared for color edits to show.
	CreatureBaker.clear_cache()
	_preview.show_genomes(genomes, palettes, reg.key, captions)


## Gives every genome the pattern `pattern_name` in palette `palette_id`, and
## keeps only creatures where at least one part actually has that pattern
## (all of them if none do, so the panel is never empty).
func _with_pattern(genomes: Array[Genome], pattern_name: StringName,
		palette_id: StringName) -> Array[Genome]:
	var out: Array[Genome] = []
	for g in genomes:
		g.patterns = [Genome.PatternGene.new(pattern_name, palette_id)]
		if _has_pattern(g.root, pattern_name):
			out.append(g)
	return out if not out.is_empty() else genomes


func _has_pattern(node: PartNode, pattern_name: StringName) -> bool:
	if node.part.patterns.has(pattern_name):
		return true
	for child in node.children.values():
		if _has_pattern(child, pattern_name):
			return true
	return false
