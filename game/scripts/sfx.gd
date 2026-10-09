extends Node
## Sounds und Musik. Als Autoload "Sfx" erreichbar.
## Echte Dateien aus res://audio/sfx/<name>.ogg|wav (Varianten <name>_1, <name>_2 …) und
## res://audio/music/<name>.ogg ersetzen automatisch die per Code erzeugten Platzhalter.
## Namen und Anlässe: ../audio-spec-fuer-spiel.md

const ProceduralMusic := preload("res://scripts/procedural_music.gd")

const RATE := 22050
const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const EXTS := ["ogg", "wav", "mp3"]
const MUSIC_FADE := 1.2

var streams: Dictionary = {}        # name -> Array[AudioStream]
var from_file: Dictionary = {}      # name -> true, wenn eine echte Datei geladen wurde
var players: Array[AudioStreamPlayer] = []
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current_music := ""
var _music_cache: Dictionary = {}
var _generating: Dictionary = {}   # name -> WorkerThreadPool-Task-ID
var _last_ui := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music_a = _music_player()
	music_b = _music_player()
	_build_procedural()
	_load_files()
	# Jeder Knopf und Regler im Spiel klickt, ohne dass jeder das selbst tun muss
	get_tree().node_added.connect(_on_node_added)


func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func has_file(sound: String) -> bool:
	return from_file.has(sound)


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var list: Array = streams.get(sound, [])
	if list.is_empty():
		return
	var stream: AudioStream = list[randi() % list.size()]
	if from_file.has(sound):
		# Die gelieferten Dateien sind schon fertig abgemischt: nur noch leicht absenken
		volume_db = maxf(volume_db, -3.0)
	if list.size() > 1 or from_file.has(sound):
		pitch *= randf_range(0.97, 1.03)
	var target: AudioStreamPlayer = null
	for p in players:
		if not p.playing:
			target = p
			break
	if target == null:
		# Alle belegt: den Player nehmen, der am längsten läuft
		target = players[0]
		for p in players:
			if p.get_playback_position() > target.get_playback_position():
				target = p
	target.stream = stream
	target.pitch_scale = pitch
	target.volume_db = volume_db
	target.play()


## Spielt den ersten Sound aus der Liste, der vorhanden ist (z. B. eigener Sound, sonst Platzhalter).
func play_first(names: Array, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	for n in names:
		if streams.has(n):
			play(n, pitch, volume_db)
			return


## Wie play_first, aber eine echte Datei hat Vorrang vor allen Platzhaltern der Liste.
func play_pref(names: Array, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	for n in names:
		if from_file.has(n):
			play(n, pitch, volume_db)
			return
	play_first(names, pitch, volume_db)


# --- Musik ----------------------------------------------------------------

## Wechselt weich zur Musik <name>. Ohne Datei läuft ein per Code erzeugter Loop,
## der beim ersten Mal im Hintergrund berechnet wird.
func play_music(music_name: String) -> void:
	if music_name == current_music:
		return
	current_music = music_name
	var s := _music_stream(music_name)
	if s:
		_crossfade(s)


## Gibt es eine Musikdatei mit diesem Namen?
func has_music(music_name: String) -> bool:
	for ext in EXTS:
		var path: String = MUSIC_DIR + music_name + "." + ext
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return true
	return false


func stop_music() -> void:
	current_music = ""
	_crossfade(null)


func _crossfade(s: AudioStream) -> void:
	var old: AudioStreamPlayer = music_a if music_a.playing else (music_b if music_b.playing else null)
	if old and old.stream == s:
		return
	var new_p := music_b if old == music_a else music_a
	if old:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, MUSIC_FADE)
		tw.tween_callback(old.stop)
	if s == null:
		return
	new_p.stream = s
	new_p.volume_db = -40.0
	new_p.play()
	create_tween().tween_property(new_p, "volume_db", 0.0, MUSIC_FADE)


func _music_stream(music_name: String) -> AudioStream:
	if _music_cache.has(music_name):
		return _music_cache[music_name]
	for ext in EXTS:
		var s := _load_stream(MUSIC_DIR + music_name + "." + ext)
		if s:
			if s is AudioStreamOggVorbis or s is AudioStreamMP3:
				s.loop = true
			elif s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_end = int(s.get_length() * s.mix_rate)
			_music_cache[music_name] = s
			return s
	# Ohne eigene Musik (Spuk, Glück, Gold …) läuft die normale Spielmusik weiter
	var gen_name := music_name if music_name == "menu" else "game"
	if gen_name != music_name:
		return _music_stream(gen_name)
	if not _generating.has(gen_name):
		_generating[gen_name] = WorkerThreadPool.add_task(_generate_music.bind(gen_name), false, "Musik")
	return null


func _exit_tree() -> void:
	# Laufende Musik-Berechnung abwarten, sonst greift sie beim Beenden ins Leere
	for id in _generating.values():
		WorkerThreadPool.wait_for_task_completion(id)


func _generate_music(music_name: String) -> void:
	var s := ProceduralMusic.render(music_name, RATE)
	_music_ready.call_deferred(music_name, s)


func _music_ready(music_name: String, s: AudioStream) -> void:
	_music_cache[music_name] = s
	if current_music == music_name or (music_name == "game" and current_music not in ["", "menu"] and _music_stream(current_music) == s):
		_crossfade(s)


# --- Dateien --------------------------------------------------------------

func _load_files() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	var found: Dictionary = {}       # name -> {Pfad -> true}
	var rx := RegEx.create_from_string("^(.+)_(\\d+)$")
	for f in dir.get_files():
		# Exportierte Spiele listen "x.ogg.import" bzw. "x.ogg.remap"
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if not f.get_extension().to_lower() in EXTS:
			continue
		var base := f.get_basename()
		var key := base
		var m := rx.search(base)
		if m and streams.has(m.get_string(1)):
			key = m.get_string(1)
		if not found.has(key):
			found[key] = {}
		found[key][SFX_DIR + f] = true
	for key in found:
		var list: Array = []
		for path in found[key]:
			var s := _load_stream(path)
			if s:
				list.append(s)
		if not list.is_empty():
			streams[key] = list
			from_file[key] = true


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	if not FileAccess.file_exists(path):
		return null
	# Noch nicht importiert (frisch hineinkopiert): direkt aus der Datei laden
	var abs_path := ProjectSettings.globalize_path(path)
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(abs_path)
		"wav":
			return AudioStreamWAV.load_from_file(abs_path)
		"mp3":
			return AudioStreamMP3.load_from_file(abs_path)
	return null


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b: BaseButton = n
		b.pressed.connect(func() -> void:
			if b.toggle_mode:
				play_pref(["ui_toggle_on" if b.button_pressed else "ui_toggle_off", "ui_click"], 1.0, -4.0)
			else:
				play("ui_click", randf_range(0.96, 1.04), -6.0))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled and _ui_ready(60):
				play("ui_hover", randf_range(0.95, 1.05), -14.0))
	elif n is Slider:
		var r: Slider = n
		r.value_changed.connect(func(_v: float) -> void:
			if _ui_ready(70):
				play_pref(["ui_slider", "tick"], 1.0 if has_file("ui_slider") else 1.4, -8.0))
	elif n is TabContainer:
		(n as TabContainer).tab_changed.connect(func(_i: int) -> void: play_pref(["ui_tab", "ui_click"], 1.0, -4.0))


func _ui_ready(gap_ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_ui < gap_ms:
		return false
	_last_ui = now
	return true


# --- Platzhalter-Sounds ---------------------------------------------------

func _put(sound: String, s: AudioStream) -> void:
	streams[sound] = [s]


func _build_procedural() -> void:
	# Kurbel-Ratsche: zwei Varianten, damit es nicht maschinengewehrartig klingt
	streams["tick"] = []
	for f0 in [2100.0, 2360.0]:
		streams["tick"].append(_make(0.05, func(t: float) -> float:
			return randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.4 + sin(TAU * f0 * t) * exp(-t * 120.0) * 0.28 \
				+ sin(TAU * 620.0 * t) * exp(-t * 90.0) * 0.2))
	# Kapsel fällt in die Schale: dumpfer Aufprall plus kleiner Nachhüpfer
	_put("clunk", _make(0.42, func(t: float) -> float:
		var s := sin(TAU * (150.0 - 90.0 * t) * t) * exp(-t * 16.0) * 0.8 + randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.3
		if t > 0.16:
			var u := t - 0.16
			s += sin(TAU * 190.0 * u) * exp(-u * 30.0) * 0.35 + randf_range(-1.0, 1.0) * exp(-u * 90.0) * 0.12
		return s))
	# Kapsel springt auf: Knack + aufsteigendes Plopp
	_put("pop", _make(0.2, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.5 + sin(TAU * (420.0 + 2600.0 * t) * t) * _env(t, 0.004, 24.0) * 0.75))
	# Münzen: zwei helle Glöckchen
	_put("coin", _bells([[0.0, 1568.0], [0.07, 2093.0]], 9.0, 0.35, 0.45))
	_put("deny", _make(0.22, func(t: float) -> float:
		var f := 180.0 if t < 0.1 else 150.0
		return (sin(TAU * f * t) + 0.35 * signf(sin(TAU * f * t))) * _env(t, 0.005, 10.0) * 0.3))
	# Auflösungs-Jingles je Seltenheit
	_put("chime_common", _bells([[0.0, 1047.0]], 6.0, 0.6))
	_put("chime_rare", _bells([[0.0, 784.0], [0.09, 1175.0]], 5.0, 0.8))
	_put("chime_epic", _bells([[0.0, 659.0], [0.075, 784.0], [0.15, 988.0], [0.225, 1319.0], [0.3, 1568.0]], 4.0, 1.2))
	_put("chime_legendary", _fanfare())
	_put("set_complete", _bells([[0.0, 784.0], [0.12, 988.0], [0.24, 1175.0], [0.36, 1568.0], [0.36, 1175.0]], 3.0, 1.4))
	_put("achievement", _bells([[0.0, 1047.0], [0.08, 1319.0], [0.16, 1568.0], [0.28, 2093.0], [0.28, 1568.0]], 3.5, 1.2))
	_put("prestige", _bells([[0.0, 262.0], [0.12, 330.0], [0.24, 392.0], [0.36, 523.0], [0.48, 659.0],
		[0.6, 784.0], [0.72, 1047.0], [0.72, 523.0], [0.72, 659.0]], 1.8, 2.6, 0.22))
	_put("bless", _make(0.9, func(t: float) -> float:
		var s := 0.0
		for k in 5:
			var st := k * 0.07
			if t >= st:
				var u := t - st
				s += sin(TAU * (2093.0 + k * 330.0) * u) * exp(-u * 6.0) * 0.12
		return s + sin(TAU * 1047.0 * t) * _env(t, 0.15, 3.0) * 0.12))
	# Leere Kapsel: lustiges "wah-wah-wahh"
	_put("empty", _make(0.85, func(t: float) -> float:
		var seg := mini(int(t / 0.25), 2)
		var u := t - seg * 0.25
		var f: float = [330.0, 294.0, 262.0][seg] - u * (60.0 if seg == 2 else 20.0)
		var wob := 1.0 + 0.04 * sin(TAU * 6.0 * t)
		return (sin(TAU * f * wob * t) + 0.4 * sin(TAU * f * 2.0 * t)) * _env(u, 0.02, 4.0 if seg == 2 else 9.0) * 0.28))
	# Fluch: Grollen mit Geisterheulen
	_put("curse", _make(0.95, func(t: float) -> float:
		var rumble := (sin(TAU * (85.0 - 35.0 * t) * t) * 0.6 + randf_range(-1.0, 1.0) * 0.25) * exp(-t * 3.5)
		var ghost := sin(TAU * (440.0 + 120.0 * sin(TAU * 1.6 * t)) * t) * _env(t, 0.2, 2.5) * 0.18
		return (rumble + ghost) * 0.7))
	_put("crit", _make(0.35, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.4 + sin(TAU * (1800.0 - 900.0 * t) * t) * exp(-t * 12.0) * 0.4 \
			+ sin(TAU * 2637.0 * t) * exp(-t * 8.0) * 0.15))
	_put("double", _make(0.32, func(t: float) -> float:
		var s := sin(TAU * (480.0 + 2400.0 * t) * t) * _env(t, 0.004, 26.0) * 0.6
		if t > 0.11:
			var u := t - 0.11
			s += sin(TAU * (640.0 + 3000.0 * u) * u) * _env(u, 0.004, 26.0) * 0.5
		return s))
	_put("combo", _bells([[0.0, 1319.0]], 14.0, 0.25, 0.3))
	_put("upgrade", _make(0.45, func(t: float) -> float:
		var s := randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.3
		if t > 0.04:
			var u := t - 0.04
			s += (sin(TAU * 2349.0 * u) + 0.5 * sin(TAU * 3136.0 * u)) * exp(-u * 7.0) * 0.22
		return s))
	_put("unlock", _make(1.1, func(t: float) -> float:
		var f := 110.0 + 330.0 * minf(t / 0.7, 1.0)
		var s := (sin(TAU * f * t) * 0.5 + signf(sin(TAU * f * 0.5 * t)) * 0.12) * _env(t, 0.05, 2.5) * 0.5
		if t > 0.7:
			var u := t - 0.7
			s += sin(TAU * 880.0 * u) * exp(-u * 6.0) * 0.3 + sin(TAU * 1319.0 * u) * exp(-u * 6.0) * 0.2
		return s))
	_put("fusion", _make(1.1, func(t: float) -> float:
		var f := 300.0 + 1200.0 * t * t
		var s := sin(TAU * f * t) * _env(t, 0.3, 1.6) * 0.25 + sin(TAU * f * 1.5 * t) * _env(t, 0.3, 1.6) * 0.12
		if t > 0.75:
			var u := t - 0.75
			s += sin(TAU * 1568.0 * u) * exp(-u * 7.0) * 0.35
		return s))
	_put("ui_click", _make(0.05, func(t: float) -> float:
		return sin(TAU * 1500.0 * t) * exp(-t * 140.0) * 0.4 + randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.2))
	_put("ui_hover", _make(0.04, func(t: float) -> float:
		return sin(TAU * 2400.0 * t) * exp(-t * 160.0) * 0.25))
	_put("ui_open", _make(0.22, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * _env(t, 0.04, 14.0) * 0.25 * (0.5 + 0.5 * sin(TAU * 30.0 * t))))
	_put("ui_close", _make(0.18, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * _env(t, 0.01, 20.0) * 0.22))
	_put("golden", _bells([[0.0, 523.0], [0.15, 659.0], [0.3, 784.0], [0.45, 1047.0], [0.75, 784.0],
		[0.9, 1047.0], [1.05, 1319.0], [1.35, 1568.0], [1.35, 1047.0], [1.35, 784.0], [1.35, 523.0]], 1.2, 4.0, 0.2))


## Hüllkurve: kurzer Anstieg, dann exponentielles Abklingen (verhindert Knackser).
static func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) * decay)


## Glocken-Töne mit abklingenden Obertönen. notes = [[start, freq], …]
func _bells(notes: Array, decay: float, tail: float, gain: float = 0.26) -> AudioStreamWAV:
	var end := 0.0
	for n in notes:
		end = maxf(end, n[0])
	return _make(end + tail, func(t: float) -> float:
		var s := 0.0
		for n in notes:
			var st: float = n[0]
			if t >= st:
				var u := t - st
				var f: float = n[1]
				s += (sin(TAU * f * u) + 0.35 * sin(TAU * f * 2.0 * u) * exp(-u * decay * 1.5) \
					+ 0.15 * sin(TAU * f * 3.01 * u) * exp(-u * decay * 3.0)) * _env(u, 0.003, decay) * gain
		return s)


## Kurze Fanfare für Legendäre: Bläser-artiger Aufstieg plus Glitzer.
func _fanfare() -> AudioStreamWAV:
	var notes := [[0.0, 523.0, 0.12], [0.12, 659.0, 0.12], [0.24, 784.0, 0.12], [0.36, 1047.0, 0.9]]
	return _make(1.7, func(t: float) -> float:
		var s := 0.0
		for n in notes:
			var st: float = n[0]
			if t >= st:
				var u := t - st
				var f: float = n[1]
				var ln: float = n[2]
				var v := 1.0 + 0.006 * sin(TAU * 5.5 * u)
				s += (sin(TAU * f * v * u) + 0.5 * sin(TAU * f * 2.0 * v * u) + 0.25 * sin(TAU * f * 3.0 * v * u)) \
					* _env(u, 0.02, 1.5 if ln > 0.5 else 9.0) * 0.16
		if t > 0.36:
			var u2 := t - 0.36
			s += sin(TAU * (2637.0 + 400.0 * sin(TAU * 7.0 * u2)) * u2) * exp(-u2 * 3.0) * 0.06
		return s)


func _make(duration: float, fn: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var fade := int(0.01 * RATE)
	for i in n:
		var s := clampf(fn.call(float(i) / RATE), -1.0, 1.0)
		if i > n - fade:
			s *= float(n - i) / fade
		data.encode_s16(i * 2, int(s * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
