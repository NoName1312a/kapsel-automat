extends SceneTree
## Headless-Test: godot --headless --path . -s res://tests/smoke_test.gd

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("Game")
	game.reset_game()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# main.gd lädt beim Start den Spielstand von der Platte: für den Test frisch anfangen
	game.reset_game()
	game.coins = 500.0
	main._clear_tray()
	var opened := 0
	for i in 40:
		main._advance_crank(1.0, true)
		await create_timer(0.65).timeout
		if main._open_first_capsule():
			await create_timer(0.35).timeout
			opened += 1
	check(opened >= 30, "40 Kapseln gekurbelt, %d geöffnet" % opened)
	check(game.achievements.has("first_capsule"), "Erfolg 'Erste Kapsel' freigeschaltet")
	check(game.album_count() > 5, "Album gefüllt (%d)" % game.album_count())

	game.coins = 1e18
	for id in game.upgrade_by_id:
		game.revealed[id] = true
		game.buy_max(id)
	check(game.is_maxed("speed") and game.is_maxed("bulk"), "Upgrades bis Max kaufbar")
	check(game.slot_count() >= 3, "Anbau gibt Aufstellplätze (%d)" % game.slot_count())
	check(game.level("speed", "glueck") == 0 and game.level("speed", "standard") == 40, "Upgrades gelten nur für ihren Automaten")
	check(game.upgrade_cost("value", "glueck") > game.upgrade_cost("value", "standard") * 0.0 and game.upgrade_cost("speed", "glueck") == floorf(15.0 * 4.0), "Upgrade-Preis skaliert mit dem Automaten")
	check(game.unlock_machine("glueck"), "Glücksautomat freischaltbar")
	check(not game.unlock_machine("spuk"), "Spuk-Automat ohne Lizenz gesperrt")
	check(not game.unlock_machine("muschel"), "Automat einer fremden Welt gesperrt")
	for i in 30:
		var c: Dictionary = game.roll_capsule("glueck")
		game.open_capsule(c, "glueck")
	check(game.stats["empties"] > 0, "Glücksautomat erzeugt Nieten (%d)" % game.stats["empties"])

	# Mehrere Automaten: der nicht gezeigte läuft nebenbei
	game.select_machine("standard")
	check("glueck" in game.placed and "standard" in game.placed, "Zwei Automaten aufgestellt")
	var bg_before: int = game.stats["bg_capsules"]
	game.run_background(20.0)
	check(game.stats["bg_capsules"] > bg_before, "Nebenautomat öffnet von allein (%d)" % (game.stats["bg_capsules"] - bg_before))
	var lvl_cost: float = game.machine_level_cost("standard")
	game.coins = lvl_cost * 2.0
	var mult_before: float = game.machine_value_mult("standard")
	check(game.level_machine("standard") and game.machine_level("standard") == 1, "Automat aufwerten")
	check(game.machine_value_mult("standard") > mult_before, "Aufwertung erhöht den Wert")
	await process_frame
	check(main.machine.level == 1, "Sterne am Automaten")

	# Reisen
	check(not game.can_travel("insel"), "Tropeninsel ohne Sets gesperrt")
	for s in game.world_sets("stadt"):
		for f in s["figures"]:
			game.owned[f["id"]] = 1
	game.coins = 1e30
	check(game.travel("insel") and game.current_world() == "insel", "Reise zur Tropeninsel")
	await process_frame
	check(game.unlock_machine("schatz") and game.unlock_machine("vulkan"), "Insel-Automaten freischaltbar")
	var jack := false
	var erupt := false
	for i in 400:
		var r: Dictionary = game.open_capsule(game.roll_capsule("schatz"), "schatz")
		jack = jack or r.get("jackpot", false)
		var r2: Dictionary = game.open_capsule(game.roll_capsule("vulkan"), "vulkan")
		erupt = erupt or r2.get("erupt", false)
	check(jack and erupt, "Jackpot und Ausbruch kommen vor")
	for w in ["eis", "station"]:
		for s in game.world_sets(game.previous_world(w)):
			for f in s["figures"]:
				game.owned[f["id"]] = 1
		game.coins = 1e30
		check(game.travel(w), "Reise nach %s" % game.world_by_id[w]["name"])
	game.unlock_machine("frost")
	var frozen := false
	for i in 50:
		frozen = frozen or game.roll_capsule("frost").get("frozen", false)
	check(frozen, "Frost-Automat liefert gefrorene Kapseln")
	main._clear_tray()
	for i in 6:
		main._advance_crank(1.0, true)
		await create_timer(0.5).timeout
	var fc = null
	for c in main.tray:
		if c.frozen_hits > 0:
			fc = c
	if fc:
		var hits: int = fc.frozen_hits
		fc.crack()
		check(fc.frozen_hits == hits - 1, "Eis bekommt Risse")
	main._clear_tray()

	game.prestige_gain()
	var gain: int = game.prestige_gain()
	check(gain > 0, "Prestige-Gewinn > 0 (%d)" % gain)
	var album_before: int = game.album_count()
	game.do_prestige()
	check(game.goldmarken == gain and game.level("speed") == 0 and game.album_count() == album_before, "Neueröffnung setzt Lauf zurück, Album bleibt")
	check(game.unlocked_worlds.size() == 4, "Welten bleiben nach Neueröffnung")
	game.goldmarken = 1000
	for id in ["p_fusion", "p_spuk"] + game.prestige_by_id.keys():
		while game.buy_prestige(id):
			pass
	check(game.fusion_unlocked(), "Fusion freigeschaltet")
	game.go_to_world("stadt")
	game.coins = 1e30
	check(game.unlock_machine("spuk"), "Spuk-Automat mit Lizenz freischaltbar")
	for id in game.figures:
		if game.figures[id]["rarity"] == "common":
			game.owned[id] = 5
	var fused: Dictionary = game.fuse("common")
	check(not fused.is_empty() and fused["figure"]["rarity"] == "rare", "Fusion Gewöhnlich → Selten")
	var fa: Dictionary = game.fuse_all()
	check(fa["count"] > 0 and not game.can_fuse("common"), "Alles fusionieren (%d Fusionen)" % fa["count"])

	for id in game.figures:
		game.owned[id] = int(game.owned.get(id, 0)) + 1
	check(game.album_count() == 192 and game.album_count("eis") == 48, "4 Alben mit je 48 Figuren")
	game.coins = 1e40
	check(game.build_golden(), "Goldener Automat baubar")
	game.check_progress()
	check(game.achievements.has("golden") and game.achievements.has("album_30"), "Ziel-Erfolge freigeschaltet")
	check(game.income_per_sec() > 0.0, "Passives Einkommen > 0 (%s/s)" % Fmt.rate(game.income_per_sec()))
	for tab in main.ui.tabs.get_child_count():
		main.ui.tabs.current_tab = tab
		await process_frame
	check(main.ui.machine_rows.size() >= 3 and main.ui.world_rows.size() == 4, "Seitenleiste: Automaten und Welten")

	game.save_game()
	var saved: float = game.coins
	var saved_ach: int = game.achievements.size()
	game.coins = 0.0
	game.achievements = {}
	game.load_game()
	check(absf(game.coins - saved) <= saved * 1e-9 and game.achievements.size() == saved_ach, "Speichern/Laden")

	main.ui._toggle_overlay(main.ui.album_panel)
	await process_frame
	await process_frame
	main.ui._toggle_overlay(main.ui.ach_panel)
	await process_frame
	check(main.ui.ach_list.get_child_count() > 0 and main.ui.album_list.get_child_count() > 0, "Album und Erfolge bauen sich auf")
	check(Fmt.num(1234.0) == "1,23 K" and Fmt.num(5e9) == "5,00 Mrd", "Zahlenformat (%s, %s)" % [Fmt.num(1234.0), Fmt.num(5e9)])

	# Story: Mausklick blättert weiter
	main.ui._on_story_event("new_game")
	await process_frame
	var lines_left: int = main.ui._story_queue.size()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.ui._on_story_click(click)   # Text fertig zeigen
	main.ui._on_story_click(click)   # nächste Zeile
	check(main.ui.story_panel.visible and main.ui._story_queue.size() == lines_left - 1, "Story per Mausklick weiter")
	main.ui._story_queue.clear()
	main.ui._next_story_line()
	check(not main.ui.story_catcher.visible, "Story schließt nach der letzten Zeile")
	main.ui._open_welcome({"seconds": 600.0, "amount": 12345.0})
	check(main.ui.welcome_panel.visible and main.ui.is_blocking(), "Willkommen-zurück-Fenster")
	main.ui.welcome_panel.visible = false
	main.ui.welcome_dim.visible = false
	# Regression v0.6.1: nach dem Willkommen-Fenster lag die Abdunklung über den Einstellungen
	main.ui.open_settings()
	await process_frame
	check(main.ui.settings_panel.get_index() > main.ui.dim.get_index(), "Einstellungen liegen über der Abdunklung")
	main.ui.settings_panel.close()
	await process_frame

	# Menüs, Einstellungen, Sounds
	main.ui.toggle_pause()
	check(main.ui.pause_panel.visible and main.ui.is_blocking(), "Pausenmenü öffnet")
	main.ui.toggle_pause()
	main.ui.open_settings()
	await process_frame
	await process_frame
	check(main.ui.settings_panel.visible, "Einstellungen im Spiel öffnen")
	main.ui.settings_panel.close()
	var settings = root.get_node("Settings")
	var old_music: float = settings.get_value("music")
	settings.set_value("music", 0.25)
	var mi := AudioServer.get_bus_index("Music")
	check(mi != -1 and AudioServer.get_bus_index("SFX") != -1, "Audio-Busse Music und SFX vorhanden")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(mi)) - 0.25) < 0.01, "Musik-Lautstärke wirkt auf den Bus")
	settings.set_value("music", old_music)
	var sfx = root.get_node("Sfx")
	var missing: Array = []
	for n in ["tick", "clunk", "pop", "coin", "deny", "chime_common", "chime_rare", "chime_epic", "chime_legendary",
			"set_complete", "achievement", "prestige", "bless", "curse", "empty", "crit", "double", "combo",
			"upgrade", "unlock", "fusion", "ui_click", "ui_hover", "ui_open", "ui_close", "golden"]:
		if not sfx.streams.has(n):
			missing.append(n)
	check(missing.is_empty(), "Alle 26 Sound-Namen belegt %s" % str(missing))
	var t0 := Time.get_ticks_msec()
	while sfx._music_stream("game") == null and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	check(sfx._music_stream("game") != null, "Spielmusik erzeugt (%d ms)" % (Time.get_ticks_msec() - t0))
	check(Links.is_placeholder(Links.url("discord")) and Links.open("discord") != "", "Platzhalter-Links zeigen Hinweis")

	game.reset_game()
	main.queue_free()
	await process_frame
	var menu = load("res://menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(not game.active, "Hauptmenü hält das Spiel an")
	check(menu.load_btn != null and not menu.load_btn.disabled, "Spiel laden aktiv, wenn Spielstand existiert")
	menu.queue_free()
	await process_frame
	print("FEHLER: %d" % fails)
	quit(1 if fails > 0 else 0)
