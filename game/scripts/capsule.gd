extends Node2D
## Eine Kapsel in der Schale. Klick öffnet sie (siehe main.gd).

enum State { FALLING, RESTING, OPENING }

const RADIUS := 24.0

var content: Dictionary = {}   # Ergebnis von Game.roll_capsule()
var machine_id := "standard"
var top_color := Color("#ff6b6b")
var gold := false
var world_id := "stadt"
var frozen_hits := 0     # gefrorene Kapsel: so oft muss man noch klicken
var _crack := 0.0
var state := State.FALLING
var split := 0.0
var _t := 0.0
var _hover := false
var _reveal_top := ""   # beim Öffnen: Fluch- oder Segen-Oberteil


func _process(delta: float) -> void:
	_t += delta
	_crack = maxf(_crack - delta * 4.0, 0.0)
	if state == State.RESTING:
		_hover = get_global_mouse_position().distance_to(global_position) < RADIUS + 6
		rotation = sin(_t * 3.0 + position.x) * 0.06
	queue_redraw()


## Ein Klick aufs Eis.
func crack() -> void:
	frozen_hits = maxi(frozen_hits - 1, 0)
	_crack = 1.0
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + 4, 0.04)
	tw.tween_property(self, "position:x", position.x - 4, 0.06)
	tw.tween_property(self, "position:x", position.x, 0.04)


## Spielt die Öffnen-Animation ab und wartet, bis sie fertig ist.
func open() -> void:
	state = State.OPENING
	if content.get("type", "") == "curse":
		_reveal_top = "capsules/curse_top.png"
	elif content.get("blessed", false):
		_reveal_top = "capsules/bless_top.png"
	rotation = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(1.35, 0.8), 0.06)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.08)
	tw.tween_property(self, "split", 34.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.12)
	await tw.finished


func _draw() -> void:
	var r := RADIUS * (1.08 if _hover and state == State.RESTING else 1.0)
	if _draw_v2(r):
		_draw_ice(r)
		return
	var bottom := Color(0.96, 0.96, 0.96)
	var top := Color("#ffc23a") if gold else top_color
	var t_top := Art.tex("capsules/gold_top.png") if gold else Art.tex("capsules/top.png")
	var tint := Color.WHITE if gold else top_color
	if _reveal_top != "" and Art.tex(_reveal_top):
		t_top = Art.tex(_reveal_top)
		tint = Color.WHITE
	var t_bottom := Art.tex("capsules/bottom.png")
	if t_top and t_bottom:
		# Pixel-Art: 24x12 je Hälfte, auf Kapselgröße skaliert
		var w := r * 2.0
		draw_texture_rect(t_bottom, Rect2(-r, split, w, r), false)
		draw_texture_rect(t_top, Rect2(-r, -r - split, w, r), false, tint)
		_draw_shine(r)
		_draw_ice(r)
		if _hover:
			draw_arc(Vector2.ZERO, r + 5, 0, TAU, 32, Color(1, 1, 1, 0.6), 2)
		return
	_half(Vector2(0, split), r, 0.0, bottom)
	_half(Vector2(0, -split), r, PI, top)
	draw_line(Vector2(-r, split), Vector2(r, split), bottom.darkened(0.25), 2)
	draw_line(Vector2(-r, -split), Vector2(r, -split), top.darkened(0.25), 2)
	draw_circle(Vector2(-8, -10 - split), 5, Color(1, 1, 1, 0.75))
	if gold:
		var glint := 0.5 + 0.5 * sin(_t * 6.0)
		draw_circle(Vector2(10, -14 - split), 2.5 + glint * 2.0, Color(1, 1, 1, glint))
	if _hover:
		draw_arc(Vector2.ZERO, r + 5, 0, TAU, 32, Color(1, 1, 1, 0.6), 2)


func _half(center: Vector2, r: float, start: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := start + PI * i / 16.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, color.darkened(0.35), 2)


## Neue Kapsel-Grafik (24×24 je Welt), falls vorhanden.
func _draw_v2(r: float) -> bool:
	var special := ""
	if _reveal_top != "":
		special = "curse_v2" if "curse" in _reveal_top else "bless_v2"
	elif gold:
		special = "gold_v2"
	var t := Art.tex("capsules/capsule_%s.png" % world_id)
	if t == null:
		return false
	var w := r * 2.0
	var tint := Color.WHITE if special != "" else top_color.lightened(0.15)
	var sp := Art.tex("capsules/%s.png" % special) if special != "" else null
	# Beim Öffnen auseinander: obere und untere Hälfte getrennt aus derselben Grafik
	var tex_top := sp if sp else t
	draw_texture_rect_region(t, Rect2(-r, split, w, r), Rect2(0, 12, 24, 12))
	draw_texture_rect_region(tex_top, Rect2(-r, -r - split, w, r), Rect2(0, 0, 24, 12), tint if sp == null else Color.WHITE)
	if _hover and state == State.RESTING:
		draw_arc(Vector2.ZERO, r + 5, 0, TAU, 32, Color(1, 1, 1, 0.6), 2)
	return true


## Glanzlicht und dunkler Rand, damit die Kapsel plastischer wirkt.
func _draw_shine(r: float) -> void:
	if state == State.OPENING:
		return
	var glint := 0.5 + 0.5 * sin(_t * 2.0 + position.x * 0.05)
	draw_rect(Rect2(Vector2(-r * 0.55, -r * 0.7), Vector2(4, 4)), Color(1, 1, 1, 0.5 + 0.4 * glint))
	draw_rect(Rect2(Vector2(-r * 0.55 + 6, -r * 0.7 - 2), Vector2(2, 2)), Color(1, 1, 1, 0.5 * glint))
	if gold:
		var g := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(Rect2(Vector2(r * 0.4, -r * 0.6) - Vector2(2, 2) * g, Vector2(4, 4) * (0.5 + g)), Color(1, 1, 0.8, g))


## Eisschicht bei gefrorenen Kapseln, mit Rissen je Klick.
func _draw_ice(r: float) -> void:
	if frozen_hits <= 0 or state == State.OPENING:
		return
	var sheet := Art.tex("fx/freeze_crack_sheet.png")
	var stage := clampi(2 - frozen_hits, 0, 2)
	if sheet:
		draw_texture_rect_region(sheet, Rect2(-r - 2, -r - 2, r * 2 + 4, r * 2 + 4), Rect2(stage * 24, 0, 24, 24))
		return
	draw_circle(Vector2.ZERO, r + 3, Color(0.75, 0.93, 1.0, 0.55))
	draw_arc(Vector2.ZERO, r + 3, 0, TAU, 32, Color(0.9, 1, 1, 0.9), 2)
	draw_rect(Rect2(Vector2(-r * 0.6, -r * 0.6), Vector2(6, 3)), Color(1, 1, 1, 0.8))
	var cracks := [[Vector2(-4, -r), Vector2(2, -6), Vector2(-6, 6)], [Vector2(r - 2, 2), Vector2(6, 0), Vector2(10, 12)]]
	for i in mini(stage + (1 if _crack > 0.0 else 0), cracks.size()):
		draw_polyline(PackedVector2Array(cracks[i]), Color(0.3, 0.5, 0.7, 0.9), 2)
