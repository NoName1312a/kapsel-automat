extends Node
## Spielstand, Wirtschaft und Regeln. Als Autoload "Game" erreichbar.
## Alle Balancing-Werte kommen aus data/*.json, damit man ohne Code-Änderung tunen kann.
## Diese Datei kennt keine Grafik: main.gd und ui.gd zeigen nur an, was hier passiert.

signal changed
signal achievement_unlocked(ach: Dictionary)
signal upgrade_revealed(up: Dictionary)
## Kapsel, die ein Nebenautomat von allein geöffnet hat (für kleine Meldungen).
signal background_opened(machine_id: String, res: Dictionary)
signal machine_leveled(machine_id: String, new_level: int)
signal world_unlocked(world_id: String)
## Story-Ereignis, z. B. "new_game", "world:insel", "set:obst", "album:stadt", "legendary_first", "golden".
signal story_event(trigger: String)

const SAVE_FILE := "save.json"
const BACKUP_FILE := "save.bak"
const TMP_FILE := "save.tmp"
const SAVE_VERSION := 4
const START_COINS := 30.0
const COMBO_WINDOW := 2.5
const OFFLINE_RATE := 0.5
const FUSION_NEXT := {"common": "rare", "rare": "epic", "epic": "legendary"}
const FUSION_COST := {"common": 3, "rare": 3, "epic": 4}
const PRESTIGE_DIVISOR := 1.0e5
const PRESTIGE_EXP := 1.0 / 3.0
const GOLDMARKE_BONUS := 0.03
const MACHINE_MAX_LEVEL := 10
const MACHINE_LEVEL_VALUE := 0.3       # +30 % Münzen je Automaten-Stufe
const MACHINE_LEVEL_SPEED := 0.25      # +25 % Tempo nebenbei je Stufe
const MACHINE_LEVEL_BASE := 60.0       # erste Stufe kostet 60 Kapseln
const MACHINE_LEVEL_GROWTH := 3.5
const BG_RATE := 0.3                   # Kapseln/s eines Nebenautomaten ohne Upgrades
const JACKPOT_MULT := 25.0
const FROZEN_MULT := 2.0
const FROZEN_HITS := 3
const ERUPT_CAPSULES := 3

# --- Lauf-Zustand (wird bei Neueröffnung zurückgesetzt) ---
var coins: float = START_COINS
var levels: Dictionary = {}
var unlocked_machines: Array = ["standard"]
var current_machine: String = "standard"
var placed: Array = ["standard"]        # aufgestellte Automaten (Platz 0 … slot_count()-1)
var machine_levels: Dictionary = {}     # machine_id -> Stufe

# --- Dauerhaft ---
var owned: Dictionary = {}              # figur_id -> Anzahl
var goldmarken: int = 0                  # ausgebbar
var goldmarken_total: int = 0            # jemals verdient (gibt Bonus)
var prestige_levels: Dictionary = {}
var achievements: Dictionary = {}        # id -> true
var revealed: Dictionary = {}            # upgrade_id -> true
var unlocked_worlds: Array = ["stadt"]
var story_seen: Dictionary = {}          # Trigger -> true
var stats: Dictionary = {}

# --- Nur zur Laufzeit ---
var combo: int = 0
var combo_timer: float = 0.0
var offline_report: Dictionary = {}      # nach dem Laden gefüllt, ui.gd zeigt es an
var _check_timer: float = 0.0
var _bg_acc: Dictionary = {}

## Erst true, wenn ein Spiel läuft (nicht im Hauptmenü): sonst kein Einkommen, kein Speichern.
var active := false

# --- Daten ---
var set_bonus: float = 0.15
var achievement_bonus: float = 0.02
var rarities: Array = []
var rarity_by_id: Dictionary = {}
var sets: Array = []
var set_by_id: Dictionary = {}
var figures: Dictionary = {}
var upgrades: Array = []
var upgrade_by_id: Dictionary = {}
var prestige_upgrades: Array = []
var prestige_by_id: Dictionary = {}
var machines: Array = []
var machine_by_id: Dictionary = {}
var golden: Dictionary = {}
var achievement_list: Array = []
var worlds: Array = []
var world_by_id: Dictionary = {}

const STAT_KEYS := ["capsules_opened", "total_earned", "run_earned", "legendaries", "empties", "curses",
	"prestiges", "fusions", "max_combo", "crank_turns", "upgrades_bought", "golden_built", "doubles",
	"crits", "play_time", "jackpots", "eruptions", "frozen_opened", "bg_capsules", "machine_upgrades",
	"blessings", "run_points"]


func _ready() -> void:
	_load_data()
	_reset_stats()


func has_save() -> bool:
	return FileAccess.file_exists("user://" + SAVE_FILE) or FileAccess.file_exists("user://" + BACKUP_FILE)


## Neues Spiel: alles auf Anfang (der alte Spielstand wird überschrieben).
func start_new() -> void:
	offline_report = {}
	reset_game()
	active = true
	fire_story("new_game")


## Spielstand laden und weiterspielen (ohne Spielstand: neues Spiel).
func start_loaded() -> void:
	if not has_save():
		start_new()
		return
	load_game()
	combo = 0
	active = true
	changed.emit()


## Zurück ins Hauptmenü: speichern und anhalten.
func stop() -> void:
	if active:
		save_game()
	active = false


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _load_data() -> void:
	var wd := _json("res://data/worlds.json")
	worlds = wd["worlds"]
	for w in worlds:
		world_by_id[w["id"]] = w
	var f := _json("res://data/figures.json")
	set_bonus = float(f["set_bonus"])
	rarities = f["rarities"]
	for r in rarities:
		rarity_by_id[r["id"]] = r
	sets = f["sets"]
	for s in sets:
		set_by_id[s["id"]] = s
		for fig in s["figures"]:
			var d: Dictionary = fig.duplicate()
			var r: Dictionary = rarity_by_id[fig["rarity"]]
			d["set_id"] = s["id"]
			d["set_name"] = s["name"]
			d["set_color"] = s["color"]
			d["world"] = s.get("world", "stadt")
			d["rarity_name"] = r["name"]
			d["rarity_color"] = r["color"]
			figures[fig["id"]] = d
	var u := _json("res://data/upgrades.json")
	upgrades = u["upgrades"]
	for x in upgrades:
		upgrade_by_id[x["id"]] = x
	prestige_upgrades = u["prestige"]
	for x in prestige_upgrades:
		prestige_by_id[x["id"]] = x
	var m := _json("res://data/machines.json")
	machines = m["machines"]
	for x in machines:
		machine_by_id[x["id"]] = x
	golden = m["golden"]
	var a := _json("res://data/achievements.json")
	achievement_bonus = float(a["bonus_per_achievement"])
	achievement_list = a["achievements"]


func _reset_stats() -> void:
	stats = {}
	for k in STAT_KEYS:
		stats[k] = 0.0


func _process(delta: float) -> void:
	if not active:
		return
	stats["play_time"] += delta
	var inc := income_per_sec()
	if inc > 0.0:
		earn(inc * delta)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			if combo >= 3:
				Sfx.play_first(["combo_break"], 1.0, -6.0)
			combo = 0
	run_background(delta)
	_check_timer += delta
	if _check_timer >= 0.5:
		_check_timer = 0.0
		check_progress()


func earn(amount: float) -> void:
	coins += amount
	if amount > 0.0:
		stats["total_earned"] += amount
		stats["run_earned"] += amount
		# Für Goldmarken zählt der Verdienst im Verhältnis zur höchsten Welt, sonst explodieren sie
		stats["run_points"] += amount / top_value_scale()


## Wertmaßstab der höchsten freigeschalteten Welt.
func top_value_scale() -> float:
	var best := 1.0
	for w in unlocked_worlds:
		best = maxf(best, float(world_by_id[w].get("value_scale", 1.0)))
	return best


# --- Werte und Multiplikatoren -------------------------------------------

## Upgrades mit "scope": "machine" gelten nur für einen Automaten (Schlüssel "<automat>/<upgrade>"),
## die übrigen (Laden) für alle.
func is_machine_upgrade(id: String) -> bool:
	return upgrade_by_id[id].get("scope", "") == "machine"


func _lkey(id: String, m: String = "") -> String:
	if not is_machine_upgrade(id):
		return id
	return (m if m != "" else current_machine) + "/" + id


func level(id: String, m: String = "") -> int:
	var lv := int(levels.get(_lkey(id, m), 0))
	if id == "hamster":
		lv = maxi(lv, int(_peff("p_hamster")))   # Hamster-Rente gilt für jeden Automaten
	return lv


func plevel(id: String) -> int:
	return int(prestige_levels.get(id, 0))


func _eff(id: String, m: String = "") -> float:
	return float(upgrade_by_id[id]["per_level"]) * level(id, m)


func _peff(id: String) -> float:
	return float(prestige_by_id[id]["per_level"]) * plevel(id)


func luck_mult(m: String = "") -> float:
	return (1.0 + _eff("luck", m)) * (1.0 + _peff("p_luck"))


## Gilt für Kapsel-Münzen und passives Einkommen.
func global_mult() -> float:
	return (1.0 + set_bonus * complete_sets()) \
		* (1.0 + GOLDMARKE_BONUS * goldmarken_total) \
		* (1.0 + _peff("p_value")) \
		* (1.0 + achievement_bonus * achievements.size())


func capsule_value_mult(m: String = "") -> float:
	return (1.0 + _eff("value", m)) * global_mult()


func combo_max(machine_id: String = "") -> int:
	var m: Dictionary = machine_by_id[machine_id if machine_id != "" else current_machine]
	return 1 + int(_eff("combo", m["id"])) + int(m.get("combo_bonus", 0))


func combo_mult() -> float:
	return 1.0 + 0.05 * maxi(combo - 1, 0)


func crank_speed() -> float:
	return 0.9 * (1.0 + _eff("speed"))


func hamster_speed() -> float:
	return _eff("hamster")


func auto_open_interval() -> float:
	var lv := level("autoopen")
	return 0.0 if lv == 0 else 0.7 / lv


func tray_size() -> int:
	return 5 + int(_eff("tray"))


func double_chance(machine_id: String = "") -> float:
	var m: Dictionary = machine_by_id[machine_id if machine_id != "" else current_machine]
	return _eff("double", m["id"]) + float(m.get("double_bonus", 0.0))


func crit_chance(m: String = "") -> float:
	return _eff("crit", m)


func has_bulk_open() -> bool:
	return level("bulk") > 0


func fusion_unlocked() -> bool:
	return plevel("p_fusion") > 0


func figure_level(id: String) -> int:
	var n := int(owned.get(id, 0))
	return 0 if n <= 0 else 1 + int(floor(log(n) / log(2.0)))


func world_scale(world_id: String) -> float:
	return float(world_by_id[world_id]["scale"]) if world_by_id.has(world_id) else 1.0


func figure_income(id: String) -> float:
	var fig: Dictionary = figures[id]
	var w: Dictionary = world_by_id.get(fig["world"], {})
	return float(rarity_by_id[fig["rarity"]]["income"]) * float(w.get("value_scale", w.get("scale", 1.0)))


func income_per_sec() -> float:
	var base := 0.0
	for id in owned:
		base += figure_income(id) * figure_level(id)
	return base * (1.0 + _eff("passive")) * global_mult()


# --- Welten ---------------------------------------------------------------

func world_index(world_id: String) -> int:
	for i in worlds.size():
		if worlds[i]["id"] == world_id:
			return i
	return -1


func current_world() -> String:
	return machine_by_id[current_machine].get("world", "stadt")


func world_machines(world_id: String) -> Array:
	var out: Array = []
	for m in machines:
		if m.get("world", "stadt") == world_id:
			out.append(m)
	return out


func world_sets(world_id: String) -> Array:
	var out: Array = []
	for s in sets:
		if s.get("world", "stadt") == world_id:
			out.append(s)
	return out


## Die vorige Welt, deren Sets man für die Reise braucht ("" bei der ersten Welt).
func previous_world(world_id: String) -> String:
	var i := world_index(world_id)
	return worlds[i - 1]["id"] if i > 0 else ""


func travel_requirements_met(world_id: String) -> bool:
	var prev := previous_world(world_id)
	if prev == "" or not prev in unlocked_worlds:
		return prev == ""
	return complete_sets(prev) >= int(world_by_id[world_id]["travel_sets"])


func can_travel(world_id: String) -> bool:
	return not world_id in unlocked_worlds and travel_requirements_met(world_id) \
		and coins >= float(world_by_id[world_id]["travel_cost"])


func travel(world_id: String) -> bool:
	if not can_travel(world_id):
		return false
	coins -= float(world_by_id[world_id]["travel_cost"])
	unlocked_worlds.append(world_id)
	var first: String = world_machines(world_id)[0]["id"]
	if not first in unlocked_machines:
		unlocked_machines.append(first)
	select_machine(first)
	world_unlocked.emit(world_id)
	fire_story("world:" + world_id)
	_after_change()
	return true


## Springt in eine schon bekannte Welt, zum ersten aufgestellten (oder freigeschalteten) Automaten dort.
func go_to_world(world_id: String) -> void:
	if not world_id in unlocked_worlds:
		return
	for id in placed:
		if machine_by_id[id].get("world", "stadt") == world_id:
			select_machine(id)
			return
	for m in world_machines(world_id):
		if m["id"] in unlocked_machines:
			select_machine(m["id"])
			return


# --- Automaten ------------------------------------------------------------

func machine() -> Dictionary:
	return machine_by_id[current_machine]


func capsule_cost(machine_id: String = "") -> float:
	var m: Dictionary = machine_by_id[machine_id if machine_id != "" else current_machine]
	return floorf(float(m["cost"]) * (1.0 - _eff("discount", m["id"])))


func can_afford_capsule() -> bool:
	return coins >= capsule_cost()


## 1 = bezahlt, 2 = gratis (Notgroschen, nur von Hand), 0 = geht nicht.
func try_pay_capsule(manual: bool, machine_id: String = "") -> int:
	var c := capsule_cost(machine_id)
	if coins >= c:
		coins -= c
		return 1
	return 2 if manual else 0


func machine_available(id: String) -> bool:
	var m: Dictionary = machine_by_id[id]
	if not m.get("world", "stadt") in unlocked_worlds:
		return false
	return not m.has("requires_prestige") or plevel(m["requires_prestige"]) > 0


func unlock_machine(id: String) -> bool:
	var m: Dictionary = machine_by_id[id]
	if id in unlocked_machines or not machine_available(id) or coins < float(m["unlock_cost"]):
		return false
	coins -= float(m["unlock_cost"])
	unlocked_machines.append(id)
	select_machine(id)
	fire_story("machine:" + id)
	_after_change()
	return true


func slot_count() -> int:
	return 1 + int(_eff("anbau")) + int(_peff("p_slot"))


## Zeigt einen Automaten groß an. Ist er noch nicht aufgestellt, kommt er auf einen freien Platz
## oder ersetzt den bisher gezeigten.
func select_machine(id: String) -> void:
	if not id in unlocked_machines:
		return
	if not id in placed:
		if placed.size() < slot_count():
			placed.append(id)
		else:
			var i := placed.find(current_machine)
			placed[maxi(i, 0)] = id
	current_machine = id
	changed.emit()


## Automat auf einen freien Platz stellen bzw. wieder abbauen (der gezeigte bleibt immer stehen).
func toggle_placed(id: String) -> bool:
	if not id in unlocked_machines:
		return false
	if id in placed:
		if id == current_machine:
			return false
		placed.erase(id)
	else:
		if placed.size() >= slot_count():
			return false
		placed.append(id)
	_after_change()
	return true


func machine_level(id: String) -> int:
	return int(machine_levels.get(id, 0))


func machine_level_cost(id: String) -> float:
	return floorf(float(machine_by_id[id]["cost"]) * MACHINE_LEVEL_BASE * pow(MACHINE_LEVEL_GROWTH, machine_level(id)))


func can_level_machine(id: String) -> bool:
	return id in unlocked_machines and machine_level(id) < MACHINE_MAX_LEVEL and coins >= machine_level_cost(id)


func level_machine(id: String) -> bool:
	if not can_level_machine(id):
		return false
	coins -= machine_level_cost(id)
	machine_levels[id] = machine_level(id) + 1
	stats["machine_upgrades"] += 1
	machine_leveled.emit(id, machine_level(id))
	if machine_level(id) >= 2:
		fire_story("machine_level:2")
	_after_change()
	return true


func machine_value_mult(id: String) -> float:
	return float(machine_by_id[id]["value_mult"]) * (1.0 + MACHINE_LEVEL_VALUE * machine_level(id))


## Kapseln pro Sekunde, die ein aufgestellter, aber nicht gezeigter Automat von allein öffnet.
func background_rate(id: String) -> float:
	return BG_RATE * (1.0 + MACHINE_LEVEL_SPEED * machine_level(id)) * (1.0 + _eff("aushilfe")) * (1.0 + _peff("p_aushilfe"))


func run_background(delta: float) -> void:
	for id in placed:
		if id == current_machine:
			continue
		var acc: float = _bg_acc.get(id, 0.0) + background_rate(id) * delta
		var n := 0
		while acc >= 1.0 and n < 20:
			acc -= 1.0
			n += 1
			if try_pay_capsule(false, id) != 1:
				acc = 0.0
				break
			var content := roll_capsule(id)
			var res := open_capsule(content, id, true)
			stats["bg_capsules"] += 1
			if res.get("erupt", false):
				for k in ERUPT_CAPSULES:
					open_capsule(roll_capsule(id), id, true)
			background_opened.emit(id, res)
		_bg_acc[id] = acc


## Würfelt beim Herausfallen, was in der Kapsel steckt (damit z. B. Gold-Kapseln vorher sichtbar sind).
func roll_capsule(machine_id: String = "") -> Dictionary:
	var m: Dictionary = machine_by_id[machine_id if machine_id != "" else current_machine]
	if randf() < float(m["empty_chance"]):
		return {"type": "empty"}
	if randf() < float(m["curse_chance"]):
		return {"type": "curse", "figure": _roll_figure(m)}
	var res := {"type": "figure", "figure": _roll_figure(m), "blessed": randf() < float(m["bless_chance"]),
		"jackpot": randf() < float(m.get("jackpot_chance", 0.0)),
		"frozen": randf() < float(m.get("frozen_chance", 0.0)),
		"erupt": randf() < float(m.get("erupt_chance", 0.0))}
	if randf() < double_chance(m["id"]):
		res["second"] = _roll_figure(m)
	return res


func _roll_figure(m: Dictionary) -> Dictionary:
	var weights: Dictionary = m["weights"]
	var chosen := _roll_rarity(weights, m["id"])
	return _random_figure(chosen, m["sets"])


func _roll_rarity(weights: Dictionary, machine_id: String = "") -> String:
	var total := 0.0
	var w := {}
	for r in rarities:
		var x := float(weights[r["id"]])
		if r["id"] != "common":
			x *= luck_mult(machine_id)
		w[r["id"]] = x
		total += x
	var roll := randf() * total
	for r in rarities:
		roll -= w[r["id"]]
		if roll <= 0.0:
			return r["id"]
	return rarities[rarities.size() - 1]["id"]


func _random_figure(rarity: String, set_ids: Array) -> Dictionary:
	var pool: Array = []
	for sid in set_ids:
		for fig in set_by_id[sid]["figures"]:
			if fig["rarity"] == rarity:
				pool.append(fig["id"])
	return figures[pool.pick_random()]


## Öffnet eine Kapsel. Gibt zurück, was passiert ist, damit main.gd die Effekte zeigen kann.
## background = von einem Nebenautomaten geöffnet (keine Kombo).
func open_capsule(content: Dictionary, machine_id: String, background: bool = false) -> Dictionary:
	stats["capsules_opened"] += 1
	if content["type"] == "empty":
		stats["empties"] += 1
		if not background:
			combo = 0
			combo_timer = 0.0
		_after_change()
		return {"type": "empty"}

	if not background:
		if combo_timer > 0.0:
			combo = mini(combo + 1, combo_max(machine_id))
		else:
			combo = 1
		var window := COMBO_WINDOW * (1.5 if int(machine_by_id[machine_id].get("combo_bonus", 0)) > 0 else 1.0)
		combo_timer = window
		stats["max_combo"] = maxf(stats["max_combo"], combo)

	var res := {"type": content["type"], "figures": [], "new": [], "set_completed": false,
		"crit": false, "blessed": content.get("blessed", false), "jackpot": content.get("jackpot", false),
		"frozen": content.get("frozen", false), "erupt": content.get("erupt", false),
		"combo": combo if not background else 0, "completed_sets": []}
	var done_before: Dictionary = {}
	for s in sets:
		if is_set_complete(s):
			done_before[s["id"]] = true
	var figs: Array = [content["figure"]]
	if content.has("second"):
		figs.append(content["second"])
		stats["doubles"] += 1
	var value := 0.0
	for fig in figs:
		if not owned.has(fig["id"]):
			res["new"].append(fig["id"])
		owned[fig["id"]] = int(owned.get(fig["id"], 0)) + 1
		if fig["rarity"] == "legendary":
			stats["legendaries"] += 1
			fire_story("legendary_first")
		value += float(rarity_by_id[fig["rarity"]]["value"])
		res["figures"].append(fig)
	value *= machine_value_mult(machine_id) * capsule_value_mult(machine_id) * (combo_mult() if not background else 1.0)
	if content["type"] == "curse":
		stats["curses"] += 1
		value = -minf(coins, capsule_cost(machine_id) * 2.0)
	else:
		if randf() < crit_chance(machine_id):
			value *= 5.0
			res["crit"] = true
			stats["crits"] += 1
		if res["blessed"]:
			value *= 3.0
			stats["blessings"] += 1
		if res["jackpot"]:
			value *= JACKPOT_MULT
			stats["jackpots"] += 1
		if res["frozen"]:
			value *= FROZEN_MULT
			stats["frozen_opened"] += 1
		if res["erupt"]:
			stats["eruptions"] += 1
	value = roundf(value)
	earn(value)
	res["value"] = value
	for s in sets:
		if not done_before.has(s["id"]) and is_set_complete(s):
			res["completed_sets"].append(s["id"])
			fire_story("set:" + s["id"])
			if complete_sets(s["world"]) == world_sets(s["world"]).size():
				fire_story("album:" + s["world"])
	res["set_completed"] = not res["completed_sets"].is_empty()
	_after_change()
	return res


func add_crank_turn() -> void:
	stats["crank_turns"] += 1


# --- Upgrades -------------------------------------------------------------

## Automaten-Upgrades kosten so viel mehr, wie der Automat mehr einbringt.
func upgrade_cost_scale(id: String, m: String = "") -> float:
	if not is_machine_upgrade(id):
		return 1.0
	return maxf(1.0, float(machine_by_id[m if m != "" else current_machine]["value_mult"]))


func upgrade_cost(id: String, m: String = "") -> float:
	var u: Dictionary = upgrade_by_id[id]
	return floorf(float(u["base_cost"]) * pow(float(u["growth"]), level(id, m)) * upgrade_cost_scale(id, m))


func is_maxed(id: String, m: String = "") -> bool:
	return level(id, m) >= int(upgrade_by_id[id]["max_level"])


func is_revealed(id: String) -> bool:
	return revealed.has(id) or float(upgrade_by_id[id]["unlock_at"]) <= 0.0


func can_buy(id: String, m: String = "") -> bool:
	return is_revealed(id) and not is_maxed(id, m) and coins >= upgrade_cost(id, m)


func buy(id: String, m: String = "") -> bool:
	if not can_buy(id, m):
		return false
	coins -= upgrade_cost(id, m)
	levels[_lkey(id, m)] = int(levels.get(_lkey(id, m), 0)) + 1
	stats["upgrades_bought"] += 1
	_after_change()
	return true


## Wie oft man das Upgrade direkt hintereinander kaufen kann (für "Max kaufen").
func buy_max(id: String, m: String = "") -> int:
	var n := 0
	while buy(id, m):
		n += 1
	return n


# --- Neueröffnung (Prestige) ---------------------------------------------

func prestige_gain() -> int:
	return int(floor(3.0 * pow(stats["run_points"] / PRESTIGE_DIVISOR, PRESTIGE_EXP)))


## Ab so viel verdienten Münzen gibt es die erste Goldmarke.
func prestige_threshold() -> float:
	return PRESTIGE_DIVISOR * pow(1.0 / 3.0, 1.0 / PRESTIGE_EXP)


func prestige_cost(id: String) -> int:
	var p: Dictionary = prestige_by_id[id]
	return int(floor(float(p["base_cost"]) * pow(float(p["growth"]), plevel(id))))


func prestige_maxed(id: String) -> bool:
	return plevel(id) >= int(prestige_by_id[id]["max_level"])


func buy_prestige(id: String) -> bool:
	if prestige_maxed(id) or goldmarken < prestige_cost(id):
		return false
	goldmarken -= prestige_cost(id)
	prestige_levels[id] = plevel(id) + 1
	_after_change()
	return true


## Münzen, Upgrades, Automaten und Stufen zurück auf Anfang. Album, Erfolge, Welten und Goldmarken bleiben.
## In jeder bekannten Welt bleibt der erste Automat freigeschaltet.
func do_prestige() -> int:
	var gain := prestige_gain()
	if gain < 1:
		return 0
	goldmarken += gain
	goldmarken_total += gain
	stats["prestiges"] += 1
	stats["run_earned"] = 0.0
	stats["run_points"] = 0.0
	coins = START_COINS + _peff("p_start")
	levels = {}
	unlocked_machines = []
	for w in unlocked_worlds:
		unlocked_machines.append(world_machines(w)[0]["id"])
	if plevel("p_keep") > 0:
		unlocked_machines.append("glueck")
	machine_levels = {}
	current_machine = "standard"
	placed = ["standard"]
	_bg_acc = {}
	combo = 0
	if story_seen.has("prestige_first"):
		story_event.emit("prestige_line")   # ab der zweiten Neueröffnung: ein Wechselspruch
	fire_story("prestige_first")
	_after_change()
	save_game()
	return gain


# --- Fusion ---------------------------------------------------------------

func fusion_dupes(rarity: String) -> int:
	var n := 0
	for id in owned:
		if figures[id]["rarity"] == rarity:
			n += maxi(int(owned[id]) - 1, 0)
	return n


func can_fuse(rarity: String) -> bool:
	return fusion_unlocked() and FUSION_NEXT.has(rarity) and fusion_dupes(rarity) >= FUSION_COST[rarity]


## Verbraucht Duplikate (immer vom häufigsten zuerst) und gibt eine Figur der nächsten Seltenheit
## aus den Sets der freigeschalteten Automaten, bevorzugt eine noch fehlende.
func fuse(rarity: String) -> Dictionary:
	if not can_fuse(rarity):
		return {}
	var need: int = FUSION_COST[rarity]
	while need > 0:
		var best := ""
		for id in owned:
			if figures[id]["rarity"] == rarity and int(owned[id]) > 1:
				if best == "" or int(owned[id]) > int(owned[best]):
					best = id
		owned[best] = int(owned[best]) - 1
		need -= 1
	var set_ids: Array = []
	for mid in unlocked_machines:
		for sid in machine_by_id[mid]["sets"]:
			if not sid in set_ids:
				set_ids.append(sid)
	var fig := _random_figure(FUSION_NEXT[rarity], set_ids)
	var is_new := not owned.has(fig["id"])
	owned[fig["id"]] = int(owned.get(fig["id"], 0)) + 1
	stats["fusions"] += 1
	if fig["rarity"] == "legendary":
		stats["legendaries"] += 1
	_after_change()
	return {"figure": fig, "is_new": is_new}


## Fusioniert alles, was geht (Gewöhnlich zuerst, dann die neu entstandenen Seltenen usw.).
## Gibt {count, new, legendary, figures} zurück.
func fuse_all() -> Dictionary:
	var out := {"count": 0, "new": 0, "legendary": 0, "figures": []}
	for rarity in ["common", "rare", "epic"]:
		while can_fuse(rarity) and out["count"] < 2000:
			var r := fuse(rarity)
			if r.is_empty():
				break
			out["count"] += 1
			out["figures"].append(r["figure"])
			if r["is_new"]:
				out["new"] += 1
			if r["figure"]["rarity"] == "legendary":
				out["legendary"] += 1
	return out


# --- Goldener Automat (Spielziel) ----------------------------------------

func golden_album_needed() -> int:
	return int(golden.get("album_needed", figures.size()))


func can_build_golden() -> bool:
	return stats["golden_built"] < 1 and golden.get("world", "stadt") in unlocked_worlds \
		and album_count() >= golden_album_needed() and coins >= float(golden["cost"])


func build_golden() -> bool:
	if not can_build_golden():
		return false
	coins -= float(golden["cost"])
	stats["golden_built"] = 1
	fire_story("golden")
	fire_story("after:golden")
	_after_change()
	save_game()
	return true


# --- Album und Erfolge ----------------------------------------------------

func is_set_complete(s: Dictionary) -> bool:
	for fig in s["figures"]:
		if not owned.has(fig["id"]):
			return false
	return true


## Komplette Sets, insgesamt oder in einer Welt.
func complete_sets(world_id: String = "") -> int:
	var n := 0
	for s in sets:
		if (world_id == "" or s.get("world", "stadt") == world_id) and is_set_complete(s):
			n += 1
	return n


## Verschiedene Figuren, insgesamt oder in einer Welt.
func album_count(world_id: String = "") -> int:
	if world_id == "":
		return owned.size()
	var n := 0
	for id in owned:
		if figures[id]["world"] == world_id:
			n += 1
	return n


func album_size(world_id: String = "") -> int:
	if world_id == "":
		return figures.size()
	var n := 0
	for s in world_sets(world_id):
		n += s["figures"].size()
	return n


func stat(key: String) -> float:
	match key:
		"album_count":
			return album_count()
		"sets_complete":
			return complete_sets()
		"machines_unlocked":
			return unlocked_machines.size()
		"worlds_unlocked":
			return unlocked_worlds.size()
		"slots":
			return slot_count()
		"max_machine_level":
			var best := 0
			for id in machine_levels:
				best = maxi(best, int(machine_levels[id]))
			return best
	if key.begins_with("album_"):
		var w := key.substr(6)
		if world_by_id.has(w):
			return album_count(w)
	if key.begins_with("unlocked_"):
		return 1.0 if key.substr(9) in unlocked_machines else 0.0
	return float(stats.get(key, 0.0))


## Story-Ereignis nur einmal pro Spielstand auslösen.
func fire_story(trigger: String) -> void:
	if story_seen.has(trigger):
		return
	story_seen[trigger] = true
	story_event.emit(trigger)


func _after_change() -> void:
	check_progress()
	changed.emit()


## Prüft neue Erfolge und neu sichtbare Upgrades.
func check_progress() -> void:
	if active:
		if album_count() >= 150:
			fire_story("figures:150")
		if placed.size() >= 2:
			fire_story("slots:2")
	for a in achievement_list:
		if not achievements.has(a["id"]) and stat(a["stat"]) >= float(a["value"]):
			achievements[a["id"]] = true
			achievement_unlocked.emit(a)
	for u in upgrades:
		if not revealed.has(u["id"]) and _upgrade_unlocked(u):
			revealed[u["id"]] = true
			if float(u["unlock_at"]) > 0.0 or u.has("unlock_stat"):
				upgrade_revealed.emit(u)


func _upgrade_unlocked(u: Dictionary) -> bool:
	if u.has("unlock_stat"):
		return stat(u["unlock_stat"]) >= float(u.get("unlock_value", 1))
	return stats["capsules_opened"] >= float(u["unlock_at"])


# --- Speichern ------------------------------------------------------------
## Atomar: erst in save.tmp schreiben, alte Datei als save.bak behalten, dann umbenennen.

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"coins": coins,
		"levels": levels,
		"unlocked_machines": unlocked_machines,
		"current_machine": current_machine,
		"placed": placed,
		"machine_levels": machine_levels,
		"owned": owned,
		"goldmarken": goldmarken,
		"goldmarken_total": goldmarken_total,
		"prestige_levels": prestige_levels,
		"achievements": achievements,
		"revealed": revealed,
		"unlocked_worlds": unlocked_worlds,
		"story_seen": story_seen,
		"stats": stats,
	}
	var f := FileAccess.open("user://" + TMP_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("Speichern fehlgeschlagen: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists(SAVE_FILE):
		if dir.file_exists(BACKUP_FILE):
			dir.remove(BACKUP_FILE)
		dir.rename(SAVE_FILE, BACKUP_FILE)
	dir.rename(TMP_FILE, SAVE_FILE)


func load_game() -> void:
	for path in ["user://" + SAVE_FILE, "user://" + BACKUP_FILE]:
		if not FileAccess.file_exists(path):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (d is Dictionary and d.has("coins")):
			continue
		coins = float(d["coins"])
		levels = d.get("levels", {})
		owned = {}
		for id in d.get("owned", {}):
			if figures.has(id):
				owned[id] = d["owned"][id]
		unlocked_worlds = d.get("unlocked_worlds", ["stadt"])
		unlocked_machines = []
		for id in d.get("unlocked_machines", ["standard"]):
			if machine_by_id.has(id):
				unlocked_machines.append(id)
		if not "standard" in unlocked_machines:
			unlocked_machines.append("standard")
		machine_levels = d.get("machine_levels", {})
		current_machine = d.get("current_machine", "standard")
		if not machine_by_id.has(current_machine) or not current_machine in unlocked_machines:
			current_machine = "standard"
		placed = []
		for id in d.get("placed", [current_machine]):
			if id in unlocked_machines and not id in placed:
				placed.append(id)
		if not current_machine in placed:
			placed.insert(0, current_machine)
		goldmarken = int(d.get("goldmarken", 0))
		goldmarken_total = int(d.get("goldmarken_total", 0))
		prestige_levels = d.get("prestige_levels", {})
		achievements = d.get("achievements", {})
		revealed = d.get("revealed", {})
		story_seen = d.get("story_seen", {})
		# Bis v4 galten alle Upgrades für alle Automaten: Stufen dem Standard-Automaten geben
		for k in levels.keys():
			if upgrade_by_id.has(k) and is_machine_upgrade(k):
				levels["standard/" + k] = maxi(int(levels.get("standard/" + k, 0)), int(levels[k]))
				levels.erase(k)
		var s: Dictionary = d.get("stats", {})
		for k in STAT_KEYS:
			stats[k] = float(s.get(k, 0.0))
		if d.has("capsules_opened"):   # Spielstand aus Version 1
			stats["capsules_opened"] = float(d["capsules_opened"])
		if int(d.get("version", 1)) < 3 and stats["golden_built"] >= 1.0:
			# Der alte Goldene Automat (Spielende v4) steht jetzt am Ende der Sternenstation
			stats["golden_built"] = 0.0
		while placed.size() > slot_count():
			placed.pop_back()
		_bg_acc = {}
		_apply_offline(float(d.get("saved_at", 0.0)))
		return


func offline_hours_cap() -> float:
	return 2.0 + _eff("offline")


func _apply_offline(saved_at: float) -> void:
	if saved_at <= 0.0:
		return
	var secs := clampf(Time.get_unix_time_from_system() - saved_at, 0.0, offline_hours_cap() * 3600.0)
	if secs < 60.0:
		return
	var rate := OFFLINE_RATE + _peff("p_offline")
	var amount := income_per_sec() * secs * rate
	if amount <= 0.0:
		return
	earn(amount)
	offline_report = {"seconds": secs, "amount": amount}


func reset_game() -> void:
	coins = START_COINS
	levels = {}
	unlocked_machines = ["standard"]
	current_machine = "standard"
	placed = ["standard"]
	machine_levels = {}
	owned = {}
	goldmarken = 0
	goldmarken_total = 0
	prestige_levels = {}
	achievements = {}
	revealed = {}
	unlocked_worlds = ["stadt"]
	story_seen = {}
	combo = 0
	_bg_acc = {}
	_reset_stats()
	save_game()
	changed.emit()
