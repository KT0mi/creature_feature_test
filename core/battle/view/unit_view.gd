##View of creature on the battle scene
class_name UnitView
extends Node2D


var unit: BattleUnit
var board: BoardView
## HP shown on the bar (follows the events, not the final state).
var shown_hp: int = 0
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var reaction_visible := false:
	set(value):
		reaction_visible = value
		queue_redraw()

var _sprite: Sprite2D
var _baked: CreatureBaker.Baked
var _facing: Grid.Facing = Grid.Facing.RIGHT
var _anim_time := 0.0

func setup(p_unit: BattleUnit, p_board: BoardView, baked: CreatureBaker.Baked) -> void:
	unit = p_unit
	board = p_board
	_baked = baked
	_sprite = Sprite2D.new()
	_sprite.texture = _baked.texture
	_sprite.hframes = _baked.frame_count
	_sprite.centered = false
	add_child(_sprite)
	shown_hp = unit.hp
	set_cell(unit.position)
	set_facing(unit.facing)

# Commented because no part has an animation
#func _process(delta: float) -> void:
	## Idle animation, 4 frames per second.
	#if _sprite and _sprite.hframes > 1:
		#_anim_time += delta
		#_sprite.frame = int(_anim_time * 4.0) % _sprite.hframes

## Puts the unit's feet on the center of `cell` (no animation).
func set_cell(cell: Vector2i) -> void:
	position = board.position + board.cell_center(cell)

## On screen only two looks exist: facing left or right. Grid RIGHT goes
## down-right and UP goes up-right (screen right); DOWN and LEFT go to the
## screen left. The arrow on the ground shows the exact direction.
func set_facing(facing: Grid.Facing) -> void:
	_facing = facing
	var looks_left := facing == Grid.Facing.DOWN or facing == Grid.Facing.LEFT
	_sprite.flip_h = looks_left
	# The feet pixel (baked ground) must stay on the cell when mirrored.
	var ground := _baked.ground
	if _sprite.flip_h:
		ground.x = _baked.frame_size.x - 1 - ground.x
	_sprite.position = -Vector2(ground)
	queue_redraw()


## Snaps everything to the unit's real state (after animations).
func sync(player_team: int) -> void:
	set_cell(unit.position)
	set_facing(unit.facing)
	shown_hp = unit.hp
	var seen := unit.statuses_visible_to(player_team)
	reaction_visible = seen.any(func(s): return s.status.is_reaction())
	visible = unit.is_alive()
	modulate = Color.WHITE
	_sprite.offset = Vector2.ZERO
	queue_redraw()

# --------- animation

##Walk (or pushed) to cell. The output is a tween that is awaited before continuing resolving battle actions.
func step_to(cell: Vector2i, seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", board.position + board.cell_center(cell), seconds)
	return tween

##Jump to cell (for now, any move without steps)
func jump_to(cell: Vector2i, seconds: float, height: float = 24.0) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", board.position + board.cell_center(cell), seconds)
	tween.parallel().tween_property(_sprite, "offset:y", -height, seconds /2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "offset:y", 0.0, seconds / 2) \
		.set_delay(seconds / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween


## Red flash and HP bar update.
func show_damage(amount: int) -> Tween:
	shown_hp = maxi(shown_hp - amount, 0)
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.3, 0.3), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	return tween


func show_heal(amount: int) -> void:
	shown_hp = mini(shown_hp + amount, unit.profile.hp)
	queue_redraw()


## Small shake (collisions).
func shake() -> Tween:
	var start := position
	var tween := create_tween()
	for dx in [3, -3, 2, 0]:
		tween.tween_property(self, "position", start + Vector2(dx, 0), 0.03)
	return tween


func die() -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hide)
	return tween


## Top of the sprite, relative to the unit's feet (for floating text).
func head_offset() -> Vector2:
	return Vector2(0, -_baked.ground.y - 6)



# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var hw := board.cell_size.x / 2.0
	var hh := board.cell_size.y / 2.0
	# Selection ring: a smaller diamond under the feet.
	if selected:
		var r := PackedVector2Array([Vector2(0, -hh * 0.6), Vector2(hw * 0.6, 0),
			Vector2(0, hh * 0.6), Vector2(-hw * 0.6, 0), Vector2(0, -hh * 0.6)])
		draw_polyline(r, Color(1, 1, 0.4), 2.0)
	# Facing arrow on the ground, along the grid direction on screen.
	var step := Grid.step(_facing)
	var dir := Vector2((step.x - step.y) * hw, (step.x + step.y) * hh).normalized()
	var tip := dir * hh * 0.85
	var side := Vector2(-dir.y, dir.x) * 5.0
	var team_color := Color(0.0, 0.684, 0.923, 1.0) if unit.team == 0 else Color(1.0, 0.145, 0.121, 1.0)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10 + side, tip - dir * 10 - side]), team_color)
	# HP bar under the feet.
	var w := 40.0
	var frac := float(shown_hp) / maxf(unit.profile.hp, 1)
	var bar := Rect2(-w / 2, 8, w, 5)
	draw_rect(bar, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(floorf(w * frac), bar.size.y)), team_color)
	draw_string(ThemeDB.fallback_font, Vector2(-w / 2, 26), "%d/%d" % [shown_hp, unit.profile.hp],
		HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color.WHITE)
	if reaction_visible:
		draw_string(ThemeDB.fallback_font, head_offset() + Vector2(-6, -4), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.85, 0.2))
