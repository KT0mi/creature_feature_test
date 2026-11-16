## A playable 1v1 battle
## Player controls team 0
## AI controls team 1
class_name BattleScene
extends Node2D


const SCENE_PATH := "res://scenes/battle_scene.tscn"
const LAB_PATH := "res://debug/creature_lab.tscn"
const PLAYER_TEAM := 0
## Seconds per walked / pushed cell.
const STEP_TIME := 0.14
const JUMP_TIME := 0.2
const PUSH_STEP_TIME := 0.08


## Where the board's top corner goes on screen.
@export var board_origin := Vector2(540, 200)

## Set by open() before the scene enters the tree. Empty = random match-up.
var genomes_a: Array[Genome] = []
var genomes_b: Array[Genome] = []
var battle_seed := 1

var rules: BattleRules
var board: BoardView
var hud: BattleHUD
var _units_root: Node2D
var _fx_root: Node2D
var _views := {}  # BattleUnit -> UnitView

var _busy := false            # animating / enemy turn: no player input
var _selected_unit := -1      # index in rules.state.units
var _selected_slot := -1      # deck slot of the chosen card
var _hover_cell := Vector2i(-1, -1)



## Replaces the current scene with a battle between `a` (player) and `b`.
static func open(tree: SceneTree, a: Array[Genome], b: Array[Genome], seed: int) -> void:
	var scene: BattleScene = load(SCENE_PATH).instantiate()
	scene.genomes_a = a
	scene.genomes_b = b
	scene.battle_seed = seed
	var old := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if old:
		old.queue_free()


func _ready() -> void:
	board = BoardView.new()
	board.position = board_origin
	add_child(board)
	# Units are y-sorted: creatures on rows nearer the camera draw on top.
	_units_root = Node2D.new()
	_units_root.y_sort_enabled = true
	add_child(_units_root)
	_fx_root = Node2D.new()  # floating texts, above everything on the board
	add_child(_fx_root)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = BattleHUD.new()
	layer.add_child(hud)
	hud.card_pressed.connect(_on_card_pressed)
	hud.end_turn_pressed.connect(_on_end_turn)
	hud.rematch_pressed.connect(func(): BattleScene.open(get_tree(), genomes_a, genomes_b, battle_seed + 1))
	hud.back_pressed.connect(func(): get_tree().change_scene_to_file(LAB_PATH))

	if genomes_a.is_empty() or genomes_b.is_empty():
		_random_matchup()
	_start_battle()


## Two random creatures, for running the scene on its own.
func _random_matchup() -> void:
	var gen := CreatureGenerator.new(PartRegistry)
	battle_seed = randi() % 100000
	genomes_a = [gen.random_genome(battle_seed * 2)]
	genomes_b = [gen.random_genome(battle_seed * 2 + 1)]


func _start_battle() -> void:
	var profiles := [_profiles(genomes_a), _profiles(genomes_b)]
	var names := [_names(genomes_a), _names(genomes_b)]
	rules = BattleRules.new_battle(profiles[0], profiles[1], battle_seed, names[0], names[1])
	var genomes: Array[Genome] = []
	genomes.append_array(genomes_a)
	genomes.append_array(genomes_b)
	for i in rules.state.units.size():
		var view := UnitView.new()
		var baked := CreatureBaker.bake(genomes[i], PartRegistry.palettes, PartRegistry.key)
		_units_root.add_child(view)
		view.setup(rules.state.units[i], board, baked)
		_views[rules.state.units[i]] = view
	hud.add_log("[b]%s[/b] vs [b]%s[/b]" % [", ".join(names[0]), ", ".join(names[1])])
	_busy = true
	await _play(rules.start())
	_next()



func _profiles(list: Array[Genome]) -> Array[CombatProfile]:
	var out: Array[CombatProfile] = []
	for g in list:
		out.append(CombatProfile.from_genome(g, PartRegistry))
	return out


func _names(list: Array[Genome]) -> PackedStringArray:
	var out := PackedStringArray()
	for g in list:
		out.append(CreatureNamer.name_of(g, PartRegistry))
	return out


# ------------------------------------------------------------ turn flow

## After every batch of events: show the result, run the AI, or hand the
## turn to the player.
func _next() -> void:
	_sync()
	if rules.state.is_over():
		_busy = true
		var w := rules.state.winner
		hud.show_result("Draw" if w < 0 else ("You win!" if w == PLAYER_TEAM else "You lose"))
		hud.set_end_turn_enabled(false)
		hud.set_cards([], "")
		return
	if rules.state.active_team != PLAYER_TEAM:
		_enemy_turn()
		return
	_busy = false
	if _selected_unit == -1 or not rules.state.units[_selected_unit].is_alive():
		_select_unit(_first_player_unit())
	_refresh_ui()


func _enemy_turn() -> void:
	_busy = true
	_refresh_ui()
	var ai := BattleAI.new(BattleAI.Mode.GREEDY, battle_seed * 31 + rules.state.round)
	for i in rules.state.units.size():
		var u := rules.state.units[i]
		if u.team != rules.state.active_team or not u.is_alive():
			continue
		for k in CombatRules.MAX_CARDS_PER_TURN:
			if rules.state.is_over():
				break
			var action := ai.choose_action(rules, i)
			if action == null:
				break
			await get_tree().create_timer(0.35).timeout
			await _play(rules.apply(action))
	if not rules.state.is_over():
		await get_tree().create_timer(0.25).timeout
		await _play(rules.end_turn())
	_next()


func _on_end_turn() -> void:
	if _busy or rules.state.active_team != PLAYER_TEAM:
		return
	_clear_card()
	_busy = true
	await _play(rules.end_turn())
	_next()


func _first_player_unit() -> int:
	for i in rules.state.units.size():
		var u := rules.state.units[i]
		if u.team == PLAYER_TEAM and u.is_alive():
			return i
	return -1


# ----------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(board.cell_at(board.get_local_mouse_position()))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_cell_clicked(board.cell_at(board.get_local_mouse_position()))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_clear_card()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_clear_card()
			KEY_SPACE, KEY_ENTER:
				_on_end_turn()
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_9:
					_on_card_pressed(event.keycode - KEY_1)


func _set_hover(cell: Vector2i) -> void:
	if cell == _hover_cell:
		return
	_hover_cell = cell
	board.set_hover(cell)
	_refresh_marks()
	_refresh_unit_info()



func _on_cell_clicked(cell: Vector2i) -> void:
	if _busy or not Grid.in_bounds(cell):
		return
	if _selected_slot != -1:
		var action := _action_for(cell)
		if action != null:
			_play_action(action)
			return
	# Otherwise: select one of the player's units, or drop the card.
	var unit := rules.state.unit_at(cell)
	if unit != null and unit.team == PLAYER_TEAM:
		_select_unit(rules.state.units.find(unit))
	else:
		_clear_card()


## The legal action for the selected card on `cell`. For aim-SELF cards,
## clicking anywhere in the area (or on the user) counts.
func _action_for(cell: Vector2i) -> BattleAction:
	var actions := _legal_for_slot()
	for a in actions:
		if a.target == cell:
			return a
	var card := _selected_card()
	if card != null and card.aim == BattleCard.Aim.SELF and actions.size() == 1:
		var user := rules.state.units[_selected_unit]
		if card.affected_cells(rules, user, actions[0].target).has(cell):
			return actions[0]
	return null


func _on_card_pressed(slot: int) -> void:
	if _busy or _selected_unit == -1:
		return
	var deck := rules.state.units[_selected_unit].deck()
	if slot < 0 or slot >= deck.size():
		return
	if slot == _selected_slot:
		# Pressing an aim-SELF card again plays it; otherwise it's a cancel.
		var actions := _legal_for_slot()
		if deck[slot].aim == BattleCard.Aim.SELF and actions.size() == 1:
			_play_action(actions[0])
		else:
			_clear_card()
		return
	if _legal_slots().has(slot):
		_selected_slot = slot
		_refresh_ui()


func _play_action(action: BattleAction) -> void:
	_selected_slot = -1
	_busy = true
	board.clear_marks()
	await _play(rules.apply(action))
	_next()


func _select_unit(index: int) -> void:
	if _selected_unit != -1:
		_views[rules.state.units[_selected_unit]].selected = false
	_selected_unit = index
	_selected_slot = -1
	if index != -1:
		_views[rules.state.units[index]].selected = true
	_refresh_ui()


func _clear_card() -> void:
	_selected_slot = -1
	_refresh_ui()


func _selected_card() -> BattleCard:
	if _selected_unit == -1 or _selected_slot == -1:
		return null
	return rules.state.units[_selected_unit].deck()[_selected_slot]


func _legal_for_slot() -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	if _selected_unit == -1:
		return out
	for a in rules.legal_actions(_selected_unit):
		if a.slot == _selected_slot:
			out.append(a)
	return out


func _legal_slots() -> Array[int]:
	var out: Array[int] = []
	if _selected_unit == -1:
		return out
	for a in rules.legal_actions(_selected_unit):
		if not out.has(a.slot):
			out.append(a.slot)
	return out


# -------------------------------------------------------------------- UI

func _refresh_ui() -> void:
	var s := rules.state
	var mine := s.active_team == PLAYER_TEAM
	var first := "you" if s.first_team == PLAYER_TEAM else "the enemy"
	hud.set_turn("Round %d - %s" % [s.round, "Your turn" if mine else "Enemy turn"],
		"Build: you %d, enemy %d (lower goes first: %s)" % [_team_build(0), _team_build(1), first])
	hud.set_end_turn_enabled(mine and not _busy)
	_refresh_cards()
	_refresh_marks()
	_refresh_unit_info()
	var card := _selected_card()
	if not mine or _busy:
		hud.set_hint("")
	elif card == null:
		hud.set_hint("Pick a card (1-9), or End turn (Space)")
	elif card.aim == BattleCard.Aim.SELF:
		hud.set_hint("%s: press it again or click the area to play it" % card.name)
	else:
		hud.set_hint("%s: click a highlighted cell (right click to cancel)" % card.name)


func _team_build(team: int) -> int:
	var total := 0
	for u in rules.state.units:
		if u.team == team and u.is_alive():
			total += u.profile.build
	return total


func _refresh_cards() -> void:
	if _selected_unit == -1 or rules.state.active_team != PLAYER_TEAM:
		hud.set_cards([], "")
		return
	var u := rules.state.units[_selected_unit]
	var playable: Array[int] = []
	if not _busy:
		playable = _legal_slots()
	var cards := []
	var deck := u.deck()
	for slot in deck.size():
		var card := deck[slot]
		# Stored cooldowns include +1 (they tick at the start of the turn).
		var left: int = u.cooldowns.get(slot, 0) - 1
		cards.append({
			"name": card.name if card.name != "" else String(card.id),
			"kind": "%s%s" % ["MOVE" if card.kind == BattleCard.Kind.MOVE else "ATK",
				", area" if card.area.size() > 1 else ""],
			"summary": card.summary(),
			"cooldown": left if not u.is_slot_ready(slot) else 0,
			"playable": playable.has(slot),
			"selected": slot == _selected_slot,
		})
	var attacks := u.played_this_turn.filter(func(c): return c.kind == BattleCard.Kind.ATTACK).size()
	hud.set_cards(cards, "Cards %d/%d\nAttack %s" % [u.played_this_turn.size(),
		CombatRules.MAX_CARDS_PER_TURN, "used" if attacks >= CombatRules.MAX_ATTACKS_PER_TURN else "ready"])


## Highlights: the selected card's targets, plus what hovering a target
## would do (the walk path, or the attack's area).
func _refresh_marks() -> void:
	var layers: Array[Dictionary] = []
	var card := _selected_card()
	if card != null and not _busy:
		var user := rules.state.units[_selected_unit]
		var actions := _legal_for_slot()
		var targets := {}
		for a in actions:
			targets[a.target] = BoardView.Mark.MOVE if card.kind == BattleCard.Kind.MOVE else BoardView.Mark.TARGET
		layers.append(targets)
		var aim_cell := Vector2i(-1, -1)
		if card.aim == BattleCard.Aim.SELF and actions.size() == 1:
			aim_cell = actions[0].target
		elif targets.has(_hover_cell):
			aim_cell = _hover_cell
		if aim_cell != Vector2i(-1, -1):
			var preview := {}
			if card.kind == BattleCard.Kind.MOVE:
				var move := card.move_effect()
				if move != null:
					for c in Grid.find_path(user.position, aim_cell, move.mode, user.facing, rules.is_free):
						preview[c] = BoardView.Mark.PATH
			else:
				for c in card.affected_cells(rules, user, aim_cell):
					preview[c] = BoardView.Mark.AREA
			layers.append(preview)
	board.set_marks(layers)


func _refresh_unit_info() -> void:
	var u := rules.state.unit_at(_hover_cell) if Grid.in_bounds(_hover_cell) else null
	if u == null and _selected_unit != -1:
		u = rules.state.units[_selected_unit]
	if u == null:
		hud.set_unit_info("")
		return
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]  (%s)" % [u.label(), "you" if u.team == PLAYER_TEAM else "enemy"])
	lines.append("HP %d/%d   Build %d" % [u.hp, u.profile.hp, u.profile.build])
	lines.append("PHY %d  SPC %d  DEF %d  RES %d" % [u.effective_stat(&"phys_dmg"),
		u.effective_stat(&"spc_dmg"), u.effective_stat(&"def"), u.effective_stat(&"res")])
	var seen := PackedStringArray()
	for s in u.statuses_visible_to(PLAYER_TEAM):
		if u.team != PLAYER_TEAM and s.status.reveal == StatusEffect.Reveal.HIDDEN_DETAILS:
			seen.append("? (hidden)" if not s.status.is_reaction() else "a reaction is ready")
		else:
			seen.append(s.label())
	if not seen.is_empty():
		lines.append("[color=#ffd966]%s[/color]" % ", ".join(seen))
	var card_names := PackedStringArray()
	for c in u.deck():
		card_names.append(c.name if c.name != "" else String(c.id))
	lines.append("Cards: %s" % (", ".join(card_names) if not card_names.is_empty() else "none"))
	hud.set_unit_info("\n".join(lines))


## Snaps every view to the real state and refreshes cell markers.
func _sync() -> void:
	for u in _views:
		_views[u].sync(PLAYER_TEAM)
	var labels := {}
	for cell in rules.state.status_cells():
		var seen := rules.state.cell_statuses_visible_to(cell, PLAYER_TEAM)
		if not seen.is_empty():
			var n: String = seen[0].status.name if seen[0].status.name != "" else String(seen[0].status.id)
			labels[cell] = n
	board.cell_labels = labels
	board.queue_redraw()
	_refresh_ui()


# ------------------------------------------------------------- animation

## Replays `events` in order. Returns when the last animation finished.
func _play(events: Array[BattleEvent]) -> void:
	for ev in events:
		var view: UnitView = _views.get(ev.unit)
		_log(ev)
		match ev.type:
			BattleEvent.Type.CARD_PLAYED:
				if ev.card:
					_float(view, ev.card.name if ev.card.name != "" else String(ev.card.id), Color(1, 0.9, 0.4))
				await _wait(0.15)
			BattleEvent.Type.STEPPED:
				var dist := absi(ev.to.x - ev.from.x) + absi(ev.to.y - ev.from.y)
				if not ev.forced and dist > 1:
					# A step to a non-adjacent cell is a JUMP landing: arc it,
					# higher and longer the farther it goes.
					await view.jump_to(ev.to, JUMP_TIME * dist, 12.0 + 8.0 * dist).finished
				else:
					await view.step_to(ev.to, PUSH_STEP_TIME if ev.forced else STEP_TIME).finished
			BattleEvent.Type.MOVED:
				# Moves without steps (teleport) haven't moved the view yet:
				# shown as a jump too.
				if view.position != board.position + board.cell_center(ev.to):
					var dist := absi(ev.to.x - ev.from.x) + absi(ev.to.y - ev.from.y)
					await view.jump_to(ev.to, JUMP_TIME * dist, 12.0 + 8.0 * dist).finished
			BattleEvent.Type.TURNED:
				view.set_facing(ev.amount)
			BattleEvent.Type.COLLIDED:
				await view.shake().finished
			BattleEvent.Type.DAMAGED:
				_float(view, "-%d" % ev.amount, Color(1, 0.35, 0.3))
				await view.show_damage(ev.amount).finished
			BattleEvent.Type.HP_LOST:
				_float(view, "-%d" % ev.amount, Color(0.8, 0.4, 1.0))
				await view.show_damage(ev.amount).finished
			BattleEvent.Type.HEALED:
				view.show_heal(ev.amount)
				_float(view, "+%d" % ev.amount, Color(0.4, 1, 0.5))
			BattleEvent.Type.STATUS_APPLIED:
				if view != null and _status_visible(ev.unit, ev.status):
					_float(view, "+%s" % _status_name(ev.status), Color(0.9, 0.8, 1.0))
			BattleEvent.Type.REACTED:
				if ev.card:
					_float(view, "! %s" % ev.card.name, Color(1, 0.85, 0.2))
				await _wait(0.2)
			BattleEvent.Type.DIED:
				await view.die().finished
	_sync()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Rising, fading text above a unit.
func _float(view: UnitView, text: String, color: Color) -> void:
	if view == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 16)
	label.position = view.position + view.head_offset() + Vector2(-40, -10)
	label.custom_minimum_size = Vector2(80, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fx_root.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)


func _status_visible(unit: BattleUnit, status: StatusEffect) -> bool:
	return unit.team == PLAYER_TEAM or status.reveal == StatusEffect.Reveal.SHOWN


func _status_name(status: StatusEffect) -> String:
	return status.name if status.name != "" else String(status.id)


## Log line for events worth reading (moves, hits, statuses...).
func _log(ev: BattleEvent) -> void:
	match ev.type:
		BattleEvent.Type.TURN_STARTED, BattleEvent.Type.TURN_ENDED, BattleEvent.Type.MOVE_STARTED, \
				BattleEvent.Type.STEPPED, BattleEvent.Type.ATTACKED:
			return
		BattleEvent.Type.STATUS_APPLIED, BattleEvent.Type.STATUS_EXPIRED:
			# Don't reveal hidden statuses (e.g. enemy traps) in the log.
			var placer: BattleUnit = ev.unit if ev.unit else ev.source
			if placer != null and placer.team != PLAYER_TEAM and ev.status.reveal != StatusEffect.Reveal.SHOWN:
				return
	var color := "#9fd3ff" if ev.unit != null and ev.unit.team == PLAYER_TEAM else "#ffb3a7"
	hud.add_log("[color=%s]%s[/color]" % [color, ev.describe()])
