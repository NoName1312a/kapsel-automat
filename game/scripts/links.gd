class_name Links
extends RefCounted
## Externe Links (Steam, Discord, Reddit, X) aus res://data/links.json.

const FILE := "res://data/links.json"


static func url(key: String) -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if d is Dictionary:
		return str(d.get(key, ""))
	return ""


static func is_placeholder(u: String) -> bool:
	return u == "" or u.contains("DEIN")


## Öffnet den Link im Browser. Gibt einen Hinweistext zurück, falls der Link noch fehlt.
static func open(key: String) -> String:
	var u := url(key)
	if is_placeholder(u):
		return "Link kommt bald! (data/links.json, Eintrag \"%s\")" % key
	OS.shell_open(u)
	return ""
