extends Control
## Launcher-Oberfläche: zeigt Version und Änderungen, aktualisiert und startet das Spiel.

const LAUNCHER_VERSION := "1.2.0"
const CONFIG_NAME := "launcher_config.json"
const GOLD_TEXT := Color("#3c1c14")
const TITLE := Color("#ffd86b")

var updater: Updater
var _auto := "--auto" in OS.get_cmdline_user_args()   # aktualisieren und sofort starten
var _logo: TextureRect
var _notes_title: Label
var _notes: RichTextLabel
var _installed_lbl: Label
var _latest_lbl: Label
var _status_lbl: Label
var _bar: ProgressBar
var _bar_lbl: Label
var _main_btn: Button
var _play_old_btn: Button
var _recheck_btn: Button
var _folder_btn: Button


func _ready() -> void:
	theme = _build_theme()
	_build_ui()
	updater = Updater.new()
	add_child(updater)
	updater.load_config(_config_path())
	updater.check_finished.connect(_on_check_finished)
	updater.progress.connect(_on_progress)
	updater.install_finished.connect(_on_install_finished)
	_check()


## --config=<pfad> (zum Testen), sonst launcher_config.json neben der .exe, sonst die mitgelieferte.
func _config_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--config="):
			return a.trim_prefix("--config=")
	if Updater.runs_from_package():
		var beside := OS.get_executable_path().get_base_dir().path_join(CONFIG_NAME)
		if FileAccess.file_exists(beside):
			return beside
	return "res://" + CONFIG_NAME


# ---------------------------------------------------------------- Ablauf

func _check() -> void:
	_set_busy("Suche nach Updates …")
	_show_installed()
	updater.check()


func _on_check_finished(ok: bool) -> void:
	_bar.visible = false
	_bar_lbl.visible = false
	_recheck_btn.disabled = false
	_show_installed()
	var have := updater.is_installed()
	_play_old_btn.visible = false
	if ok and updater.latest_tag != "":
		_latest_lbl.text = "Neueste Version: %s" % updater.latest_tag
		_show_notes(updater.latest_tag, updater.latest_published, updater.latest_notes)
	else:
		_latest_lbl.text = "Neueste Version: unbekannt"
		if have:
			_show_notes(updater.installed_tag(), "", updater.installed_notes())
	if updater.update_available():
		_main_btn.disabled = false
		_main_btn.text = "Aktualisieren" if have else "Installieren"
		_status_lbl.text = "Neue Version %s ist da!" % updater.latest_tag if have else "Das Spiel ist noch nicht installiert."
		_play_old_btn.visible = have
	elif have:
		_main_btn.disabled = false
		_main_btn.text = "Spielen"
		if ok and updater.last_error == "":
			_status_lbl.text = "Alles aktuell."
		else:
			_status_lbl.text = "Offline: %s. Du spielst die installierte Version." % updater.last_error
	else:
		_main_btn.disabled = true
		_main_btn.text = "Nicht installiert"
		_status_lbl.text = updater.last_error if updater.last_error != "" else "Kein Download gefunden."
	if _auto and not _main_btn.disabled:
		_on_main_pressed()


func _on_main_pressed() -> void:
	if updater.update_available():
		_play_old_btn.visible = false
		_recheck_btn.disabled = true
		_set_busy("Lade %s herunter …" % updater.latest_tag)
		_bar.visible = true
		_bar_lbl.visible = true
		_bar.value = 0
		updater.install_latest()
	elif updater.is_installed():
		_play()


func _on_progress(done: int, total: int) -> void:
	if total > 0:
		_bar.value = 100.0 * done / total
		_bar_lbl.text = "%s / %s" % [_mb(done), _mb(total)]
	else:
		_bar_lbl.text = _mb(done)
	if total > 0 and done >= total:
		_status_lbl.text = "Entpacke …"


func _on_install_finished(ok: bool, message: String) -> void:
	_bar.visible = false
	_bar_lbl.visible = false
	_recheck_btn.disabled = false
	_show_installed()
	if ok:
		_status_lbl.text = "Version %s installiert. Spielstände bleiben erhalten." % updater.installed_tag()
		_main_btn.disabled = false
		_main_btn.text = "Spielen"
		if _auto:
			_play()
	else:
		_status_lbl.text = "Fehler: " + message
		_main_btn.disabled = false
		_main_btn.text = "Nochmal versuchen" if not updater.is_installed() else "Aktualisieren"
		_play_old_btn.visible = updater.is_installed()


func _play() -> void:
	if not updater.launch_game():
		_status_lbl.text = "Spiel konnte nicht gestartet werden: %s" % updater.game_main_file()
		return
	_status_lbl.text = "Viel Spaß!"
	if updater.config.get("close_on_play", true):
		await get_tree().create_timer(0.8).timeout
		get_tree().quit()


func _set_busy(text: String) -> void:
	_status_lbl.text = text
	_main_btn.disabled = true
	_main_btn.text = "Bitte warten …"


func _show_installed() -> void:
	var tag := updater.installed_tag()
	_installed_lbl.text = "Installiert: %s" % (tag if tag != "" and updater.is_installed() else "nichts")


func _show_notes(tag: String, date: String, md: String) -> void:
	_notes_title.text = "Was ist neu in %s%s" % [tag, (" (%s)" % date) if date != "" else ""]
	_notes.text = markdown_to_bbcode(md) if md.strip_edges() != "" else "[i]Keine Beschreibung.[/i]"


static func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)


## Einfache Umwandlung der Release-Beschreibung: Überschriften, Listen, **fett**, *kursiv*, `code`.
static func markdown_to_bbcode(md: String) -> String:
	var out: PackedStringArray = []
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var ital := RegEx.create_from_string("(?<![*\\w])[*_](.+?)[*_](?![*\\w])")
	var code := RegEx.create_from_string("`([^`]+)`")
	var link := RegEx.create_from_string("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	for raw in md.replace("\r", "").split("\n"):
		# Links werden zu reinem Text, dann eckige Klammern für BBCode entschärfen
		var line: String = link.sub(raw, "$1", true)
		line = line.replace("[", "\u0001").replace("]", "\u0002")
		line = line.replace("\u0001", "[lb]").replace("\u0002", "[rb]")
		line = bold.sub(line, "[b]$1[/b]", true)
		line = ital.sub(line, "[i]$1[/i]", true)
		line = code.sub(line, "[code]$1[/code]", true)
		var t := line.strip_edges()
		if t.begins_with("#"):
			var title := t.lstrip("#").strip_edges()
			out.append("[color=#ffd86b][b]%s[/b][/color]" % title)
		elif t.begins_with("- ") or t.begins_with("* ") or t.begins_with("+ "):
			var indent := "    " if raw.begins_with("  ") else ""
			out.append("%s• %s" % [indent, t.substr(2)])
		else:
			out.append(t)
	return "\n".join(out)


# ---------------------------------------------------------------- Oberfläche

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://art/menu_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_logo = TextureRect.new()
	_logo.texture = load("res://art/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(400, 160)
	col.add_child(_logo)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)

	# Links: Änderungen
	var notes_panel := PanelContainer.new()
	notes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(notes_panel)
	var notes_box := VBoxContainer.new()
	notes_panel.add_child(notes_box)
	_notes_title = Label.new()
	_notes_title.text = "Was ist neu"
	_notes_title.add_theme_color_override("font_color", TITLE)
	_notes_title.add_theme_font_size_override("font_size", 20)
	notes_box.add_child(_notes_title)
	_notes = RichTextLabel.new()
	_notes.bbcode_enabled = true
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.add_theme_font_size_override("normal_font_size", 16)
	_notes.add_theme_font_size_override("bold_font_size", 16)
	_notes.add_theme_font_size_override("italics_font_size", 16)
	notes_box.add_child(_notes)

	# Rechts: Version, Fortschritt, Knöpfe
	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(330, 0)
	row.add_child(side_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side_panel.add_child(side)
	_installed_lbl = _label(side, "Installiert: …", 18)
	_latest_lbl = _label(side, "Neueste Version: …", 18)
	_status_lbl = _label(side, "", 16)
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_color_override("font_color", Color("#cfe8ff"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 20)
	_bar.visible = false
	side.add_child(_bar)
	_bar_lbl = _label(side, "", 14)
	_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_lbl.visible = false
	_main_btn = Button.new()
	_main_btn.theme_type_variation = "BigButton"
	_main_btn.custom_minimum_size = Vector2(0, 64)
	_main_btn.text = "Bitte warten …"
	_main_btn.disabled = true
	_main_btn.pressed.connect(_on_main_pressed)
	side.add_child(_main_btn)
	_play_old_btn = _small_button(side, "Ohne Update spielen", _play)
	_play_old_btn.visible = false
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 8)
	side.add_child(small)
	_recheck_btn = _small_button(small, "Erneut prüfen", _check)
	_folder_btn = _small_button(small, "Spielordner", func(): OS.shell_open(updater.install_dir))
	for b in [_recheck_btn, _folder_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var foot := _label(col, "Launcher %s" % LAUNCHER_VERSION, 12)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.modulate = Color(1, 1, 1, 0.5)


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _small_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_theme() -> Theme:
	var th := Theme.new()
	for st in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(st, "Button", _nine("button_%s" % st, 5, 2, 8.0))
		th.set_stylebox(st, "BigButton", _nine("menu_button_%s" % st, 6, 3, 12.0))
	th.set_type_variation("BigButton", "Button")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "BigButton", GOLD_TEXT)
	th.set_color("font_disabled_color", "BigButton", Color(0.24, 0.11, 0.08, 0.5))
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	th.set_font_size("font_size", "BigButton", 28)
	th.set_font_size("font_size", "Button", 15)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("focus", "BigButton", StyleBoxEmpty.new())
	th.set_stylebox("panel", "PanelContainer", _nine("panel_dark_9slice", 6, 2, 14.0))
	th.set_stylebox("background", "ProgressBar", _nine("progress_bar_bg", 3, 2, 0.0))
	th.set_stylebox("fill", "ProgressBar", _nine("progress_bar_fill", 3, 2, 0.0))
	return th


## Ganzzahlig vergrößerte 9-Slice-Grafik als StyleBox.
func _nine(name: String, margin: int, factor: int, content: float) -> StyleBoxTexture:
	var t: Texture2D = load("res://art/%s.png" % name)
	var img := t.get_image()
	img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(margin * factor)
	sb.set_content_margin_all(content)
	return sb
