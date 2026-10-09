extends Node
## Lädt Pixel-Art aus res://art/ (Pfade siehe ../art-spec-fuer-spiel.md).
## Fehlt eine Datei, gibt tex() null zurück und das Spiel zeichnet den Platzhalter.
## Als Autoload "Art" erreichbar.

const ROOT := "res://art/"

var _cache: Dictionary = {}


func tex(rel_path: String) -> Texture2D:
	if _cache.has(rel_path):
		return _cache[rel_path]
	var path := ROOT + rel_path
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		# Noch nicht importiert (z. B. direkt nach dem Hineinkopieren): direkt als Bild laden
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			t = ImageTexture.create_from_image(img)
	_cache[rel_path] = t
	return t


func figure(id: String) -> Texture2D:
	return tex("figures/%s.png" % id)


func machine_part(machine_id: String, part: String) -> Texture2D:
	return tex("machines/%s_%s.png" % [machine_id, part])


## Ganzzahlig hochskalierte Kopie (Nearest), z. B. für 9-Slice-Rahmen, die sonst zu dünn wären.
func scaled(rel_path: String, factor: int) -> Texture2D:
	var key := "%s@%d" % [rel_path, factor]
	if _cache.has(key):
		return _cache[key]
	var t := tex(rel_path)
	var out: Texture2D = null
	if t:
		var img := t.get_image()
		img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## StyleBoxTexture aus einer 9-Slice-Grafik, oder null, wenn sie fehlt.
func stylebox(rel_path: String, margin: int, factor: int = 2, content_margin: float = -1.0) -> StyleBoxTexture:
	var t := scaled(rel_path, factor)
	if t == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.set_texture_margin_all(margin * factor)
	sb.set_content_margin_all(content_margin if content_margin >= 0.0 else margin * factor + 4.0)
	return sb


var _theme: Theme
var _theme_built := false


## Gemeinsames Pixel-Theme für Spiel und Menüs (null ohne Pixel-Art).
## Menüknöpfe nutzen die Variante "BigButton" (button.theme_type_variation = "BigButton").
func ui_theme() -> Theme:
	if _theme_built:
		return _theme
	_theme_built = true
	if not has_art():
		return null
	var th := Theme.new()
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := stylebox("ui/button_%s.png" % st, 5, 2, 8.0)
		if sb:
			th.set_stylebox(st, "Button", sb)
		# Breiter Menüknopf; bis die eigene Grafik da ist, der grüne Knopf
		var mb := stylebox("ui/menu_button_%s.png" % st, 6, 3, 12.0)
		if mb == null:
			mb = stylebox("ui/button_green_%s.png" % st, 5, 3, 12.0)
		if mb:
			th.set_stylebox(st, "BigButton", mb)
		var sb2 := stylebox("ui/button_steam_%s.png" % st, 5, 3, 12.0)
		if sb2:
			th.set_stylebox(st, "SteamButton", sb2)
	th.set_type_variation("BigButton", "Button")
	th.set_type_variation("SteamButton", "BigButton")
	if tex("ui/menu_button_normal.png"):
		# Goldener Knopf: dunkle Schrift liest sich besser
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			th.set_color(c, "BigButton", Color("#3c1c14"))
		th.set_color("font_disabled_color", "BigButton", Color(0.24, 0.11, 0.08, 0.5))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			th.set_color(c, "SteamButton", Color.WHITE)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("focus", "BigButton", StyleBoxEmpty.new())
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	th.set_font_size("font_size", "BigButton", 24)
	var panel := stylebox("ui/panel_9slice.png", 6, 2, 12.0)
	if panel:
		th.set_stylebox("panel", "PanelContainer", panel)
	var dark := stylebox("ui/panel_dark_9slice.png", 6, 2, 8.0)
	if dark:
		th.set_stylebox("panel", "TabContainer", dark)
	# Lautstärkeregler: eigene Grafik, sonst der Fortschrittsbalken
	# Die Höhe des Reglers ergibt sich aus dem Innenabstand
	var track := stylebox("ui/slider_track.png", 3, 2, 4.0)
	if track == null:
		track = stylebox("ui/progress_bar_bg.png", 3, 2, 5.0)
	var fill := stylebox("ui/slider_fill.png", 3, 2, 4.0)
	if fill == null:
		fill = stylebox("ui/progress_bar_fill.png", 3, 2, 5.0)
	if track and fill:
		th.set_stylebox("slider", "HSlider", track)
		th.set_stylebox("grabber_area", "HSlider", fill)
		th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := scaled("ui/slider_grabber.png", 2)
	if grab == null:
		grab = scaled("ui/coin.png", 2)
	if grab:
		th.set_icon("grabber", "HSlider", grab)
		th.set_icon("grabber_highlight", "HSlider", grab)
	# Checkbox ohne Knopf-Rahmen
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		th.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	var on := scaled("ui/checkbox_on.png", 2)
	var off := scaled("ui/checkbox_off.png", 2)
	if on and off:
		th.set_icon("checked", "CheckBox", on)
		th.set_icon("unchecked", "CheckBox", off)
	_theme = th
	return th


func has_art() -> bool:
	return tex("machines/standard_body.png") != null
