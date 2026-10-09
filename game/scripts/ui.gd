extends CanvasLayer
## Alle Menüs: Kopfzeile, Automaten-Leiste links, Seitenleiste mit Tabs, Album, Erfolge,
## Pausenmenü, Popups, Story-Szenen und Meldungen.

signal open_all_requested
signal clear_tray_requested

const SettingsPanel := preload("res://scripts/settings_panel.gd")
const MENU_SCENE := "res://menu.tscn"

const TOP_H := 56.0
const PANEL_POS := Vector2(870, 64)
const PANEL_SIZE := Vector2(400, 648)
const STRIP_POS := Vector2(8, 66)
const GOLD := Color("#ffe14d")
const MINT := Color("#9fffcb")
const DIM_TEXT := Color(1, 1, 1, 0.7)

var coins_label: Label
var income_label: Label
var goldmarken_top: Label
var world_btn: Button
var status_label: Label
var status_timer := 0.0
var toast_box: VBoxContainer
var _toast_queue: Array = []
var open_all_btn: Button
var tabs: TabContainer
var strip: VBoxContainer
var _strip_key := ""

var upgrade_rows: Dictionary = {}       # id -> {row, name, desc, buy, max}
var machine_rows: Dictionary = {}       # id -> {row, title, info, main, level, place}
var world_rows: Dictionary = {}         # id -> {row, info, button}
var slots_label: Label
var golden_label: Label
var golden_btn: Button
var prestige_info: Label
var prestige_btn: Button
var prestige_rows: Dictionary = {}      # id -> {name, desc, buy}
var goldmarken_label: Label

var dim: ColorRect
var album_panel: PanelContainer
var album_list: VBoxContainer
var album_world := ""
var ach_panel: PanelContainer
var ach_list: VBoxContainer
var story_panel: PanelContainer
var story_label: Label
var story_name: Label
var story_portrait: TextureRect
var _story_queue: Array = []
var confirm: ConfirmationDialog
var info_dialog: AcceptDialog
var _confirm_action: Callable
var _theme: Theme
var pause_panel: PanelContainer
var settings_panel: SettingsPanel
var _bg_toast_cooldown := 0.0
var _idle_timer := 90.0


func _ready() -> void:
	_apply_pixel_theme()
	_build_hud()
	_build_topbar()
	_build_strip()
	_build_sidebar()
	album_panel = _build_overlay("Sammelalbum")
	album_list = album_panel.get_meta("list")
	ach_panel = _build_overlay("Erfolge & Statistik")
	ach_list = ach_panel.get_meta("list")
	_build_pause_menu()
	_build_story()
	_build_dialogs()

	Game.achievement_unlocked.connect(_on_achievement)
	Game.upgrade_revealed.connect(func(u: Dictionary) -> void:
		Sfx.play_first(["toast"], 1.0, -4.0)
		toast("Neues Upgrade", u["name"]))
	Game.background_opened.connect(_on_background_opened)
	Game.world_unlocked.connect(func(w: String) -> void:
		toast("Neue Welt: " + Game.world_by_id[w]["name"], Game.world_by_id[w]["desc"]))
	Game.story_event.connect(_on_story_event)
	var t := Timer.new()
	t.wait_time = 0.2
	t.autostart = true
	t.timeout.connect(refresh)
	add_child(t)
	Game.changed.connect(refresh)
	refresh()


func show_offline_report_later() -> void:
	_show_offline_report.call_deferred()


func _process(delta: float) -> void:
	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0:
			status_label.text = ""
	_bg_toast_cooldown = maxf(_bg_toast_cooldown - delta, 0.0)
	# Krümel meldet sich ab und zu mit einem Spruch
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(120.0, 200.0)
		var line := Story.random_idle_line()
		if line != "" and not is_blocking() and Game.active:
			say("Krümel: " + line)
			status_timer = 6.0


func is_blocking() -> bool:
	return album_panel.visible or ach_panel.visible or confirm.visible or info_dialog.visible \
		or pause_panel.visible or settings_panel.visible or story_panel.visible


## Esc schließt das oberste Fenster, sonst öffnet es das Menü.
func _unhandled_input(event: InputEvent) -> void:
	if story_panel.visible and event is InputEventMouseButton and event.pressed:
		_next_story_line()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if story_panel.visible and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_ESCAPE]:
		_next_story_line()
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if settings_panel.visible:
		settings_panel.close()
	elif album_panel.visible:
		_toggle_overlay(album_panel)
	elif ach_panel.visible:
		_toggle_overlay(ach_panel)
	else:
		toggle_pause()


func say(msg: String) -> void:
	status_label.text = msg
	status_timer = 2.5


## Meldungen kommen in eine Warteschlange und erscheinen nacheinander.
func toast(title: String, sub: String) -> void:
	if _toast_queue.size() > 6:
		return   # nicht endlos stapeln, wenn viel auf einmal passiert
	_toast_queue.append([title, sub])
	if _toast_queue.size() == 1 and toast_box.get_child_count() == 0:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		return
	var item: Array = _toast_queue[0]
	var title: String = item[0]
	var sub: String = item[1]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(370, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a2d55")
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	p.add_child(v)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	var icon := Art.tex("ui/trophy.png")
	if icon:
		hb.add_child(_icon_rect(icon, 32))
	var a := Label.new()
	a.text = title
	a.add_theme_font_size_override("font_size", 20)
	a.add_theme_color_override("font_color", GOLD)
	hb.add_child(a)
	var b := Label.new()
	b.text = sub
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(350, 0)
	v.add_child(b)
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6 if _toast_queue.size() > 1 else 2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		p.queue_free()
		_toast_queue.pop_front()
		_next_toast())


func _on_achievement(a: Dictionary) -> void:
	Sfx.play("achievement")
	toast("Erfolg: " + a["name"], "%s  (+%d %% Münzen)" % [a["desc"], int(Game.achievement_bonus * 100)])


## Nebenautomaten melden nur Besonderes, und höchstens alle paar Sekunden.
func _on_background_opened(machine_id: String, res: Dictionary) -> void:
	if res.get("type", "") == "empty" or _bg_toast_cooldown > 0.0:
		return
	var m: Dictionary = Game.machine_by_id[machine_id]
	for f in res.get("figures", []):
		if f["rarity"] == "legendary" or f["id"] in res.get("new", []):
			_bg_toast_cooldown = 4.0
			Sfx.play_first(["new_figure"], 1.0, -8.0)
			toast("%s: %s" % [m["name"], "Legendär!" if f["rarity"] == "legendary" else "Neue Figur"],
				"%s (%s) fürs Album" % [f["name"], f["rarity_name"]])
			return


# --- Aufbau ---------------------------------------------------------------

func _label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap_label(text: String, size: int, color: Color, width: float) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _apply_pixel_theme() -> void:
	_theme = Art.ui_theme()


func _themed(c: Control) -> Control:
	if _theme:
		c.theme = _theme
	return c


func _icon_rect(t: Texture2D, size: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


## Karte mit dunklem Hintergrund für eine Zeile in der Seitenleiste.
func _card() -> PanelContainer:
	var c := PanelContainer.new()
	var sb: StyleBox = Art.stylebox("ui/card_9slice.png", 6, 2, 8.0)
	if sb == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.1, 0.07, 0.15, 0.55)
		flat.border_color = Color(1, 1, 1, 0.08)
		flat.set_border_width_all(1)
		flat.set_corner_radius_all(6)
		flat.set_content_margin_all(6)
		sb = flat
	c.add_theme_stylebox_override("panel", sb)
	return c


func _header(text: String) -> Label:
	var l := _label(text, 16, GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Bronze/Silber/Gold je nachdem, wie weit hinten der Erfolg in seiner Reihe steht.
func _trophy_tier(a: Dictionary) -> String:
	var same: Array = []
	for x in Game.achievement_list:
		if x["stat"] == a["stat"]:
			same.append(x["id"])
	var i := same.find(a["id"])
	if same.size() == 1:
		return "silver"
	return ["bronze", "silver", "gold", "gold"][mini(i, 3)]


func _build_hud() -> void:
	var hint := _label("Kurbel halten/ziehen oder LEERTASTE  ·  Kapsel anklicken oder E  ·  A = alle öffnen  ·  Esc = Menü", 14, Color(1, 1, 1, 0.55))
	hint.position = Vector2(120, 694)
	add_child(hint)

	status_label = _label("", 20, GOLD)
	status_label.position = Vector2(480, 540)
	status_label.size = Vector2(380, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(488, 70)
	toast_box.custom_minimum_size = Vector2(370, 0)
	toast_box.add_theme_constant_override("separation", 8)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)


## Kopfzeile: Einstellungen, Welt, Münzen, Einkommen, Goldmarken, Album, Erfolge, Menü.
func _build_topbar() -> void:
	var bar := PanelContainer.new()
	_themed(bar)
	var sb: StyleBox = Art.stylebox("ui/topbar_9slice.png", 6, 2, 6.0)
	if sb == null:
		sb = Art.stylebox("ui/panel_dark_9slice.png", 6, 2, 6.0)
	if sb:
		bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, TOP_H)
	bar.custom_minimum_size = Vector2(1280, TOP_H)
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)

	var gear := _button("", open_settings)
	var gt := Art.tex("icons/settings.png")
	if gt:
		gear.icon = gt
		gear.add_theme_constant_override("icon_max_width", 28)
	else:
		gear.text = "Einst."
	gear.tooltip_text = "Einstellungen"
	h.add_child(gear)

	world_btn = _button("", func() -> void: tabs.current_tab = 2)
	world_btn.tooltip_text = "Welten"
	world_btn.add_theme_font_size_override("font_size", 16)
	world_btn.custom_minimum_size = Vector2(190, 0)
	h.add_child(world_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var coin_icon := Art.tex("ui/coin.png")
	if coin_icon:
		h.add_child(_icon_rect(coin_icon, 32))
	coins_label = _label("", 28, GOLD)
	coins_label.custom_minimum_size = Vector2(170, 0)
	h.add_child(coins_label)
	income_label = _label("", 16, MINT)
	income_label.custom_minimum_size = Vector2(130, 0)
	income_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(income_label)
	var gm_icon := Art.tex("ui/goldmarke.png")
	if gm_icon:
		h.add_child(_icon_rect(gm_icon, 24))
	goldmarken_top = _label("", 16, GOLD)
	goldmarken_top.custom_minimum_size = Vector2(60, 0)
	goldmarken_top.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(goldmarken_top)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer2)
	for e in [["Album", func() -> void: _toggle_overlay(album_panel)],
			["Erfolge", func() -> void: _toggle_overlay(ach_panel)],
			["Menü", toggle_pause]]:
		var b := _button(e[0], e[1])
		b.custom_minimum_size = Vector2(92, 0)
		b.add_theme_font_size_override("font_size", 16)
		h.add_child(b)


## Links: die aufgestellten Automaten. Klick zeigt ihn groß, die anderen laufen nebenbei.
func _build_strip() -> void:
	strip = VBoxContainer.new()
	strip.position = STRIP_POS
	strip.add_theme_constant_override("separation", 6)
	_themed(strip)
	add_child(strip)


func _rebuild_strip() -> void:
	var key := "%s|%s|%d" % [str(Game.placed), Game.current_machine, Game.slot_count()]
	for id in Game.placed:
		key += "|%d" % Game.machine_level(id)
	if key == _strip_key:
		return
	_strip_key = key
	for c in strip.get_children():
		c.queue_free()
	if Game.slot_count() <= 1 and Game.unlocked_machines.size() <= 1:
		return
	strip.add_child(_label("Plätze %d/%d" % [Game.placed.size(), Game.slot_count()], 13, DIM_TEXT))
	for id in Game.placed:
		var m: Dictionary = Game.machine_by_id[id]
		var mid: String = id
		var b := _button("", func() -> void:
			if Game.current_machine != mid:
				Sfx.play_first(["machine_switch"])
			Game.select_machine(mid))
		b.custom_minimum_size = Vector2(100, 74)
		b.icon = _machine_icon(id)
		b.add_theme_constant_override("icon_max_width", 40)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.text = "%s\n%s" % [_short_name(m), "★%d" % Game.machine_level(id) if Game.machine_level(id) > 0 else ""]
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = "%s%s" % [m["name"], "  (wird gezeigt)" if id == Game.current_machine else "  (läuft nebenbei, %s Kapseln/s)" % Fmt.rate(Game.background_rate(id))]
		if id == Game.current_machine:
			b.modulate = Color(1.15, 1.1, 0.8)
		else:
			b.modulate = Color(0.85, 0.85, 0.9)
		strip.add_child(b)
	for i in Game.slot_count() - Game.placed.size():
		var e := _label("freier Platz\n(Automaten-Tab)", 11, Color(1, 1, 1, 0.45))
		e.custom_minimum_size = Vector2(100, 40)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		strip.add_child(e)


func _short_name(m: Dictionary) -> String:
	return String(m["name"]).replace("-Automat", "").replace("automat", "")


func _machine_icon(id: String) -> Texture2D:
	var t := Art.machine_part(id, "body")
	if t == null:
		t = Art.machine_part("standard", "body")
	return t


func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	_themed(panel)
	panel.position = PANEL_POS
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Vier Reiter müssen in 380 px passen
	tabs.add_theme_font_size_override("font_size", 15)
	tabs.add_theme_constant_override("side_margin", 0)
	tabs.clip_tabs = false
	box.add_child(tabs)
	_build_upgrade_tab(_scroll_tab(tabs, "Upgrades"))
	_build_machine_tab(_scroll_tab(tabs, "Automaten"))
	_build_world_tab(_scroll_tab(tabs, "Welten"))
	_build_prestige_tab(_scroll_tab(tabs, "Goldmarken"))

	open_all_btn = _button("Alle öffnen (A)", func() -> void: open_all_requested.emit())
	open_all_btn.theme_type_variation = "BigButton"
	open_all_btn.custom_minimum_size = Vector2(0, 44)
	open_all_btn.add_theme_font_size_override("font_size", 18)
	box.add_child(open_all_btn)


func _scroll_tab(tc: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tc.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func _build_upgrade_tab(v: VBoxContainer) -> void:
	var cats: Array = Game.upgrades.map(func(u: Dictionary) -> String: return u.get("category", ""))
	var cat_names: Dictionary = {}
	var cat_order: Array = []
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades.json"))
	for c in data.get("categories", []):
		cat_names[c["id"]] = c["name"]
		cat_order.append(c["id"])
	for c in cats:
		if not c in cat_order:
			cat_order.append(c)
	for cat in cat_order:
		var head := _header(cat_names.get(cat, "Weitere"))
		v.add_child(head)
		var members: Array = []
		for u in Game.upgrades:
			if u.get("category", "") == cat:
				members.append(u)
		for u in members:
			_upgrade_row(v, u)
		upgrade_rows["_head_" + cat] = {"head": head, "members": members.map(func(u: Dictionary) -> String: return u["id"])}


func _upgrade_row(v: VBoxContainer, u: Dictionary) -> void:
	var id: String = u["id"]
	var card := _card()
	v.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var ic := Art.tex("icons/upgrades/%s.png" % id)
	if ic:
		row.add_child(_icon_rect(ic, 32))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	row.add_child(tv)
	var name_l := _label("", 15)
	tv.add_child(name_l)
	var desc_l := _wrap_label(u["desc"], 12, DIM_TEXT, 170)
	tv.add_child(desc_l)
	var b := _button("", func() -> void:
		if Game.buy(id):
			Sfx.play("upgrade")
		else:
			Sfx.play("deny"))
	b.custom_minimum_size = Vector2(96, 40)
	b.add_theme_font_size_override("font_size", 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	var mx := _button("Max", func() -> void:
		if Game.buy_max(id) > 0:
			Sfx.play("upgrade", 0.9)
		else:
			Sfx.play("deny"))
	mx.custom_minimum_size = Vector2(44, 40)
	mx.add_theme_font_size_override("font_size", 12)
	mx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mx)
	upgrade_rows[id] = {"row": card, "name": name_l, "desc": desc_l, "buy": b, "max": mx}


func _build_machine_tab(v: VBoxContainer) -> void:
	slots_label = _wrap_label("", 13, DIM_TEXT, 350)
	v.add_child(slots_label)
	for m in Game.machines:
		var id: String = m["id"]
		var card := _card()
		v.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(_icon_rect(_machine_icon(id), 44))
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_theme_constant_override("separation", 2)
		row.add_child(cv)
		var title := _label(m["name"], 15)
		cv.add_child(title)
		cv.add_child(_wrap_label(m["desc"], 12, DIM_TEXT, 290))
		var info := _label("", 12, MINT)
		cv.add_child(info)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 4)
		cv.add_child(btns)
		var main_b := _button("", func() -> void:
			if id in Game.unlocked_machines:
				if Game.current_machine != id:
					Sfx.play_first(["machine_switch"])
				Game.select_machine(id)
			elif Game.unlock_machine(id):
				Sfx.play("unlock")
			else:
				Sfx.play("deny"))
		main_b.add_theme_font_size_override("font_size", 13)
		main_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(main_b)
		var lvl_b := _button("", func() -> void:
			if not Game.level_machine(id):
				Sfx.play("deny"))
		lvl_b.add_theme_font_size_override("font_size", 13)
		lvl_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(lvl_b)
		var place_b := _button("", func() -> void:
			if Game.toggle_placed(id):
				Sfx.play_first(["slot_place", "clunk"])
			else:
				Sfx.play("deny")
				say("Kein freier Platz: mehr Plätze gibt es mit „Anbau“."))
		place_b.add_theme_font_size_override("font_size", 13)
		btns.add_child(place_b)
		machine_rows[id] = {"row": card, "title": title, "info": info, "main": main_b, "level": lvl_b, "place": place_b}


func _build_world_tab(v: VBoxContainer) -> void:
	v.add_child(_wrap_label("Jede Welt hat ein eigenes Album und eigene Automaten. Wer genug Sets einer Welt komplett hat, kann weiterreisen. Bekannte Welten bleiben auch nach einer Neueröffnung offen.", 12, DIM_TEXT, 350))
	for w in Game.worlds:
		var id: String = w["id"]
		var card := _card()
		v.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var ic := Art.tex("icons/world_%s.png" % id)
		if ic:
			row.add_child(_icon_rect(ic, 40))
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cv)
		cv.add_child(_label(w["name"], 16, Color(w["color"]).lightened(0.3)))
		cv.add_child(_wrap_label(w["desc"], 12, DIM_TEXT, 290))
		var info := _label("", 12, MINT)
		cv.add_child(info)
		var b := _button("", func() -> void:
			if id in Game.unlocked_worlds:
				Sfx.play_first(["machine_switch"])
				Game.go_to_world(id)
			elif Game.travel(id):
				Sfx.play_pref(["travel", "prestige"])
			else:
				Sfx.play("deny"))
		b.add_theme_font_size_override("font_size", 13)
		cv.add_child(b)
		world_rows[id] = {"row": card, "info": info, "button": b}
	v.add_child(HSeparator.new())
	golden_label = _wrap_label("", 14, GOLD, 350)
	v.add_child(golden_label)
	golden_btn = _button("", func() -> void:
		if Game.build_golden():
			Sfx.play("golden")
			_show_ending()
		else:
			Sfx.play("deny"))
	golden_btn.theme_type_variation = "BigButton"
	v.add_child(golden_btn)


func _build_prestige_tab(v: VBoxContainer) -> void:
	prestige_info = _wrap_label("", 13, Color.WHITE, 350)
	v.add_child(prestige_info)
	prestige_btn = _button("", func() -> void:
		var gain := Game.prestige_gain()
		if gain < 1:
			Sfx.play("deny")
			return
		_ask("Laden neu eröffnen?\n\nMünzen, Upgrades, Automaten und ihre Stufen werden zurückgesetzt.\nAlbum, Erfolge, Welten und Goldmarken bleiben.\n\nDu bekommst %d Goldmarken." % gain, func() -> void:
			clear_tray_requested.emit()
			Game.do_prestige()
			Sfx.play("prestige")
			toast("Neueröffnung!", "+%d Goldmarken" % gain)))
	prestige_btn.theme_type_variation = "BigButton"
	prestige_btn.custom_minimum_size = Vector2(0, 46)
	v.add_child(prestige_btn)
	var gm_row := HBoxContainer.new()
	v.add_child(gm_row)
	var gm_icon := Art.scaled("ui/goldmarke.png", 2)
	if gm_icon:
		gm_row.add_child(_icon_rect(gm_icon, 32))
	goldmarken_label = _label("", 16, GOLD)
	gm_row.add_child(goldmarken_label)
	for p in Game.prestige_upgrades:
		var id: String = p["id"]
		var card := _card()
		v.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var ic := Art.tex("icons/upgrades/%s.png" % id)
		if ic:
			row.add_child(_icon_rect(ic, 32))
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		var name_l := _label("", 15)
		tv.add_child(name_l)
		tv.add_child(_wrap_label(p["desc"], 12, DIM_TEXT, 200))
		var b := _button("", func() -> void:
			if Game.buy_prestige(id):
				Sfx.play("bless")
			else:
				Sfx.play("deny"))
		b.custom_minimum_size = Vector2(96, 40)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 13)
		row.add_child(b)
		prestige_rows[id] = {"name": name_l, "buy": b}


func _build_overlay(title: String) -> PanelContainer:
	if dim == null:
		dim = ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.size = Vector2(1280, 720)
		dim.visible = false
		add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(80, 30)
	panel.custom_minimum_size = Vector2(1120, 660)
	panel.size = Vector2(1120, 660)
	panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#241c33")
	bg.set_corner_radius_all(14)
	bg.border_color = Color("#4e3f63")
	bg.set_border_width_all(3)
	if _theme:
		panel.theme = _theme
	else:
		panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := _label(title, 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	panel.set_meta("head", head)
	head.add_child(_button("Schließen", func() -> void: _toggle_overlay(panel)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	panel.set_meta("scroll", sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	panel.set_meta("list", list)
	return panel


func _build_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	_themed(pause_panel)
	if _theme == null:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#241c33")
		bg.border_color = Color("#4e3f63")
		bg.set_border_width_all(3)
		bg.set_corner_radius_all(14)
		pause_panel.add_theme_stylebox_override("panel", bg)
	pause_panel.visible = false
	add_child(pause_panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	pause_panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var t := _label("Menü", 30, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var entries := [
		["Weiter", toggle_pause],
		["Einstellungen", open_settings],
		["Hauptmenü", func() -> void:
			clear_tray_requested.emit()
			Game.stop()
			get_tree().change_scene_to_file(MENU_SCENE)],
		["Spielstand löschen", func() -> void:
			_ask("Wirklich ALLES löschen? Album, Erfolge, Welten und Goldmarken sind dann weg.", func() -> void:
				clear_tray_requested.emit()
				Game.reset_game()
				toggle_pause())],
		["Speichern & Beenden", func() -> void:
			Game.save_game()
			get_tree().quit()],
	]
	for e in entries:
		var b := _button(e[0], e[1])
		b.theme_type_variation = "BigButton"
		b.custom_minimum_size = Vector2(340, 50)
		b.add_theme_font_size_override("font_size", 22)
		v.add_child(b)

	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.closed.connect(func() -> void:
		dim.visible = pause_panel.visible or album_panel.visible or ach_panel.visible)


func toggle_pause() -> void:
	var opening := not pause_panel.visible
	album_panel.visible = false
	ach_panel.visible = false
	pause_panel.visible = opening
	dim.visible = opening
	if opening:
		Sfx.play("ui_open")
		pause_panel.reset_size()
		pause_panel.position = ((Vector2(1280, 720) - pause_panel.size) / 2.0).round()
	else:
		Sfx.play_pref(["ui_back", "ui_close"])


func open_settings() -> void:
	dim.visible = true
	settings_panel.open()


# --- Story ----------------------------------------------------------------

func _build_story() -> void:
	story_panel = PanelContainer.new()
	_themed(story_panel)
	story_panel.position = Vector2(140, 470)
	story_panel.custom_minimum_size = Vector2(720, 200)
	story_panel.size = Vector2(720, 200)
	story_panel.visible = false
	add_child(story_panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	story_panel.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	m.add_child(h)
	story_portrait = TextureRect.new()
	story_portrait.custom_minimum_size = Vector2(128, 128)
	story_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	story_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(story_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	story_name = _label("", 20, GOLD)
	v.add_child(story_name)
	story_label = _wrap_label("", 18, Color.WHITE, 520)
	story_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(story_label)
	v.add_child(_label("Klicken oder Leertaste: weiter", 12, Color(1, 1, 1, 0.45)))


func _on_story_event(trigger: String) -> void:
	var lines: Array = []
	if trigger == "prestige_line":
		var l: Dictionary = Story.random_prestige_line()
		if not l.is_empty():
			lines.append(l)
	else:
		lines = Story.lines_for(trigger)
	if lines.is_empty():
		return
	if trigger == "legendary_first":
		# erst nach der Legendär-Animation
		await get_tree().create_timer(1.8).timeout
	_story_queue.append_array(lines)
	if not story_panel.visible:
		_next_story_line()


func _next_story_line() -> void:
	if _story_queue.is_empty():
		story_panel.visible = false
		return
	var item: Dictionary = _story_queue.pop_front()
	story_name.text = item["name"]
	story_name.add_theme_color_override("font_color", item["color"])
	story_name.visible = item["name"] != ""
	story_portrait.texture = item["portrait"]
	story_portrait.visible = story_portrait.texture != null
	story_label.text = item["text"]
	# Erzähler ohne Namen: kursiv wirkender, gedämpfter Text
	story_label.add_theme_color_override("font_color", Color.WHITE if item["name"] != "" else Color(0.85, 0.85, 0.95))
	story_label.visible_ratio = 0.0
	story_panel.visible = true
	Sfx.play_first(["story_blip", "ui_hover"], 1.0, -4.0)
	var tw := story_label.create_tween()
	tw.tween_property(story_label, "visible_ratio", 1.0, clampf(item["text"].length() * 0.02, 0.2, 1.5))


# --- Dialoge --------------------------------------------------------------

func _build_dialogs() -> void:
	confirm = ConfirmationDialog.new()
	confirm.title = "Bestätigen"
	confirm.ok_button_text = "Ja"
	confirm.cancel_button_text = "Abbrechen"
	confirm.confirmed.connect(func() -> void:
		Sfx.play_first(["ui_confirm"])
		_confirm_action.call())
	add_child(confirm)
	info_dialog = AcceptDialog.new()
	info_dialog.ok_button_text = "Weiter"
	add_child(info_dialog)


func _ask(text: String, action: Callable) -> void:
	_confirm_action = action
	confirm.dialog_text = text
	confirm.popup_centered()


func _info(title: String, text: String) -> void:
	info_dialog.title = title
	info_dialog.dialog_text = text
	info_dialog.popup_centered()


func _show_offline_report() -> void:
	var r := Game.offline_report
	if r.is_empty():
		return
	Sfx.play_first(["offline_welcome"])
	_info("Willkommen zurück!", "Du warst %s weg.\nDeine Vitrinen haben in der Zeit %s Münzen verdient." % [
		Fmt.duration(r["seconds"]), Fmt.num(r["amount"])])
	Game.offline_report = {}


func _show_ending() -> void:
	var s := Game.stats
	_info("Der Goldene Automat!", ("Geschafft! Der Goldene Automat steht in deiner Sternenstation.\n\n" +
		"Spielzeit: %s\nKapseln geöffnet: %s\nFiguren: %d/%d\nLegendäre Figuren: %d\nNeueröffnungen: %d\nErfolge: %d/%d\n\n" +
		"Du kannst weiterspielen, die Alben vervollständigen und die restlichen Erfolge holen.") % [
		Fmt.duration(s["play_time"]), Fmt.num(s["capsules_opened"]), Game.album_count(), Game.figures.size(),
		int(s["legendaries"]), int(s["prestiges"]), Game.achievements.size(), Game.achievement_list.size()])


func _toggle_overlay(panel: PanelContainer) -> void:
	var opening := not panel.visible
	album_panel.visible = false
	ach_panel.visible = false
	panel.visible = opening
	dim.visible = opening
	if panel == album_panel:
		Sfx.play_pref(["album_page", "ui_open"] if opening else ["album_page", "ui_close"], 1.0 if opening else 0.9)
	else:
		Sfx.play("ui_open" if opening else "ui_close")
	if opening:
		if panel == album_panel:
			album_world = Game.current_world()
			_fill_album()
		else:
			_fill_achievements()


# --- Inhalte --------------------------------------------------------------

func _fill_album() -> void:
	for child in album_list.get_children():
		child.queue_free()
	var w: Dictionary = Game.world_by_id[album_world]
	# Welt-Auswahl
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	album_list.add_child(wrow)
	for ww in Game.worlds:
		var wid: String = ww["id"]
		var known: bool = wid in Game.unlocked_worlds or Game.album_count(wid) > 0
		var b := _button("%s  %d/%d" % [ww["name"], Game.album_count(wid), Game.album_size(wid)] if known else "???", func() -> void:
			album_world = wid
			Sfx.play_pref(["album_page", "ui_click"])
			_fill_album())
		b.disabled = not known
		b.toggle_mode = false
		if wid == album_world:
			b.modulate = Color(1.2, 1.15, 0.8)
		b.add_theme_font_size_override("font_size", 15)
		wrow.add_child(b)
	var head := _wrap_label("%s: %d/%d Figuren  ·  Sets %d/%d  ·  Insgesamt %d/%d  ·  Jedes Set +%d %% auf alle Münzen, jede Figur bringt passives Einkommen, Duplikate erhöhen ihre Stufe." % [
		w["name"], Game.album_count(album_world), Game.album_size(album_world), Game.complete_sets(album_world), Game.world_sets(album_world).size(),
		Game.album_count(), Game.figures.size(), int(Game.set_bonus * 100)], 14, Color(1, 1, 1, 0.8), 1060)
	album_list.add_child(head)

	if Game.fusion_unlocked():
		var fr := HBoxContainer.new()
		fr.add_theme_constant_override("separation", 10)
		album_list.add_child(fr)
		fr.add_child(_label("Fusion:", 18, Color("#c77dff")))
		for rarity in Game.FUSION_NEXT:
			var r: Dictionary = Game.rarity_by_id[rarity]
			var nxt: Dictionary = Game.rarity_by_id[Game.FUSION_NEXT[rarity]]
			var rr: String = rarity
			var b := _button("%d %s → 1 %s  (%d Duplikate)" % [Game.FUSION_COST[rarity], r["name"], nxt["name"], Game.fusion_dupes(rarity)], func() -> void:
				var res := Game.fuse(rr)
				if res.is_empty():
					Sfx.play("deny")
					return
				Sfx.play("fusion")
				toast("Fusion!", "%s (%s)%s" % [res["figure"]["name"], res["figure"]["rarity_name"], "  NEU!" if res["is_new"] else ""])
				_fill_album())
			b.disabled = not Game.can_fuse(rarity)
			fr.add_child(b)

	for s in Game.world_sets(album_world):
		var done := Game.is_set_complete(s)
		var have_n := 0
		for fig in s["figures"]:
			if Game.owned.has(fig["id"]):
				have_n += 1
		var trow := HBoxContainer.new()
		album_list.add_child(trow)
		var badge := Art.scaled("ui/set_badge_%s.png" % s["id"], 2)
		if badge:
			trow.add_child(_icon_rect(badge, 32))
		trow.add_child(_label("%s  %d/%d%s" % [s["name"], have_n, s["figures"].size(), "   ✓ komplett" if done else ""], 20, Color(s["color"])))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		album_list.add_child(grid)
		for fig in s["figures"]:
			grid.add_child(_album_cell(s, Game.figures[fig["id"]]))


func _album_cell(s: Dictionary, fig: Dictionary) -> Control:
	var have: int = int(Game.owned.get(fig["id"], 0))
	var r: Dictionary = Game.rarity_by_id[fig["rarity"]]
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(256, 84)
	var art_sb := Art.stylebox("ui/album_slot_%s%s.png" % [fig["rarity"], "" if have > 0 else "_locked"], 6, 2, 10.0)
	if art_sb:
		cell.add_theme_stylebox_override("panel", art_sb)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(s["color"]).darkened(0.45) if have > 0 else Color(0.16, 0.14, 0.2)
		sb.border_color = Color(r["color"])
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		cell.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	cell.add_child(hb)
	var tex := Art.figure(fig["id"])
	var sil := Art.tex("figures/silhouettes/%s.png" % fig["id"])
	if have == 0 and sil:
		tex = sil
	if tex:
		var tr := _icon_rect(tex, 64)
		if have == 0 and sil == null:
			tr.modulate = Color(0, 0, 0, 0.6)   # Silhouette, solange nicht gesammelt
		hb.add_child(tr)
	else:
		# Noch ohne Grafik: farbiger Platzhalter
		var ph := ColorRect.new()
		ph.custom_minimum_size = Vector2(64, 64)
		ph.color = Color(s["color"]) if have > 0 else Color(0, 0, 0, 0.35)
		hb.add_child(ph)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 13)
	if have > 0:
		var inc := Game.figure_income(fig["id"]) * Game.figure_level(fig["id"]) * (1.0 + Game._eff("passive")) * Game.global_mult()
		l.text = "%s\n%s · x%d\nStufe %d · %s/s" % [fig["name"], r["name"], have, Game.figure_level(fig["id"]), Fmt.rate(inc)]
		var fl := Story.flavor(fig["id"])
		if fl != "":
			cell.tooltip_text = "%s: %s" % [fig["name"], fl]
	else:
		l.text = "???\n%s" % r["name"]
	hb.add_child(l)
	return cell


func _fill_achievements() -> void:
	for child in ach_list.get_children():
		child.queue_free()
	var s := Game.stats
	ach_list.add_child(_label("Erfolge %d/%d  ·  +%d %% auf alle Münzen" % [
		Game.achievements.size(), Game.achievement_list.size(), int(Game.achievement_bonus * 100 * Game.achievements.size())], 18, GOLD))
	var st := _wrap_label("Spielzeit %s  ·  Kapseln %s (davon nebenbei %s)  ·  Verdient %s  ·  Legendär %d  ·  Jackpots %d  ·  Neueröffnungen %d  ·  Fusionen %d  ·  Beste Kombo %d" % [
		Fmt.duration(s["play_time"]), Fmt.num(s["capsules_opened"]), Fmt.num(s["bg_capsules"]), Fmt.num(s["total_earned"]),
		int(s["legendaries"]), int(s["jackpots"]), int(s["prestiges"]), int(s["fusions"]), int(s["max_combo"])], 14, Color(1, 1, 1, 0.75), 1060)
	ach_list.add_child(st)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	ach_list.add_child(grid)
	for a in Game.achievement_list:
		var got := Game.achievements.has(a["id"])
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(345, 64)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#4a3a1e") if got else Color(0.16, 0.14, 0.2)
		sb.border_color = GOLD if got else Color(0.35, 0.32, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		cell.add_theme_stylebox_override("panel", sb)
		var ah := HBoxContainer.new()
		cell.add_child(ah)
		var trophy := Art.tex("icons/trophy_%s.png" % _trophy_tier(a)) if got else Art.tex("icons/lock.png")
		if trophy:
			ah.add_child(_icon_rect(trophy, 32))
		var v := VBoxContainer.new()
		ah.add_child(v)
		v.add_child(_label(a["name"], 16, GOLD if got else Color(0.7, 0.7, 0.75)))
		var progress := ""
		if not got:
			progress = "  (%s/%s)" % [Fmt.num(minf(Game.stat(a["stat"]), a["value"])), Fmt.num(a["value"])]
		v.add_child(_wrap_label(a["desc"] + progress, 13, Color(1, 1, 1, 0.8 if got else 0.55), 270))
		grid.add_child(cell)


# --- Aktualisieren --------------------------------------------------------

func refresh() -> void:
	coins_label.text = Fmt.num(Game.coins)
	income_label.text = "+%s/s" % Fmt.rate(Game.income_per_sec())
	goldmarken_top.text = str(Game.goldmarken)
	goldmarken_top.tooltip_text = "Goldmarken (ausgebbar)"
	var cw: Dictionary = Game.world_by_id[Game.current_world()]
	world_btn.text = "%s  ·  %d/%d" % [cw["name"], Game.album_count(cw["id"]), Game.album_size(cw["id"])]
	var wic := Art.tex("icons/world_%s.png" % cw["id"])
	if wic:
		world_btn.icon = wic
		world_btn.add_theme_constant_override("icon_max_width", 28)
	open_all_btn.visible = Game.has_bulk_open()
	_rebuild_strip()

	# Upgrades
	for key in upgrade_rows:
		if String(key).begins_with("_head_"):
			var hd: Dictionary = upgrade_rows[key]
			var any := false
			for id in hd["members"]:
				any = any or Game.is_revealed(id)
			hd["head"].visible = any
	for u in Game.upgrades:
		var id: String = u["id"]
		var r: Dictionary = upgrade_rows[id]
		var shown := Game.is_revealed(id)
		r["row"].visible = shown
		if not shown:
			continue
		var b: Button = r["buy"]
		var mx: Button = r["max"]
		r["name"].text = "%s  %d/%d" % [u["name"], Game.level(id), int(u["max_level"])]
		if Game.is_maxed(id):
			b.text = "Max"
			b.disabled = true
			mx.disabled = true
		else:
			b.text = Fmt.num(Game.upgrade_cost(id))
			b.disabled = not Game.can_buy(id)
			mx.disabled = b.disabled

	# Automaten der aktuellen Welt
	var world := Game.current_world()
	slots_label.text = "%s  ·  Aufstellplätze %d/%d belegt. Aufgestellte Automaten laufen nebenbei von allein, der gezeigte wird gekurbelt." % [
		cw["name"], Game.placed.size(), Game.slot_count()]
	for m in Game.machines:
		var id: String = m["id"]
		var r: Dictionary = machine_rows[id]
		var in_world: bool = m.get("world", "stadt") == world
		r["row"].visible = in_world
		if not in_world:
			continue
		var unlocked: bool = id in Game.unlocked_machines
		var lv := Game.machine_level(id)
		r["title"].text = "%s  %s" % [m["name"], "★".repeat(lv)]
		r["info"].text = "Kapsel %s  ·  Wert x%s  ·  Stufe %d/%d" % [Fmt.num(Game.capsule_cost(id)), Fmt.rate(Game.machine_value_mult(id)), lv, Game.MACHINE_MAX_LEVEL]
		var mb: Button = r["main"]
		var lb: Button = r["level"]
		var pb: Button = r["place"]
		lb.visible = unlocked
		pb.visible = unlocked and Game.slot_count() > 1
		if id == Game.current_machine:
			mb.text = "Wird gezeigt"
			mb.disabled = true
		elif unlocked:
			mb.text = "Zeigen"
			mb.disabled = false
		elif not Game.machine_available(id):
			mb.text = "Braucht „%s“" % Game.prestige_by_id[m["requires_prestige"]]["name"] if m.has("requires_prestige") else "Gesperrt"
			mb.disabled = true
		else:
			mb.text = "Freischalten: %s" % Fmt.num(float(m["unlock_cost"]))
			mb.disabled = Game.coins < float(m["unlock_cost"])
		if lv >= Game.MACHINE_MAX_LEVEL:
			lb.text = "Stufe Max"
			lb.disabled = true
		else:
			lb.text = "Aufwerten: %s" % Fmt.num(Game.machine_level_cost(id))
			lb.disabled = not Game.can_level_machine(id)
		pb.text = "Abbauen" if id in Game.placed else "Aufstellen"
		pb.disabled = id == Game.current_machine or (not id in Game.placed and Game.placed.size() >= Game.slot_count())

	# Welten
	for w in Game.worlds:
		var id: String = w["id"]
		var r: Dictionary = world_rows[id]
		var b: Button = r["button"]
		var known: bool = id in Game.unlocked_worlds
		r["info"].text = "Album %d/%d  ·  Sets %d/%d" % [Game.album_count(id), Game.album_size(id), Game.complete_sets(id), Game.world_sets(id).size()]
		if id == world:
			b.text = "Du bist hier"
			b.disabled = true
		elif known:
			b.text = "Hinreisen"
			b.disabled = false
		else:
			var prev := Game.previous_world(id)
			var need := int(w["travel_sets"])
			if Game.travel_requirements_met(id):
				b.text = "Reisen: %s" % Fmt.num(float(w["travel_cost"]))
				b.disabled = Game.coins < float(w["travel_cost"])
			elif prev in Game.unlocked_worlds:
				b.text = "Braucht %d Sets in %s (%d/%d)" % [need, Game.world_by_id[prev]["name"], Game.complete_sets(prev), need]
				b.disabled = true
			else:
				b.text = "Noch unbekannt"
				b.disabled = true
	var g := Game.golden
	golden_label.text = "%s\n%s\nFiguren: %d/%d" % [g["name"], g["desc"], Game.album_count(), Game.golden_album_needed()]
	if Game.stats["golden_built"] >= 1:
		golden_btn.text = "Gebaut!"
		golden_btn.disabled = true
	elif not g.get("world", "stadt") in Game.unlocked_worlds:
		golden_btn.text = "Steht in der %s" % Game.world_by_id[g.get("world", "stadt")]["name"]
		golden_btn.disabled = true
	else:
		golden_btn.text = "Bauen: %s" % Fmt.num(float(g["cost"]))
		golden_btn.disabled = not Game.can_build_golden()

	# Goldmarken
	var gain := Game.prestige_gain()
	prestige_info.text = ("Neueröffnung: Münzen, Upgrades, Automaten und ihre Stufen starten von vorn. " +
		"Album, Erfolge, Welten und Goldmarken bleiben. Jede jemals verdiente Goldmarke bringt dauerhaft +%d %% Münzen.") % [int(Game.GOLDMARKE_BONUS * 100)]
	prestige_btn.text = "Neu eröffnen: +%d Goldmarken" % gain if gain >= 1 else "Neu eröffnen (noch zu wenig verdient)"
	prestige_btn.disabled = gain < 1
	goldmarken_label.text = "%d Goldmarken  (gesamt %d → +%s %%)" % [Game.goldmarken, Game.goldmarken_total, Fmt.num(roundf(Game.goldmarken_total * Game.GOLDMARKE_BONUS * 100))]
	for p in Game.prestige_upgrades:
		var id: String = p["id"]
		var r: Dictionary = prestige_rows[id]
		var b: Button = r["buy"]
		r["name"].text = "%s  %d/%d" % [p["name"], Game.plevel(id), int(p["max_level"])]
		if Game.prestige_maxed(id):
			b.text = "Max"
			b.disabled = true
		else:
			b.text = "%d GM" % Game.prestige_cost(id)
			b.disabled = Game.goldmarken < Game.prestige_cost(id)
