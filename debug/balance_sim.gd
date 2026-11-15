## Headless balance test: random creature pairs fight 1v1, AI vs AI, and a
## report shows whether more parts / higher build / going first win more
## often, and how each card does. Nothing is saved.
##
## Run from the project folder:
##   godot --headless --path . --script res://debug/balance_sim.gd -- --battles 200 --seed 1 --ai greedy
## Options: --battles N (default 200), --seed S (default 1),
##          --ai greedy|random (default greedy).
extends SceneTree

var _battles := 200
var _seed := 1
var _mode := BattleAI.Mode.GREEDY

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


func _card_ids(p: CombatProfile) -> PackedStringArray:
	var ids := PackedStringArray()
	for c in p.battle_cards:
		if not ids.has(String(c.id)):
			ids.append(String(c.id))
	return ids


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
	var card_games := {}
	var card_wins := {}
	for r in results:
		rounds += r.rounds
		if r.winner < 0:
			draws += 1
			continue
		decided += 1
		if r.winner == r.first:
			first_wins += 1
		for side in 2:
			for id in r.cards[side]:
				card_games[id] = card_games.get(id, 0) + 1
				if r.winner == side:
					card_wins[id] = card_wins.get(id, 0) + 1

	print("")
	print("=== Balance report: %d battles, AI %s, seed %d (%.1fs) ==="
		% [results.size(), BattleAI.Mode.keys()[_mode].to_lower(), _seed, ms / 1000.0])
	print("draws (no winner by round %d):  %d" % [CombatRules.MAX_ROUNDS, draws])
	print("average rounds:                %.1f" % (float(rounds) / maxi(results.size(), 1)))
	print("first team wins:               %s" % ("%.0f%% of %d" % [100.0 * first_wins / decided, decided] if decided else "n/a"))
	print("MORE PARTS wins:               %s" % _rate(results, "part_count"))
	print("HIGHER BUILD wins:             %s" % _rate(results, "build"))
	print("(ideal: near 50% -- more parts shouldn't simply win)")
	if not card_games.is_empty():
		print("cards (win rate when in the deck):")
		var ids := card_games.keys()
		ids.sort()
		for id in ids:
			print("  %-20s %3.0f%%  (%d decks)" % [id, 100.0 * card_wins.get(id, 0) / card_games[id], card_games[id]])
