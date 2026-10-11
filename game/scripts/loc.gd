extends Node
## Sprache (Autoload "Loc"). Der Quelltext ist Deutsch; Loc.t("deutscher Text") gibt im englischen
## Modus die Übersetzung aus res://data/lang_en.json zurück ({"deutsch": "english"}).
## Fehlt eine Übersetzung, bleibt der deutsche Text stehen. Spieldaten (Figuren, Upgrades, Story …)
## laufen beim Laden durch translate_data().

signal language_changed

const LANGS := ["en", "de"]
const FILE_EN := "res://data/lang_en.json"

var lang := "en"
var _en: Dictionary = {}


func _ready() -> void:
	if FileAccess.file_exists(FILE_EN):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE_EN))
		if d is Dictionary:
			_en = d


func t(s: String) -> String:
	if lang == "de":
		return s
	return str(_en.get(s, s))


func is_en() -> bool:
	return lang != "de"


func set_lang(l: String) -> void:
	l = l if l in LANGS else "en"
	if l == lang:
		return
	lang = l
	Fmt.en = l != "de"
	language_changed.emit()


## Übersetzt alle Texte in geladenen JSON-Daten (rekursiv, Schlüssel bleiben unverändert).
func translate_data(v):
	if lang == "de":
		return v
	if v is String:
		return t(v)
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(translate_data(x))
		return a
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			d[k] = translate_data(v[k])
		return d
	return v


## Sprache im laufenden Spiel wechseln: speichern, Daten neu laden, Szene neu aufbauen.
func switch(l: String) -> void:
	if l == lang:
		return
	if Game.active:
		Game.save_game()
	Settings.set_value("language", l)
	Game._load_data()
	Story.reload()
	get_tree().reload_current_scene()
	# Nach dem Neuaufbau die Einstellungen wieder öffnen, damit man sieht, was passiert ist
	await get_tree().process_frame
	await get_tree().process_frame
	var sc := get_tree().current_scene
	if sc == null:
		return
	if "ui" in sc and sc.ui != null:
		sc.ui.open_settings()
	elif "settings_panel" in sc and sc.settings_panel != null:
		sc.settings_panel.open()
