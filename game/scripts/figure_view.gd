extends Node2D
## Große Anzeige der zuletzt gezogenen Figur. Platzhalter-Grafik: Farbklecks mit Gesicht.

var figure: Dictionary = {}
var is_new := false
var scale_base := 1.0
var _t := 0.0


func show_figure(fig: Dictionary, new_one: bool) -> void:
	figure = fig
	is_new = new_one
	visible = true
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * scale_base * 1.2, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE * scale_base, 0.1)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	if figure.is_empty():
		return
	var rc := Color(figure["rarity_color"])
	var sc := Color(figure["set_color"])
	var rarity: String = figure["rarity"]

	# Strahlen hinter der Figur: Pixel-Art-Strahlen (ab Selten), sonst Polygone (ab Episch)
	var rays_t := Art.tex("ui/reveal_rays.png")
	if rays_t and rarity != "common":
		var big := rarity == "legendary"
		var alpha: float = {"rare": 0.35, "epic": 0.6, "legendary": 0.85}[rarity]
		var sz := 384.0 if big else 320.0
		draw_set_transform(Vector2.ZERO, _t * (0.8 if big else 0.4), Vector2.ONE)
		draw_texture_rect(rays_t, Rect2(Vector2(-sz, -sz) / 2.0, Vector2(sz, sz)), false, Color(rc, alpha))
		draw_set_transform(Vector2.ZERO)
	elif rarity == "epic" or rarity == "legendary":
		var rays := 12 if rarity == "legendary" else 8
		var ray_len := 150.0 if rarity == "legendary" else 115.0
		for i in rays:
			var a := _t * 0.6 + TAU * i / rays
			var pts := PackedVector2Array([
				Vector2.ZERO,
				Vector2.from_angle(a - 0.12) * ray_len,
				Vector2.from_angle(a + 0.12) * ray_len,
			])
			draw_colored_polygon(pts, Color(rc, 0.25))

	var bob := sin(_t * 2.5) * 4.0
	var c := Vector2(0, bob)
	var tex := Art.figure(figure["id"])
	if tex:
		var glow := Art.tex("ui/glow.png")
		if glow:
			draw_texture_rect(glow, Rect2(c - Vector2(110, 110), Vector2(220, 220)), false, Color(rc, 0.55))
		draw_texture_rect(tex, Rect2(c - Vector2(96, 96), Vector2(192, 192)), false)
	else:
		_draw_placeholder(c, rc, sc)
	_draw_labels(rc)


func _draw_placeholder(c: Vector2, rc: Color, sc: Color) -> void:
	draw_circle(c, 76, rc)
	draw_circle(c, 66, sc)
	draw_circle(c + Vector2(-22, -12), 11, Color.WHITE)
	draw_circle(c + Vector2(22, -12), 11, Color.WHITE)
	draw_circle(c + Vector2(-20, -10), 5, Color.BLACK)
	draw_circle(c + Vector2(24, -10), 5, Color.BLACK)
	draw_arc(c + Vector2(0, 10), 20, 0.25, PI - 0.25, 16, Color(0.15, 0.1, 0.15), 4)
	draw_circle(c + Vector2(-40, 12), 8, Color(1, 0.5, 0.6, 0.45))
	draw_circle(c + Vector2(40, 12), 8, Color(1, 0.5, 0.6, 0.45))


func _draw_labels(rc: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-160, 120), figure["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 28, Color.WHITE)
	draw_string(font, Vector2(-160, 148), "%s · %s" % [figure["rarity_name"], figure["set_name"]], HORIZONTAL_ALIGNMENT_CENTER, 320, 18, rc)
	var stamp := Art.tex("ui/new_stamp.png")
	if is_new and stamp:
		var pulse := 1.0 + 0.06 * sin(_t * 8.0)
		draw_set_transform(Vector2(70, -78), -0.15, Vector2(pulse, pulse))
		draw_texture_rect(stamp, Rect2(Vector2(-44, -22), Vector2(88, 44)), false)
		draw_set_transform(Vector2.ZERO)
	elif is_new:
		var pulse := 1.0 + 0.08 * sin(_t * 8.0)
		draw_set_transform(Vector2(0, -100), -0.12, Vector2(pulse, pulse))
		draw_string(font, Vector2(-80, 0), "NEU!", HORIZONTAL_ALIGNMENT_CENTER, 160, 30, Color("#ffe14d"))
		draw_set_transform(Vector2.ZERO)
