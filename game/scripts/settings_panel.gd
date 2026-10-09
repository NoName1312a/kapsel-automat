extends PanelContainer
## Einstellungs-Fenster für Hauptmenü und Spiel: Lautstärken, Bildschirmwackeln, Vollbild.

signal closed

const GOLD := Color("#ffe14d")


func _ready() -> void:
	var th := Art.ui_theme()
	if th:
		theme = th
	else:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#241c33")
		bg.border_color = Color("#4e3f63")
		bg.set_border_width_all(3)
		bg.set_corner_radius_all(14)
		add_theme_stylebox_override("panel", bg)
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var ic := Art.tex("icons/settings.png")
	if ic:
		var tr := TextureRect.new()
		tr.texture = ic
		tr.custom_minimum_size = Vector2(40, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(tr)
	var title := Label.new()
	title.text = "Einstellungen"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	head.add_child(title)

	_slider_row(v, "Gesamtlautstärke", "master", "sound_on")
	_slider_row(v, "Musik", "music", "music")
	_slider_row(v, "Effekte", "sfx", "sound_on")
	_slider_row(v, "Bildschirmwackeln", "shake", "")

	# Mit Checkbox-Grafik eine echte Checkbox, sonst ein Umschalt-Knopf
	var has_cb := Art.tex("ui/checkbox_on.png") != null
	var fs: Button = CheckBox.new() if has_cb else Button.new()
	fs.toggle_mode = true
	fs.focus_mode = Control.FOCUS_NONE
	fs.custom_minimum_size = Vector2(0, 44)
	fs.add_theme_font_size_override("font_size", 20)
	fs.button_pressed = Settings.get_value("fullscreen")
	var label_for := func(on: bool) -> String:
		return "Vollbild" if has_cb else ("Vollbild: An" if on else "Vollbild: Aus")
	fs.text = label_for.call(fs.button_pressed)
	fs.toggled.connect(func(on: bool) -> void:
		fs.text = label_for.call(on)
		Settings.set_value("fullscreen", on))
	v.add_child(fs)

	var done := Button.new()
	done.text = "Fertig"
	done.theme_type_variation = "BigButton"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(0, 48)
	done.add_theme_font_size_override("font_size", 20)
	done.pressed.connect(close)
	v.add_child(done)


func _slider_row(v: VBoxContainer, label: String, key: String, icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var on_t: Texture2D = Art.tex("icons/ui16/%s.png" % icon) if icon != "" else null
	var off_t: Texture2D = Art.tex("icons/ui16/sound_off.png") if icon != "" else null
	ic.texture = on_t
	if Art.has_art():
		row.add_child(ic)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(210, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 28)
	s.value = float(Settings.get_value(key)) * 100.0
	row.add_child(s)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(62, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_size_override("font_size", 20)
	pct.text = "%d %%" % int(s.value)
	row.add_child(pct)
	var set_icon := func(x: float) -> void:
		ic.texture = off_t if x <= 0.0 and off_t else on_t
	set_icon.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		set_icon.call(x)
		pct.text = "%d %%" % int(x)
		Settings.set_value(key, x / 100.0)
		# Hörprobe beim Effekte-Regler
		if key == "sfx" or key == "master":
			Sfx.play("coin", 1.0, -6.0))


func open() -> void:
	visible = true
	modulate.a = 0.0
	Sfx.play("ui_open")
	# Nach dem Layout mittig setzen
	await get_tree().process_frame
	reset_size()
	position = ((Vector2(1280, 720) - size) / 2.0).round()
	modulate.a = 1.0


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play("ui_close")
	closed.emit()
