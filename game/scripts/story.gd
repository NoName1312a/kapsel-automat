extends Node
## Story aus res://data/story.json (vom Story-Thread). Als Autoload "Story" erreichbar.
## Format: {"characters": {id: {name, color, portrait, fallback_portrait}},
##          "beats": [{"id", "trigger", "style", "lines": [{"speaker", "portrait", "text"}, …]}, …],
##          "prestige_lines", "kruemel_idle", "figure_flavor", "machine_flavor"}
## Ältere Form (speaker/portrait am Beat, lines als Strings) wird auch verstanden.
## Ohne Datei passiert einfach nichts.

const FILE := "res://data/story.json"

var beats: Array = []
var characters: Dictionary = {}
var prestige_lines: Array = []
var kruemel_idle: Array = []
var figure_flavor: Dictionary = {}
var machine_flavor: Dictionary = {}


func _ready() -> void:
	if not FileAccess.file_exists(FILE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not d is Dictionary:
		return
	beats = d.get("beats", [])
	characters = d.get("characters", {})
	prestige_lines = d.get("prestige_lines", [])
	kruemel_idle = d.get("kruemel_idle", [])
	figure_flavor = d.get("figure_flavor", {})
	machine_flavor = d.get("machine_flavor", {})


func beats_for(trigger: String) -> Array:
	return beats.filter(func(b: Dictionary) -> bool: return b.get("trigger", "") == trigger)


## Alle Zeilen zu einem Ereignis, fertig zum Anzeigen: {name, color, portrait (Texture2D oder null), text, style}.
func lines_for(trigger: String) -> Array:
	var out: Array = []
	for b in beats_for(trigger):
		for line in b.get("lines", []):
			if line is Dictionary:
				out.append(make_line(str(line.get("speaker", "")), line.get("portrait"), str(line.get("text", "")), b.get("style", "")))
			else:
				out.append(make_line(str(b.get("speaker", "")), b.get("portrait"), str(line), b.get("style", "")))
	return out


func make_line(speaker: String, portrait, text: String, style: String = "bubble") -> Dictionary:
	var c: Dictionary = characters.get(speaker, {})
	var who: String = c.get("name", speaker)
	var tex: Texture2D = null
	if portrait != null and str(portrait) != "":
		tex = Art.tex("portraits/%s.png" % portrait)
	if tex == null and c.get("portrait") != null:
		tex = _res_tex(str(c["portrait"]))
	if tex == null and c.get("fallback_portrait") != null:
		tex = _res_tex(str(c["fallback_portrait"]))
	return {"name": who, "color": Color(c.get("color", "#ffe14d")), "portrait": tex, "text": text, "style": style}


func _res_tex(path: String) -> Texture2D:
	# Pfade in story.json beginnen mit "art/"; Art.tex erwartet den Teil danach
	return Art.tex(path.trim_prefix("res://").trim_prefix("art/"))


func random_prestige_line() -> Dictionary:
	if prestige_lines.is_empty():
		return {}
	return make_line("kruemel", "kruemel", str(prestige_lines.pick_random()))


func random_idle_line() -> String:
	return str(kruemel_idle.pick_random()) if not kruemel_idle.is_empty() else ""


func flavor(figure_id: String) -> String:
	return str(figure_flavor.get(figure_id, ""))
