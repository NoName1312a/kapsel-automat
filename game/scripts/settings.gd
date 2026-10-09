extends Node
## Einstellungen (Lautstärken, Vollbild, Bildschirmwackeln), gespeichert in user://settings.cfg.
## Legt beim Start die Audio-Busse "Music" und "SFX" unter "Master" an. Als Autoload "Settings" erreichbar.

signal changed

const FILE := "user://settings.cfg"
const DEFAULTS := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"fullscreen": false,
	"shake": 1.0,
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	_migrate_old_user_dir()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	# Ein Hauch Hall macht die Effekte runder
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_bus) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.25
		rv.damping = 0.6
		rv.wet = 0.08
		rv.dry = 1.0
		AudioServer.add_bus_effect(sfx_bus, rv)
	_load()
	apply()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v) -> void:
	values[key] = v
	apply()
	save()
	changed.emit()


func shake_mult() -> float:
	return float(get_value("shake"))


func apply() -> void:
	_set_volume("Master", float(get_value("master")))
	_set_volume("Music", float(get_value("music")))
	_set_volume("SFX", float(get_value("sfx")))
	# Im Headless-Test gibt es kein echtes Fenster
	if DisplayServer.get_name() != "headless":
		var fs: bool = get_value("fullscreen")
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func _set_volume(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))


func save() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(FILE)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(FILE) != OK:
		return
	for k in DEFAULTS:
		values[k] = cf.get_value("settings", k, DEFAULTS[k])


## Bis v0.5 lagen Spielstand und Einstellungen unter app_userdata/<Projektname>. Seit es einen
## festen Ordner "KapselAutomat" gibt, einmal von dort herüberholen (nur wenn hier noch nichts liegt).
func _migrate_old_user_dir() -> void:
	if FileAccess.file_exists("user://save.json") or FileAccess.file_exists("user://settings.cfg"):
		return
	var old := OS.get_data_dir().path_join("Godot/app_userdata/Kapsel-Automat (Prototyp)")
	if not DirAccess.dir_exists_absolute(old):
		return
	for f in ["save.json", "save.bak", "settings.cfg"]:
		var src := old.path_join(f)
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, "user://" + f)
