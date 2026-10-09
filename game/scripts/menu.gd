extends Control
## Hauptmenü: Neues Spiel, Spiel laden, Einstellungen, Steam-Wunschliste, Discord/Reddit/X, Beenden.

const SettingsPanel := preload("res://scripts/settings_panel.gd")
const GAME_SCENE := "res://main.tscn"
const GOLD := Color("#ffe14d")
const CAPSULE_COLORS := ["#ff6b6b", "#ffd93d", "#6bcB77", "#4d96ff", "#c77dff", "#ff9f45"]

var settings_panel: SettingsPanel
var confirm: ConfirmationDialog
var dim: ColorRect
var hint: Label
var hint_timer := 0.0
var load_btn: Button
var logo: Control
var _t := 0.0
var _floaters: Array = []


func _ready() -> void:
	Game.stop()
	var th := Art.ui_theme()
	if th:
		theme = th
	_build_background()
	_build_logo()
	_build_buttons()
	_build_socials()

	var ver := _label("Version %s" % ProjectSettings.get_setting("application/config/version", "?"), 14, Color(1, 1, 1, 0.45))
	ver.position = Vector2(16, 694)
	add_child(ver)
	hint = _label("", 18, GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(290, 600)
	hint.size = Vector2(700, 30)
	add_child(hint)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(1280, 720)
	dim.visible = false
	add_child(dim)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.closed.connect(func() -> void: dim.visible = false)

	confirm = ConfirmationDialog.new()
	confirm.title = "Neues Spiel"
	confirm.dialog_text = "Es gibt schon einen Spielstand.\nNeues Spiel starten und ihn überschreiben?"
	confirm.ok_button_text = "Neues Spiel"
	confirm.cancel_button_text = "Abbrechen"
	confirm.confirmed.connect(_start_new)
	add_child(confirm)

	Sfx.play_music("menu")


func _process(delta: float) -> void:
	_t += delta
	if logo:
		logo.position.y = 36.0 + sin(_t * 1.6) * 6.0
	for f in _floaters:
		var n: Node2D = f["node"]
		n.position.y -= f["speed"] * delta
		n.rotation += f["spin"] * delta
		if n.position.y < -40:
			n.position = Vector2(randf_range(0, 1280), 760)
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_panel.visible:
			settings_panel.close()
			get_viewport().set_input_as_handled()


# --- Aufbau ---------------------------------------------------------------

func _label(text: String, size_px: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.15))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _build_background() -> void:
	var bg_t := Art.tex("bg/menu_background.png")
	var own_bg := bg_t != null
	if bg_t == null:
		bg_t = Art.tex("bg/background.png")
	if bg_t:
		var bg := TextureRect.new()
		bg.texture = bg_t
		bg.size = Vector2(1280, 720)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(bg)
	if not own_bg:
		# Spiel-Hintergrund abdunkeln, damit Logo und Knöpfe herausstechen
		var shade := ColorRect.new()
		shade.color = Color(0.08, 0.05, 0.14, 0.55)
		shade.size = Vector2(1280, 720)
		add_child(shade)
	# Aufsteigende Kapseln als Deko
	var top_t := Art.tex("capsules/top.png")
	var bot_t := Art.tex("capsules/bottom.png")
	for i in 14:
		var n := Node2D.new()
		n.position = Vector2(randf_range(0, 1280), randf_range(0, 760))
		var col := Color(CAPSULE_COLORS[i % CAPSULE_COLORS.size()])
		var sc := randf_range(1.6, 2.6)
		n.draw.connect(func() -> void:
			if top_t and bot_t:
				n.draw_texture_rect(bot_t, Rect2(Vector2(-9, 0) * sc, Vector2(18, 9) * sc), false, Color(1, 1, 1, 0.45))
				n.draw_texture_rect(top_t, Rect2(Vector2(-9, -9) * sc, Vector2(18, 9) * sc), false, Color(col, 0.45))
			else:
				n.draw_circle(Vector2.ZERO, 9 * sc, Color(col, 0.4)))
		add_child(n)
		_floaters.append({"node": n, "speed": randf_range(18, 45), "spin": randf_range(-0.6, 0.6)})


func _build_logo() -> void:
	var lt := Art.tex("ui/logo.png")
	if lt:
		var tr := TextureRect.new()
		tr.texture = lt
		var sz := lt.get_size() * 3.0
		if sz.x > 900:
			sz *= 900.0 / sz.x
		if sz.y > 220:
			sz *= 220.0 / sz.y
		tr.size = sz
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2((1280 - sz.x) / 2.0, 36)
		logo = tr
	else:
		var box := VBoxContainer.new()
		box.size = Vector2(1280, 170)
		var t := _label("KAPSEL-AUTOMAT", 72, GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 14)
		box.add_child(t)
		var sub := _label("Kurbeln. Öffnen. Sammeln.", 24, Color("#9fffcb"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
		logo = box
	add_child(logo)


func _menu_button(text: String, icon_path: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "BigButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 54)
	b.add_theme_font_size_override("font_size", 24)
	var ic := Art.tex(icon_path) if icon_path != "" else null
	if ic:
		b.icon = ic
		b.add_theme_constant_override("icon_max_width", 32)
	b.pressed.connect(cb)
	return b


func _build_buttons() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.position = Vector2(450, 270)
	v.size = Vector2(380, 0)
	add_child(v)
	v.add_child(_menu_button("Neues Spiel", "icons/play.png", func() -> void:
		if Game.has_save():
			confirm.popup_centered()
		else:
			_start_new()))
	load_btn = _menu_button("Spiel laden", "icons/load.png", _start_loaded)
	load_btn.disabled = not Game.has_save()
	if load_btn.disabled:
		load_btn.tooltip_text = "Noch kein Spielstand vorhanden"
	v.add_child(load_btn)
	v.add_child(_menu_button("Einstellungen", "icons/settings.png", func() -> void:
		dim.visible = true
		settings_panel.open()))
	var wish := _menu_button("Auf Steam wunschlisten", "icons/social/steam_24.png", func() -> void: _open_link("steam_wishlist"))
	wish.theme_type_variation = "SteamButton"
	v.add_child(wish)
	v.add_child(_menu_button("Beenden", "icons/quit.png", func() -> void: get_tree().quit()))


func _build_socials() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	for s in [["discord", "Discord"], ["reddit", "Reddit"], ["x", "X"]]:
		var key: String = s[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = s[1]
		b.custom_minimum_size = Vector2(110, 46)
		b.add_theme_font_size_override("font_size", 18)
		var ic := Art.tex("icons/social/%s_24.png" % key)
		if ic:
			b.icon = ic
		b.pressed.connect(func() -> void: _open_link(key))
		h.add_child(b)
	# Unten rechts in die Ecke
	h.reset_size()
	h.position = Vector2(1280 - h.size.x - 20, 720 - h.size.y - 16)


func _open_link(key: String) -> void:
	var msg := Links.open(key)
	if msg != "":
		hint.text = msg
		hint_timer = 3.5


# --- Spielstart -----------------------------------------------------------

func _start_new() -> void:
	Sfx.play_first(["menu_start"])
	Game.start_new()
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_loaded() -> void:
	Sfx.play_first(["menu_start"])
	Game.start_loaded()
	get_tree().change_scene_to_file(GAME_SCENE)
