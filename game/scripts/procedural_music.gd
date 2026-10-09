extends RefCounted
## Per Code erzeugte Musik-Loops (Platzhalter, bis echte Musik in res://audio/music/ liegt).
## Läuft im Hintergrund-Thread: nur Rechnen, keine Szenen-Zugriffe.

const MIDI_A4 := 69


static func hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - MIDI_A4) / 12.0)


static func render(music_name: String, rate: int) -> AudioStreamWAV:
	var cfg: Dictionary
	if music_name == "menu":
		# Fmaj7 – Em7 – Dm7 – Cmaj7, ruhig, Spieluhr in Vierteln
		cfg = {"bpm": 74.0, "beats_per_chord": 8, "passes": 1, "arp_step": 1.0, "bass": false, "hat": false,
			"chords": [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]}
	else:
		# Cmaj7 – Am7 – Dm7 – G7, entspannter Groove mit Achteln
		cfg = {"bpm": 88.0, "beats_per_chord": 8, "passes": 2, "arp_step": 0.5, "bass": true, "hat": true,
			"chords": [[48, 52, 55, 59], [45, 48, 52, 55], [50, 53, 57, 60], [43, 47, 50, 53]]}
	var beat: float = 60.0 / cfg["bpm"]
	var chords: Array = cfg["chords"]
	var bpc: int = cfg["beats_per_chord"]
	var total_beats: int = chords.size() * bpc * int(cfg["passes"])
	var n := int(total_beats * beat * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 if music_name == "menu" else 1717

	for pass_i in int(cfg["passes"]):
		for ci in chords.size():
			var chord: Array = chords[ci]
			var t0 := (pass_i * chords.size() + ci) * bpc * beat
			var dur := bpc * beat
			# Flächenklang
			for note in chord:
				_add_pad(buf, rate, t0, dur + 0.6, hz(note), 0.045)
			# Bass
			if cfg["bass"]:
				for b in [0, 3, 4, 7]:
					if b < bpc:
						_add_pluck(buf, rate, t0 + b * beat, beat * 1.4, hz(chord[0] - 12), 0.16, 5.0, true)
			else:
				_add_pad(buf, rate, t0, dur + 0.6, hz(chord[0] - 12), 0.06)
			# Spieluhr-Arpeggio über die Akkordtöne, eine Oktave höher
			var step: float = cfg["arp_step"]
			var steps := int(bpc / step)
			var pattern := [0, 1, 2, 3, 2, 1, 3, 2] if pass_i == 0 else [0, 2, 1, 3, 1, 2, 3, 0]
			for s in steps:
				if rng.randf() < (0.18 if step < 1.0 else 0.25):
					continue   # Pausen machen es lebendiger
				var idx: int = pattern[s % pattern.size()]
				var note: int = chord[idx] + 12 + (12 if (s % 8 == 6 and rng.randf() < 0.5) else 0)
				_add_bell(buf, rate, t0 + s * step * beat, 1.6, hz(note), 0.085 if step < 1.0 else 0.11)
			# Leise Hi-Hats auf den Offbeats
			if cfg["hat"]:
				for b in bpc:
					_add_hat(buf, rate, t0 + (b + 0.5) * beat, 0.025, rng)

	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var gain := 0.7 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


## Weicher Flächenklang. Was über das Ende hinausragt, landet am Anfang (nahtloser Loop).
static func _add_pad(buf: PackedFloat32Array, rate: int, t0: float, dur: float, f: float, amp: float) -> void:
	var n := buf.size()
	var start := int(t0 * rate)
	var len_s := int(dur * rate)
	var att := 0.5 * rate
	var rel := 0.6 * rate
	var w := TAU * f / rate
	var w2 := TAU * f * 1.003 / rate
	for i in len_s:
		var e := 1.0
		if i < att:
			e = i / att
		elif i > len_s - rel:
			e = (len_s - i) / rel
		var j := (start + i) % n
		buf[j] += (sin(w * i) + 0.6 * sin(w2 * i) + 0.15 * sin(2.0 * w * i)) * e * amp


static func _add_bell(buf: PackedFloat32Array, rate: int, t0: float, dur: float, f: float, amp: float) -> void:
	var n := buf.size()
	var start := int(t0 * rate)
	var len_s := int(dur * rate)
	var w := TAU * f / rate
	var k1 := exp(-4.0 / rate)
	var k2 := exp(-9.0 / rate)
	var e1 := 1.0
	var e2 := 1.0
	for i in len_s:
		var a := minf(i / 60.0, 1.0)
		var j := (start + i) % n
		buf[j] += (sin(w * i) * e1 + 0.4 * sin(w * 2.0 * i) * e2 + 0.12 * sin(w * 4.07 * i) * e2) * a * amp
		e1 *= k1
		e2 *= k2


static func _add_pluck(buf: PackedFloat32Array, rate: int, t0: float, dur: float, f: float, amp: float, decay: float, soft: bool) -> void:
	var n := buf.size()
	var start := int(t0 * rate)
	var len_s := int(dur * rate)
	var w := TAU * f / rate
	var k := exp(-decay / rate)
	var e := 1.0
	for i in len_s:
		var a := minf(i / 120.0, 1.0)
		var tail := minf(float(len_s - i) / 400.0, 1.0)
		var j := (start + i) % n
		var s := sin(w * i) + (0.15 if soft else 0.4) * sin(w * 3.0 * i)
		buf[j] += s * e * a * tail * amp
		e *= k


static func _add_hat(buf: PackedFloat32Array, rate: int, t0: float, amp: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var start := int(t0 * rate)
	var len_s := int(0.05 * rate)
	var prev := 0.0
	for i in len_s:
		var x := rng.randf_range(-1.0, 1.0)
		var hp := x - prev   # grober Hochpass, damit es zischt statt rauscht
		prev = x
		buf[(start + i) % n] += hp * exp(-i * 90.0 / rate) * amp
