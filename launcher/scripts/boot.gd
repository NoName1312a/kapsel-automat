extends Node
## Startszene. Lädt ein neueres Launcher-Update (launcher/app-<version>.pck), falls eines
## heruntergeladen wurde, und öffnet dann die Bibliothek. So aktualisiert sich der Launcher selbst,
## ohne dass jemand das ZIP neu herunterladen muss. Diese Datei möglichst nie ändern:
## Sie läuft immer in der Version, die im ZIP ausgeliefert wurde.

const APP_INFO := "launcher/app.json"


func _ready() -> void:
	var base := _base_dir()
	var info_path := base.path_join(APP_INFO)
	var builtin: String = load("res://scripts/version.gd").VERSION
	if FileAccess.file_exists(info_path):
		var info = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		if info is Dictionary:
			var pck := base.path_join("launcher").path_join(str(info.get("file", "")))
			_remove_stale(base.path_join("launcher"), str(info.get("file", "")))
			if _newer(str(info.get("version", "")), builtin) and FileAccess.file_exists(pck):
				if ProjectSettings.load_resource_pack(pck, true):
					print("Launcher-Update geladen: ", info.get("version"))
				else:
					push_warning("Launcher-Update %s ließ sich nicht laden" % pck)
	get_tree().change_scene_to_file.call_deferred("res://library.tscn")


## Wie Updater.pick_base_dir(), hier bewusst kopiert, damit boot.gd nichts anderes laden muss.
func _base_dir() -> String:
	if ProjectSettings.globalize_path("res://") == "":
		var exe_dir := OS.get_executable_path().get_base_dir()
		var probe := exe_dir.path_join(".launcher_write_test")
		var f := FileAccess.open(probe, FileAccess.WRITE)
		if f:
			f.close()
			DirAccess.remove_absolute(probe)
			return exe_dir
	return OS.get_user_data_dir()


## Alte app-*.pck aufräumen. Jetzt geht das, weil noch keine davon geladen ist.
func _remove_stale(dir: String, keep: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("app-") and (f.ends_with(".pck") or f.ends_with(".part")) and f != keep:
			DirAccess.remove_absolute(dir.path_join(f))


func _newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in range(max(pa.size(), pb.size())):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
