extends CanvasLayer
## Mini-Modus (wie TaskbarHero): kleines randloses Fenster unten rechts über der Taskleiste,
## immer im Vordergrund. Man kann weiter kurbeln (Automat gedrückt halten), Kapseln öffnen sich
## von selbst, die drei günstigsten Upgrades lassen sich direkt kaufen, Automaten durchschalten.
## Ziehen am Rand verschiebt das Fenster. Wird von main.gd erzeugt.

signal exit_requested

const SIZE := Vector2i(640, 150)
const GOLD := Color("#ffe14d")
const MINT := Color("#9fffcb")
const OPEN_INTERVAL := 0.15

var main: Node            # main.gd
var active := false
var holding := false

var _saved := {}
var _open_timer := 0.0
var _refresh_timer := 0.0
var _drag := false
var _drag_offset := Vector2i.ZERO

var root_panel: PanelContainer
var machine_btn: TextureButton
var machine_name: Label
var coins_label: Label
var income_label: Label
var last_label: Label
var up_buttons: Array = []    # Button
var up_ids: Array = []        # Upgrade-ID je Knopf


func _ready() -> void:
	layer = 50
	visible = false
	_build()
	Game.changed.connect(_refresh)


func _build() -> void:
	root_panel = PanelContainer.new()
	root_panel.size = Vector2(SIZE)
	var th := Art.ui_theme()
	if th:
		root_panel.theme = th
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#241c33")
	sb.border_color = Color("#ffe14d")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	root_panel.add_theme_stylebox_override("panel", sb)
	root_panel.gui_input.connect(_on_drag_input)
	root_panel.tooltip_text = "Am Rand ziehen zum Verschieben"
	add_child(root_panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	root_panel.add_child(h)

	# Automat: gedrückt halten = kurbeln
	machine_btn = TextureButton.new()
	machine_btn.custom_minimum_size = Vector2(80, 100)
	machine_btn.ignore_texture_size = true
	machine_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	machine_btn.tooltip_text = "Gedrückt halten zum Kurbeln"
	machine_btn.button_down.connect(func() -> void: holding = true)
	machine_btn.button_up.connect(func() -> void: holding = false)
	machine_btn.mouse_exited.connect(func() -> void: holding = false)
	h.add_child(machine_btn)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.custom_minimum_size = Vector2(170, 0)
	h.add_child(info)
	machine_name = _label("", 12, Color(1, 1, 1, 0.7))
	machine_name.clip_text = true
	info.add_child(machine_name)
	coins_label = _label("", 24, GOLD)
	info.add_child(coins_label)
	income_label = _label("", 13, MINT)
	info.add_child(income_label)
	last_label = _label("", 13)
	last_label.clip_text = true
	info.add_child(last_label)
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 4)
	info.add_child(sw)
	sw.add_child(_small_button("◀", "Vorheriger aufgestellter Automat", func() -> void: _switch(-1)))
	sw.add_child(_small_button("▶", "Nächster aufgestellter Automat", func() -> void: _switch(1)))

	var ups := VBoxContainer.new()
	ups.add_theme_constant_override("separation", 3)
	ups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ups)
	for i in 3:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_constant_override("icon_max_width", 22)
		b.clip_text = true
		var idx := i
		b.pressed.connect(func() -> void: _buy(idx))
		ups.add_child(b)
		up_buttons.append(b)
		up_ids.append("")

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	h.add_child(side)
	var big := _small_button("Groß", "Zurück zum großen Fenster (M)", func() -> void: exit_requested.emit())
	big.custom_minimum_size = Vector2(56, 40)
	side.add_child(big)
	var quit := _small_button("✕", "Speichern und beenden", func() -> void:
		Game.save_game()
		get_tree().quit())
	quit.custom_minimum_size = Vector2(56, 30)
	side.add_child(quit)


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _small_button(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 26)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	return b


# --- Fenster --------------------------------------------------------------

func enter() -> void:
	if active:
		return
	active = true
	Settings.mini_mode = true
	var w := get_window()
	_saved = {"mode": w.mode, "size": w.size, "pos": w.position, "scale": w.content_scale_size}
	if w.mode != Window.MODE_WINDOWED:
		w.mode = Window.MODE_WINDOWED
	w.content_scale_size = SIZE
	w.min_size = Vector2i.ZERO
	w.borderless = true
	w.always_on_top = true
	# Auf großen Bildschirmen etwas größer, damit es lesbar bleibt
	var screen := w.current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var k := clampf(usable.size.y / 1040.0, 1.0, 2.0)
	var px := Vector2i(int(SIZE.x * k), int(SIZE.y * k))
	w.size = px
	w.position = usable.position + usable.size - px - Vector2i(12, 12)
	visible = true
	_refresh()


func exit() -> void:
	if not active:
		return
	active = false
	holding = false
	visible = false
	var w := get_window()
	w.always_on_top = false
	w.borderless = false
	w.content_scale_size = _saved.get("scale", Vector2i(1280, 720))
	w.size = _saved.get("size", Vector2i(1280, 720))
	w.position = _saved.get("pos", Vector2i(100, 100))
	Settings.mini_mode = false
	Settings.apply()


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		_drag_offset = DisplayServer.mouse_get_position() - get_window().position
	elif event is InputEventMouseMotion and _drag:
		get_window().position = DisplayServer.mouse_get_position() - _drag_offset


# --- Spiel ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	# Kapseln öffnen sich im Mini-Modus von selbst (inkl. Eis knacken)
	_open_timer -= delta
	if _open_timer <= 0.0:
		_open_timer = OPEN_INTERVAL
		main._open_first_capsule()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_refresh()


func show_result(res: Dictionary) -> void:
	if not active:
		return
	match res.get("type", ""):
		"empty":
			last_label.text = "Leer!"
			last_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		_:
			var figs: Array = res.get("figures", [])
			if figs.is_empty():
				return
			var f: Dictionary = figs[0]
			var neu := "NEU! " if f["id"] in res.get("new", []) else ""
			last_label.text = "%s%s · %s  %s%s" % [neu, f["name"], f["rarity_name"], "+" if res["value"] >= 0 else "", Fmt.num(res["value"])]
			last_label.add_theme_color_override("font_color", Color(f["rarity_color"]))


func _refresh() -> void:
	if not active:
		return
	var m: Dictionary = Game.machine()
	machine_btn.texture_normal = Art.machine_part(m["id"], "body") if Art.machine_part(m["id"], "body") else Art.machine_part("standard", "body")
	machine_name.text = "%s · %s" % [Game.world_by_id[Game.current_world()]["name"], m["name"]]
	coins_label.text = Fmt.num(Game.coins)
	income_label.text = "+%s/s · Kapsel %s" % [Fmt.rate(Game.income_per_sec()), Fmt.num(Game.capsule_cost())]
	# Die drei günstigsten noch offenen Upgrades für diesen Automaten (und den Laden)
	var open: Array = []
	for u in Game.upgrades:
		var id: String = u["id"]
		if Game.is_revealed(id) and not Game.is_maxed(id):
			open.append(id)
	open.sort_custom(func(a: String, b: String) -> bool: return Game.upgrade_cost(a) < Game.upgrade_cost(b))
	for i in up_buttons.size():
		var b: Button = up_buttons[i]
		if i >= open.size():
			b.visible = false
			up_ids[i] = ""
			continue
		var id: String = open[i]
		var u: Dictionary = Game.upgrade_by_id[id]
		up_ids[i] = id
		b.visible = true
		b.icon = Art.tex("icons/upgrades/%s.png" % id)
		b.text = "%s %d  ·  %s" % [u["name"], Game.level(id) + 1, Fmt.num(Game.upgrade_cost(id))]
		b.tooltip_text = u["desc"]
		b.disabled = not Game.can_buy(id)


func _buy(i: int) -> void:
	var id: String = up_ids[i]
	if id != "" and Game.buy(id):
		Sfx.play("upgrade")
	else:
		Sfx.play("deny")
	_refresh()


func _switch(dir: int) -> void:
	if Game.placed.size() < 2:
		Sfx.play("deny")
		return
	var i := Game.placed.find(Game.current_machine)
	Game.select_machine(Game.placed[wrapi(i + dir, 0, Game.placed.size())])
	Sfx.play("ui_click")
	_refresh()
