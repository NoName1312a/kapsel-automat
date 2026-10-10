extends Node
## Ein Spiel der Bibliothek: prüft sein neuestes GitHub-Release, lädt es herunter und installiert es
## nach <basis>/games/<id>/. Spielstände liegen im Benutzerordner des Spiels und werden nie angefasst.
## Bewusst ohne class_name: Launcher-Updates werden als .pck nachgeladen, und neue Klassennamen
## würden dabei nicht registriert. Andere Skripte laden diese Datei per preload().

signal check_finished(ok: bool)          # nach check(): latest_* ist gefüllt, wenn ok
signal progress(done: int, total: int)   # während des Downloads (total = -1, wenn unbekannt)
signal install_finished(ok: bool, message: String)

const VERSION_FILE := ".launcher_version.json"

var config := {}
var install_dir := ""           # Basisordner, in dem games/ liegt
var latest_tag := ""
var latest_name := ""
var latest_notes := ""
var latest_published := ""
var latest_asset_url := ""
var latest_asset_size := -1
var last_error := ""

var _http: HTTPRequest
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.max_redirects = 10     # Release-Downloads leiten auf GitHubs Datei-Server um
	_http.timeout = 0.0
	add_child(_http)
	set_process(false)


# ---------------------------------------------------------------- Konfiguration

const DEFAULTS := {
	"api_base": "https://api.github.com",
	"asset_suffix": "game.zip",
	# Das Spiel kommt als .pck und läuft in der signierten Launcher-.exe selbst (--main-pack).
	# So muss Windows nur ein einziges Programm zulassen.
	"pack": "",
	"game_args": [],
	# Alternative: eigene Spiel-.exe starten (nur wenn pack leer ist)
	"game_exe": "",
	"include_prereleases": false,
}


## settings: globale Launcher-Einstellungen (api_base, token …), game: Eintrag aus games.json.
func setup(settings: Dictionary, game: Dictionary, base_dir: String) -> void:
	config = DEFAULTS.duplicate(true)
	config.merge(settings, true)
	config.merge(game, true)
	if not config.has("asset_prefix"):
		config["asset_prefix"] = str(config.get("id", "")) + "-"
	install_dir = base_dir


func game_id() -> String:
	return str(config.get("id", "spiel"))


## true, wenn der Launcher aus einer .pck läuft (fertige Version), false im Projektordner.
## Nicht OS.has_feature("editor") nehmen: Ausgeliefert wird die signierte offizielle Godot-.exe,
## und die meldet immer "editor".
static func runs_from_package() -> bool:
	return ProjectSettings.globalize_path("res://") == ""


## Neben der Launcher-.exe (portabel), sonst im Benutzerordner des Launchers.
static func pick_base_dir(override := "") -> String:
	if override != "":
		return override
	if runs_from_package():
		var exe_dir := OS.get_executable_path().get_base_dir()
		if _is_writable(exe_dir):
			return exe_dir
	return OS.get_user_data_dir()


static func _is_writable(dir: String) -> bool:
	var probe := dir.path_join(".launcher_write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _platform_value(key: String) -> String:
	var v = config.get(key, "")
	if v is Dictionary:
		return str(v.get(OS.get_name(), ""))
	return str(v)


func game_dir() -> String:
	return install_dir.path_join("games").path_join(game_id())


func game_exe_path() -> String:
	return game_dir().path_join(_platform_value("game_exe"))


func game_pack_path() -> String:
	var pack := _platform_value("pack")
	return game_dir().path_join(pack) if pack != "" else ""


## Datei, deren Vorhandensein "installiert" bedeutet
func game_main_file() -> String:
	var pack := game_pack_path()
	return pack if pack != "" else game_exe_path()


# ---------------------------------------------------------------- Installierte Version

func installed_tag() -> String:
	var p := game_dir().path_join(VERSION_FILE)
	if not FileAccess.file_exists(p):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return str(d.get("tag", "")) if d is Dictionary else ""


func is_installed() -> bool:
	if installed_tag() == "":
		return false
	return FileAccess.file_exists(game_main_file()) or DirAccess.dir_exists_absolute(game_main_file())


func update_available() -> bool:
	if latest_tag == "" or latest_asset_url == "":
		return false
	return not is_installed() or compare_versions(latest_tag, installed_tag()) > 0


## "v1.2.10" > "v1.2.9"; Text nach "-" (z. B. "-beta") zählt als älter als ohne.
static func compare_versions(a: String, b: String) -> int:
	var pa := _parse_version(a)
	var pb := _parse_version(b)
	for i in range(max(pa[0].size(), pb[0].size())):
		var x: int = pa[0][i] if i < pa[0].size() else 0
		var y: int = pb[0][i] if i < pb[0].size() else 0
		if x != y:
			return 1 if x > y else -1
	if pa[1] == pb[1]:
		return 0
	if pa[1] == "":
		return 1
	if pb[1] == "":
		return -1
	return 1 if pa[1] > pb[1] else -1


static func _parse_version(s: String) -> Array:
	s = s.strip_edges().trim_prefix("v").trim_prefix("V")
	var pre := ""
	var dash := s.find("-")
	if dash >= 0:
		pre = s.substr(dash + 1)
		s = s.substr(0, dash)
	var nums: Array[int] = []
	for part in s.split("."):
		nums.append(int(part) if part.is_valid_int() else 0)
	return [nums, pre]


# ---------------------------------------------------------------- Neuestes Release abfragen

func check() -> void:
	if _busy:
		return
	_busy = true
	last_error = ""
	var repo := str(config["repo"])
	var url := "%s/repos/%s/releases" % [str(config["api_base"]).trim_suffix("/"), repo]
	url += "?per_page=10" if config.get("include_prereleases", false) else "/latest"
	_http.download_file = ""
	var err := _http.request(url, _api_headers())
	if err != OK:
		_busy = false
		last_error = "Anfrage fehlgeschlagen (%d)" % err
		check_finished.emit(false)
		return
	var res: Array = await _http.request_completed
	_busy = false
	var ok := _parse_release_response(res[0], res[1], res[3])
	check_finished.emit(ok)


func _api_headers() -> PackedStringArray:
	var h := PackedStringArray(["User-Agent: Kapsel-Launcher", "Accept: application/vnd.github+json"])
	if str(config.get("token", "")) != "":
		h.append("Authorization: Bearer " + str(config["token"]))
	return h


func _parse_release_response(result: int, code: int, body: PackedByteArray) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		last_error = "Keine Verbindung"
		return false
	if code == 404:
		last_error = "Noch kein Release gefunden"
		return false
	if code != 200:
		last_error = "GitHub antwortet mit Fehler %d" % code
		return false
	var data = JSON.parse_string(body.get_string_from_utf8())
	var rel = null
	if data is Array:
		for r in data:
			if r is Dictionary and not r.get("draft", false):
				rel = r
				break
	elif data is Dictionary:
		rel = data
	if not rel is Dictionary:
		last_error = "Antwort von GitHub nicht lesbar"
		return false
	latest_tag = str(rel.get("tag_name", ""))
	latest_name = str(rel.get("name", latest_tag)) if rel.get("name") != null else latest_tag
	latest_notes = str(rel.get("body", "")) if rel.get("body") != null else ""
	latest_published = str(rel.get("published_at", "")).substr(0, 10)
	latest_asset_url = ""
	latest_asset_size = -1
	var prefix := str(config.get("asset_prefix", "")).to_lower()
	var suffix := _platform_value("asset_suffix").to_lower()
	for a in rel.get("assets", []):
		var aname := str(a.get("name", "")).to_lower()
		if aname.begins_with(prefix) and aname.ends_with(suffix):
			latest_asset_url = str(a.get("browser_download_url", ""))
			latest_asset_size = int(a.get("size", -1))
			break
	if latest_asset_url == "":
		last_error = "Release %s hat keine Datei für %s" % [latest_tag, OS.get_name()]
	return true


# ---------------------------------------------------------------- Herunterladen + installieren

func install_latest() -> void:
	if _busy or latest_asset_url == "":
		return
	_busy = true
	DirAccess.make_dir_recursive_absolute(install_dir.path_join("games"))
	var zip_path := install_dir.path_join("games").path_join(game_id() + ".zip.part")
	DirAccess.remove_absolute(zip_path)
	_http.download_file = zip_path
	var headers := PackedStringArray(["User-Agent: Kapsel-Launcher", "Accept: application/octet-stream"])
	var err := _http.request(latest_asset_url, headers)
	if err != OK:
		_finish_install(false, "Download konnte nicht starten (%d)" % err)
		return
	set_process(true)
	var res: Array = await _http.request_completed
	set_process(false)
	_http.download_file = ""
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		DirAccess.remove_absolute(zip_path)
		_finish_install(false, "Download fehlgeschlagen (%d / HTTP %d)" % [res[0], res[1]])
		return
	progress.emit(latest_asset_size, latest_asset_size)
	var msg := _install_zip(zip_path)
	DirAccess.remove_absolute(zip_path)
	_finish_install(msg == "", msg)


func _process(_delta: float) -> void:
	var total := _http.get_body_size()
	if total <= 0:
		total = latest_asset_size
	progress.emit(_http.get_downloaded_bytes(), total)


func _finish_install(ok: bool, message: String) -> void:
	_busy = false
	install_finished.emit(ok, message)


## Entpackt nach game_new/, tauscht dann game/ aus. Gibt "" zurück oder eine Fehlermeldung.
func _install_zip(zip_path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return "Heruntergeladene Datei ist kein gültiges ZIP"
	var files := zip.get_files()
	if files.is_empty():
		zip.close()
		return "ZIP ist leer"
	var prefix := _common_root(files)
	var new_dir := game_dir() + ".neu"
	var old_dir := game_dir() + ".alt"
	_remove_tree(new_dir)
	_remove_tree(old_dir)
	DirAccess.make_dir_recursive_absolute(new_dir)
	for f in files:
		var rel := f.substr(prefix.length())
		if rel == "" or rel.begins_with("/") or ".." in rel.split("/"):
			continue
		var target := new_dir.path_join(rel)
		if f.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target)
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out == null:
			zip.close()
			return "Kann %s nicht schreiben" % rel
		out.store_buffer(zip.read_file(f))
		out.close()
	zip.close()
	if not FileAccess.file_exists(new_dir.path_join(game_main_file().get_file())):
		_remove_tree(new_dir)
		return "Im Download fehlt %s" % game_main_file().get_file()
	if OS.get_name() != "Windows" and _platform_value("pack") == "":
		var exe := new_dir.path_join(_platform_value("game_exe"))
		if FileAccess.file_exists(exe):
			OS.execute("chmod", ["+x", exe])
	var meta := FileAccess.open(new_dir.path_join(VERSION_FILE), FileAccess.WRITE)
	meta.store_string(JSON.stringify({"tag": latest_tag, "name": latest_name, "notes": latest_notes, "installed": Time.get_datetime_string_from_system()}, "  "))
	meta.close()
	# Austausch: alte Version erst wegräumen, wenn die neue komplett entpackt ist
	if DirAccess.dir_exists_absolute(game_dir()):
		if DirAccess.rename_absolute(game_dir(), old_dir) != OK:
			_remove_tree(new_dir)
			return "Spielordner ist gesperrt. Läuft das Spiel noch?"
	if DirAccess.rename_absolute(new_dir, game_dir()) != OK:
		DirAccess.rename_absolute(old_dir, game_dir())
		return "Neue Version konnte nicht verschoben werden"
	_remove_tree(old_dir)
	return ""


## Liegt alles in einem gemeinsamen Oberordner ("KapselAutomat/..."), wird er weggelassen.
func _common_root(files: PackedStringArray) -> String:
	var first := files[0]
	var slash := first.find("/")
	if slash < 0:
		return ""
	var root := first.substr(0, slash + 1)
	for f in files:
		if not f.begins_with(root):
			return ""
	return root


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		_remove_tree(path.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func installed_notes() -> String:
	var p := game_dir().path_join(VERSION_FILE)
	if not FileAccess.file_exists(p):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return str(d.get("notes", "")) if d is Dictionary else ""


# ---------------------------------------------------------------- Spiel starten

## Startet das Spiel als eigenen Prozess und gibt die Prozess-ID zurück (-1 bei Fehler).
func launch_game() -> int:
	var args := PackedStringArray()
	for a in config.get("game_args", []):
		args.append(str(a))
	var pack := game_pack_path()
	if pack != "":
		# Gleiche signierte .exe wie der Launcher, nur mit den Spieldaten
		args.append_array(PackedStringArray(["--main-pack", pack]))
		return OS.create_process(OS.get_executable_path(), args, false)
	return OS.create_process(game_exe_path(), args, false)


## Löscht die installierten Spieldateien (nicht die Spielstände).
func uninstall() -> void:
	_remove_tree(game_dir())
