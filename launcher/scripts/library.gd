extends Control
## Spielebibliothek: links alle Spiele aus games.json, rechts das gewählte Spiel mit Installieren,
## Aktualisieren und Spielen. Beim Spielstart minimiert sich der Launcher und kommt nach dem Spiel
## wieder nach vorn. Neue Spiele kommen über die Spieleliste im Repo dazu, ohne neues Launcher-Release.

const Updater := preload("res://scripts/updater.gd")
const CONFIG_NAME := "launcher_config.json"
const STATS_FILE := "user://bibliothek.json"
const CATALOG_CACHE := "user://spieleliste.json"
const COVER_CACHE := "user://cover"
const GOLD_TEXT := Color("#3c1c14")
const TITLE := Color("#ffd86b")
const MUTED := Color(1, 1, 1, 0.6)

var version := ""
var settings := {
	"api_base": "https://api.github.com",
	"catalog_url": "https://raw.githubusercontent.com/NoName1312a/kapsel-automat/main/launcher/games.json",
	"launcher_repo": "NoName1312a/kapsel-automat",
	"minimize_on_play": true,
}
var base_dir := ""
var games: Array = []            # Einträge aus games.json
var updaters := {}               # id -> Updater
var installing := {}             # id -> true während Download/Entpacken
var running := {}                # id -> {"pid": int, "start": float}
var stats := {}                  # id -> {"playtime": Sekunden, "last_played": Unix-Zeit}
var selected := ""

var _list: VBoxContainer
var _list_buttons := {}          # id -> Button
var _cover: TextureRect
var _name_lbl: Label
var _desc_lbl: Label
var _play_btn: Button
var _play_old_btn: Button
var _status_lbl: Label
var _bar: ProgressBar
var _bar_lbl: Label
var _notes_title: Label
var _notes: RichTextLabel
var _info_installed: Label
var _info_latest: Label
var _info_playtime: Label
var _info_last: Label
var _folder_btn: Button
var _uninstall_btn: Button
var _confirm: ConfirmationDialog
var _app_btn: Button
var _app_lbl: Label
var _watch: Timer


func _ready() -> void:
	version = ResourceLoader.load("res://scripts/version.gd", "", ResourceLoader.CACHE_MODE_IGNORE).VERSION
	_load_settings()
	base_dir = Updater.pick_base_dir(str(settings.get("install_dir", "")))
	_migrate_old_install()
	_load_stats()
	theme = _build_theme()
	_build_ui()
	_watch = Timer.new()
	_watch.wait_time = 0.5
	_watch.timeout.connect(_watch_running)
	add_child(_watch)
	_watch.start()
	_apply_catalog(_load_local_catalog())
	_fetch_catalog()
	_check_launcher_update()


# ---------------------------------------------------------------- Einstellungen und Daten

## --config=<pfad> (zum Testen), sonst launcher_config.json neben der .exe, sonst die mitgelieferte.
func _load_settings() -> void:
	var paths := ["res://" + CONFIG_NAME]
	if Updater.runs_from_package():
		paths.append(OS.get_executable_path().get_base_dir().path_join(CONFIG_NAME))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--config="):
			paths.append(a.trim_prefix("--config="))
	for p in paths:
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				settings.merge(d, true)


## Version 1.2 hat Kapsel-Automat nach game/ installiert, jetzt liegt jedes Spiel in games/<id>/.
func _migrate_old_install() -> void:
	var old := base_dir.path_join("game")
	var target := base_dir.path_join("games").path_join("kapsel-automat")
	if DirAccess.dir_exists_absolute(old) and FileAccess.file_exists(old.path_join(Updater.VERSION_FILE)) \
			and not DirAccess.dir_exists_absolute(target):
		DirAccess.make_dir_recursive_absolute(base_dir.path_join("games"))
		DirAccess.rename_absolute(old, target)


func _load_stats() -> void:
	if FileAccess.file_exists(STATS_FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(STATS_FILE))
		if d is Dictionary:
			stats = d


func _save_stats() -> void:
	var f := FileAccess.open(STATS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(stats, "  "))
		f.close()


func _stat(id: String) -> Dictionary:
	if not stats.has(id):
		stats[id] = {"playtime": 0.0, "last_played": 0.0}
	return stats[id]


# ---------------------------------------------------------------- Spieleliste

func _load_local_catalog() -> Array:
	for p in [CATALOG_CACHE, "res://games.json"]:
		var list := _parse_catalog(FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else "")
		if not list.is_empty():
			return list
	return []


func _parse_catalog(text: String) -> Array:
	var d = JSON.parse_string(text) if text != "" else null
	var out: Array = []
	if d is Dictionary and d.get("games") is Array:
		for g in d["games"]:
			if g is Dictionary and str(g.get("id", "")) != "" and str(g.get("repo", "")) != "":
				out.append(g)
	return out


## Holt die aktuelle Spieleliste aus dem Repo. Ohne Internet bleibt die zuletzt bekannte.
func _fetch_catalog() -> void:
	var url := str(settings.get("catalog_url", ""))
	if url == "":
		return
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(url, PackedStringArray(["User-Agent: Kapsel-Launcher"])) != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return
	var text: String = res[3].get_string_from_utf8()
	var list := _parse_catalog(text)
	if list.is_empty():
		return
	var f := FileAccess.open(CATALOG_CACHE, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	if JSON.stringify(list) != JSON.stringify(games):
		_apply_catalog(list)


func _apply_catalog(list: Array) -> void:
	games = list
	var ids := []
	for g in games:
		var id := str(g["id"])
		ids.append(id)
		if not updaters.has(id):
			var u = Updater.new()
			add_child(u)
			u.check_finished.connect(_on_check_finished.bind(id))
			u.progress.connect(_on_progress.bind(id))
			u.install_finished.connect(_on_install_finished.bind(id))
			updaters[id] = u
		updaters[id].setup(settings, g, base_dir)
		if not updaters[id]._busy:
			updaters[id].check()
	for id in updaters.keys():
		if not id in ids and not installing.has(id):
			updaters[id].queue_free()
			updaters.erase(id)
	_rebuild_list()
	if selected == "" or not updaters.has(selected):
		selected = str(games[0]["id"]) if not games.is_empty() else ""
	_select(selected)


func _game(id: String) -> Dictionary:
	for g in games:
		if str(g["id"]) == id:
			return g
	return {}


# ---------------------------------------------------------------- Ablauf je Spiel

func _on_check_finished(_ok: bool, id: String) -> void:
	_refresh_list_entry(id)
	if id == selected:
		_refresh_detail()


func _on_progress(done: int, total: int, id: String) -> void:
	if id != selected:
		_refresh_list_entry(id)
		return
	if total > 0:
		_bar.value = 100.0 * done / total
		_bar_lbl.text = "%s / %s" % [_mb(done), _mb(total)]
		if done >= total:
			_status_lbl.text = "Entpacke …"
	else:
		_bar_lbl.text = _mb(done)


func _on_install_finished(ok: bool, message: String, id: String) -> void:
	installing.erase(id)
	var u = updaters.get(id)
	_refresh_list_entry(id)
	if id == selected:
		_refresh_detail()
		if ok:
			_status_lbl.text = "Version %s installiert. Spielstände bleiben erhalten." % u.installed_tag()
		else:
			_status_lbl.text = "Fehler: " + message


func _on_play_pressed() -> void:
	var u = updaters.get(selected)
	if u == null or running.has(selected) or installing.has(selected):
		return
	if u.update_available():
		installing[selected] = true
		_bar.value = 0
		u.install_latest()
		_refresh_detail()
		_status_lbl.text = "Lade %s herunter …" % u.latest_tag
		_refresh_list_entry(selected)
	elif u.is_installed():
		_play(selected)


func _play(id: String) -> void:
	var u = updaters.get(id)
	if u == null or running.has(id):
		return
	var pid: int = u.launch_game()
	if pid <= 0:
		_status_lbl.text = "Spiel konnte nicht gestartet werden: %s" % u.game_main_file()
		return
	running[id] = {"pid": pid, "start": Time.get_unix_time_from_system()}
	_stat(id)["last_played"] = Time.get_unix_time_from_system()
	_save_stats()
	_refresh_list_entry(id)
	_refresh_detail()
	if settings.get("minimize_on_play", true):
		await get_tree().create_timer(0.5).timeout
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


## Merkt, wann ein Spiel beendet wurde: Spielzeit verbuchen und den Launcher wieder zeigen.
func _watch_running() -> void:
	for id in running.keys():
		var r: Dictionary = running[id]
		if OS.is_process_running(int(r["pid"])):
			continue
		running.erase(id)
		var s := _stat(id)
		s["playtime"] = float(s.get("playtime", 0.0)) + Time.get_unix_time_from_system() - float(r["start"])
		_save_stats()
		_refresh_list_entry(id)
		if id == selected:
			_refresh_detail()
		if running.is_empty():
			_bring_to_front()


func _bring_to_front() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_request_attention()


func _on_uninstall_confirmed() -> void:
	var u = updaters.get(selected)
	if u == null or running.has(selected) or installing.has(selected):
		return
	u.uninstall()
	_status_lbl.text = "Deinstalliert. Spielstände bleiben erhalten."
	_refresh_list_entry(selected)
	_refresh_detail()


# ---------------------------------------------------------------- Launcher-Update

## Sucht im Launcher-Repo nach launcher-app-<version>.pck. Ist sie neuer, wird sie nach
## launcher/ geladen; boot.gd lädt sie beim nächsten Start. Die signierte .exe bleibt unverändert.
func _check_launcher_update() -> void:
	var repo := str(settings.get("launcher_repo", ""))
	if repo == "":
		return
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var url := "%s/repos/%s/releases/latest" % [str(settings["api_base"]).trim_suffix("/"), repo]
	if http.request(url, PackedStringArray(["User-Agent: Kapsel-Launcher", "Accept: application/vnd.github+json"])) != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		http.queue_free()
		return
	var rel = JSON.parse_string(res[3].get_string_from_utf8())
	var asset_url := ""
	var new_version := ""
	if rel is Dictionary:
		for a in rel.get("assets", []):
			var n := str(a.get("name", ""))
			if n.begins_with("launcher-app-") and n.ends_with(".pck"):
				new_version = n.trim_prefix("launcher-app-").trim_suffix(".pck")
				asset_url = str(a.get("browser_download_url", ""))
	if asset_url == "" or Updater.compare_versions(new_version, version) <= 0:
		http.queue_free()
		return
	var dir := base_dir.path_join("launcher")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := "app-%s.pck" % new_version
	_app_lbl.text = "Lade Launcher %s …" % new_version
	http.download_file = dir.path_join(file + ".part")
	http.max_redirects = 10
	http.timeout = 0.0
	if http.request(asset_url, PackedStringArray(["User-Agent: Kapsel-Launcher"])) != OK:
		http.queue_free()
		return
	res = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		DirAccess.remove_absolute(dir.path_join(file + ".part"))
		_app_lbl.text = "Launcher %s" % version
		return
	DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.rename_absolute(dir.path_join(file + ".part"), dir.path_join(file))
	var f := FileAccess.open(dir.path_join("app.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": new_version, "file": file}))
	f.close()
	_app_lbl.text = "Launcher %s" % version
	_app_btn.text = "Launcher-Update %s: neu starten" % new_version
	_app_btn.visible = true


func _restart() -> void:
	if not running.is_empty() or not installing.is_empty():
		_app_btn.text = "Erst nach Spiel/Download neu starten"
		return
	OS.create_process(OS.get_executable_path(), [])
	get_tree().quit()


# ---------------------------------------------------------------- Anzeige

func _select(id: String) -> void:
	selected = id
	for gid in _list_buttons:
		_list_buttons[gid].button_pressed = gid == id
	_refresh_detail()


func _refresh_detail() -> void:
	var u = updaters.get(selected)
	var g := _game(selected)
	if u == null:
		_name_lbl.text = "Keine Spiele gefunden"
		_desc_lbl.text = "Die Spieleliste konnte nicht geladen werden."
		_play_btn.disabled = true
		return
	_name_lbl.text = str(g.get("name", selected))
	_desc_lbl.text = str(g.get("description", ""))
	_cover.texture = _cover_for(g)
	var have: bool = u.is_installed()
	var busy := installing.has(selected)
	var is_running := running.has(selected)
	_bar.visible = busy
	_bar_lbl.visible = busy
	_play_old_btn.visible = false
	_play_btn.disabled = false
	if is_running:
		_play_btn.text = "Läuft …"
		_play_btn.disabled = true
		_status_lbl.text = "Viel Spaß! Der Launcher kommt zurück, wenn du das Spiel beendest."
	elif busy:
		_play_btn.text = "Bitte warten …"
		_play_btn.disabled = true
	elif u._busy:
		_play_btn.text = "Suche Updates …"
		_play_btn.disabled = true
		_status_lbl.text = ""
	elif u.update_available():
		_play_btn.text = "Aktualisieren" if have else "Installieren"
		_status_lbl.text = ("Neue Version %s ist da!" % u.latest_tag) if have else "Noch nicht installiert."
		_play_old_btn.visible = have
	elif have:
		_play_btn.text = "Spielen"
		_status_lbl.text = "Alles aktuell." if u.last_error == "" else "Offline: %s. Du spielst die installierte Version." % u.last_error
	else:
		_play_btn.text = "Nicht verfügbar"
		_play_btn.disabled = true
		_status_lbl.text = u.last_error if u.last_error != "" else "Kein Download gefunden."
	var tag: String = u.latest_tag if u.latest_tag != "" else u.installed_tag()
	var md: String = u.latest_notes if u.latest_tag != "" else u.installed_notes()
	_notes_title.text = "Was ist neu in %s%s" % [tag, (" (%s)" % u.latest_published) if u.latest_published != "" else ""] if tag != "" else "Was ist neu"
	_notes.text = markdown_to_bbcode(md) if md.strip_edges() != "" else "[i]Keine Beschreibung.[/i]"
	_info_installed.text = "Installiert: %s" % (u.installed_tag() if have else "nein")
	_info_latest.text = "Neueste Version: %s" % (u.latest_tag if u.latest_tag != "" else "unbekannt")
	var s := _stat(selected)
	_info_playtime.text = "Spielzeit: %s" % _duration(float(s.get("playtime", 0.0)))
	_info_last.text = "Zuletzt gespielt: %s" % _date(float(s.get("last_played", 0.0)))
	_folder_btn.disabled = not have
	_uninstall_btn.disabled = not have or busy or is_running


func _refresh_list_entry(id: String) -> void:
	var b: Button = _list_buttons.get(id)
	var u = updaters.get(id)
	if b == null or u == null:
		return
	var lbl: Label = b.get_node("Row/Text/Status")
	if running.has(id):
		lbl.text = "Läuft"
	elif installing.has(id):
		lbl.text = "Wird geladen …"
	elif u.update_available():
		lbl.text = "Update verfügbar" if u.is_installed() else "Nicht installiert"
	elif u.is_installed():
		lbl.text = u.installed_tag()
	else:
		lbl.text = "Nicht verfügbar"


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list_buttons.clear()
	var group := ButtonGroup.new()
	for g in games:
		var id := str(g["id"])
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 64)
		b.theme_type_variation = "GameEntry"
		b.pressed.connect(_select.bind(id))
		var row := HBoxContainer.new()
		row.name = "Row"
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var thumb := TextureRect.new()
		thumb.texture = _cover_for(g)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.custom_minimum_size = Vector2(80, 45)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(thumb)
		var text := VBoxContainer.new()
		text.name = "Text"
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)
		var n := _label(text, str(g.get("name", id)), 17)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := _label(text, "…", 13)
		st.name = "Status"
		st.modulate = MUTED
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(b)
		_list_buttons[id] = b
		_refresh_list_entry(id)


var _cover_cache := {}

## Cover aus res:// (mitgeliefert) oder cover_url (wird einmal heruntergeladen und gespeichert).
func _cover_for(g: Dictionary) -> Texture2D:
	var id := str(g.get("id", ""))
	if _cover_cache.has(id):
		return _cover_cache[id]
	var tex: Texture2D = null
	var res_path := str(g.get("cover", ""))
	if res_path.begins_with("res://") and ResourceLoader.exists(res_path):
		tex = load(res_path)
	var cached := COVER_CACHE.path_join(id + ".png")
	if tex == null and FileAccess.file_exists(cached):
		var img := Image.load_from_file(cached)
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = load("res://art/covers/default.png")
		var url := str(g.get("cover_url", ""))
		if url != "":
			_download_cover(id, url, cached)
	_cover_cache[id] = tex
	return tex


func _download_cover(id: String, url: String, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(COVER_CACHE)
	var http := HTTPRequest.new()
	http.max_redirects = 10
	add_child(http)
	if http.request(url, PackedStringArray(["User-Agent: Kapsel-Launcher"])) != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return
	var img := Image.new()
	if img.load_png_from_buffer(res[3]) != OK and img.load_jpg_from_buffer(res[3]) != OK:
		return
	img.save_png(path)
	_cover_cache.erase(id)
	_rebuild_list()
	_select(selected)


static func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)


static func _duration(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 60:
		return "%d Min." % m
	return "%d Std. %d Min." % [m / 60, m % 60]


static func _date(unix: float) -> String:
	if unix <= 0.0:
		return "noch nie"
	var d := Time.get_datetime_dict_from_unix_time(int(unix + Time.get_time_zone_from_system().get("bias", 0) * 60))
	return "%02d.%02d.%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


## Einfache Umwandlung der Release-Beschreibung: Überschriften, Listen, **fett**, *kursiv*, `code`.
static func markdown_to_bbcode(md: String) -> String:
	var out: PackedStringArray = []
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var ital := RegEx.create_from_string("(?<![*\\w])[*_](.+?)[*_](?![*\\w])")
	var code := RegEx.create_from_string("`([^`]+)`")
	var link := RegEx.create_from_string("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	for raw in md.replace("\r", "").split("\n"):
		# Links werden zu reinem Text, dann eckige Klammern für BBCode entschärfen
		var line: String = link.sub(raw, "$1", true)
		line = line.replace("[", "\u0001").replace("]", "\u0002")
		line = line.replace("\u0001", "[lb]").replace("\u0002", "[rb]")
		line = bold.sub(line, "[b]$1[/b]", true)
		line = ital.sub(line, "[i]$1[/i]", true)
		line = code.sub(line, "[code]$1[/code]", true)
		var t := line.strip_edges()
		if t.begins_with("#"):
			out.append("[color=#ffd86b][b]%s[/b][/color]" % t.lstrip("#").strip_edges())
		elif t.begins_with("- ") or t.begins_with("* ") or t.begins_with("+ "):
			var indent := "    " if raw.begins_with("  ") else ""
			out.append("%s• %s" % [indent, t.substr(2)])
		else:
			out.append(t)
	return "\n".join(out)


# ---------------------------------------------------------------- Aufbau der Oberfläche

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#17121f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Kopfzeile
	var top := PanelContainer.new()
	top.theme_type_variation = "TopBar"
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top.add_child(top_row)
	var logo := TextureRect.new()
	logo.texture = load("res://art/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(100, 40)
	top_row.add_child(logo)
	var title := _label(top_row, "Spielebibliothek", 22)
	title.add_theme_color_override("font_color", TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_app_btn = Button.new()
	_app_btn.visible = false
	_app_btn.pressed.connect(_restart)
	top_row.add_child(_app_btn)
	_app_lbl = _label(top_row, "Launcher %s" % version, 13)
	_app_lbl.modulate = MUTED

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	# Linke Spalte: Spiele
	var side := PanelContainer.new()
	side.theme_type_variation = "SideBar"
	side.custom_minimum_size = Vector2(280, 0)
	body.add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 8)
	side.add_child(side_box)
	var lib_lbl := _label(side_box, "MEINE SPIELE", 13)
	lib_lbl.modulate = MUTED
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	# Rechte Seite: gewähltes Spiel
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 0)
	body.add_child(detail)

	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 280)
	hero.clip_contents = true
	detail.add_child(hero)
	_cover = TextureRect.new()
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(_cover)
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(shade)
	var hero_text := VBoxContainer.new()
	hero_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hero_text.offset_left = 28
	hero_text.offset_right = -28
	hero_text.offset_top = -100
	hero_text.offset_bottom = -16
	hero_text.alignment = BoxContainer.ALIGNMENT_END
	hero.add_child(hero_text)
	_name_lbl = _label(hero_text, "", 40)
	_name_lbl.add_theme_color_override("font_color", TITLE)
	_name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_name_lbl.add_theme_constant_override("outline_size", 8)
	_desc_lbl = _label(hero_text, "", 16)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_desc_lbl.add_theme_constant_override("outline_size", 6)

	var content := MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + s, 20)
	detail.add_child(content)
	var content_box := VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 14)
	content.add_child(content_box)

	# Aktionszeile
	var action := HBoxContainer.new()
	action.add_theme_constant_override("separation", 16)
	content_box.add_child(action)
	_play_btn = Button.new()
	_play_btn.theme_type_variation = "BigButton"
	_play_btn.custom_minimum_size = Vector2(240, 60)
	_play_btn.pressed.connect(_on_play_pressed)
	action.add_child(_play_btn)
	var state := VBoxContainer.new()
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	action.add_child(state)
	_status_lbl = _label(state, "", 16)
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_color_override("font_color", Color("#cfe8ff"))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.visible = false
	state.add_child(_bar)
	_bar_lbl = _label(state, "", 13)
	_bar_lbl.visible = false
	_play_old_btn = _small_button(action, "Ohne Update spielen", func(): _play(selected))
	_play_old_btn.visible = false

	# Unten: Änderungen und Infos
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 16)
	content_box.add_child(lower)
	var notes_panel := PanelContainer.new()
	notes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(notes_panel)
	var notes_box := VBoxContainer.new()
	notes_panel.add_child(notes_box)
	_notes_title = _label(notes_box, "Was ist neu", 19)
	_notes_title.add_theme_color_override("font_color", TITLE)
	_notes = RichTextLabel.new()
	_notes.bbcode_enabled = true
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_notes.add_theme_font_size_override(k, 15)
	notes_box.add_child(_notes)
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(300, 0)
	lower.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info_panel.add_child(info)
	_info_installed = _label(info, "", 16)
	_info_latest = _label(info, "", 16)
	_info_playtime = _label(info, "", 16)
	_info_last = _label(info, "", 16)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	_folder_btn = _small_button(info, "Spielordner öffnen", func():
		var u = updaters.get(selected)
		if u:
			OS.shell_open(u.game_dir()))
	_uninstall_btn = _small_button(info, "Deinstallieren", func(): _confirm.popup_centered())
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Deinstallieren"
	_confirm.dialog_text = "Spieldateien löschen? Deine Spielstände bleiben erhalten."
	_confirm.ok_button_text = "Löschen"
	_confirm.cancel_button_text = "Abbrechen"
	_confirm.confirmed.connect(_on_uninstall_confirmed)
	add_child(_confirm)


## Dunkler Verlauf von unten über das Cover, damit der Titel lesbar bleibt.
func _shade_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.07, 0.12, 0.0))
	grad.set_color(1, Color(0.09, 0.07, 0.12, 0.95))
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.fill_from = Vector2(0, 0.3)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _small_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_theme() -> Theme:
	var th := Theme.new()
	for st in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(st, "Button", _nine("button_%s" % st, 5, 2, 8.0))
		th.set_stylebox(st, "BigButton", _nine("menu_button_%s" % st, 6, 3, 12.0))
	th.set_type_variation("BigButton", "Button")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "BigButton", GOLD_TEXT)
	th.set_color("font_disabled_color", "BigButton", Color(0.24, 0.11, 0.08, 0.5))
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	th.set_font_size("font_size", "BigButton", 28)
	th.set_font_size("font_size", "Button", 15)
	for v in ["Button", "BigButton", "GameEntry"]:
		th.set_stylebox("focus", v, StyleBoxEmpty.new())
	# Einträge der Spieleliste: flach, gewählt mit Goldrand
	th.set_type_variation("GameEntry", "Button")
	th.set_stylebox("normal", "GameEntry", _flat(Color(1, 1, 1, 0.03)))
	th.set_stylebox("hover", "GameEntry", _flat(Color(1, 1, 1, 0.08)))
	th.set_stylebox("pressed", "GameEntry", _flat(Color(1, 0.85, 0.42, 0.16), Color("#ffd86b")))
	th.set_stylebox("hover_pressed", "GameEntry", _flat(Color(1, 0.85, 0.42, 0.2), Color("#ffd86b")))
	th.set_stylebox("panel", "PanelContainer", _nine("panel_dark_9slice", 6, 2, 14.0))
	th.set_type_variation("TopBar", "PanelContainer")
	var top := _flat(Color("#0f0c15"))
	top.set_content_margin_all(10)
	top.content_margin_left = 20
	top.content_margin_right = 20
	th.set_stylebox("panel", "TopBar", top)
	th.set_type_variation("SideBar", "PanelContainer")
	var side := _flat(Color("#1d1727"))
	side.set_content_margin_all(12)
	th.set_stylebox("panel", "SideBar", side)
	th.set_stylebox("background", "ProgressBar", _nine("progress_bar_bg", 3, 2, 0.0))
	th.set_stylebox("fill", "ProgressBar", _nine("progress_bar_fill", 3, 2, 0.0))
	return th


func _flat(color: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	return sb


## Ganzzahlig vergrößerte 9-Slice-Grafik als StyleBox.
func _nine(name: String, margin: int, factor: int, content: float) -> StyleBoxTexture:
	var t: Texture2D = load("res://art/%s.png" % name)
	var img := t.get_image()
	img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(margin * factor)
	sb.set_content_margin_all(content)
	return sb
