extends SceneTree
## Balancing-Simulation: ein Bot spielt mit vereinfachten Regeln und meldet, wann er Meilensteine erreicht.
## godot --headless --path . -s res://tests/balance_sim.gd
## Annahmen: Spieler kurbelt 60 % der Zeit selbst, öffnet sofort, kauft immer das günstigste Upgrade,
## wertet Automaten auf, reist so früh wie möglich und stellt Automaten mit fehlenden Figuren nebenbei auf.

const DT := 1.0
const MAX_HOURS := 45.0
const ACTIVE := 0.6

var g
var t := 0.0
var marks := {}
var run_start := 0.0

func mark(key: String) -> void:
	if not marks.has(key):
		marks[key] = t
		print("%6.1f h  %s   (Münzen %s, Album %d, Goldmarken %d, Plätze %d)" % [t / 3600.0, key, Fmt.num(g.coins), g.album_count(), g.goldmarken_total, g.slot_count()])

func _initialize() -> void:
	_run.call_deferred()

## Erwartete Münzen pro Kapsel abzüglich Preis.
func ev(mid: String) -> float:
	var m: Dictionary = g.machine_by_id[mid]
	var tot := 0.0
	var val := 0.0
	for r in g.rarities:
		var w: float = float(m["weights"][r["id"]]) * (g.luck_mult() if r["id"] != "common" else 1.0)
		tot += w
		val += w * float(r["value"])
	var curse := float(m["curse_chance"])
	var bonus: float = (1.0 + 4.0 * g.crit_chance()) * (1.0 + 2.0 * float(m["bless_chance"])) \
		* (1.0 + 24.0 * float(m["jackpot_chance"])) * (1.0 + float(m["frozen_chance"])) \
		* (1.0 + 3.0 * float(m["erupt_chance"])) * (1.0 + g.double_chance(mid))
	var per: float = val / tot * g.machine_value_mult(mid) * g.capsule_value_mult() * bonus
	return per * (1.0 - float(m["empty_chance"])) * (1.0 - curse) - curse * g.capsule_cost(mid) * 2.0 - g.capsule_cost(mid)

func missing(mid: String) -> int:
	var n := 0
	for sid in g.machine_by_id[mid]["sets"]:
		for f in g.set_by_id[sid]["figures"]:
			if not g.owned.has(f["id"]):
				n += 1
	return n

func _run() -> void:
	g = root.get_node("Game")
	g.reset_game()
	g.active = true
	g.set_process(false)
	var acc := 0.0
	var wall := Time.get_ticks_msec()
	while t < MAX_HOURS * 3600.0:
		t += DT
		g.stats["play_time"] = t
		g.earn(g.income_per_sec() * DT)
		var rate: float = g.crank_speed() * ACTIVE + g.hamster_speed()
		acc += rate * DT
		var n := 0
		while acc >= 1.0 and n < 50:
			acc -= 1.0
			n += 1
			if g.try_pay_capsule(false) != 1:
				acc = 0.0
				break
			g.combo_timer = 1.0 if rate > 0.4 else 0.0
			var res: Dictionary = g.open_capsule(g.roll_capsule(), g.current_machine)
			if res.get("erupt", false):
				for k in 3:
					g.open_capsule(g.roll_capsule(), g.current_machine)
		g.run_background(DT)
		if int(t) % 5 == 0:
			_decide()
		if g.build_golden():
			mark("GOLDENER AUTOMAT (Ende)")
			break
		if int(t) % 3600 == 0:
			print("%6.1f h  ... Münzen %s, %s/s passiv, EV %s, Automat %s, Welten %d, Album %d, Mult %s" % [t / 3600.0, Fmt.num(g.coins), Fmt.rate(g.income_per_sec()), Fmt.num(ev(g.current_machine)), g.current_machine, g.unlocked_worlds.size(), g.album_count(), Fmt.num(g.capsule_value_mult())])
	print("Erfolge: %d/%d, Kapseln: %s, Rechenzeit %d s" % [g.achievements.size(), g.achievement_list.size(), Fmt.num(g.stats["capsules_opened"]), (Time.get_ticks_msec() - wall) / 1000])
	g.reset_game()
	quit()

func _decide() -> void:
	# Kaufen: günstigstes Upgrade, dazu Automaten-Stufen, wenn sie weniger als ein Upgrade kosten
	var bought := true
	while bought:
		bought = false
		var best := ""
		for id in g.upgrade_by_id:
			if g.can_buy(id) and (best == "" or g.upgrade_cost(id) < g.upgrade_cost(best)):
				best = id
		var best_m := ""
		for mid in g.placed:
			if g.can_level_machine(mid) and (best_m == "" or g.machine_level_cost(mid) < g.machine_level_cost(best_m)):
				best_m = mid
		if best_m != "" and (best == "" or g.machine_level_cost(best_m) < g.upgrade_cost(best)):
			g.level_machine(best_m)
			bought = true
			if g.machine_level(best_m) == 10:
				mark("Automat %s Stufe 10" % best_m)
		elif best != "":
			g.buy(best)
			bought = true
			if best == "hamster":
				mark("Hamster gekauft")
			if best == "anbau":
				mark("Anbau %d" % g.level("anbau"))
	# Reisen
	for w in g.worlds:
		if g.can_travel(w["id"]):
			g.travel(w["id"])
			mark("Reise nach " + w["name"])
	# Automaten freischalten
	for m in g.machines:
		var mid: String = m["id"]
		if not mid in g.unlocked_machines and g.machine_available(mid) and g.coins > float(m["unlock_cost"]) * 1.2:
			g.unlock_machine(mid)
			mark(mid + " freigeschaltet")
	# Gezeigter Automat: bester Erwartungswert. Nebenautomaten: die mit den meisten fehlenden Figuren.
	var choice: String = g.current_machine
	for mid in g.unlocked_machines:
		if ev(mid) > ev(choice):
			choice = mid
	g.select_machine(choice)
	var cands: Array = []
	for mid in g.unlocked_machines:
		if mid != choice and missing(mid) > 0 and g.coins > g.capsule_cost(mid) * 50:
			cands.append(mid)
	cands.sort_custom(func(a: String, b: String) -> bool: return missing(a) > missing(b))
	for mid in g.placed.duplicate():
		if mid != choice and not mid in cands.slice(0, g.slot_count() - 1):
			g.toggle_placed(mid)
	for mid in cands.slice(0, g.slot_count() - 1):
		if not mid in g.placed:
			g.toggle_placed(mid)
	# Fusion für fehlende Seltenheiten
	if g.fusion_unlocked():
		for r in ["epic", "rare", "common"]:
			while g.can_fuse(r):
				g.fuse(r)
	for k in [48, 100, 150, 192]:
		if g.album_count() >= k:
			mark("Album %d" % k)
	for w in g.worlds:
		if g.album_count(w["id"]) >= 48:
			mark("Album %s komplett" % w["name"])
	# Neueröffnung, wenn sich die Goldmarken etwa verdoppeln
	var gain: int = g.prestige_gain()
	if t - run_start > 900.0 and gain >= maxi(5, g.goldmarken_total):
		g.do_prestige()
		run_start = t
		mark("Neueröffnung %d (+%d)" % [g.stats["prestiges"], gain])
		for id in ["p_fusion", "p_hamster", "p_spuk", "p_slot", "p_keep", "p_aushilfe", "p_value", "p_luck", "p_start", "p_offline"]:
			while g.buy_prestige(id):
				pass
