## Headless balance test: random creature pairs fight 1v1, AI vs AI, and a
## report shows whether more parts / higher build / going first win more
## often, and how each CARD and each PART does. Nothing is saved.
##
## Run from the project folder:
##   godot --headless --path . --script res://debug/balance_sim.gd -- --battles 200 --seed 1 --ai greedy
## Options: --battles N (default 200), --seed S (default 1),
##          --ai greedy|random (default greedy),
##          --min-games N: hide cards/parts seen in fewer battles (default 5).
##
## Card/part win rates: "when ONE side has it, how often does that side
## win?" Battles where both sides have it (mirrors) and draws are left out,
## since they say nothing about it. Each rate comes with a 95% range
## (Wilson interval): with few battles, a rate far from 50% can still be
## luck, and the range shows how far the true rate could be.
##   STRONG  even the low end of the range is above 50%
##   WEAK    even the high end is below 50%
extends SceneTree

var _battles := 200
var _seed := 1
var _mode := BattleAI.Mode.GREEDY
var _min_games := 5

func _init() -> void:
	# Autoloads (PartRegistry) are ready after the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_read_args()
	var reg: Node = root.get_node("PartRegistry")
	var gen := CreatureGenerator.new(reg)

	var results := []  # one Dictionary per battle
	var started := Time.get_ticks_msec()
	for i in _battles:
		var genomes := [gen.random_genome(_seed * 100000 + i * 2), gen.random_genome(_seed * 100000 + i * 2 + 1)]
		var profiles: Array[CombatProfile] = []
		for g in genomes:
			profiles.append(CombatProfile.from_genome(g, reg))
		var a: Array[CombatProfile] = [profiles[0]]
		var b: Array[CombatProfile] = [profiles[1]]
		var rules := BattleRules.new_battle(a, b, _seed * 7919 + i)
		rules.start()
		var first := rules.state.first_team
		var ai := BattleAI.new(_mode, _seed * 31 + i)
		while not rules.state.is_over():
			ai.play_turn(rules)
		results.append({
			"winner": rules.state.winner, "first": first, "rounds": rules.state.round,
			"part_count": [genomes[0].root.count(), genomes[1].root.count()],
			"build": [profiles[0].build, profiles[1].build],
			"cards": [_card_ids(profiles[0]), _card_ids(profiles[1])],
			"parts": [_part_ids(genomes[0]), _part_ids(genomes[1])],
		})
	_report(results, Time.get_ticks_msec() - started)
	quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--battles":
				_battles = args[i + 1].to_int()
			"--seed":
				_seed = args[i + 1].to_int()
			"--ai":
				_mode = BattleAI.Mode.RANDOM if args[i + 1] == "random" else BattleAI.Mode.GREEDY
			"--min-games":
				_min_games = args[i + 1].to_int()


func _card_ids(p: CombatProfile) -> PackedStringArray:
	var ids := PackedStringArray()
	for c in p.battle_cards:
		if not ids.has(String(c.id)):
			ids.append(String(c.id))
	return ids


## Ids of the parts in `genome`, each once. Parts in copy sockets (the
## second half of a pair: far arm, far wing...) are skipped, like
## CombatProfile does for cards, so a pair shows up as ONE row (its near
## part) instead of two identical rows.
func _part_ids(genome: Genome) -> PackedStringArray:
	var ids := PackedStringArray()
	_collect_part_ids(genome.root, ids)
	return ids


func _collect_part_ids(node: PartNode, ids: PackedStringArray) -> void:
	if not ids.has(String(node.part.id)):
		ids.append(String(node.part.id))
	for socket in node.part.sockets:
		var child: PartNode = node.children.get(socket.name)
		if child != null and socket.copy_from == &"":
			_collect_part_ids(child, ids)


## "When side X has more of something, how often does it win?"
func _rate(results: Array, key: String) -> String:
	var wins := 0
	var games := 0
	for r in results:
		if r.winner < 0 or r[key][0] == r[key][1]:
			continue
		games += 1
		var higher := 0 if r[key][0] > r[key][1] else 1
		if r.winner == higher:
			wins += 1
	if games == 0:
		return "n/a (no battle with a winner where this differed)"
	return "%.0f%% of %d battles" % [100.0 * wins / games, games]


func _report(results: Array, ms: int) -> void:
	var draws := 0
	var first_wins := 0
	var decided := 0
	var rounds := 0
	for r in results:
		rounds += r.rounds
		if r.winner < 0:
			draws += 1
			continue
		decided += 1
		if r.winner == r.first:
			first_wins += 1

	print("")
	print("=== Balance report: %d battles, AI %s, seed %d (%.1fs) ==="
		% [results.size(), BattleAI.Mode.keys()[_mode].to_lower(), _seed, ms / 1000.0])
	print("draws (no winner by round %d):  %d" % [CombatRules.MAX_ROUNDS, draws])
	print("average rounds:                %.1f" % (float(rounds) / maxi(results.size(), 1)))
	print("first team wins:               %s" % ("%.0f%% of %d" % [100.0 * first_wins / decided, decided] if decided else "n/a"))
	print("MORE PARTS wins:               %s" % _rate(results, "part_count"))
	print("HIGHER BUILD wins:             %s" % _rate(results, "build"))
	print("(ideal: near 50% -- more parts shouldn't simply win)")
	_print_table("CARDS", _presence_rates(results, "cards"), func(_id): return "")
	var reg: Node = root.get_node("PartRegistry")
	_print_table("PARTS", _presence_rates(results, "parts"), func(id):
		var part: PartDef = reg.get_part(StringName(id))
		if part == null:
			return ""
		var build: int = part.stats.build_weight if part.stats else 0
		return "%-6s build %+d  %d card(s)" % [part.type, build, part.added_cards.size()])


## For every id in results[i][key] (cards or parts): in battles with a
## winner where exactly ONE side has it, how often does that side win?
## Returns id -> [wins, battles].
func _presence_rates(results: Array, key: String) -> Dictionary:
	var out := {}
	for r in results:
		if r.winner < 0:
			continue  # draws say nothing about who's stronger
		var a: PackedStringArray = r[key][0]
		var b: PackedStringArray = r[key][1]
		for side in 2:
			var mine: PackedStringArray = a if side == 0 else b
			var theirs: PackedStringArray = b if side == 0 else a
			for id in mine:
				if theirs.has(id):
					continue  # mirror: both sides have it
				var entry: Array = out.get(id, [0, 0])
				entry[1] += 1
				if r.winner == side:
					entry[0] += 1
				out[id] = entry
	return out


## Prints `rates` (id -> [wins, battles]) sorted from strongest to weakest,
## with a 95% margin and a STRONG/WEAK flag. `extra` gives more text per id.
func _print_table(title: String, rates: Dictionary, extra: Callable) -> void:
	var ids := rates.keys().filter(func(id): return rates[id][1] >= _min_games)
	print("")
	if ids.is_empty():
		print("%s: no data (none seen in %d+ battles with a winner where only one side had it)"
			% [title, _min_games])
		return
	ids.sort_custom(func(x, y):
		return float(rates[x][0]) / rates[x][1] > float(rates[y][0]) / rates[y][1])
	print("%s (win rate when only one side has it; sorted strongest first):" % title)
	for id in ids:
		var wins: int = rates[id][0]
		var games: int = rates[id][1]
		var p := float(wins) / games
		var range := _wilson(wins, games)
		var flag := ""
		if range.x > 0.5:
			flag = "STRONG"
		elif range.y < 0.5:
			flag = "WEAK"
		print("  %-28s %3.0f%%  [%3.0f-%3.0f%%]  (%3d battles)  %-6s %s"
			% [id, 100.0 * p, 100.0 * range.x, 100.0 * range.y, games, flag, extra.call(id)])
	var hidden: int = rates.size() - ids.size()
	if hidden > 0:
		print("  (%d more seen in fewer than %d battles; see --min-games)" % [hidden, _min_games])


## 95% Wilson score interval for `wins` out of `games`: (low, high), 0-1.
## Unlike "rate +/- margin", it stays sensible at 0% / 100% and with few
## battles (e.g. 5 wins of 5 is roughly 57-100%, not exactly 100%).
func _wilson(wins: int, games: int) -> Vector2:
	var z := 1.96
	var n := float(games)
	var p := wins / n
	var denom := 1.0 + z * z / n
	var center := (p + z * z / (2.0 * n)) / denom
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return Vector2(maxf(0.0, center - half), minf(1.0, center + half))
