extends CanvasLayer
# Интерфейс демо «Третий шанс»: главное меню, пауза, обратный отсчёт, HUD гонки, экран результатов.
# Управляется геймпадом (ui_* действия: стик/крестовина, A, B) и клавиатурой. Данные берёт у main.gd (ссылка main).

var main: Node
var state := "hud"                 # menu | pause | hud | results
var sel := 0
var items: Array = []
var root: Control
var menu_panel: Control
var side: ColorRect
var title_lbl: Label
var sub_lbl: Label
var item_lbls: Array = []
var desc_lbl: Label
var hint_lbl: Label
var dim: ColorRect
var hud_root: Control
var lbl_rank: Label
var lbl_time: Label
var lbl_speed: Label
var lbl_alt: Label
var lbl_lvl: Label
var lbl_count: Label
var lbl_skip: Label
var lbl_stab: Label
var ov_ctl: Control
var ov_off := Vector2.ZERO
var ov_sc := 1.0
var prog_bar: ColorRect
var prog_bg: ColorRect
var dmg_ctl: Control
var map_ctl: Control
var res_panel: Control
var res_title: Label
var res_rows: Array = []
var res_btns: Array = []
var res_sub: Label
var marks: Array = []
var res_t_show := -1.0
var go_t := 0.0
var last_count := 99
var map_b := Rect2()
var map_s := 1.0
var marker_root: Control
var marker_lbls: Array = []

const CREAM := Color(0.97, 0.9, 0.75)
const ORANGE := Color(1.0, 0.58, 0.16)
const DARK := Color(0.07, 0.05, 0.03, 0.62)
const LEVEL_DESC := ["Максимальная помощь: корабль едет почти как автомобиль, сам выравнивается по крену.",
	"Сильная помощь: снос гасится, крен выравнивается.", "Помощь слабее, управление ближе к настоящему.",
	"Без гашения сноса: инерция как есть. Для тех, кто освоился.", "Всё вручную: нет удержания высоты и стабилизации, схема 2. Для психов."]

func _ready() -> void:
	layer = 10
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	_build_hud(); _build_menu(); _build_results()
	marker_root = Control.new(); marker_root.set_anchors_preset(Control.PRESET_FULL_RECT); marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(marker_root); root.move_child(marker_root, 0)
	_show_state("hud")

func _lbl(text: String, size: int, col: Color, parent: Control, pos := Vector2.ZERO) -> Label:
	var l := Label.new(); l.text = text; l.position = pos
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9)); l.add_theme_constant_override("outline_size", maxi(3, size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(l); return l

# ---------- HUD ----------
func _build_hud() -> void:
	ov_ctl = Control.new(); ov_ctl.set_anchors_preset(Control.PRESET_FULL_RECT); ov_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; ov_ctl.visible = false; root.add_child(ov_ctl); ov_ctl.draw.connect(_draw_ov)
	lbl_stab = _lbl("СТАБИЛИЗАЦИЯ ВЫКЛ  (A / T — включить)", 26, Color(1.0, 0.35, 0.25), root, Vector2(520, 800)); lbl_stab.visible = false
	lbl_skip = _lbl("A / Enter — пропустить заставку", 24, Color(1, 1, 1, 0.8), root, Vector2(1030, 835)); lbl_skip.visible = false
	hud_root = Control.new(); hud_root.set_anchors_preset(Control.PRESET_FULL_RECT); hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hud_root)
	var tl := Control.new(); tl.position = Vector2(28, 18); tl.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(tl)
	_lbl("ПОЗИЦИЯ", 16, Color(1, 1, 1, 0.65), tl, Vector2(2, 0))
	lbl_rank = _lbl("1/11", 70, CREAM, tl, Vector2(0, 14))
	var tc := Control.new(); tc.set_anchors_preset(Control.PRESET_CENTER_TOP); tc.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(tc)
	lbl_time = _lbl("0:00.0", 44, CREAM, tc, Vector2(-80, 14))
	prog_bg = ColorRect.new(); prog_bg.color = Color(0, 0, 0, 0.45); prog_bg.position = Vector2(-220, 72); prog_bg.size = Vector2(440, 8); tc.add_child(prog_bg)
	prog_bar = ColorRect.new(); prog_bar.color = ORANGE; prog_bar.position = Vector2(-220, 72); prog_bar.size = Vector2(0, 8); tc.add_child(prog_bar)
	lbl_lvl = _lbl("", 16, Color(1, 1, 1, 0.55), tc, Vector2(-220, 86))
	var bl := Control.new(); bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); bl.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(bl)
	lbl_speed = _lbl("0", 76, CREAM, bl, Vector2(28, -170))
	lbl_alt = _lbl("", 22, Color(1, 1, 1, 0.85), bl, Vector2(34, -62))
	var bc := Control.new(); bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); bc.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(bc)
	dmg_ctl = Control.new(); dmg_ctl.position = Vector2(-150, -70); dmg_ctl.size = Vector2(300, 52); dmg_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; bc.add_child(dmg_ctl)
	dmg_ctl.draw.connect(_draw_damage)
	var br := Control.new(); br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); br.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(br)
	map_ctl = Control.new(); map_ctl.position = Vector2(-292, -292); map_ctl.size = Vector2(268, 268); map_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; br.add_child(map_ctl)
	map_ctl.draw.connect(_draw_map)
	var cc := Control.new(); cc.set_anchors_preset(Control.PRESET_CENTER); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(cc)
	lbl_count = _lbl("", 200, ORANGE, cc, Vector2(-120, -170)); lbl_count.add_theme_constant_override("outline_size", 22)

func _draw_damage() -> void:
	var c := dmg_ctl
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.35))
	var groups := [["main", "ТЯГА"], ["lift", "ВЗЛЁТ"], ["shunt", "МАНЕВР"]]
	var x := 10.0
	for g in groups:
		var names := []
		for nm in main.engines: if main.engines[nm]["kind"] == g[0]: names.append(nm)
		names.sort()
		var w := 15.0 * names.size()
		c.draw_string(ThemeDB.fallback_font, Vector2(x, 14), g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
		var i := 0
		for nm in names:
			var ok: bool = main.parts.has(nm)
			c.draw_rect(Rect2(x + i * 15.0, 22, 12, 22), Color(0.35, 0.9, 0.45, 0.9) if ok else Color(0.9, 0.2, 0.15, 0.9))
			i += 1
		x += maxf(w, 46.0) + 14.0

func _map_setup() -> void:
	var lo := Vector2(1e12, 1e12); var hi := Vector2(-1e12, -1e12)
	for p in main.trk_pts: lo = lo.min(p); hi = hi.max(p)
	var sz := hi - lo
	map_s = minf(240.0 / maxf(sz.x, 1.0), 240.0 / maxf(sz.y, 1.0))
	map_b = Rect2(lo, sz)

func _mp(p: Vector2) -> Vector2:
	return Vector2(14.0, 14.0) + (p - map_b.position) * map_s + Vector2((240.0 - map_b.size.x * map_s) * 0.5, (240.0 - map_b.size.y * map_s) * 0.5)

func _draw_map() -> void:
	var c := map_ctl
	if map_b.size == Vector2.ZERO: _map_setup()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.4))
	var pts := PackedVector2Array()
	var step := 3
	for i in range(0, main.trk_pts.size(), step): pts.append(_mp(main.trk_pts[i]))
	if pts.size() > 1: c.draw_polyline(pts, Color(0.95, 0.85, 0.65, 0.85), 3.0, true)
	for br in main.branches:
		var bp := PackedVector2Array(); for p in (br["pts"] as PackedVector2Array): bp.append(_mp(p))
		if bp.size() > 1: c.draw_polyline(bp, Color(1.0, 0.55, 0.2, 0.95), 2.0, true)
	var s0: float = main.s0 if main.s0 >= 0.0 else 0.0
	c.draw_circle(_mp((main._track_at(s0) as Array)[0]), 5.0, Color(0.3, 1.0, 0.4))
	c.draw_circle(_mp((main._track_at(s0 + main.race_len) as Array)[0]), 5.0, Color(1.0, 0.25, 0.2))
	for b in main.bots:
		var q := (b["rb"] as SB).gpos
		c.draw_circle(_mp(Vector2(q.x, q.z)), 3.0, Color(0.6, 0.75, 1.0, 0.9) if not b["fin"] else Color(0.6, 0.6, 0.6, 0.6))
	var sp: Vector3 = main.ship.gpos; var fw: Vector3 = -main.ship.gtf.basis.z
	var pp := _mp(Vector2(sp.x, sp.z)); var d := Vector2(fw.x, fw.z).normalized()
	var n := Vector2(-d.y, d.x)
	c.draw_colored_polygon(PackedVector2Array([pp + d * 9.0, pp - d * 6.0 + n * 5.0, pp - d * 6.0 - n * 5.0]), Color(1, 1, 1))

func _ovp(p: Vector2) -> Vector2:
	return ov_off + (p - map_b.position) * ov_sc

func _draw_ov() -> void:                                                    # заставка: общий план всей трассы, маршрут прорисовывается от старта к финишу
	var u: float = main.intro_t(); var c := ov_ctl
	var a := 1.0 - smoothstep(5.8, 7.0, u)
	if a <= 0.0: return
	if map_b.size == Vector2.ZERO: _map_setup()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.02, 0.012, 0.008, 0.66 * a))
	var area := Rect2(c.size.x * 0.07, c.size.y * 0.17, c.size.x * 0.86, c.size.y * 0.68)
	ov_sc = minf(area.size.x / maxf(map_b.size.x, 1.0), area.size.y / maxf(map_b.size.y, 1.0))
	ov_off = area.position + (area.size - map_b.size * ov_sc) * 0.5
	var rev := smoothstep(0.0, 1.0, clampf(u / 4.6, 0.0, 1.0))
	var n: int = int(main.trk_pts.size() * rev)
	var pts := PackedVector2Array()
	for i in range(0, n, 3): pts.append(_ovp(main.trk_pts[i]))
	if pts.size() > 1: c.draw_polyline(pts, Color(0.97, 0.88, 0.68, a), 5.0, true)
	var ba := clampf((u - 3.2) / 1.4, 0.0, 1.0) * a
	if ba > 0.0:
		for br in main.branches:
			var bp := PackedVector2Array(); for p in (br["pts"] as PackedVector2Array): bp.append(_ovp(p))
			if bp.size() > 1: c.draw_polyline(bp, Color(1.0, 0.54, 0.12, ba), 4.0, true)
	var f := ThemeDB.fallback_font
	var s0: float = main.s0 if main.s0 >= 0.0 else 0.0
	var ps := _ovp((main._track_at(s0) as Array)[0]); var pf2 := _ovp((main._track_at(s0 + main.race_len) as Array)[0])
	c.draw_circle(ps, 9.0, Color(0.3, 1.0, 0.4, a)); c.draw_string(f, ps + Vector2(14, -10), "СТАРТ", HORIZONTAL_ALIGNMENT_LEFT, 300, 28, Color(0.3, 1.0, 0.4, a))
	if rev > 0.92:
		var fa := clampf((rev - 0.92) / 0.08, 0.0, 1.0) * a
		c.draw_circle(pf2, 9.0, Color(1.0, 0.3, 0.2, fa)); c.draw_string(f, pf2 + Vector2(14, -10), "ФИНИШ", HORIZONTAL_ALIGNMENT_LEFT, 300, 28, Color(1.0, 0.3, 0.2, fa))
	c.draw_string(f, Vector2(c.size.x * 0.07, c.size.y * 0.12), "ТРАССА · %d КМ" % int(round(main.race_len / 1000.0)), HORIZONTAL_ALIGNMENT_LEFT, 900, 46, Color(1.0, 0.54, 0.12, a))
	if ba > 0.0: c.draw_string(f, Vector2(c.size.x * 0.07, c.size.y * 0.89), "оранжевым — срезки", HORIZONTAL_ALIGNMENT_LEFT, 700, 26, Color(1.0, 0.54, 0.12, ba))

# ---------- Меню / пауза ----------
# Страницы: main (меню/пауза) → settings → controls (→ keys, advanced → organ:<ключ>) | sound | camera
var page := "main"
var scroll: ScrollContainer
var vbox: VBoxContainer
var page_lbl: Label
var plot: Control
var capturing := ""                    # id действия, для которого ждём нажатие клавиши
var opened_frame := -1
const ORGAN_SHORT := {"thr": "Газ (тяговые моторы)", "pitch": "Тангаж", "yaw": "Рыскание", "roll": "Крен", "shunt": "Маневровые (вектор)", "boost": "Усиление маневровых", "lift": "Взлётные моторы"}

class PlotCtl extends Control:
	var ui
	func _init() -> void:
		custom_minimum_size = Vector2(560, 520); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if not ui.page.begins_with("organ:"): return
		var organ: String = ui.page.substr(6)
		var tn = ui.main.tune
		var f := ThemeDB.fallback_font
		var s: float = tn.v[organ + ".start"]; var mx: float = tn.v[organ + ".max"]
		var t: float = tn.time_of(organ)
		var lo := minf(0.0, minf(s, mx)); var hi := maxf(0.0, maxf(s, mx))
		if hi - lo < 0.0001: hi = lo + 1.0
		var titles := ["Стик / курок геймпада: усилие по отклонению", "Кнопка геймпада / клавиша-стрелка: усилие по времени удержания"]
		for pi in 2:
			var oy := pi * 270.0
			draw_rect(Rect2(0, oy, 560, 250), Color(0.04, 0.025, 0.015, 0.78))
			draw_string(f, Vector2(10, oy + 20), titles[pi], HORIZONTAL_ALIGNMENT_LEFT, 540, 15, Color(1.0, 0.78, 0.4))
			var r := Rect2(54, oy + 34, 490, 170)
			for i in 11:
				var x := r.position.x + r.size.x * i / 10.0
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.10 if i % 5 else 0.25))
				var y := r.position.y + r.size.y * i / 10.0
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.10 if i % 5 else 0.25))
			for i: int in [0, 5, 10]:
				var val: float = lo + (hi - lo) * i / 10.0
				draw_string(f, Vector2(6, r.end.y - r.size.y * i / 10.0 + 4), "%.2f" % val, HORIZONTAL_ALIGNMENT_LEFT, 46, 12, Color(0.8, 0.8, 0.8))
				var xv := (1.0 * i / 10.0) if pi == 0 else (t * i / 10.0)
				draw_string(f, Vector2(r.position.x + r.size.x * i / 10.0 - 12, r.end.y + 16), "%.2f" % xv, HORIZONTAL_ALIGNMENT_LEFT, 40, 12, Color(0.8, 0.8, 0.8))
			draw_string(f, Vector2(r.position.x, r.end.y + 36), "отклонение 0…1" if pi == 0 else "время удержания, с", HORIZONTAL_ALIGNMENT_LEFT, 490, 12, Color(0.65, 0.65, 0.65))
			var dz: float = clampf(float(ui.main.cfg["deadzone"]), 0.0, 0.9) if pi == 0 else 0.0
			if dz > 0.0:
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x * dz, r.size.y), Color(0.9, 0.25, 0.2, 0.22))
				draw_string(f, Vector2(r.position.x + 4, r.position.y + 14), "мёртвая зона", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(1, 0.55, 0.5))
			var pts := PackedVector2Array()
			for i in 81:
				var u := i / 80.0
				var e: float = tn.effort(organ, maxf(u, 0.0001)) if i > 0 else s
				pts.append(Vector2(r.position.x + r.size.x * (dz + (1.0 - dz) * u), r.end.y - r.size.y * (e - lo) / (hi - lo)))
			draw_polyline(pts, Color(1, 0.8, 0.25), 2.5)
			draw_circle(pts[0], 5, Color(0.4, 1, 0.5)); draw_circle(pts[80], 5, Color(1, 0.4, 0.4))

func _build_menu() -> void:
	dim = ColorRect.new(); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.color = Color(0.05, 0.03, 0.02, 0.22); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(dim)
	menu_panel = Control.new(); menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT); menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(menu_panel)
	side = ColorRect.new(); side.position = Vector2(0, 0); side.size = Vector2(760, 2000); side.color = Color(0.04, 0.025, 0.015, 0.72); side.mouse_filter = Control.MOUSE_FILTER_IGNORE; menu_panel.add_child(side)
	title_lbl = _lbl("КАРНАВАЛЬСКАЯ\nГОНКА", 76, CREAM, menu_panel, Vector2(90, 70))
	sub_lbl = _lbl("Космоолухи · демо-прототип", 26, ORANGE, menu_panel, Vector2(96, 290))
	page_lbl = _lbl("", 38, ORANGE, menu_panel, Vector2(90, 40)); page_lbl.custom_minimum_size = Vector2(620, 0); page_lbl.size = Vector2(620, 90); page_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll = ScrollContainer.new(); scroll.position = Vector2(90, 330); scroll.size = Vector2(640, 380); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE; menu_panel.add_child(scroll)
	vbox = VBoxContainer.new(); vbox.custom_minimum_size = Vector2(620, 0); vbox.add_theme_constant_override("separation", 8); vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE; scroll.add_child(vbox)
	desc_lbl = _lbl("", 20, Color(1, 1, 1, 0.75), menu_panel, Vector2(96, 730))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc_lbl.custom_minimum_size = Vector2(620, 0); desc_lbl.size = Vector2(620, 80)
	hint_lbl = _lbl("↑↓ выбор    A / Enter подтвердить    ◀ ▶ изменить    B / Esc назад", 18, Color(1, 1, 1, 0.5), menu_panel, Vector2(96, 842))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint_lbl.custom_minimum_size = Vector2(620, 0); hint_lbl.size = Vector2(620, 40)
	plot = PlotCtl.new(); plot.ui = self; plot.position = Vector2(800, 120); menu_panel.add_child(plot)

func _bool_item(label: String, key: String, hint := "") -> Dictionary:
	return {"t": "%s:  %s" % [label, "ВКЛ" if main.cfg[key] else "выкл"], "d": hint, "a": func(): _tog(key), "s": func(_d): _tog(key)}

func _num_item(label: String, get_v: Callable, set_v: Callable, step: float, lo: float, hi: float, hint := "", fmt := "%.2f") -> Dictionary:
	var stepf := func(d: int): set_v.call(clampf(snappedf(float(get_v.call()) + d * step, step * 0.01), lo, hi))
	return {"t": ("%s:  ◀ " + fmt + " ▶") % [label, get_v.call()], "d": hint, "a": func(): stepf.call(1), "s": stepf}

func _tv_item(label: String, key: String, step: float, lo: float, hi: float, hint := "", fmt := "%.2f") -> Dictionary:
	return _num_item(label, func(): return main.tune.v[key], func(x): _set_tv(key, x), step, lo, hi, hint, fmt)

func _page_items() -> Array:
	var lv: String = main.LEVEL_NAMES[main._lvl()]
	var lvl_item := {"t": "Сложность:  ◀ %s ▶" % lv, "d": main.LEVEL_TAGS[main._lvl()] + "\n" + LEVEL_DESC[main._lvl()], "s": func(d): _change_level(d), "a": func(): _change_level(1), "id": "level"}
	var back := {"t": "Назад", "a": func(): back_page()}
	var it: Array = []
	match page:
		"main":
			if state == "menu":
				it = [{"t": "Начать гонку", "a": func(): _start_race()}, lvl_item, {"t": "Настройки", "a": func(): goto_page("settings")}, {"t": "Выход", "a": func(): get_tree().quit()}]
			elif state == "pause":
				it = [{"t": "Продолжить", "a": func(): close_pause()}, {"t": "Начать заново", "a": func(): _restart()}, lvl_item, {"t": "Настройки", "a": func(): goto_page("settings")}, {"t": "В главное меню", "a": func(): _to_menu()}]
		"settings":
			it = [{"t": "Управление", "a": func(): goto_page("controls")}, {"t": "Звук", "a": func(): goto_page("sound")}, {"t": "Камера", "a": func(): goto_page("camera")}, back]
		"controls":
			it = [{"t": "Схема геймпада:  ◀ %d ▶" % (main.scheme + 1), "d": "Схема 1: левый стик — тангаж (вверх-вниз) и крен (влево-вправо), бамперы LB/RB — рыскание, правый стик — маневровые (всё переназначается). Схема 2: каждый стик управляет своим бортом маневровых.", "s": func(_d): _flip_scheme(), "a": func(): _flip_scheme()},
				_bool_item("Левый стик, влево-вправо: инверсия", "inv_lx"), _bool_item("Левый стик, вверх-вниз: инверсия", "inv_ly"),
				_bool_item("Правый стик, влево-вправо: инверсия", "inv_rx"), _bool_item("Правый стик, вверх-вниз: инверсия", "inv_ry"),
				_bool_item("Клавиатура: инверсия тангажа (стрелки вверх-вниз)", "inv_kb_pitch"),
				_num_item("Мёртвая зона стиков", func(): return float(main.cfg["deadzone"]), func(x): _set_cfg("deadzone", x), 0.01, 0.0, 0.4, "Отклонение стика, меньше которого он считается нулевым."),
				{"t": "Кнопки геймпада…", "d": "Переназначение стиков, курков и кнопок геймпада: тангаж, крен, рыскание, газ и другие.", "a": func(): goto_page("pad")},
				{"t": "Клавиши клавиатуры…", "d": "Переназначение клавиш: газ, взлётные, повороты, маневровые, камера и другие.", "a": func(): goto_page("keys")},
				{"t": "Расширенные…", "d": "Степень нажатия: как растёт усилие от отклонения стика или от времени удержания кнопки.", "a": func(): goto_page("advanced")},
				{"t": "Сбросить управление", "d": "Вернуть инверсии, схему, мёртвую зону и клавиши к значениям по умолчанию.", "a": func(): _reset_controls()}, back]
		"pad":
			for pb in main.PADBIND:
				var pid: String = pb[0]
				var pcap: bool = capturing == "pad:" + pid
				it.append({"t": "%s:  %s" % [pb[1], "нажмите кнопку или отклоните стик…" if pcap else main.pad_name(main.pad[pid])], "d": "A / Enter — выбрать, затем нажать кнопку, курок или отклонить стик. Esc или Start — отмена. Если назначение занято, действия поменяются местами.", "a": func(): capturing = "pad:" + pid; _refresh_items()})
			it.append({"t": "Сбросить кнопки геймпада", "a": func(): _reset_pad()})
			it.append(back)
		"keys":
			for kb in main.KEYBIND:
				var id: String = kb[0]
				var cap: bool = capturing == id
				it.append({"t": "%s:  %s" % [kb[1], "нажмите клавишу…" if cap else OS.get_keycode_string(main.keys[id]).to_upper()], "d": "Enter / A — выбрать, затем нажать новую клавишу. Esc — отмена. Если клавиша занята, действия поменяются клавишами.", "a": func(): capturing = id; _refresh_items()})
			it.append({"t": "Сбросить клавиши", "a": func(): _reset_keys()})
			it.append(back)
		"advanced":
			for o in main.tune.ORGANS:
				var key: String = o[0]
				it.append({"t": ORGAN_SHORT.get(key, o[1]), "d": o[2], "a": func(): goto_page("organ:" + key)})
			it.append({"t": "Сбросить все кривые", "d": "Вернуть степень нажатия всех органов к значениям по умолчанию.", "a": func(): _reset_organ(""), "d2": ""})
			it.append(back)
		"sound":
			it = [_num_item("Общая громкость", func(): return float(main.cfg["vol"]), func(x): _set_vol(x), 0.1, 0.0, 1.0, "Общая громкость игры.", "%.1f"),
				_num_item("Громкость музыки", func(): return float(main.cfg["music"]), func(x): _set_music(x), 0.1, 0.0, 1.0, "Музыка меню, гонки и результатов.", "%.1f"), back]
		"camera":
			it = [_tv_item("Плавность следования камеры", "cam_smooth", 0.1, 0.0, 2.0, "0 — жёсткая камера, больше — плавнее отстаёт от корабля.", "%.1f"),
				_tv_item("Тряска камеры", "cam_shake", 0.1, 0.0, 2.0, "Амплитуда тряски от тяги, скорости и ударов. 0 — без тряски.", "%.1f"), back]
		_:
			if page.begins_with("organ:"):
				var o: String = page.substr(6)
				it = [_tv_item("Стартовое усилие", o + ".start", 0.05, 0.0, 5.0, "Усилие в момент нажатия (стик: как только вышел из мёртвой зоны)."),
					_tv_item("Максимальное усилие", o + ".max", 0.05, 0.0, 5.0, "Усилие при полном отклонении стика или после полного времени удержания."),
					_tv_item("Время до максимума, с (кнопки, стрелки)", o + ".time", 0.05, 0.05, 3.0, "Сколько держать кнопку или клавишу, чтобы дойти до максимума. Для стиков не используется."),
					{"t": "Кривая:  ◀ %s ▶" % main.tune.FN_NAMES[int(main.tune.v[o + ".fn"])], "d": "Линейная, экспоненциальная (вначале мягко, в конце резко) или логарифмическая (вначале резко).", "a": func(): _fn_step(o, 1), "s": func(d): _fn_step(o, d)},
					_tv_item("Крутизна кривой", o + ".k", 0.5, 0.5, 10.0, "Для экспоненты и логарифма: больше — круче изгиб. У линейной не используется.", "%.1f"),
					{"t": "Сбросить эту кривую", "a": func(): _reset_organ(o)}, back]
	return it

func _tog(key: String) -> void:
	main.cfg[key] = not main.cfg[key]; main._save_cfg()

func _set_tv(key: String, x: float) -> void:
	main.tune.v[key] = x; main.tune.save_file()

func _set_cfg(key: String, x) -> void:
	main.cfg[key] = x; main._save_cfg()

func _set_music(x: float) -> void:
	_set_cfg("music", x); main.music.refresh()

func _flip_scheme() -> void:
	main.scheme = 1 - main.scheme; main._save_cfg()

func _set_vol(x: float) -> void:
	main.cfg["vol"] = x; main._save_cfg(); _apply_volume()

func _reset_keys() -> void:
	for kb in main.KEYBIND: main.keys[kb[0]] = kb[2]
	main.apply_keys(); main._save_cfg()

func _reset_organ(o: String) -> void:
	if o == "": main.tune.reset_organs()
	else: main.tune.reset_organ(o)
	main.tune.save_file()

func _show_sel(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree(): scroll.ensure_control_visible(c)

func _fn_step(o: String, d: int) -> void:
	main.tune.v[o + ".fn"] = float(posmod(int(main.tune.v[o + ".fn"]) + d, 3)); main.tune.save_file()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(main.cfg["vol"]), 0.0001)))

func _reset_pad() -> void:
	main._load_pad(); main.apply_pad(); main._save_cfg(); _refresh_items()

func _reset_controls() -> void:
	for k in ["inv_lx", "inv_ly", "inv_rx", "inv_ry", "swap_roll", "inv_kb_pitch"]: main.cfg[k] = false
	main._load_pad(); main.apply_pad()
	main.cfg["deadzone"] = 0.12; main.scheme = 0
	for kb in main.KEYBIND: main.keys[kb[0]] = kb[2]
	main.apply_keys(); main._save_cfg()

func goto_page(p: String) -> void:
	page = p; sel = 0; capturing = ""; _refresh_items()

func back_page() -> void:
	capturing = ""
	var parent := {"settings": "main", "controls": "settings", "sound": "settings", "camera": "settings", "keys": "controls", "pad": "controls", "advanced": "controls"}
	if page.begins_with("organ:"): page = "advanced"
	elif page == "main": return
	else: page = parent.get(page, "main")
	sel = 0; _refresh_items()
	if main.tune != null: main.tune.save_file()
	main._save_cfg()

func _page_title() -> String:
	match page:
		"settings": return "НАСТРОЙКИ"
		"controls": return "НАСТРОЙКИ › УПРАВЛЕНИЕ"
		"keys": return "УПРАВЛЕНИЕ › КЛАВИШИ"
		"pad": return "УПРАВЛЕНИЕ › ГЕЙМПАД"
		"advanced": return "УПРАВЛЕНИЕ › РАСШИРЕННЫЕ"
		"sound": return "НАСТРОЙКИ › ЗВУК"
		"camera": return "НАСТРОЙКИ › КАМЕРА"
	if page.begins_with("organ:"): return "РАСШИРЕННЫЕ › " + String(ORGAN_SHORT.get(page.substr(6), page.substr(6))).to_upper()
	return ""

func _refresh_items() -> void:
	if state == "results":
		items = [{"t": "Ещё раз", "id": "again"}, {"t": "В главное меню", "id": "tomenu"}]
		sel = clampi(sel, 0, items.size() - 1)
		for i in res_btns.size():
			var l: Label = res_btns[i]; l.text = ("▶ " if i == sel else "   ") + items[i]["t"]; l.add_theme_color_override("font_color", ORANGE if i == sel else CREAM)
		return
	items = _page_items()
	sel = clampi(sel, 0, maxi(items.size() - 1, 0))
	var sub := page != "main"
	title_lbl.visible = (state == "menu" and not sub) or (state == "pause" and not sub)
	sub_lbl.visible = state == "menu" and not sub
	page_lbl.visible = sub; page_lbl.text = _page_title()
	side.size = Vector2(3000, 2000) if sub else Vector2(760, 2000); side.color = Color(0, 0, 0, 1) if sub else Color(0.04, 0.025, 0.015, 0.72)
	scroll.position = Vector2(90, 150 if sub else 330); scroll.size = Vector2(640, 560 if sub else 380)
	plot.visible = page.begins_with("organ:"); plot.queue_redraw()
	for c in vbox.get_children(): vbox.remove_child(c); c.queue_free()
	var cur: Label = null
	for i in items.size():
		var l := _lbl(("▶ " if i == sel else "    ") + items[i]["t"], 34 if not sub else 28, ORANGE if i == sel else CREAM, vbox)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(620, 0)
		if i == sel: cur = l
	if cur != null: _show_sel.call_deferred(cur)
	desc_lbl.text = String(items[sel].get("d", "")) if items.size() > 0 else ""

func _show_state(st: String) -> void:
	state = st
	var menu_like := st in ["menu", "pause"]
	menu_panel.visible = menu_like; dim.visible = menu_like or st == "results"
	if st == "pause": title_lbl.text = "ПАУЗА"
	elif st == "menu": title_lbl.text = "КАРНАВАЛЬСКАЯ\nГОНКА"
	hud_root.visible = st in ["hud", "pause", "results"] and st != "menu"
	if main.music != null and main.music_ok():
		if st == "menu": main.music.set_paused(false); main.music.play_menu()
		elif st == "results": main.music.play_results()
	res_panel.visible = st == "results"
	page = "main"; capturing = ""; sel = 0; _refresh_items()

func open_menu() -> void:
	main.cam_mode = 3
	_show_state("menu"); main._sync_time_scale()

func open_pause() -> void:
	if state != "hud": return
	opened_frame = Engine.get_process_frames()
	_show_state("pause"); main._sync_time_scale(); if main.music != null: main.music.set_paused(true)

func close_pause() -> void:
	main._save_cfg(); main.tune.save_file()
	_show_state("hud"); main._sync_time_scale(); if main.music != null: main.music.set_paused(false)

func blocking() -> bool:
	return state in ["menu", "pause"]

func on_settings_closed() -> void:
	main._sync_time_scale()

func _start_race() -> void:
	state = "hud"; _show_state("hud"); main.cam_mode = 0; main.begin_intro(); main._sync_time_scale()

func _restart() -> void:
	Engine.time_scale = 1.0; Engine.set_meta("skip_menu", true); main._reset()

func _to_menu() -> void:
	Engine.time_scale = 1.0
	if Engine.has_meta("skip_menu"): Engine.remove_meta("skip_menu")
	main._reset()

func _activate() -> void:
	if state == "results":
		if items[sel]["id"] == "again": _restart()
		else: _to_menu()
		return
	var a = items[sel].get("a")
	if a != null: (a as Callable).call(); _refresh_items()

func _step(d: int) -> void:
	var s = items[sel].get("s")
	if s != null: (s as Callable).call(d); _refresh_items()

func _change_level(d: int) -> void:
	main.cfg["level"] = posmod(int(main.cfg["level"]) + d, 5); main._save_cfg(); _refresh_items()

func _input(ev: InputEvent) -> void:                                   # перехват клавиши при переназначении
	if capturing.begins_with("pad:"):
		_pad_capture(ev); return
	if capturing == "" or not (ev is InputEventKey) or not ev.pressed or ev.echo: return
	get_viewport().set_input_as_handled()
	var kc: int = (ev as InputEventKey).physical_keycode
	if kc == KEY_ESCAPE: capturing = ""; _refresh_items(); return
	if kc in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5]: return          # служебные клавиши
	for k2 in main.keys:
		if k2 != capturing and main.keys[k2] == kc: main.keys[k2] = main.keys[capturing]        # занята — меняемся
	main.keys[capturing] = kc; capturing = ""
	main.apply_keys(); main._save_cfg(); _refresh_items()

func _pad_capture(ev: InputEvent) -> void:
	var nb := {}
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled(); capturing = ""; _refresh_items(); return
	if ev is InputEventJoypadButton and ev.pressed:
		get_viewport().set_input_as_handled()
		if (ev as InputEventJoypadButton).button_index == JOY_BUTTON_START: capturing = ""; _refresh_items(); return
		nb = {"t": "b", "i": (ev as InputEventJoypadButton).button_index, "s": 1}
	elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > 0.7:
		get_viewport().set_input_as_handled()
		var ax := (ev as InputEventJoypadMotion).axis
		nb = {"t": "a", "i": ax, "s": 1 if (ev as InputEventJoypadMotion).axis_value > 0.0 else -1}
		if ax >= 4: nb["s"] = 1
	if nb.is_empty(): return
	var id := capturing.substr(4)
	var kind := ""
	for pb in main.PADBIND: if pb[0] == id: kind = pb[3]
	if kind == "b" and nb["t"] != "b": return                           # для этого действия подходит только кнопка
	var old: Dictionary = main.pad[id]
	for pb in main.PADBIND:
		var o2: String = pb[0]
		if o2 != id and main.pad[o2]["t"] == nb["t"] and main.pad[o2]["i"] == nb["i"] and main.pad[o2]["s"] == nb["s"] and (pb[3] == "m" or old["t"] == "b"):
			main.pad[o2] = old.duplicate()
	main.pad[id] = nb; capturing = ""
	main.apply_pad(); main._save_cfg(); _refresh_items()

# ---------- Результаты ----------
func _build_results() -> void:
	res_panel = Control.new(); res_panel.set_anchors_preset(Control.PRESET_CENTER); res_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(res_panel)
	var bg := ColorRect.new(); bg.position = Vector2(-380, -340); bg.size = Vector2(760, 640); bg.color = DARK; res_panel.add_child(bg)
	res_title = _lbl("ФИНИШ", 60, ORANGE, res_panel, Vector2(-350, -336))
	res_sub = _lbl("", 28, CREAM, res_panel, Vector2(-346, -268))
	var rows := VBoxContainer.new(); rows.position = Vector2(-350, -215); rows.add_theme_constant_override("separation", 0); rows.mouse_filter = Control.MOUSE_FILTER_IGNORE; res_panel.add_child(rows)
	for i in 11:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; rows.add_child(hb)
		var row := [_lbl("", 22, CREAM, hb), _lbl("", 22, CREAM, hb), _lbl("", 22, CREAM, hb)]
		(row[0] as Label).custom_minimum_size = Vector2(44, 0)
		var nm := row[1] as Label; nm.custom_minimum_size = Vector2(390, 0); nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nm.size_flags_horizontal = Control.SIZE_FILL
		(row[2] as Label).custom_minimum_size = Vector2(240, 0); (row[2] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		res_rows.append(row)
	for i in 2: res_btns.append(_lbl("", 34, CREAM, res_panel, Vector2(-350 + i * 330, 252)))
	res_panel.visible = false

func _update_results() -> void:
	var ents := []
	ents.append({"n": "Вы", "fin": main.p_fin, "t": main.p_fin_t, "p": main.p_prog, "me": true, "dnf": false})
	for b in main.bots: ents.append({"n": b["name"], "fin": b["fin"], "t": b["fin_t"], "p": b["prog"], "me": false, "dnf": b.get("dnf", false)})
	ents.sort_custom(func(a, b):
		if a["fin"] and b["fin"]: return a["t"] < b["t"]
		if a["fin"] != b["fin"]: return a["fin"]
		return a["p"] > b["p"])
	var place := 1
	for i in res_rows.size():
		var r: Array = res_rows[i]
		if i >= ents.size(): for l in r: (l as Label).text = ""; continue
		var e: Dictionary = ents[i]
		var col := ORANGE if e["me"] else CREAM
		(r[0] as Label).text = "%d" % (i + 1); (r[1] as Label).text = e["n"]
		(r[2] as Label).text = ("%.1f с" % e["t"]) if e["fin"] else ("сошёл" if e["dnf"] else "%d%% дистанции" % int(clampf(float(e["p"]) / main.race_len, 0.0, 1.0) * 100.0))
		for l in r: (l as Label).add_theme_color_override("font_color", col)
	res_sub.text = "место %d из %d  ·  %.1f с" % [main.rank, main.bots.size() + 1, main.p_fin_t]

# ---------- Маркеры соперников: подписи одного размера независимо от расстояния ----------
func _update_markers() -> void:
	var cam: Camera3D = main.cam
	var show := state in ["hud", "pause", "results"] and cam != null
	marker_root.visible = show
	if not show: return
	while marker_lbls.size() < main.bots.size():
		var l := _lbl("", 17, CREAM, marker_root); l.add_theme_constant_override("outline_size", 5); marker_lbls.append(l)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var sc := Vector2(vs.x / maxf(1.0, float(get_viewport().size.x)), vs.y / maxf(1.0, float(get_viewport().size.y)))
	var me: Vector3 = main.ship.gpos
	for i in main.bots.size():
		var b: Dictionary = main.bots[i]; var l: Label = marker_lbls[i]
		var p: Vector3 = (b["rb"] as SB).gpos + Vector3(0, 28, 0)
		if cam.is_position_behind(p * SB.K): l.visible = false; continue
		var d := me.distance_to(p)
		var sp := cam.unproject_position(p * SB.K) * sc
		l.text = "%s  %s" % [b["name"], ("%d м" % int(d)) if d < 1000.0 else ("%.1f км" % (d / 1000.0))]
		l.reset_size()
		var half := l.size * 0.5
		sp = Vector2(clampf(sp.x, half.x + 8.0, vs.x - half.x - 8.0), clampf(sp.y, half.y + 8.0, vs.y - half.y - 8.0))
		l.position = sp - Vector2(half.x, l.size.y)
		l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65) if b["fin"] else (ORANGE if main.rank > 1 and float(b["prog"]) > float(main.p_prog) else CREAM))
		l.visible = true
	var placed: Array = []                                                      # разводим перекрывающиеся подписи по вертикали
	for l2 in marker_lbls:
		if not (l2 as Label).visible: continue
		var lab: Label = l2; var rect := Rect2(lab.position, lab.size)
		for _k in 6:
			var hit := false
			for r in placed:
				if rect.intersects(r): lab.position.y = (r as Rect2).end.y + 2.0; rect = Rect2(lab.position, lab.size); hit = true; break
			if not hit: break
		placed.append(rect)

# ---------- Каждый кадр ----------
func _process(_dt: float) -> void:
	if main == null or not is_instance_valid(main) or main.ship == null: return
	_update_markers()
	# HUD
	var v: float = main.ship.gvel.length()
	lbl_rank.text = "%d/%d" % [main.rank, main.bots.size() + 1]
	var t: float = main.race_t
	lbl_time.text = "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
	lbl_speed.text = "%d м/с" % int(v)
	lbl_alt.text = "высота %d м   ·   %d км/ч" % [int(main.ship.gpos.y), int(v * 3.6)]
	lbl_lvl.text = "Уровень: " + main.LEVEL_NAMES[main._lvl()]
	prog_bar.size.x = 440.0 * clampf(float(main.p_prog) / main.race_len, 0.0, 1.0) if main.race_len < 1e11 else 0.0
	dmg_ctl.queue_redraw(); map_ctl.queue_redraw()
	# обратный отсчёт
	if state in ["hud", "pause"]: hud_root.visible = not main.in_cutscene()
	lbl_skip.visible = state == "hud" and main.in_cutscene()
	lbl_stab.visible = state == "hud" and not main.assist and int(main.cfg["level"]) < 4 and not main.in_cutscene()
	ov_ctl.visible = state == "hud" and main.intro_t() < 7.0
	if ov_ctl.visible: ov_ctl.queue_redraw()
	var cnt: int = int(ceil(main.start_t)) if main.start_t > 0.0 and main.start_t <= 6.0 and state == "hud" else 0
	if cnt > 0: lbl_count.text = str(cnt); lbl_count.visible = true; go_t = 0.9; last_count = cnt
	elif go_t > 0.0 and state == "hud": go_t -= _dt if _dt > 0.0 else 0.016; lbl_count.text = "СТАРТ!"; lbl_count.visible = true
	else: lbl_count.visible = false
	# финиш -> результаты
	if state == "hud" and main.p_fin and res_t_show < 0.0: res_t_show = Time.get_ticks_msec() / 1000.0 + 2.5
	if state == "hud" and res_t_show > 0.0 and Time.get_ticks_msec() / 1000.0 >= res_t_show:
		_show_state("results"); _update_results()
	if state == "results": _update_results()
	# навигация
	if state in ["menu", "pause", "results"] and not main.tech_open and capturing == "":
		if Input.is_action_just_pressed("ui_down"): sel = (sel + 1) % items.size(); _refresh_items()
		if Input.is_action_just_pressed("ui_up"): sel = (sel - 1 + items.size()) % items.size(); _refresh_items()
		if state != "results":
			if Input.is_action_just_pressed("ui_left"): _step(-1)
			if Input.is_action_just_pressed("ui_right"): _step(1)
		if Input.is_action_just_pressed("ui_accept"): _activate()
		elif state != "results" and Input.is_action_just_pressed("ui_cancel") and Engine.get_process_frames() != opened_frame:
			if page != "main": back_page()
			elif state == "pause": close_pause()
