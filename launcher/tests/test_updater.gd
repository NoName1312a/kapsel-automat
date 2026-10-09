extends SceneTree
## Ende-zu-Ende-Test gegen tests/mock_github.py.
## Am einfachsten über tests/run_tests.sh starten.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var port := args[0]
	var dir := args[1]
	var mock := args[2]

	print("Versionsvergleich")
	ok(Updater.compare_versions("v0.6.0", "v0.5.9") == 1, "0.6.0 > 0.5.9")
	ok(Updater.compare_versions("v1.2.10", "1.2.9") == 1, "1.2.10 > 1.2.9")
	ok(Updater.compare_versions("v1.0", "v1.0.0") == 0, "1.0 == 1.0.0")
	ok(Updater.compare_versions("v1.0.0-beta", "v1.0.0") == -1, "beta < final")

	print("Markdown")
	var bb: String = load("res://scripts/launcher.gd").markdown_to_bbcode("## Titel\n- **fett** [Link](http://a) `c`")
	print("    " + bb.replace("\n", " | "))
	ok("[b]fett[/b]" in bb and "• " in bb and "Link" in bb and not "http" in bb, "Überschrift, Liste, fett, Link")

	var u := Updater.new()
	root.add_child(u)
	var cfg := {"repo": "test/test", "api_base": "http://127.0.0.1:" + port, "install_dir": dir, "game_args": ["--headless"]}
	var cfg_path := dir.path_join("cfg.json")
	DirAccess.make_dir_recursive_absolute(dir)
	_write(cfg_path, JSON.stringify(cfg))
	u.load_config(cfg_path)
	_write(dir.path_join("spielstand_marker.txt"), "bleibt")

	print("Erstinstallation")
	ok(not u.is_installed(), "anfangs nichts installiert")
	u.check()
	var r = await u.check_finished
	ok(r, "Release gefunden: " + u.latest_tag)
	ok(u.latest_asset_url.ends_with("-game.zip"), "Spieldaten gewählt, nicht der Launcher")
	ok(u.update_available(), "Installation angeboten")
	var ticks := [0]
	u.progress.connect(func(_a, _b): ticks[0] += 1)
	u.install_latest()
	var done = [false, ""]
	u.install_finished.connect(func(a, b): done[0] = a; done[1] = b)
	await u.install_finished
	ok(done[0], "installiert (%s)" % done[1])
	ok(u.installed_tag() == "v0.5.0", "Version v0.5.0 gemerkt")
	ok(FileAccess.file_exists(u.game_pack_path()), "KapselAutomat.pck liegt in game/ (Oberordner entfernt)")
	ok(ticks[0] > 0, "Fortschritt gemeldet")
	u.check()
	await u.check_finished
	ok(not u.update_available(), "danach kein Update nötig")

	print("Update auf v0.6.0")
	_write(mock.path_join("current_tag.txt"), "v0.6.0")
	_write(u.game_dir().path_join("alt_nur_in_0.5.txt"), "x")
	u.check()
	await u.check_finished
	ok(u.update_available(), "Update erkannt")
	u.install_latest()
	await u.install_finished
	ok(done[0], "aktualisiert (%s)" % done[1])
	ok(u.installed_tag() == "v0.6.0", "Version jetzt v0.6.0")
	ok(not FileAccess.file_exists(u.game_dir().path_join("alt_nur_in_0.5.txt")), "alte Dateien entfernt")
	ok(FileAccess.get_file_as_string(u.game_dir().path_join("version.txt")).strip_edges() == "0.6.0", "neue Dateien da")
	ok(FileAccess.file_exists(dir.path_join("spielstand_marker.txt")), "Dateien außerhalb von game/ unberührt")
	ok(not DirAccess.dir_exists_absolute(dir.path_join("game_old")) and not DirAccess.dir_exists_absolute(dir.path_join("game_new")), "keine Reste")

	print("Spiel starten")
	# Das Testspiel schreibt in seinen eigenen Benutzerordner, nicht in den des Launchers
	var marker := OS.get_user_data_dir().get_base_dir().path_join("Fake-Spiel/gestartet.txt")
	DirAccess.remove_absolute(marker)
	ok(u.launch_game(), "Launcher-Programm mit Spieldaten gestartet")
	for i in 40:
		if FileAccess.file_exists(marker):
			break
		await create_timer(0.25).timeout
	ok(FileAccess.get_file_as_string(marker) == "Fake-Spiel", "Spiel lief mit seinen eigenen Projektdaten")

	print("Offline")
	cfg["api_base"] = "http://127.0.0.1:1"
	_write(cfg_path, JSON.stringify(cfg))
	u.load_config(cfg_path)
	u.latest_tag = ""
	u.latest_asset_url = ""
	u.check()
	r = await u.check_finished
	ok(not r, "Fehler erkannt: " + u.last_error)
	ok(u.is_installed() and not u.update_available(), "installierte Version bleibt spielbar")

	print("ERGEBNIS: %s" % ("ALLES OK" if fails == 0 else "%d FEHLER" % fails))
	quit(1 if fails else 0)
