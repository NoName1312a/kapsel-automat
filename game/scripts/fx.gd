extends RefCounted
## Einmal-Effekte: Sprite-Sheet-Animationen aus res://art/fx/ und gezeichnete Ersatz-Effekte,
## solange die Grafik fehlt.

const GOLD := Color("#ffe14d")


## Spielt ein waagerechtes Sprite-Sheet einmal ab. Gibt false zurück, wenn die Grafik fehlt.
static func play_sheet(parent: Node, path: String, frames: int, pos: Vector2, scale: float, fps: float, z: int = 5) -> bool:
	var t := Art.tex(path)
	if t == null:
		return false
	var sp := Sprite2D.new()
	sp.texture = t
	sp.hframes = frames
	sp.position = pos
	sp.scale = Vector2(scale, scale)
	sp.z_index = z
	parent.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "frame", frames - 1, frames / fps).from(0)
	tw.tween_callback(sp.queue_free)
	return true


## Legendär-Moment hinter der Figur: Lichtsäule, Schockwelle, Funkenregen.
static func legendary(parent: Node, pos: Vector2) -> void:
	var has_sheet := play_sheet(parent, "fx/legendary_sheet.png", 12, pos, 3.0, 12.0, -1)
	play_sheet(parent, "fx/legendary_ring_sheet.png", 8, pos, 4.0, 14.0, -1)
	if not has_sheet:
		var n := LegendaryFallback.new()
		n.position = pos
		n.z_index = -1
		parent.add_child(n)


## Aufwertung über dem Automaten-Gehäuse.
static func machine_upgrade(parent: Node, machine: Node2D) -> void:
	# Gehäuse ist 128×160 Pixel (×2), Ursprung oben Mitte
	if not play_sheet(parent, "fx/upgrade_sheet.png", 10, machine.position + Vector2(0, 160), 2.0, 12.0, 4):
		var n := UpgradeFallback.new()
		n.position = machine.position + Vector2(0, 160)
		n.z_index = 4
		parent.add_child(n)
	var tw := machine.create_tween()
	tw.tween_property(machine, "scale", Vector2(1.06, 0.95), 0.08)
	tw.tween_property(machine, "scale", Vector2(0.97, 1.04), 0.1)
	tw.tween_property(machine, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if "flash" in machine:
		machine.flash = 1.0


class LegendaryFallback extends Node2D:
	var t := 0.0
	var sparks: Array = []

	func _ready() -> void:
		for i in 28:
			sparks.append({"a": randf() * TAU, "v": randf_range(120, 320), "s": randf_range(3, 7)})

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > 1.4:
			queue_free()

	func _draw() -> void:
		var k := t / 1.4
		# Lichtsäule
		var pillar_a := (1.0 - k) * 0.55
		draw_rect(Rect2(-60 * (1.0 - k * 0.5), -420, 120 * (1.0 - k * 0.5), 840), Color(1, 0.9, 0.4, pillar_a * 0.5))
		draw_rect(Rect2(-24, -420, 48, 840), Color(1, 1, 0.85, pillar_a))
		# Schockwellen
		for i in 2:
			var kk := clampf(k * 1.6 - i * 0.25, 0.0, 1.0)
			if kk > 0.0 and kk < 1.0:
				draw_arc(Vector2.ZERO, 40 + kk * 260, 0, TAU, 64, Color(1, 0.85, 0.3, 1.0 - kk), 10 * (1.0 - kk) + 2)
		# Funken in Pixel-Quadraten, damit es zum Stil passt
		for sp in sparks:
			var p: Vector2 = Vector2.from_angle(sp["a"]) * sp["v"] * minf(t * 1.5, 1.2) + Vector2(0, 160 * t * t)
			var s: float = sp["s"] * (1.0 - k)
			draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), Color(1, 0.95, 0.5, 1.0 - k))
		# Kurzer Blitz
		if t < 0.12:
			draw_circle(Vector2.ZERO, 300, Color(1, 1, 0.9, 0.35 * (1.0 - t / 0.12)))


class UpgradeFallback extends Node2D:
	var t := 0.0
	var bits: Array = []

	func _ready() -> void:
		for i in 22:
			bits.append({"x": randf_range(-120, 120), "y": randf_range(-130, 140), "d": randf() * 0.4, "s": randf_range(4, 9)})

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > 1.2:
			queue_free()

	func _draw() -> void:
		var k := t / 1.2
		# Aufsteigende Funken und Sterne
		for b in bits:
			var tt: float = clampf((t - b["d"]) / 0.8, 0.0, 1.0)
			if tt <= 0.0 or tt >= 1.0:
				continue
			var p := Vector2(b["x"], b["y"] - tt * 90.0)
			var s: float = b["s"] * (1.0 - tt)
			draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), Color(1, 0.9, 0.35, 1.0 - tt))
			draw_rect(Rect2(p - Vector2(s * 2.0, 1), Vector2(s * 4.0, 2)), Color(1, 1, 0.8, (1.0 - tt) * 0.6))
		# Lichtband, das über das Gehäuse fährt
		var y := lerpf(160.0, -170.0, clampf(k * 1.4, 0.0, 1.0))
		draw_rect(Rect2(-128, y - 10, 256, 20), Color(1, 1, 0.8, 0.35 * (1.0 - k)))
