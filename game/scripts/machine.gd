extends Node2D
## Der Automat: Glaskuppel mit Kapseln, Gehäuse, Kurbel, Ausgabeschacht und Schale.
## Mit Pixel-Art (art/machines/…) wird alles ×2 aus den Sprites gezeichnet,
## ohne Pixel-Art fällt er auf die per Code gezeichnete Platzhalter-Version zurück.

const CAPSULE_COLORS := ["#ff6b6b", "#ffd93d", "#6bcB77", "#4d96ff", "#c77dff", "#ff9f45"]

# Pixel-Art-Layout (Sprite-Pixel ×2). Ursprung = Mitte oben am Gehäuse.
const S := 2.0
const BODY_POS := Vector2(-128, 0)          # linke obere Ecke des Gehäuses (128×160)
const DOME_POS := Vector2(-128, -236)       # Kuppel (128×128); Unterkante überlappt den Kragen
const ART_DOME_CENTER := Vector2(0, -100)   # (64, 68) in der Kuppel
const ART_DOME_RADIUS := 108.0
const ART_CRANK := Vector2(0, 160)          # (64, 80) im Gehäuse
const ART_CHUTE := Vector2(0, 242)          # Mitte der Schacht-Öffnung (64, 121)
const ART_LCD := Rect2(40, 46, 46, 20)      # Preis-Display (84–107, 23–33)
const ART_TRAY_TOP := 300.0
const ART_TRAY_REST := 334.0                # Kapselmitte auf der Schale

# Platzhalter-Layout
const DOME_CENTER := Vector2(0, -130)
const DOME_RADIUS := 124.0
const CRANK_CENTER := Vector2(0, 90)
const CHUTE := Vector2(0, 195)

var machine_id := "standard"
var crank_angle := 0.0
var jiggle := 0.0        # 0..1, Kapseln in der Kuppel wackeln beim Kurbeln
var blocked := 0.0       # rotes Aufblinken, wenn die Kurbel blockiert
var price := 8.0
var hamster := false
var body_color := Color("#e8484f")
var title := ""
var tray_slots := 5
var level := 0           # Automaten-Stufe (Sterne)
var flash := 0.0         # kurzes Aufleuchten nach einer Aufwertung
var _t := 0.0
var _balls: Array = []
var _art := false


func _ready() -> void:
	_art = Art.has_art()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r := ART_DOME_RADIUS if _art else DOME_RADIUS
	var ball_r := 18.0 if _art else 19.0
	while _balls.size() < (34 if _art else 22):
		var p := Vector2(rng.randf_range(-r, r), rng.randf_range(-r * 0.4, r))
		if p.length() < r - ball_r - 4:
			_balls.append({"pos": p, "col": Color(CAPSULE_COLORS[rng.randi() % CAPSULE_COLORS.size()]), "ph": rng.randf() * TAU})
	# Untere Kapseln zuerst zeichnen, damit die oberen darüber liegen
	_balls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y > b["pos"].y)


func _process(delta: float) -> void:
	_t += delta
	jiggle = move_toward(jiggle, 0.0, delta * 3.0)
	blocked = move_toward(blocked, 0.0, delta * 3.0)
	flash = move_toward(flash, 0.0, delta * 1.5)
	queue_redraw()


func crank_global() -> Vector2:
	return to_global(ART_CRANK if _art else CRANK_CENTER)


func chute_global() -> Vector2:
	return to_global(ART_CHUTE if _art else CHUTE)


func tray_rest_y() -> float:
	return to_global(Vector2(0, ART_TRAY_REST if _art else 268.0)).y


static func tray_width(slots: int) -> float:
	return maxf(288.0, 40.0 + slots * 50.0)


func _draw() -> void:
	if _art:
		_draw_art()
	else:
		_draw_placeholder()


# --- Pixel-Art ------------------------------------------------------------

func _skin() -> String:
	# Nach dem Bau des Goldenen Automaten wird der Standard-Automat golden
	if machine_id == "standard" and Game.stats.get("golden_built", 0.0) >= 1.0:
		return "golden"
	return machine_id


func _draw_art() -> void:
	var body_t := Art.machine_part(_skin(), "body")
	var dome_t := Art.machine_part(_skin(), "dome")
	# Automat ohne eigene Grafik: Standard-Gehäuse in seiner Farbe
	var tint := Color.WHITE
	if body_t == null:
		body_t = Art.machine_part("standard", "body")
		tint = Color.WHITE.lerp(body_color.lightened(0.25), 0.6)
	if dome_t == null:
		dome_t = Art.machine_part("standard", "dome")
	var lit := Color.WHITE.lerp(Color(1.6, 0.8, 0.8), blocked) * tint
	lit = lit.lerp(Color(1.8, 1.7, 1.2), flash * 0.6)

	# Kapseln in der Kuppel, dann die Glaskuppel darüber (Glanzlichter liegen in der Grafik)
	var top_t := Art.tex("capsules/top.png")
	var bot_t := Art.tex("capsules/bottom.png")
	var dc := ART_DOME_CENTER
	for b in _balls:
		var ph: float = b["ph"]
		var off := Vector2(sin(_t * 22.0 + ph), cos(_t * 19.0 + ph)) * 4.0 * jiggle
		var p: Vector2 = dc + b["pos"] + off
		if top_t and bot_t:
			draw_texture_rect(bot_t, Rect2(p + Vector2(-18, 0), Vector2(36, 18)), false)
			draw_texture_rect(top_t, Rect2(p + Vector2(-18, -18), Vector2(36, 18)), false, b["col"])
		else:
			draw_circle(p, 18, b["col"])
	draw_texture_rect(dome_t, Rect2(DOME_POS, Vector2(256, 256)), false)

	draw_texture_rect(body_t, Rect2(BODY_POS, Vector2(256, 320)), false, lit)
	_draw_stars(Vector2(0, 286))
	# Schale vor dem Sockel, wächst mit dem Upgrade
	_draw_tray()

	# Preis im LCD
	var font := ThemeDB.fallback_font
	draw_string(font, ART_LCD.position + Vector2(0, 16), Fmt.num(price), HORIZONTAL_ALIGNMENT_CENTER, ART_LCD.size.x, 14, Color("#9fffcb"))

	# Kurbelgriff dreht sich um den Drehpunkt
	var crank_t := Art.tex("machines/crank_%s.png" % _skin())
	if crank_t == null:
		crank_t = Art.tex("machines/crank.png")
	draw_set_transform(ART_CRANK, crank_angle, Vector2.ONE)
	draw_texture_rect(crank_t, Rect2(Vector2(-48, -48), Vector2(96, 96)), false)
	draw_set_transform(Vector2.ZERO)

	if hamster:
		var frame := int(_t * 8.0) % 2 if jiggle > 0.05 else 0
		var ht := Art.tex("props/hamster_%d.png" % frame)
		var hp := Vector2(-196, 252 - (absf(sin(_t * 10.0)) * 4.0 if jiggle > 0.05 else 0.0))
		if ht:
			draw_texture_rect(ht, Rect2(hp, Vector2(64, 64)), false)


## Stufensterne am Sockel (bis 10).
func _draw_stars(center: Vector2) -> void:
	if level <= 0:
		return
	var full := Art.tex("fx/level_star.png")
	var empty := Art.tex("fx/level_star_empty.png")
	var n := 10
	var step := 20.0
	var x0 := center.x - (n - 1) * step / 2.0
	for i in n:
		var p := Vector2(x0 + i * step, center.y)
		var on := i < level
		if full:
			var t := full if on else empty
			if t:
				draw_texture_rect(t, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false)
		elif on or i < 10:
			_star(p, 7.0, Color("#ffe14d") if on else Color(0, 0, 0, 0.35))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## Schale als 3-teiliges Sprite: linker Rand, gestreckte Mitte, rechter Rand.
func _draw_tray() -> void:
	var t := Art.tex("props/tray.png")
	var w := tray_width(tray_slots)
	var x0 := -w / 2.0
	if t == null:
		draw_rect(Rect2(x0, ART_TRAY_TOP, w, 64), Color("#3b2f4a"))
		return
	var edge := 16.0
	var h := 64.0
	draw_texture_rect_region(t, Rect2(x0, ART_TRAY_TOP, edge * S, h), Rect2(0, 0, edge, 32))
	draw_texture_rect_region(t, Rect2(x0 + edge * S, ART_TRAY_TOP, w - edge * S * 2, h), Rect2(edge, 0, 144 - edge * 2, 32))
	draw_texture_rect_region(t, Rect2(x0 + w - edge * S, ART_TRAY_TOP, edge * S, h), Rect2(144 - edge, 0, edge, 32))


# --- Platzhalter ----------------------------------------------------------

func _draw_placeholder() -> void:
	var dark := Color("#2a2030")
	var body := body_color.lerp(Color.WHITE, blocked * 0.5)

	draw_rect(Rect2(-40, -268, 80, 16), Color("#c43a41"))
	var dc := DOME_CENTER
	draw_circle(dc, DOME_RADIUS, Color(0.75, 0.9, 1.0, 0.18))
	for b in _balls:
		var ph: float = b["ph"]
		var off := Vector2(sin(_t * 22.0 + ph), cos(_t * 19.0 + ph)) * 4.0 * jiggle
		var c: Color = b["col"]
		var p: Vector2 = dc + b["pos"] + off
		draw_circle(p, 19, Color(0.95, 0.95, 0.95))
		_draw_half(p, 19, PI, c)
		draw_circle(p + Vector2(-6, -8), 4, Color(1, 1, 1, 0.7))
	draw_arc(dc, DOME_RADIUS, 0, TAU, 72, Color(1, 1, 1, 0.55), 4)
	draw_arc(dc, DOME_RADIUS - 16, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.5), 6)

	draw_rect(Rect2(-120, -10, 240, 240), body)
	draw_rect(Rect2(-120, -10, 240, 240), body.darkened(0.3), false, 4)
	draw_rect(Rect2(-120, -10, 240, 18), body.darkened(0.15))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-120, 5), title, HORIZONTAL_ALIGNMENT_CENTER, 240, 14, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(66, 24, 34, 10), dark)
	draw_string(font, Vector2(40, 62), Fmt.num(price), HORIZONTAL_ALIGNMENT_CENTER, 86, 18, Color.WHITE)

	var cc := CRANK_CENTER
	draw_circle(cc, 52, Color("#c9ccd6"))
	draw_arc(cc, 52, 0, TAU, 48, Color("#8a8f9e"), 4)
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(cc + Vector2.from_angle(a) * 42, cc + Vector2.from_angle(a) * 50, Color("#8a8f9e"), 2)
	var hand := cc + Vector2.from_angle(crank_angle - PI / 2) * 42
	draw_line(cc, hand, Color("#5a5f6e"), 14)
	draw_circle(hand, 15, Color("#ffd23f"))
	draw_arc(hand, 15, 0, TAU, 24, Color("#b8901a"), 3)
	draw_circle(cc, 12, dark)

	draw_rect(Rect2(-44, 168, 88, 52), dark)
	draw_rect(Rect2(-44, 168, 88, 52), body.darkened(0.4), false, 3)

	var tw := tray_width(tray_slots)
	draw_rect(Rect2(-tw / 2.0, 236, tw, 62), Color("#3b2f4a"))
	draw_rect(Rect2(-tw / 2.0 - 10, 290, tw + 20, 12), Color("#4e3f63"))

	if hamster:
		_draw_hamster(Vector2(-88, 150))


func _draw_half(center: Vector2, r: float, start: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := start + PI * i / 16.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _draw_hamster(p: Vector2) -> void:
	var bob := absf(sin(_t * 10.0)) * 4.0 if jiggle > 0.05 else 0.0
	p.y -= bob
	var fur := Color("#d9a066")
	draw_circle(p + Vector2(-12, -18), 8, fur.darkened(0.2))
	draw_circle(p + Vector2(12, -18), 8, fur.darkened(0.2))
	draw_circle(p, 22, fur)
	draw_circle(p + Vector2(0, 6), 13, Color("#f5dcc0"))
	draw_circle(p + Vector2(-8, -4), 3, Color.BLACK)
	draw_circle(p + Vector2(8, -4), 3, Color.BLACK)
	draw_circle(p + Vector2(0, 3), 3, Color("#e07a8a"))
