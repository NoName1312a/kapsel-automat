extends Node2D
## Hauptszene: Automat, Kapseln, Figuren-Anzeige und Effekte. Die Menüs stecken in ui.gd.

const Machine := preload("res://scripts/machine.gd")
const Capsule := preload("res://scripts/capsule.gd")
const FigureView := preload("res://scripts/figure_view.gd")
const UI := preload("res://scripts/ui.gd")

const FX := preload("res://scripts/fx.gd")

const MACHINE_POS := Vector2(340, 296)
const REVEAL_POS := Vector2(690, 330)
const TICKS_PER_TURN := 12
const AUTOSAVE_SECONDS := 10.0

var world: Node2D
var machine: Machine
var reveal: FigureView
var reveal2: FigureView          # zweite Figur bei Doppelkapseln
var ui: UI
var combo_label: Label
var tray: Array[Capsule] = []
var crank_progress := 0.0
var holding_mouse := false
var dragging := false
var last_drag_angle := 0.0
var shake := 0.0
var auto_open_timer := 0.0
var save_timer := 0.0
var bg_sprite: Sprite2D
var _bg_world := ""
var _last_machine := ""


func _ready() -> void:
	randomize()
	world = Node2D.new()
	add_child(world)
	# Eigene Ebene hinter allem, damit der Hintergrund beim Screenshake ruhig bleibt
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg_sprite = Sprite2D.new()
	bg_sprite.centered = false
	bg_sprite.scale = Vector2(4, 4)
	bg_layer.add_child(bg_sprite)
	machine = Machine.new()
	machine.position = MACHINE_POS
	world.add_child(machine)
	reveal = FigureView.new()
	reveal.position = REVEAL_POS
	reveal.visible = false
	world.add_child(reveal)
	reveal2 = FigureView.new()
	reveal2.position = REVEAL_POS + Vector2(0, 0)
	reveal2.visible = false
	world.add_child(reveal2)

	combo_label = Label.new()
	combo_label.position = REVEAL_POS + Vector2(-100, -205)
	combo_label.size = Vector2(200, 40)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 26)
	combo_label.add_theme_color_override("font_color", Color("#ff9f45"))
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 6)
	world.add_child(combo_label)

	ui = UI.new()
	add_child(ui)
	ui.open_all_requested.connect(_open_all)
	ui.clear_tray_requested.connect(_clear_tray)
	Game.changed.connect(_sync_machine)
	Game.machine_leveled.connect(_on_machine_leveled)
	# Direkt gestartet (ohne Hauptmenü, z. B. im Editor mit F6): Spielstand laden
	if not Game.active:
		Game.start_loaded()
	_sync_machine()
	ui.show_offline_report_later()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Game.active:
		Game.save_game()


## Jeder Automat kann eigene Musik haben, sonst die der Welt; nach dem Ende klingt es golden.
func _music_name() -> String:
	if Game.stats.get("golden_built", 0.0) >= 1.0 and Game.current_world() == "station":
		return "golden"
	var id := Game.current_machine
	if Sfx.has_music(id):
		return id
	return Game.world_by_id[Game.current_world()].get("music", "game")


## Hintergrund der aktuellen Welt. Ohne eigene Grafik: der Spielhallen-Hintergrund in Weltfarbe.
func _sync_background() -> void:
	var wid := Game.current_world()
	if wid == _bg_world:
		return
	_bg_world = wid
	var w: Dictionary = Game.world_by_id[wid]
	var t := Art.tex(w.get("bg", ""))
	bg_sprite.modulate = Color.WHITE
	if t == null:
		t = Art.tex("bg/background.png")
		if wid != "stadt":
			bg_sprite.modulate = Color.WHITE.lerp(Color(w["color"]), 0.45)
	bg_sprite.texture = t


func _sync_machine() -> void:
	var m := Game.machine()
	machine.machine_id = Game.current_machine
	machine.body_color = Color(m["color"])
	machine.title = m["name"]
	machine.price = Game.capsule_cost()
	machine.hamster = Game.level("hamster") > 0
	machine.tray_slots = Game.tray_size()
	machine.level = Game.machine_level(Game.current_machine)
	if machine.machine_id != _last_machine:
		if _last_machine != "":
			_clear_tray()
		_last_machine = machine.machine_id
	_sync_background()
	Sfx.play_music(_music_name())


# --- Eingabe --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if ui.is_blocking():
		holding_mouse = false
		dragging = false
		return
	var mp := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for c in tray:
				if c.state == Capsule.State.RESTING and c.global_position.distance_to(mp) < Capsule.RADIUS + 8:
					_open_capsule(c)
					return
			if mp.distance_to(machine.crank_global()) < 80:
				holding_mouse = true
				dragging = true
				last_drag_angle = (mp - machine.crank_global()).angle()
		else:
			holding_mouse = false
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		# Im Uhrzeigersinn ziehen dreht die Kurbel zusätzlich
		var a := (mp - machine.crank_global()).angle()
		var d := wrapf(a - last_drag_angle, -PI, PI)
		last_drag_angle = a
		if d > 0.0:
			_advance_crank(d / TAU, true)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E, KEY_ENTER:
				_open_first_capsule()
			KEY_A:
				if Game.has_bulk_open():
					_open_all()
			KEY_F1:
				Game.earn(Game.coins + 1000.0)   # Test-Abkürzung: Münzen verdoppeln (+1000)
				Game.changed.emit()


func _process(delta: float) -> void:
	var manual := (holding_mouse or Input.is_key_pressed(KEY_SPACE)) and not ui.is_blocking()
	if manual:
		_advance_crank(Game.crank_speed() * delta, true)
	if Game.hamster_speed() > 0.0:
		_advance_crank(Game.hamster_speed() * delta, false)
		if randf() < delta / 25.0:
			Sfx.play_first(["hamster_squeak"], randf_range(0.9, 1.15), -8.0)

	var interval := Game.auto_open_interval()
	if interval > 0.0:
		auto_open_timer -= delta
		if auto_open_timer <= 0.0 and _open_first_capsule():
			auto_open_timer = interval

	combo_label.text = "Kombo x%d" % Game.combo if Game.combo >= 2 else ""

	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * Settings.shake_mult()
	shake = move_toward(shake, 0.0, delta * 40.0)

	save_timer += delta
	if save_timer >= AUTOSAVE_SECONDS:
		save_timer = 0.0
		Game.save_game()


# --- Kurbel und Kapseln ---------------------------------------------------

func _advance_crank(amount: float, manual: bool) -> void:
	if tray.size() >= Game.tray_size():
		if manual:
			_blocked("Schale voll! Erst Kapseln öffnen.")
		return
	if not Game.can_afford_capsule():
		# Notgroschen: von Hand darf man pleite gratis kurbeln, wenn die Schale leer ist
		# und es kein passives Einkommen gibt, das einen ohnehin rettet
		if not manual or not tray.is_empty() or Game.income_per_sec() > 0.5:
			if manual:
				_blocked("Nicht genug Münzen.")
			return
	var before := crank_progress
	crank_progress += amount
	if int(before * TICKS_PER_TURN) != int(crank_progress * TICKS_PER_TURN):
		Sfx.play("tick", randf_range(0.92, 1.08), -4.0)
		machine.jiggle = 1.0
	machine.crank_angle = crank_progress * TAU
	if crank_progress >= 1.0:
		crank_progress -= 1.0
		Game.add_crank_turn()
		_drop_capsule(manual)


func _blocked(msg: String) -> void:
	if machine.blocked <= 0.0:
		Sfx.play("deny")
		ui.say(msg)
	machine.blocked = 1.0


func _drop_capsule(manual: bool, free: bool = false) -> void:
	if tray.size() >= Game.tray_size():
		return
	var paid := 1 if free else Game.try_pay_capsule(manual)
	if paid == 0:
		return
	if paid == 2:
		ui.say("Gratis-Kapsel (Notgroschen)")
	var c := Capsule.new()
	c.content = Game.roll_capsule()
	c.machine_id = Game.current_machine
	c.top_color = Color(Machine.CAPSULE_COLORS.pick_random())
	c.gold = c.content["type"] == "figure" and c.content["figure"]["rarity"] == "legendary"
	c.world_id = Game.current_world()
	if c.content.get("frozen", false):
		c.frozen_hits = Game.FROZEN_HITS - 1
	c.position = machine.chute_global() - world.position
	world.add_child(c)
	tray.append(c)
	var target := Vector2(_slot_x(tray.size() - 1), machine.tray_rest_y() - world.position.y)
	var tw := c.create_tween()
	tw.tween_property(c, "position", target, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if c.state == Capsule.State.FALLING:
			c.state = Capsule.State.RESTING)
	if c.gold:
		Sfx.play_pref(["clunk_gold", "clunk"])
	else:
		Sfx.play("clunk", randf_range(0.95, 1.05))
	if c.gold:
		ui.say("Eine goldene Kapsel …!")
	Game.changed.emit()


func _slot_x(i: int) -> float:
	var n := Game.tray_size()
	var w := Machine.tray_width(n) - 40.0
	return MACHINE_POS.x - w / 2.0 + (i + 0.5) * (w / n)


func _layout_tray() -> void:
	for i in tray.size():
		var c := tray[i]
		if c.state != Capsule.State.FALLING:
			c.create_tween().tween_property(c, "position:x", _slot_x(i), 0.2)


func _open_first_capsule() -> bool:
	for c in tray:
		if c.state == Capsule.State.RESTING:
			_open_capsule(c)
			return true
	return false


func _open_all() -> void:
	var delay := 0.0
	for c in tray.duplicate():
		if c.state == Capsule.State.RESTING:
			get_tree().create_timer(delay).timeout.connect(_open_capsule.bind(c))
			delay += 0.12


func _clear_tray() -> void:
	for c in tray:
		c.queue_free()
	tray.clear()
	reveal.visible = false
	reveal2.visible = false
	crank_progress = 0.0


func _open_capsule(c: Capsule) -> void:
	if not is_instance_valid(c) or c.state != Capsule.State.RESTING:
		return
	if c.frozen_hits > 0:
		# Gefrorene Kapsel: erst das Eis knacken
		c.crack()
		Sfx.play_pref(["ice_crack", "tick"], randf_range(0.9, 1.1))
		_burst(c.position, Color("#bfefff"), 8)
		if c.frozen_hits == 0:
			Sfx.play_pref(["ice_break", "pop"])
		return
	if c.gold:
		Sfx.play_pref(["pop_gold", "pop"])
	else:
		Sfx.play("pop", randf_range(0.95, 1.1))
	await c.open()
	if not is_instance_valid(c):
		return
	var res := Game.open_capsule(c.content, c.machine_id)
	var pos := c.position
	tray.erase(c)
	c.queue_free()
	_layout_tray()

	if res.get("jackpot", false):
		FX.play_sheet(world, "fx/jackpot_sheet.png", 8, REVEAL_POS + Vector2(0, -170), 3.0, 10.0)
		_float_text("JACKPOT x%d!" % int(Game.JACKPOT_MULT), REVEAL_POS + Vector2(-120, -130), Color("#ffe14d"), 40)
		Sfx.play_pref(["jackpot", "coin_big", "set_complete"])
		_burst(REVEAL_POS, Color("#ffe14d"), 80)
		shake = maxf(shake, 12.0)
	if res.get("erupt", false):
		FX.play_sheet(world, "fx/erupt_sheet.png", 8, machine.position + Vector2(0, -320), 3.0, 12.0)
		Sfx.play_pref(["erupt", "curse"])
		_burst(machine.position + Vector2(0, -120), Color("#ff6a2b"), 60)
		shake = maxf(shake, 10.0)
		ui.say("Ausbruch! %d Gratis-Kapseln" % Game.ERUPT_CAPSULES)
		for k in Game.ERUPT_CAPSULES:
			get_tree().create_timer(0.25 + k * 0.2).timeout.connect(_drop_capsule.bind(false, true))
	if res.get("frozen", false) and res["type"] != "empty":
		_float_text("Eis geknackt x%d" % int(Game.FROZEN_MULT), pos + Vector2(-60, -100), Color("#bfefff"), 22)

	match res["type"]:
		"empty":
			Sfx.play("empty")
			_burst(pos, Color(0.5, 0.5, 0.55), 10)
			_float_text("Leer!", pos + Vector2(-30, -70), Color(0.75, 0.75, 0.8))
			return
		"curse":
			Sfx.play("curse")
			_burst(pos, Color("#7a2bd1"), 40)
			_float_text("Fluch! %s" % Fmt.num(res["value"]), REVEAL_POS + Vector2(60, -60), Color("#c77dff"))
			shake = 8.0
		_:
			pass

	var figs: Array = res["figures"]
	var best: Dictionary = figs[0]
	for f in figs:
		if _rank(f["rarity"]) > _rank(best["rarity"]):
			best = f
	var rarity: String = best["rarity"]
	var rc := Color(best["rarity_color"])
	var amount: int = {"common": 18, "rare": 32, "epic": 60, "legendary": 120}[rarity]
	_burst(pos, rc, amount)
	_burst(REVEAL_POS, rc, amount)

	if figs.size() == 2:
		reveal.position = REVEAL_POS + Vector2(-85, 0)
		reveal2.position = REVEAL_POS + Vector2(85, 0)
		reveal.scale_base = 0.65
		reveal2.scale_base = 0.65
		reveal.show_figure(figs[0], figs[0]["id"] in res["new"])
		reveal2.show_figure(figs[1], figs[1]["id"] in res["new"])
		ui.say("Doppelkapsel!")
		Sfx.play("double")
	else:
		reveal.position = REVEAL_POS
		reveal.scale_base = 1.0
		reveal2.visible = false
		reveal.show_figure(figs[0], figs[0]["id"] in res["new"])

	Sfx.play("chime_" + rarity)
	if rarity == "legendary":
		shake = 16.0
		FX.legendary(world, REVEAL_POS)
	elif rarity == "epic":
		shake = maxf(shake, 7.0)
	if Game.combo >= 2:
		# Pro Kombo-Stufe einen Halbton höher (Tonleiter), höchstens eine Oktave
		Sfx.play("combo", pow(2.0, mini(Game.combo - 2, 12) / 12.0), -6.0)
	if res["type"] != "curse":
		var txt := "+" + Fmt.num(res["value"])
		var col := Color("#ffe14d")
		if res["crit"]:
			txt += "  TREFFER x5!"
			col = Color("#ff6b6b")
			shake = maxf(shake, 9.0)
			Sfx.play("crit")
		if res["blessed"]:
			txt += "  Segen x3!"
			col = Color("#9fffcb")
			Sfx.play("bless")
		_float_text(txt, REVEAL_POS + Vector2(90, -60), col)
		var big: bool = res["crit"] or rarity == "legendary"
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			if big:
				Sfx.play_pref(["coin_big", "coin"])
			else:
				Sfx.play("coin"))
	if not res["new"].is_empty() and rarity != "legendary":
		get_tree().create_timer(0.3).timeout.connect(func() -> void: Sfx.play_first(["new_figure"], 1.0, -3.0))
	if res["set_completed"]:
		Sfx.play("set_complete")
		ui.toast("Set komplett!", "+%d %% auf alle Münzen" % int(Game.set_bonus * 100))
		shake = maxf(shake, 10.0)


func _rank(rarity: String) -> int:
	return ["common", "rare", "epic", "legendary"].find(rarity)


# --- Effekte --------------------------------------------------------------

func _burst(pos: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 700)
	var star := Art.tex("particles/star.png")
	if star:
		p.texture = star
		p.amount = maxi(6, amount / 2)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	else:
		p.scale_amount_min = 3.0
		p.scale_amount_max = 8.0
	p.color = color.lerp(Color.WHITE, 0.45) if star else color
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Automat wurde aufgewertet: Animation über dem Gehäuse.
func _on_machine_leveled(id: String, new_level: int) -> void:
	if id != Game.current_machine:
		ui.toast("%s aufgewertet" % Game.machine_by_id[id]["name"], "Stufe %d" % new_level)
		Sfx.play_pref(["machine_levelup", "upgrade"], 1.0, -4.0)
		return
	machine.level = new_level
	FX.machine_upgrade(world, machine)
	Sfx.play_pref(["machine_levelup", "unlock"])
	_burst(machine.position + Vector2(0, 120), Color("#ffe14d"), 40)
	shake = maxf(shake, 6.0)
	_float_text("Stufe %d!" % new_level, machine.position + Vector2(-60, -30), Color("#ffe14d"), 34)


func _float_text(text: String, pos: Vector2, color: Color, size: int = 30) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	world.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
