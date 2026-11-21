##Battle scene interface
class_name BattleHUD
extends Control

#Passes slot index
signal card_pressed(slot: int)
signal end_turn_pressed
signal rematch_pressed
signal back_pressed
## The "use grit on a miss" toggle changed.
signal grit_toggled(on: bool)

var _turn_label: Label
var _initiative_label: Label
var _unit_info: RichTextLabel
var _log: RichTextLabel
var _cards_box: HBoxContainer
var _budget_label: Label
var _end_turn: Button
var _grit_toggle: CheckButton
var _result_panel: PanelContainer
var _result_label: Label
var _hint: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks reach the board


func _ready() -> void:
	_turn_label = _label(Vector2(12, 8), 20)
	_initiative_label = _label(Vector2(12, 36), 14)
	# Hint line just above the card bar, centered.
	_hint = _label(Vector2.ZERO, 14)
	_anchor(_hint, Vector4(0.5, 1, 0.5, 1), Vector4(-320, -160, 320, -138))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_unit_info = _rich(Rect2(12, 84, 270, 230))  # below the 2-line turn info
	_log = _rich(Rect2(0, 0, 0, 0))
	_anchor(_log, Vector4(1, 0, 1, 0), Vector4(-312, 8, -12, 238))
	_log.scroll_following = true

	# Bottom bar: cards, budget, end turn.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -130
	bottom.offset_bottom = -10
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)
	_budget_label = Label.new()
	_budget_label.custom_minimum_size = Vector2(110, 0)
	_budget_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	bottom.add_child(_budget_label)
	_cards_box = HBoxContainer.new()
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.add_theme_constant_override("separation", 8)
	bottom.add_child(_cards_box)
	# Grit: re-roll this turn's missed attacks (only spent on a miss).
	_grit_toggle = CheckButton.new()
	_grit_toggle.text = "Use grit\non a miss"
	_grit_toggle.button_pressed = true
	_grit_toggle.focus_mode = Control.FOCUS_NONE
	_grit_toggle.toggled.connect(func(on): grit_toggled.emit(on))
	bottom.add_child(_grit_toggle)
	_end_turn = Button.new()
	_end_turn.text = "End turn\n(Space)"
	_end_turn.custom_minimum_size = Vector2(120, 0)
	_end_turn.focus_mode = Control.FOCUS_NONE  # Space is handled by the scene
	_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	bottom.add_child(_end_turn)

	# Result panel (hidden until the end).
	_result_panel = PanelContainer.new()
	_anchor(_result_panel, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-160, -70, 160, 70))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_result_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["Rematch", rematch_pressed], ["Back to lab", back_pressed]]:
		var b := Button.new()
		b.text = spec[0]
		var sig: Signal = spec[1]
		b.pressed.connect(func(): sig.emit())
		buttons.add_child(b)
	box.add_child(buttons)
	_result_panel.add_child(box)
	_result_panel.hide()
	add_child(_result_panel)



## Anchors (left, top, right, bottom as fractions of the screen) and pixel
## offsets from those anchors. (Setting `position` on an anchored control
## doesn't place it relative to its anchors.)
func _anchor(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


func _rich(rect: Rect2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.position = rect.position
	r.size = rect.size
	r.bbcode_enabled = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", 13)
	r.add_theme_color_override("default_color", Color(1, 1, 1, 0.9))
	r.add_theme_constant_override("outline_size", 3)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(r)
	return r


# ------------------------------------------------------------- updates

func set_turn(text: String, initiative: String) -> void:
	_turn_label.text = text
	_initiative_label.text = initiative


func set_hint(text: String) -> void:
	_hint.text = text


func set_unit_info(bbcode: String) -> void:
	_unit_info.text = bbcode


func add_log(line: String) -> void:
	_log.append_text(line + "\n")


## Shows the acting unit's grit on the toggle, e.g. "Use grit (1/2)".
func set_grit(grit: int, max_grit: int) -> void:
	_grit_toggle.text = "Use grit\non a miss (%d/%d)" % [grit, max_grit]
	_grit_toggle.disabled = grit == 0


func set_end_turn_enabled(on: bool) -> void:
	_end_turn.disabled = not on


## One button per deck slot. `cards` entries:
##   { "name", "kind", "summary", "cooldown" (turns left), "playable",
##     "selected" }
func set_cards(cards: Array, budget: String) -> void:
	_budget_label.text = budget
	for child in _cards_box.get_children():
		child.queue_free()
	for i in cards.size():
		var c: Dictionary = cards[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 0)
		b.toggle_mode = true
		b.button_pressed = c.selected
		var state := "ready" if c.cooldown <= 0 else "cooldown %d" % c.cooldown
		b.text = "%d. %s\n[%s]\n%s" % [i + 1, c.name, c.kind, state]
		b.tooltip_text = c.summary
		b.disabled = not c.playable
		b.focus_mode = Control.FOCUS_NONE  # Space must not press the last clicked card
		b.pressed.connect(func(): card_pressed.emit(i))
		_cards_box.add_child(b)


func show_result(text: String) -> void:
	_result_label.text = text
	_result_panel.show()


func hide_result() -> void:
	_result_panel.hide()
