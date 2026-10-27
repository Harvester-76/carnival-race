class_name MenuSkin
extends Control
# Оформление меню v2 (дизайн Claude Design, холст 1600×900, исходник menu_v2/menu_v2.dc.html).
# Рисует фон, заголовок, строки пунктов, карточки справа и строку подсказок; логика меню остаётся в demo_ui.gd.
# Строка пункта: {"t": текст, "l": подпись, "kind": "" | "choice" | "toggle" | "slider" | "action", "val": значение, "on": вкл, "pct": 0..1, "vtxt": текст значения, "dis": недоступно}

const ICE := Color("E8F0FF")
const ORANGE := Color("FF8A1E")
const STEEL := Color("93A9D9")
const NIGHT := Color("0A1024")
const DEEP := Color("02040C")
const ASH := Color("5C6B94")
const SOFT := Color("BFCCEB")
const INK := Color("060A18")
const RUST := Color("C24E00")
const BG_FILES := {"bar": "bar", "port": "porthole", "hangar": "hangar", "cabin": "cabin", "engine": "engine", "about": "about", "exit": "exit", "space": "space", "corridor": "corridor"}
const PAPER := Color("F8EBD2")          # тёплая бумага билета
const SAND := Color("EAD2A4")           # фон рисунка
const COCOA := Color("2B1A0E")          # тёплые чернила
const BG_FADE := 0.30                   # смена фона через затемнение, с
const FLIP_T := 0.42                    # переворот карточки, с
const MAIN_BG := ["bar", "port", "hangar", "cabin", "engine", "about", "exit"]

var f_title: Font
var f_t6: Font
var f_t8: Font
var f_t7: Font
var f_t4: Font
var f_mono: Font
var tex := {}
var t_anim := 0.0

# что рисуем
var mode := "main"                     # main | page | pause | about | dialog
var bg_key := "bar"
var items: Array = []
var sel := 0
var title := ""
var hint := ""
var hint_btns: Array = []
var card := {}                         # данные карточки справа (сложность / корабль)
var scroll_y := 0.0
var rows_w := 1000.0
var res := {}                          # данные экрана результатов
var ach_row0 := 0                      # грамоты: первый видимый ряд и плавное положение прокрутки
var ach_off := 0.0
var padmap := {}                       # данные экрана «Кнопки геймпада» (заполняет demo_ui)
var bg_cur := ""                       # фон главного меню: текущий / предыдущий и момент смены
var bg_prev := ""
var bg_t0 := -10.0
var flip_n := 0                        # карточка сложности: номер показанной / предыдущей и момент переворота
var flip_t0 := -10.0
var flip_prev := {}
var flip_last := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	f_title = _font("DelaGothicOne-400.ttf"); f_t4 = _font("GolosText-400.ttf"); f_t6 = _font("GolosText-600.ttf")
	f_t7 = _font("GolosText-700.ttf"); f_t8 = _font("GolosText-800.ttf"); f_mono = _font("JetBrainsMono-700.ttf")
	for k in BG_FILES.values(): tex[k] = load("res://menu_v2/bg/%s.png" % k)

func _font(f: String) -> Font:
	var r = load("res://menu_v2/fonts/" + f)
	return r if r is Font else ThemeDB.fallback_font

func _process(_dt: float) -> void:
	if visible: t_anim = Time.get_ticks_msec() / 1000.0; queue_redraw()                   # реальное время: в меню Engine.time_scale = 0

# ---------- примитивы ----------
func _txt(font: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var asc := font.get_ascent(size); var desc := font.get_descent(size)
	draw_string(font, Vector2(pos.x, pos.y + (asc - desc) * 0.5), s, align, w, size, col)

func _txt_sh(font: Font, pos: Vector2, s: String, size: int, col: Color, sh: float) -> void:
	_txt(font, pos + Vector2(sh, sh), s, size, DEEP); _txt(font, pos, s, size, col)

func _wrap(font: Font, s: String, size: int, w: float) -> PackedStringArray:
	var out := PackedStringArray(); var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w and cur != "":
			out.append(cur); cur = word
		else: cur = t
	if cur != "": out.append(cur)
	return out

func _para(font: Font, pos: Vector2, s: String, size: int, col: Color, w: float, lh: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var y := pos.y
	for ln in _wrap(font, s, size, w):
		_txt(font, Vector2(pos.x, y + lh * 0.5), ln, size, col, align, w); y += lh
	return y - pos.y

func _box(r: Rect2, fill: Color, border := Color(0, 0, 0, 0), bw := 0, rad := 8) -> void:
	var sb := StyleBoxFlat.new(); sb.bg_color = fill; sb.set_corner_radius_all(rad)
	if bw > 0: sb.border_color = border; sb.set_border_width_all(bw)
	draw_style_box(sb, r)

func _grad_h(r: Rect2, stops: Array) -> void:                      # горизонтальный градиент по списку [t, цвет]
	for i in stops.size() - 1:
		var a: Array = stops[i]; var b: Array = stops[i + 1]
		var x0 := r.position.x + r.size.x * float(a[0]); var x1 := r.position.x + r.size.x * float(b[0])
		draw_polygon(PackedVector2Array([Vector2(x0, r.position.y), Vector2(x1, r.position.y), Vector2(x1, r.end.y), Vector2(x0, r.end.y)]), PackedColorArray([a[1], b[1], b[1], a[1]]))

func _grad_v(r: Rect2, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([c0, c0, c1, c1]))

func _tri(c: Vector2, sz: float, dir: int, col: Color) -> void:     # треугольный маркер ▶ / ◀ (в шрифтах значков нет)
	var h := sz * 0.5
	draw_colored_polygon(PackedVector2Array([c + Vector2(-h * dir * 0.7, -h), c + Vector2(h * dir * 0.7, 0), c + Vector2(-h * dir * 0.7, h)]), col)

var ach_tex := {}                                                   # иконки достижений menu_v2/ach/<id>.png (кэш; null — файла нет, рисуется звёздочка)
func _ach_icon(id: String, c: Vector2, size: float, dim: bool = false) -> bool:
	if id == "": return false
	if not ach_tex.has(id):
		var p := "res://menu_v2/ach/%s.png" % id
		ach_tex[id] = load(p) if ResourceLoader.exists(p) else null
	var t = ach_tex[id]
	if t == null: return false
	draw_texture_rect(t, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false, Color(0.07, 0.09, 0.2, 0.92) if dim else Color.WHITE)    # закрытое достижение — тёмный силуэт
	return true

func _star(c: Vector2, r: float, col: Color) -> void:             # четырёхлучевая звёздочка ✦
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0; var rr := r if i % 2 == 0 else r * 0.32
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)

func _diamond(c: Vector2, r: float, fill: Color, border: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if fill.a > 0.0: draw_colored_polygon(pts, fill)
	pts.append(pts[0]); draw_polyline(pts, border, 3.0)

func _frame() -> void:
	draw_rect(Rect2(24, 24, 1552, 852), Color(STEEL.r, STEEL.g, STEEL.b, 0.35), false, 2.0)
	var d := Color(STEEL.r, STEEL.g, STEEL.b, 0.22)
	var r := Rect2(32, 32, 1536, 836)
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), d, 1.0, 6.0); draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, d, 1.0, 6.0)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), d, 1.0, 6.0); draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, d, 1.0, 6.0)
	_star(Vector2(58, 50), 11, STEEL); _star(Vector2(1542, 850), 11, STEEL)

func _bg_img(key: String, cover_pos := 0.5, mod := Color.WHITE) -> void:
	var t: Texture2D = tex.get(BG_FILES.get(key, "bar"))
	if t == null: return
	var ts := t.get_size(); var sc := maxf(1600.0 / ts.x, 900.0 / ts.y)
	var sz := ts * sc
	draw_texture_rect(t, Rect2(Vector2((1600.0 - sz.x) * cover_pos, (900.0 - sz.y) * 0.5), sz), false, mod)

# ---------- строка пункта ----------
func _row(r: Rect2, it: Dictionary, on: bool, fs: int) -> void:
	var dis := bool(it.get("dis", false))
	var fg := ASH if dis else ICE
	var wgt := f_t8 if on else f_t6
	_box(r, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.16) if on else Color(0, 0, 0, 0), ORANGE if on else Color(0, 0, 0, 0), 3 if on else 0, 8)
	if on: _tri(Vector2(r.position.x + 30, r.position.y + r.size.y * 0.5), 22, 1, ORANGE)
	var lab := String(it.get("l", it.get("t", "")))
	var kind := String(it.get("kind", ""))
	var lx := r.position.x + 62.0
	var right := r.end.x - 28.0
	var arrow := ORANGE if on else (Color("2C3A66") if dis else Color("6476A6"))
	if kind == "choice":
		var cw := float(it.get("cw", 300.0)); var cfs := int(it.get("cfs", 26))
		var lab_w := f_t8.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cw = minf(cw, r.size.x - 62.0 - lab_w - 28.0 - 40.0 - 52.0 - 14.0)
		var vw0 := f_t7.get_string_size(String(it.get("val", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		if vw0 > cw and cw > 40.0: cfs = maxi(14, int(cfs * cw / vw0))
		_tri(Vector2(right - 12, r.position.y + r.size.y * 0.5), 22, 1, arrow)
		_txt(f_t7, Vector2(right - 40 - cw, r.position.y + r.size.y * 0.5), String(it.get("val", "")), cfs, fg, HORIZONTAL_ALIGNMENT_CENTER, cw)
		_tri(Vector2(right - 40 - cw - 26, r.position.y + r.size.y * 0.5), 22, -1, arrow)
		right = right - 40 - cw - 52
	elif kind == "toggle":
		var tw := 168.0; var th := 44.0; var tx := right - tw; var ty := r.position.y + (r.size.y - th) * 0.5
		var tgl := bool(it.get("on", false))
		_box(Rect2(tx, ty, tw, th), Color(0, 0, 0, 0), ORANGE if on else Color("3B4C7E"), 2, 22)
		var off_r := Rect2(tx + 4, ty + 4, 78, th - 8); var on_r := Rect2(tx + 86, ty + 4, 78, th - 8)
		_box(on_r if tgl else off_r, ORANGE if tgl else ICE, Color(0, 0, 0, 0), 0, 18)
		_txt(f_t8, Vector2(off_r.position.x, off_r.get_center().y), "ВЫКЛ", 20, INK if not tgl else Color("6476A6"), HORIZONTAL_ALIGNMENT_CENTER, 78)
		_txt(f_t8, Vector2(on_r.position.x, on_r.get_center().y), "ВКЛ", 20, INK if tgl else Color("6476A6"), HORIZONTAL_ALIGNMENT_CENTER, 78)
		right = tx - 20
	elif kind == "slider":
		var tw2 := float(it.get("tw", 300.0)); var vt := String(it.get("vtxt", ""))
		if r.size.x < 800.0: tw2 = minf(tw2, 190.0)
		_txt(f_mono, Vector2(right - 104, r.position.y + r.size.y * 0.5), vt, 26, fg, HORIZONTAL_ALIGNMENT_RIGHT, 104)
		var tx2 := right - 104 - 22 - tw2; var cy := r.position.y + r.size.y * 0.5
		_box(Rect2(tx2, cy - 6, tw2, 12), Color("3A2A1E"), Color(0, 0, 0, 0), 0, 6)
		var pw := tw2 * clampf(float(it.get("pct", 0.0)), 0.0, 1.0); var fill := ORANGE if on else STEEL
		_box(Rect2(tx2, cy - 6, maxf(pw, 1.0), 12), fill, Color(0, 0, 0, 0), 0, 6)
		draw_circle(Vector2(tx2 + pw, cy), 14.0, fill); draw_circle(Vector2(tx2 + pw, cy), 9.0, ICE)
		right = tx2 - 20
	elif kind == "value":
		var vt2 := String(it.get("val", "")); var vw := maxf(60.0, f_mono.get_string_size(vt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28.0)
		var capt := bool(it.get("cap", false)); var fl := 0.5 + 0.5 * sin(t_anim * 11.0)           # ждёт назначения: ячейка мерцает
		_box(Rect2(right - vw, r.position.y + (r.size.y - 40) * 0.5, vw, 40), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.12 + 0.38 * fl) if capt else Color(0, 0, 0, 0), ORANGE if on or capt else STEEL, 2, 8)
		_txt(f_mono, Vector2(right - vw, r.position.y + r.size.y * 0.5), vt2, 22, Color(ICE.r, ICE.g, ICE.b, 0.45 + 0.55 * fl) if capt else ICE, HORIZONTAL_ALIGNMENT_CENTER, vw)
		right -= vw + 20
	elif kind == "action":
		_txt(f_t7, Vector2(right - 20, r.position.y + r.size.y * 0.5 - 2), "›", 38, arrow, HORIZONTAL_ALIGNMENT_RIGHT, 20)
		right -= 40
	elif dis:
		_box(Rect2(right - 190, r.position.y + (r.size.y - 36) * 0.5, 190, 36), Color(0, 0, 0, 0), Color("4A3828"), 2, 6)
		_txt(f_t7, Vector2(right - 190, r.position.y + r.size.y * 0.5), "НЕДОСТУПНО", 18, Color("8A6A4C"), HORIZONTAL_ALIGNMENT_CENTER, 190)
		right -= 210
	var w := maxf(right - lx - 10.0, 60.0)
	if f_t6.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		var lines := _wrap(wgt, lab, fs, w); var lh := fs * 1.15; var y0 := r.position.y + (r.size.y - lh * lines.size()) * 0.5
		for i in lines.size(): _txt(wgt, Vector2(lx, y0 + lh * (i + 0.5)), lines[i], fs, fg)
	else:
		_txt(wgt, Vector2(lx, r.position.y + r.size.y * 0.5), lab, fs, fg)

func _lab_w(r_w: float, it: Dictionary, fs: int) -> float:                  # ширина под подпись пункта (за вычетом элементов справа); та же арифметика, что в _row
	var dis := bool(it.get("dis", false)); var kind := String(it.get("kind", ""))
	var lab := String(it.get("l", it.get("t", "")))
	var lx := 62.0; var right := r_w - 28.0
	if kind == "choice":
		var cw := float(it.get("cw", 300.0)); var lab_w := f_t8.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cw = minf(cw, r_w - 62.0 - lab_w - 28.0 - 40.0 - 52.0 - 14.0); right = right - 40 - cw - 52
	elif kind == "toggle": right = right - 168.0 - 20.0
	elif kind == "slider":
		var tw2 := float(it.get("tw", 300.0))
		if r_w < 800.0: tw2 = minf(tw2, 190.0)
		right = right - 104 - 22 - tw2 - 20
	elif kind == "value": right -= maxf(60.0, f_mono.get_string_size(String(it.get("val", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28.0) + 20.0
	elif kind == "action": right -= 40.0
	elif dis: right -= 210.0
	return maxf(right - lx - 10.0, 60.0)

func _row_h(it: Dictionary, on: bool, fs: int, r_w: float, h: float) -> float:   # выбранный пункт растёт под многострочную подпись
	if not on: return h
	var lab := String(it.get("l", it.get("t", "")))
	var w := _lab_w(r_w, it, fs)
	if f_t6.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w: return h
	return maxf(h, _wrap(f_t8, lab, fs, w).size() * fs * 1.15 + 22.0)

func _rows(x: float, y: float, w: float, h: float, fs: int, gap: float, y_max := 900.0) -> void:
	var hs := PackedFloat64Array(); var offs := PackedFloat64Array(); var total := 0.0
	for i in items.size():
		var hh := _row_h(items[i], i == sel, fs, w, h); hs.append(hh); offs.append(total); total += hh + gap
	var view := y_max - y
	if total > view:                                                      # длинный список: прокручиваем так, чтобы выбранный пункт был виден
		var sy := offs[sel] if sel < offs.size() else 0.0; var sh := hs[sel] if sel < hs.size() else h
		scroll_y = clampf(scroll_y, sy + sh - view, sy)
		scroll_y = clampf(scroll_y, 0.0, total - view)
	else: scroll_y = 0.0
	for i in items.size():
		var ry := y + offs[i] - scroll_y
		if ry < y - hs[i] * 0.2 or ry + hs[i] > y_max + 4.0: continue
		_row(Rect2(x, ry, w, hs[i]), items[i], i == sel, fs)

# ---------- подсказки ----------
func _hint_bar(x_end: float, y: float, left_text := "", line_col := Color(0, 0, 0, 0), x_start := 0.0) -> void:
	if line_col.a > 0.0: draw_line(Vector2(x_start, y), Vector2(1600, y), line_col, 2.0)
	var cy := y + 50.0
	var bw := 0.0
	for b0 in hint_btns:
		var k0 := String(b0["k"])
		bw += f_t6.get_string_size(String(b0["l"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 10.0 + 28.0 + (40.0 if k0 in ["A", "B"] else maxf(44.0, f_t6.get_string_size(String(b0["g"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20.0))
	if left_text != "":
		var tw := x_end - bw - 120.0 - 40.0
		var lines := _wrap(f_t4, left_text, 22, tw)
		if lines.size() > 3: lines.resize(3); lines[2] = lines[2].substr(0, maxi(lines[2].length() - 2, 0)) + "…"
		var ty := cy - lines.size() * 15.0
		for ln in lines: _txt(f_t4, Vector2(120, ty + 15.0), ln, 22, SOFT); ty += 30.0
	var x := x_end
	for i in range(hint_btns.size() - 1, -1, -1):
		var b: Dictionary = hint_btns[i]
		var lw := f_t6.get_string_size(String(b["l"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		x -= lw; _txt(f_t6, Vector2(x, cy), String(b["l"]), 24, STEEL)
		x -= 10
		var k := String(b["k"])
		if k == "A":
			draw_circle(Vector2(x - 20, cy), 20, ICE); _txt(f_t8, Vector2(x - 40, cy), "A", 22, INK, HORIZONTAL_ALIGNMENT_CENTER, 40); x -= 40
		elif k == "B":
			draw_arc(Vector2(x - 20, cy), 18.5, 0, TAU, 40, ICE, 3.0); _txt(f_t8, Vector2(x - 40, cy), "B", 22, ICE, HORIZONTAL_ALIGNMENT_CENTER, 40); x -= 40
		else:
			var gw := maxf(44.0, f_t6.get_string_size(String(b["g"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20)
			_box(Rect2(x - gw, cy - 20, gw, 40), Color(0, 0, 0, 0), STEEL, 2, 8); _txt(f_t6, Vector2(x - gw, cy), String(b["g"]), 18, ICE, HORIZONTAL_ALIGNMENT_CENTER, gw); x -= gw
		x -= 28

# ---------- карточки справа ----------
func _pips(c: Vector2, n: int, cur: int, r: float, dark: bool) -> void:                  # ромбики номера выбранного
	for i in n:
		var cc := c + Vector2(-i * (r * 2 + 10), 0)
		var on := (n - 1 - i) == cur
		_diamond(cc, r * 0.7, ORANGE if on else (Color(0, 0, 0, 0)), ICE if not dark else COCOA)

func _card_ticket() -> void:                                                  # билет сложности (фон «иллюминатор»); при смене уровня переворачивается
	if flip_n == 0: flip_n = int(card.get("n", 1)); flip_last = card
	elif int(card.get("n", 1)) != flip_n:
		flip_prev = flip_last; flip_n = int(card.get("n", 1)); flip_t0 = t_anim
	var e := (t_anim - flip_t0) / FLIP_T
	if e >= 1.0: flip_last = card; _ticket_face(card); return
	var sx := cos(e * PI) if e < 0.5 else -cos(e * PI)                          # 1 → 0 → 1 вокруг вертикальной оси билета
	sx = maxf(sx, 0.03)
	var cx := 1040.0 + 220.0
	draw_set_transform_matrix(Transform2D(Vector2(sx, 0.0), Vector2(0.0, 1.0 - 0.05 * (1.0 - sx)), Vector2(cx * (1.0 - sx), 456.0 * 0.05 * (1.0 - sx))))
	_ticket_face(flip_prev if e < 0.5 else card)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _ticket_face(cd: Dictionary) -> void:
	var x := 1040.0; var y := 72.0; var w := 440.0; var h := 768.0
	_box(Rect2(x + 10, y + 10, w, h), DEEP, Color(0, 0, 0, 0), 0, 10); _box(Rect2(x, y, w, h), PAPER, Color(0, 0, 0, 0), 0, 10)
	var img := Rect2(x + 40, y + 32, 360, 360)
	_box(img, SAND, COCOA, 3, 4)
	var n := int(cd.get("n", 1)); var total := int(cd.get("total", 5))
	var lpic: Texture2D = cd.get("pic")
	if lpic != null: draw_texture_rect(lpic, img.grow(-4), false)
	else: _txt(f_title, Vector2(img.position.x, img.get_center().y), ["I", "II", "III", "IV", "V", "VI"][clampi(n - 1, 0, 5)], 150, Color(COCOA.r, COCOA.g, COCOA.b, 0.28), HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	draw_dashed_line(Vector2(x + 28, y + 412), Vector2(x + w - 28, y + 412), Color(COCOA.r, COCOA.g, COCOA.b, 0.5), 3.0, 10.0)
	draw_circle(Vector2(x, y + 414), 18, Color("070B18")); draw_circle(Vector2(x + w, y + 414), 18, Color("070B18"))
	_txt(f_t8, Vector2(x + 32, y + 454), "СЛОЖНОСТЬ %d/%d" % [n, total], 22, COCOA)
	_pips(Vector2(x + w - 40, y + 454), total, n - 1, 11, true)
	var cy := y + 520.0
	_tri(Vector2(x + 52, cy), 26, -1, ORANGE if n > 1 else Color("BBA682")); _tri(Vector2(x + w - 52, cy), 26, 1, ORANGE if n < total else Color("BBA682"))
	var name := String(cd.get("name", ""))
	var lines := _wrap(f_title, name, 31, w - 150.0); var lh := 34.0
	for i in lines.size(): _txt(f_title, Vector2(x + 75, cy - lh * (lines.size() - 1) * 0.5 + i * lh), lines[i], 31, COCOA, HORIZONTAL_ALIGNMENT_CENTER, w - 150.0)
	var yy := y + 574.0
	yy += _para(f_t8, Vector2(x + 32, yy), "«%s»" % String(cd.get("slogan", "")), 26, RUST, w - 64.0, 31.0, HORIZONTAL_ALIGNMENT_CENTER) + 8.0
	_para(f_t6, Vector2(x + 32, yy), String(cd.get("desc", "")), 22, COCOA, w - 64.0, 30.0, HORIZONTAL_ALIGNMENT_CENTER)

func _card_ship() -> void:                                                    # карточка корабля (фон «ангар»)
	var right := 1480.0; var w := 520.0; var n := int(card.get("n", 1)); var total := int(card.get("total", 1))
	var sw := 0.5 + 0.06 * sin(t_anim * 1.57)                                     # тень пульсирует вместе с покачиванием (shadowPulse 4 с)
	draw_set_transform(Vector2(1100, 670), 0.0, Vector2(1.0 - 0.14 * (sw - 0.5) * 2.0, 0.107))
	for i in 12: draw_circle(Vector2.ZERO, 280.0 - i * 8.0, Color(0.36, 0.88, 1.0, 0.04))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cur: Texture2D = card.get("pic")
	if cur != null:                                                               # picture of the ship: bob 4 s, ±18 px, ±1.5°
		var ph := sin(t_anim * TAU / 4.0)
		var sz := Vector2(680, 460)
		draw_set_transform(Vector2(1100, 372 - 9.0 - 9.0 * ph), deg_to_rad(-0.25 * ph), Vector2.ONE)
		draw_texture_rect(cur, Rect2(-sz * 0.5, sz), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var name := String(card.get("name", ""))
	var slog := _wrap(f_t8, "«%s»" % String(card.get("slogan", "")), 28, w)
	var dsc := _wrap(f_t6, String(card.get("desc", "")), 24, 460.0)
	var total_h := 26.0 + 10.0 + 59.0 + 10.0 + slog.size() * 34.0 + 10.0 + dsc.size() * 32.0
	var y := 828.0 - total_h
	_txt(f_t8, Vector2(right - w, y + 13), "КОРАБЛЬ %d/%d" % [n, total], 22, STEEL, HORIZONTAL_ALIGNMENT_RIGHT, w - (total * 24.0 + 16.0))
	_pips(Vector2(right - 8, y + 13), total, n - 1, 10, false)
	y += 36.0
	var nw := f_title.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	_txt_sh(f_title, Vector2(right - nw, y + 30), name, 56, ICE, 4.0)
	_tri(Vector2(right - nw - 34, y + 30), 30, -1, ORANGE if n > 1 else ASH); _tri(Vector2(right + 34, y + 30), 30, 1, ORANGE if n < total else ASH)
	y += 69.0
	for ln in slog:
		_txt(f_t8, Vector2(right - w + 1, y + 19), ln, 28, Color(0, 0, 0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, w); _txt(f_t8, Vector2(right - w, y + 17), ln, 28, ORANGE, HORIZONTAL_ALIGNMENT_RIGHT, w); y += 34.0
	y += 10.0
	for ln in dsc:
		_txt(f_t6, Vector2(right - 460 + 1, y + 18), ln, 24, Color(0, 0, 0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 460.0); _txt(f_t6, Vector2(right - 460, y + 16), ln, 24, SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 460.0); y += 32.0

# ---------- экран «Кнопки геймпада» (схема геймпада, подписи, список действий) ----------
# id, сторона (L/R/TL/TR), y подписи, название элемента, привязка (t: a ось / b кнопка, i, s), точка на схеме для линии, фигура подсветки: [0 прямоугольник x y w h r | 1 точка x y r | 2 кольцо x y r]
const PAD_SLOTS := [
	{"id": "a4", "side": "L", "y": 240, "ctl": "LT", "t": "a", "i": 4, "s": 1, "tx": 645, "ty": 279, "sh": [0, 600, 262, 90, 34, 10]},
	{"id": "b9", "side": "L", "y": 288, "ctl": "LB", "t": "b", "i": 9, "s": 1, "tx": 645, "ty": 310, "sh": [0, 580, 298, 130, 24, 12]},
	{"id": "a1-", "side": "L", "y": 336, "ctl": "Л.стик ↑", "t": "a", "i": 1, "s": -1, "tx": 650, "ty": 392, "sh": [1, 650, 388, 9]},
	{"id": "a0-", "side": "L", "y": 384, "ctl": "Л.стик ←", "t": "a", "i": 0, "s": -1, "tx": 620, "ty": 420, "sh": [1, 618, 420, 9]},
	{"id": "a0+", "side": "L", "y": 432, "ctl": "Л.стик →", "t": "a", "i": 0, "s": 1, "tx": 680, "ty": 420, "sh": [1, 682, 420, 9]},
	{"id": "a1+", "side": "L", "y": 480, "ctl": "Л.стик ↓", "t": "a", "i": 1, "s": 1, "tx": 650, "ty": 448, "sh": [1, 650, 452, 9]},
	{"id": "b7", "side": "L", "y": 528, "ctl": "L3", "t": "b", "i": 7, "s": 1, "tx": 650, "ty": 420, "sh": [2, 650, 420, 42]},
	{"id": "b11", "side": "L", "y": 576, "ctl": "Крест ↑", "t": "b", "i": 11, "s": 1, "tx": 720, "ty": 497, "sh": [0, 708, 490, 24, 20, 3]},
	{"id": "b13", "side": "L", "y": 624, "ctl": "Крест ←", "t": "b", "i": 13, "s": 1, "tx": 697, "ty": 520, "sh": [0, 690, 508, 20, 24, 3]},
	{"id": "b12", "side": "L", "y": 672, "ctl": "Крест ↓", "t": "b", "i": 12, "s": 1, "tx": 720, "ty": 543, "sh": [0, 708, 530, 24, 20, 3]},
	{"id": "b14", "side": "L", "y": 720, "ctl": "Крест →", "t": "b", "i": 14, "s": 1, "tx": 743, "ty": 520, "sh": [0, 730, 508, 20, 24, 3]},
	{"id": "a5", "side": "R", "y": 240, "ctl": "RT", "t": "a", "i": 5, "s": 1, "tx": 955, "ty": 279, "sh": [0, 910, 262, 90, 34, 10]},
	{"id": "b10", "side": "R", "y": 288, "ctl": "RB", "t": "b", "i": 10, "s": 1, "tx": 955, "ty": 310, "sh": [0, 890, 298, 130, 24, 12]},
	{"id": "b3", "side": "R", "y": 336, "ctl": "Y", "t": "b", "i": 3, "s": 1, "tx": 950, "ty": 380, "sh": [1, 950, 380, 18]},
	{"id": "b2", "side": "R", "y": 384, "ctl": "X", "t": "b", "i": 2, "s": 1, "tx": 910, "ty": 420, "sh": [1, 910, 420, 18]},
	{"id": "b1", "side": "R", "y": 432, "ctl": "B", "t": "b", "i": 1, "s": 1, "tx": 990, "ty": 420, "sh": [1, 990, 420, 18], "lock": "Назад · закреплено"},
	{"id": "b0", "side": "R", "y": 480, "ctl": "A", "t": "b", "i": 0, "s": 1, "tx": 950, "ty": 460, "sh": [1, 950, 460, 18]},
	{"id": "a3-", "side": "R", "y": 528, "ctl": "П.стик ↑", "t": "a", "i": 3, "s": -1, "tx": 880, "ty": 492, "sh": [1, 880, 488, 9]},
	{"id": "a2-", "side": "R", "y": 576, "ctl": "П.стик ←", "t": "a", "i": 2, "s": -1, "tx": 850, "ty": 520, "sh": [1, 848, 520, 9]},
	{"id": "a2+", "side": "R", "y": 624, "ctl": "П.стик →", "t": "a", "i": 2, "s": 1, "tx": 910, "ty": 520, "sh": [1, 912, 520, 9]},
	{"id": "a3+", "side": "R", "y": 672, "ctl": "П.стик ↓", "t": "a", "i": 3, "s": 1, "tx": 880, "ty": 548, "sh": [1, 880, 552, 9]},
	{"id": "b8", "side": "R", "y": 720, "ctl": "R3", "t": "b", "i": 8, "s": 1, "tx": 880, "ty": 520, "sh": [2, 880, 520, 42]},
	{"id": "b4", "side": "TL", "y": 188, "ctl": "View", "t": "b", "i": 4, "s": 1, "tx": 760, "ty": 410, "sh": [1, 760, 410, 12]},
	{"id": "b6", "side": "TR", "y": 188, "ctl": "Menu", "t": "b", "i": 6, "s": 1, "tx": 840, "ty": 410, "sh": [1, 840, 410, 12], "lock": "Пауза · закреплено"},
]

func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(1, n + 1):
		var t := float(k) / n; var u := 1.0 - t
		out.append(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	return out

func _pad_body_pts() -> PackedVector2Array:                                   # контур корпуса из дизайна (SVG-путь из кубических кривых)
	var pts := PackedVector2Array([Vector2(640, 330)])
	pts.append_array(_bez(Vector2(640, 330), Vector2(700, 310), Vector2(900, 310), Vector2(960, 330)))
	pts.append_array(_bez(Vector2(960, 330), Vector2(1040, 340), Vector2(1080, 380), Vector2(1100, 460)))
	pts.append_array(_bez(Vector2(1100, 460), Vector2(1125, 560), Vector2(1130, 660), Vector2(1080, 700)))
	pts.append_array(_bez(Vector2(1080, 700), Vector2(1040, 730), Vector2(1000, 700), Vector2(975, 660)))
	pts.append_array(_bez(Vector2(975, 660), Vector2(955, 625), Vector2(930, 600), Vector2(890, 600)))
	pts.append(Vector2(710, 600))
	pts.append_array(_bez(Vector2(710, 600), Vector2(670, 600), Vector2(645, 625), Vector2(625, 660)))
	pts.append_array(_bez(Vector2(625, 660), Vector2(600, 700), Vector2(560, 730), Vector2(520, 700)))
	pts.append_array(_bez(Vector2(520, 700), Vector2(470, 660), Vector2(475, 560), Vector2(500, 460)))
	pts.append_array(_bez(Vector2(500, 460), Vector2(520, 380), Vector2(560, 340), Vector2(640, 330)))
	return pts

func _pad_anchor(sl: Dictionary) -> Vector2:                                    # откуда идёт линия от подписи
	match String(sl["side"]):
		"L": return Vector2(480, float(sl["y"]))
		"R": return Vector2(1120, float(sl["y"]))
		"TL": return Vector2(760, 202)
		_: return Vector2(840, 202)

func _pad_shape(sh: Array, fill: Color, line: Color) -> void:
	match int(sh[0]):
		0: _box(Rect2(float(sh[1]), float(sh[2]), float(sh[3]), float(sh[4])), fill, line, 3, int(sh[5]))
		1: draw_circle(Vector2(float(sh[1]), float(sh[2])), float(sh[3]), fill); draw_arc(Vector2(float(sh[1]), float(sh[2])), float(sh[3]), 0, TAU, 28, line, 3.0, true)
		2: draw_arc(Vector2(float(sh[1]), float(sh[2])), float(sh[3]), 0, TAU, 40, line, 4.0, true)

func _pad_chip(sl: Dictionary, st: String) -> void:                            # подпись: чип с названием элемента + действие. st: "" | "sel" | "cur" | "live"
	var acts: Dictionary = padmap.get("acts", {})
	var lock := String(sl.get("lock", ""))
	var txt := String(acts.get(sl["id"], ""))
	var act := lock if lock != "" else (txt if txt != "" else "не назначено")
	var on := st == "sel"
	var col := ORANGE if on else (ASH if (lock != "" or txt == "") else ICE)
	var fs := 26
	var cw := maxf(44.0, f_mono.get_string_size(String(sl["ctl"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20.0)
	var tw := f_t8.get_string_size(act, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var side := String(sl["side"]); var cy := float(sl["y"])
	var room := 400.0 if side == "R" else 360.0
	if tw > room: fs = maxi(16, int(fs * room / tw)); tw = f_t8.get_string_size(act, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx := 0.0; var tx := 0.0
	if side == "R": cx = 1130.0; tx = cx + cw + 12.0
	elif side == "TR": cx = 850.0; tx = cx + cw + 12.0
	else:
		var endx := 470.0 if side == "L" else 750.0
		tx = endx - tw; cx = tx - 12.0 - cw
	var fill := Color(0, 0, 0, 0)
	if on: fill = ORANGE
	elif st == "live": fill = Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.4)
	_box(Rect2(cx, cy - 18, cw, 36), fill, ORANGE if (on or st != "") else (STEEL if lock == "" else ASH), 2, 8)
	_txt(f_mono, Vector2(cx, cy), String(sl["ctl"]), 18, INK if on else ICE, HORIZONTAL_ALIGNMENT_CENTER, cw)
	_txt(f_t8 if on else f_t6, Vector2(tx, cy), act, fs, col)

func _draw_padmap() -> void:
	_settings_bg(0.22)
	var small := "УПРАВЛЕНИЕ"; var sw := f_title.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_txt(f_title, Vector2(120, 100), small, 30, STEEL); _txt(f_title, Vector2(120 + sw + 14, 100), "›", 30, ORANGE)
	_txt(f_title, Vector2(120 + sw + 50, 100), "КНОПКИ ГЕЙМПАДА", 56, ICE)
	_txt(f_t4, Vector2(1080, 60 + 52), "Карнавальская Гонка", 24, STEEL, HORIZONTAL_ALIGNMENT_RIGHT, 400.0)
	_star(Vector2(1480 - f_t4.get_string_size("Карнавальская Гонка", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x - 22, 60 + 52), 8, STEEL)
	draw_dashed_line(Vector2(120, 146), Vector2(1480, 146), Color("24335E"), 2.0, 8.0)
	var sel_id := String(padmap.get("sel", "")); var cur_id := String(padmap.get("cur", ""))
	var live: Dictionary = padmap.get("live", {})
	var lc := Color("6476A6")
	for sl in PAD_SLOTS:                                                        # линии к элементам (под корпусом)
		var a := _pad_anchor(sl)
		if String(sl["id"]) == sel_id: continue
		draw_line(a, Vector2(float(sl["tx"]), float(sl["ty"])), lc, 2.0, true)
	var body := _pad_body_pts()
	draw_colored_polygon(body, Color("0E1733")); var bl := body.duplicate(); bl.append(body[0]); draw_polyline(bl, STEEL, 4.0, true)
	for sh in [[600, 262, 90, 34, 10], [910, 262, 90, 34, 10], [580, 298, 130, 24, 12], [890, 298, 130, 24, 12]]: _box(Rect2(sh[0], sh[1], sh[2], sh[3]), Color("24335E"), STEEL, 3, sh[4])
	for c in [Vector2(650, 420), Vector2(880, 520)]:
		draw_circle(c, 42, INK); draw_arc(c, 42, 0, TAU, 40, STEEL, 3.0, true); draw_circle(c, 26, Color("24335E"))
	_box(Rect2(690, 508, 60, 24), Color("24335E"), STEEL, 3, 4); _box(Rect2(708, 490, 24, 60), Color("24335E"), STEEL, 3, 4); draw_rect(Rect2(709, 509, 22, 22), Color("24335E"))
	draw_arc(Vector2(800, 365), 20, 0, TAU, 28, STEEL, 3.0, true)
	for c in [Vector2(760, 410), Vector2(840, 410)]: draw_circle(c, 12, Color("24335E")); draw_arc(c, 12, 0, TAU, 20, STEEL, 3.0, true)
	for b in [["Y", Vector2(950, 380)], ["X", Vector2(910, 420)], ["B", Vector2(990, 420)]]:
		draw_circle(b[1], 18, Color("24335E")); draw_arc(b[1], 18, 0, TAU, 24, STEEL, 3.0, true); _txt(f_t8, b[1] - Vector2(20, 0), b[0], 20, ICE, HORIZONTAL_ALIGNMENT_CENTER, 40)
	draw_circle(Vector2(950, 460), 18, ICE); _txt(f_t8, Vector2(930, 460), "A", 20, INK, HORIZONTAL_ALIGNMENT_CENTER, 40)
	for sl in PAD_SLOTS:                                                        # подсветка нажатых прямо сейчас
		if live.has(sl["id"]): _pad_shape(sl["sh"], Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.45), ORANGE)
	for sl in PAD_SLOTS: _pad_chip(sl, "live" if live.has(sl["id"]) else ("cur" if String(sl["id"]) == cur_id and sel_id == "" else ""))
	var lock_txt := String(padmap.get("locked", ""))
	if lock_txt != "":                                                          # переназначение запрещено: всё серое + предупреждение
		draw_rect(Rect2(0, 170, 1600, 580), Color(0.03, 0.04, 0.07, 0.8))
		var lines := _wrap(f_t6, lock_txt, 26, 600.0); var bh := 74.0 + lines.size() * 34.0; var by := 450.0 - bh * 0.5
		_box(Rect2(470, by + 8, 660, bh), Color(0, 0, 0, 0.8), Color(0, 0, 0, 0), 0, 8); _box(Rect2(460, by, 660, bh), INK, ORANGE, 3, 8)
		_tri(Vector2(496, by + 34), 20, 1, ORANGE); _txt(f_t8, Vector2(520, by + 34), "ПЕРЕНАЗНАЧЕНИЕ НЕДОСТУПНО", 22, ORANGE)
		for i in lines.size(): _txt(f_t6, Vector2(490, by + 78 + i * 34), lines[i], 26, ICE)
	var pop: Dictionary = padmap.get("pop", {})
	if sel_id != "" and lock_txt == "":
		draw_rect(Rect2(0, 170, 1600, 560), Color(0, 0, 0, 0.72))               # затемняем всё, кроме выбранного элемента
		for sl in PAD_SLOTS:
			if String(sl["id"]) != sel_id: continue
			draw_line(_pad_anchor(sl), Vector2(float(sl["tx"]), float(sl["ty"])), ORANGE, 4.0, true)
			_pad_shape(sl["sh"], ORANGE, ORANGE); _pad_chip(sl, "sel")
			if not pop.is_empty(): _pad_popup(sl, pop)
	_hint_bar(1480.0, 800.0, String(padmap.get("hint", "")), Color("18224A"))

func _pad_popup(sl: Dictionary, pop: Dictionary) -> void:                       # список действий для выбранного элемента (с противоположной стороны от подписи)
	var rows: Array = pop.get("rows", [])
	var vis := mini(rows.size(), 8); var rh := 46.0
	var w := 440.0 if String(sl["side"]).begins_with("L") else 430.0; var x := 1130.0 if String(sl["side"]).begins_with("L") else 40.0
	var h := 12.0 + 38.0 + vis * (rh + 2.0) + 10.0; var y := 218.0
	_box(Rect2(x + 10, y + 10, w, h), Color.BLACK, Color(0, 0, 0, 0), 0, 8); _box(Rect2(x, y, w, h), INK, ORANGE, 3, 8)
	_txt(f_t8, Vector2(x + 20, y + 28), "ДЕЙСТВИЕ ДЛЯ " + String(sl["ctl"]).to_upper(), 20, STEEL)
	var top := int(pop.get("top", 0)); var psel := int(pop.get("sel", 0))
	for k in vis:
		var i := top + k
		if i >= rows.size(): break
		var r: Dictionary = rows[i]; var on := i == psel; var dis := bool(r.get("dis", false))
		var ry := y + 50.0 + k * (rh + 2.0)
		var cur := bool(r.get("cur", false))
		_box(Rect2(x + 12, ry, w - 24, rh), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.16) if on else Color(0, 0, 0, 0), ORANGE if (on or cur) else Color(0, 0, 0, 0), 3 if on else 2, 6)
		if on: _tri(Vector2(x + 34, ry + rh * 0.5), 18, 1, ORANGE)
		var nc := ASH if dis else (ORANGE if cur else ICE)
		var nm := String(r.get("name", "")); var nfs := 23; var nmw := w - 54 - 24 - 104.0
		var nw0 := f_t8.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		if nw0 > nmw: nfs = maxi(15, int(nfs * nmw / nw0))
		_txt(f_t8 if (cur or on) else f_t6, Vector2(x + 54, ry + rh * 0.5), nm, nfs, nc)
		_txt(f_t6, Vector2(x + w - 24 - 104, ry + rh * 0.5), "нельзя" if dis else String(r.get("note", "")), 17, ASH if dis else STEEL, HORIZONTAL_ALIGNMENT_RIGHT, 96.0)
	if rows.size() > vis:                                                       # полоса прокрутки
		var th := vis * (rh + 2.0); var bh := th * float(vis) / rows.size()
		_box(Rect2(x + w - 8, y + 50.0 + (th - bh) * float(top) / float(rows.size() - vis), 4, bh), STEEL, Color(0, 0, 0, 0), 0, 2)


# ---------- экраны ----------
func _draw() -> void:
	if mode == "main": _draw_main()
	elif mode == "page": _draw_page()
	elif mode == "pause": _draw_pause()
	elif mode == "about": _draw_about()
	elif mode == "dialog": _draw_dialog()
	elif mode == "ach": _draw_ach()
	elif mode == "results": _draw_results()
	elif mode == "padmap": _draw_padmap()

func _main_bg(key: String, k: float) -> void:                              # фон пункта главного меню; k — яркость картинки (для затемнения)
	var m := Color(k, k, k, 1.0)
	if key == "port": _bg_img("port", 1.0, m); _grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.02, 0.03, 0.07, 0.7)], [0.45, Color(0.02, 0.03, 0.07, 0.35)], [0.65, Color(0.02, 0.03, 0.07, 0.0)]])
	elif key == "hangar": _bg_img("hangar", 1.0, m); _grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.02, 0.03, 0.07, 0.7)], [0.45, Color(0.02, 0.03, 0.07, 0.35)], [0.65, Color(0.02, 0.03, 0.07, 0.0)]])
	elif key == "bar": _bg_img("bar", 0.5, m); _grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.012, 0.024, 0.063, 0.94)], [0.3, Color(0.012, 0.024, 0.063, 0.86)], [0.52, Color(0.012, 0.024, 0.063, 0.45)], [0.7, Color(0.012, 0.024, 0.063, 0.0)]])
	else: _bg_img(key, 0.5, m); _grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.012, 0.024, 0.063, 0.92)], [0.34, Color(0.012, 0.024, 0.063, 0.8)], [0.6, Color(0.012, 0.024, 0.063, 0.3)], [0.75, Color(0.012, 0.024, 0.063, 0.0)]])

func _draw_main() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Color("070B18"))
	if bg_key != bg_cur:                                                      # фон сменился: гаснет прежний, потом проявляется новый
		bg_prev = bg_cur; bg_cur = bg_key; bg_t0 = t_anim
		if bg_prev == "": bg_t0 = -10.0
	var e := (t_anim - bg_t0) / BG_FADE
	if e >= 1.0 or bg_prev == "": _main_bg(bg_cur, 1.0)
	elif e < 0.5: _main_bg(bg_prev, 1.0 - e * 2.0)
	else: _main_bg(bg_cur, (e - 0.5) * 2.0)
	_grad_v(Rect2(0, 720, 1600, 180), Color(0.012, 0.024, 0.063, 0.0), Color(0.012, 0.024, 0.063, 0.85))
	_frame()
	_txt_sh(f_title, Vector2(120, 84 + 40), "КАРНАВАЛЬСКАЯ", 76, ICE, 5.0)
	_txt_sh(f_title, Vector2(120, 84 + 80 + 66), "ГОНКА", 132, ORANGE, 6.0)
	_txt(f_t6, Vector2(120, 84 + 80 + 66 + 66 + 38), "демо-прототип", 30, STEEL)
	_rows(104, 360, 820, 52, 32, 4.0, 800.0)
	if bg_key == "port": _card_ticket()
	elif bg_key == "hangar": _card_ship()
	_hint_bar(924.0, 756.0, "")

func _settings_bg(k: float) -> void:                                          # фон настроек: картинка пункта «Настройки» главного меню, сильно затемнённая
	draw_rect(Rect2(0, 0, 1600, 900), Color.BLACK)
	_bg_img("engine", 0.5, Color(k, k, k * 1.1, 1.0))
	_grad_v(Rect2(0, 0, 1600, 900), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.55))

func _draw_page() -> void:
	_settings_bg(0.3)
	var tsz := mini(64, int(64.0 * 1000.0 / maxf(f_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x, 1.0)))
	_txt(f_title, Vector2(120, 60 + 40), title, tsz, ICE)
	_txt(f_t4, Vector2(1080, 60 + 52), "Карнавальская Гонка", 24, STEEL, HORIZONTAL_ALIGNMENT_RIGHT, 400.0)
	_star(Vector2(1480 - f_t4.get_string_size("Карнавальская Гонка", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x - 22, 60 + 52), 8, STEEL)
	draw_dashed_line(Vector2(120, 60 + 86), Vector2(1480, 60 + 86), Color("24335E"), 2.0, 8.0)
	_rows(104, 224, rows_w, 64 if rows_w < 800.0 else 60, 26 if rows_w < 800.0 else 30, 6.0, 790.0)
	_hint_bar(1480.0, 800.0, hint, Color("18224A"))

func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Color(0.012, 0.024, 0.063, 0.72))
	var h := 14 + 40 + 80 + 28 + items.size() * 86.0 + 40 + 14
	_box(Rect2(490, 130 + 10, 640, h), Color("010208"), Color(0, 0, 0, 0), 0, 8); _box(Rect2(480, 130, 640, h), Color("0E1733"), STEEL, 3, 8)
	draw_rect(Rect2(494, 144, 612, h - 28), Color(STEEL.r, STEEL.g, STEEL.b, 0.5), false, 1.0)
	_txt(f_title, Vector2(485, 130 + 14 + 40 + 40), "ПАУЗА", 80, DEEP, HORIZONTAL_ALIGNMENT_CENTER, 640.0); _txt(f_title, Vector2(480, 130 + 14 + 40 + 40), "ПАУЗА", 80, ICE, HORIZONTAL_ALIGNMENT_CENTER, 640.0)
	_rows(502, 130 + 14 + 40 + 80 + 28, 592, 80, 34, 6.0, 900.0)
	_hint_bar(1480.0, 756.0, "")

func _draw_dialog() -> void:
	_bg_img("exit"); _grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.012, 0.024, 0.063, 0.92)], [0.34, Color(0.012, 0.024, 0.063, 0.8)], [0.6, Color(0.012, 0.024, 0.063, 0.3)], [0.75, Color(0.012, 0.024, 0.063, 0.0)]])
	_frame()
	_txt_sh(f_title, Vector2(120, 250), title, 76, ICE, 5.0)
	_txt(f_t6, Vector2(120, 340), hint, 30, STEEL)
	_rows(104, 420, 700, 80, 38, 8.0, 900.0)
	_hint_bar(1480.0, 756.0, "")

func _draw_about() -> void:
	_bg_img("about"); _grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.012, 0.024, 0.063, 0.96)], [0.46, Color(0.012, 0.024, 0.063, 0.9)], [0.66, Color(0.012, 0.024, 0.063, 0.5)], [0.84, Color(0.012, 0.024, 0.063, 0.1)]])
	_grad_v(Rect2(0, 700, 1600, 200), Color(0.012, 0.024, 0.063, 0.0), Color(0.012, 0.024, 0.063, 0.9))
	draw_rect(Rect2(24, 24, 1552, 852), Color(STEEL.r, STEEL.g, STEEL.b, 0.35), false, 2.0)
	var mw := f_title.get_string_size("МЕНЮ", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_txt(f_title, Vector2(120, 60 + 54), "МЕНЮ", 30, STEEL)
	_tri(Vector2(120 + mw + 22, 60 + 54), 16, 1, ORANGE)
	_txt_sh(f_title, Vector2(120 + mw + 48, 60 + 40), "ОБ ИГРЕ", 64, ICE, 4.0)
	draw_dashed_line(Vector2(120, 60 + 86), Vector2(1480, 60 + 86), Color("24335E"), 2.0, 8.0)
	var y := 176.0
	_txt_sh(f_title, Vector2(120, y + 24), "Карнавальская Гонка", 44, ORANGE, 4.0); y += 56.0
	_txt(f_t6, Vector2(120, y + 14), String(card.get("version", "")), 26, STEEL); y += 50.0
	y += _para(f_t6, Vector2(120, y), String(card.get("about", "")), 25, ICE, 820.0, 34.0) + 12.0
	_txt(f_t8, Vector2(120, y + 12), "КОМАНДА", 22, STEEL); y += 34.0
	draw_line(Vector2(120, y), Vector2(940, y), Color(STEEL.r, STEEL.g, STEEL.b, 0.3), 2.0); y += 10.0
	for i in items.size():
		var it: Dictionary = items[i]; var on := i == sel
		var r := Rect2(94, y, 856, 48)
		_box(r, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.16) if on else Color(0, 0, 0, 0), ORANGE if on else Color(0, 0, 0, 0), 3 if on else 0, 8)
		if on: _tri(Vector2(116, y + 24), 18, 1, ORANGE)
		_txt(f_t6, Vector2(146, y + 24), String(it.get("role", "")), 24, STEEL)
		_txt(f_t7, Vector2(430, y + 24), String(it.get("name", "")), 28, ICE)
		if bool(it.get("links", false)):
			var bx := 940.0
			for lk in [["SoundCloud", Color("FF5500")], ["VK", Color("0077FF")]]:
				var lw := f_t7.get_string_size(lk[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 58.0
				bx -= lw; _box(Rect2(bx, y + 5, lw, 38), lk[1], Color(0, 0, 0, 0), 0, 8)
				_box(Rect2(bx + 6, y + 10, 28, 28), Color.WHITE, Color(0, 0, 0, 0), 0, 6); _txt(f_t8, Vector2(bx + 6, y + 24), "♪" if lk[0] == "SoundCloud" else "VK", 14, lk[1], HORIZONTAL_ALIGNMENT_CENTER, 28)
				_txt(f_t7, Vector2(bx + 42, y + 24), lk[0], 20, Color.WHITE); bx -= 10.0
		elif String(it.get("vk", "")) != "":                                       # одна ссылка: страница ВКонтакте
			var vw := f_t7.get_string_size("VK", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 58.0; var vx := 940.0 - vw
			_box(Rect2(vx, y + 5, vw, 38), Color("0077FF"), Color(0, 0, 0, 0), 0, 8)
			_box(Rect2(vx + 6, y + 10, 28, 28), Color.WHITE, Color(0, 0, 0, 0), 0, 6); _txt(f_t8, Vector2(vx + 6, y + 24), "VK", 14, Color("0077FF"), HORIZONTAL_ALIGNMENT_CENTER, 28)
			_txt(f_t7, Vector2(vx + 42, y + 24), "VK", 20, Color.WHITE)
		y += 54.0
	_hint_bar(1480.0, 756.0, hint)

func _draw_ach() -> void:                                                   # грамоты на стене каюты
	_bg_img("cabin")
	_grad_v(Rect2(0, 740, 1600, 160), Color(0.012, 0.024, 0.063, 0.0), Color(0.012, 0.024, 0.063, 0.92))
	_txt_sh(f_title, Vector2(250, 44 + 48), "ДОСТИЖЕНИЯ", 64, ICE, 5.0)
	var got := 0
	for it in items: if String(it.get("st", "")) in ["got", "new"]: got += 1
	_txt(f_mono, Vector2(250 + f_title.get_string_size("ДОСТИЖЕНИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x + 24, 44 + 78), "%d / %d" % [got, items.size()], 32, ORANGE)
	var rows_n := (items.size() + 3) / 4
	var srow := clampi(sel / 4, 0, maxi(rows_n - 1, 0))
	if srow < ach_row0: ach_row0 = srow
	if srow > ach_row0 + 2: ach_row0 = srow - 2
	ach_row0 = clampi(ach_row0, 0, maxi(rows_n - 3, 0))
	ach_off = lerpf(ach_off, float(ach_row0), 0.25) if absf(ach_off - ach_row0) > 0.01 else float(ach_row0)           # плавная прокрутка рядами
	for i in items.size():
		var it: Dictionary = items[i]; var st := String(it.get("st", "lock")); var on := i == sel
		var col := i % 4; var row := i / 4
		if row < ach_row0 - 1 or row > ach_row0 + 3: continue
		var r := Rect2(84 + col * (207 + 22), 170 + (float(row) - ach_off) * (150 + 26), 207, 150)
		if r.position.y < 150.0 or r.end.y > 740.0: continue
		_box(Rect2(r.position + Vector2(6, 8), r.size), Color(0.01, 0.016, 0.047, 0.6), Color(0, 0, 0, 0), 0, 4)
		var has := st in ["got", "new"]
		_box(r, Color("2A1A0C") if has else Color("0E1733"), ORANGE if on else (Color("C9A66B") if has else Color("3B4C7E")), 4 if on else 3, 4)
		draw_circle(Vector2(r.get_center().x, r.position.y - 10), 6, Color("6476A6"))
		var inner := r.grow(-8)
		_box(inner, Color("F1E4C4") if has else Color("1A2550"), Color(0, 0, 0, 0), 0, 0)
		var ink := Color("2A1A0C") if has else (Color("6476A6") if st != "hidden" else Color("3B4C7E"))
		var seal := Vector2(r.get_center().x, r.position.y + 50)
		if st != "hidden" and _ach_icon(String(it.get("id", "")), Vector2(seal.x, r.position.y + 54), 68.0, not has): pass
		else:
			draw_circle(seal, 19, ORANGE if has else Color("24335E"))
			if has: _star(seal, 10, INK)
			else: _txt(f_t8, Vector2(seal.x - 19, seal.y), "?" if st == "hidden" else "·", 20, Color("6476A6"), HORIZONTAL_ALIGNMENT_CENTER, 38.0)
		var ttl := String(it.get("title", "")) if st != "hidden" else "???"
		var lines := _wrap(f_t8, ttl, 20, inner.size.x - 16)
		for k in lines.size(): _txt(f_t8, Vector2(inner.position.x + 8, r.position.y + 96 + k * 23), lines[k], 20, ink, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x - 16)
		if st == "new": _box(Rect2(r.end.x - 70, r.position.y - 12, 82, 26), ORANGE, Color(0, 0, 0, 0), 0, 6); _txt(f_t8, Vector2(r.end.x - 70, r.position.y + 1), "НОВОЕ", 15, INK, HORIZONTAL_ALIGNMENT_CENTER, 82)
	if rows_n > 3:                                                             # полоса прокрутки
		var th := 3.0 * 176.0 - 26.0; var bh := th * 3.0 / rows_n
		_box(Rect2(1038, 170, 6, th), Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 3)
		_box(Rect2(1038, 170 + (th - bh) * ach_off / float(rows_n - 3), 6, bh), ORANGE, Color(0, 0, 0, 0), 0, 3)
		if ach_row0 > 0: draw_colored_polygon(PackedVector2Array([Vector2(1041, 140), Vector2(1033, 154), Vector2(1049, 154)]), STEEL)
		if ach_row0 < rows_n - 3: draw_colored_polygon(PackedVector2Array([Vector2(1041, 736), Vector2(1033, 722), Vector2(1049, 722)]), STEEL)
	if items.size() > 0:
		var it2: Dictionary = items[clampi(sel, 0, items.size() - 1)]
		var px := 1130.0; var py := 182.0
		_box(Rect2(px + 10, py + 10, 374, 576), DEEP, Color(0, 0, 0, 0), 0, 8); _box(Rect2(px, py, 374, 576), Color(0.024, 0.039, 0.094, 0.9), ORANGE, 3, 8)
		_txt(f_t8, Vector2(px + 28, py + 40), "ГРАМОТА %d / %d" % [sel + 1, items.size()], 20, STEEL)
		var st2 := String(it2.get("st", "lock")); var has2 := st2 in ["got", "new"]
		if st2 != "hidden" and _ach_icon(String(it2.get("id", "")), Vector2(px + 76, py + 118), 120.0, not has2): pass
		else:
			draw_circle(Vector2(px + 28 + 48, py + 70 + 48), 56, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.25)); draw_circle(Vector2(px + 28 + 48, py + 70 + 48), 48, ORANGE if has2 else Color("24335E"))
		if st2 != "hidden" and ach_tex.get(String(it2.get("id", ""))) != null: pass
		elif has2: _star(Vector2(px + 76, py + 118), 26, INK)
		else: _txt(f_t8, Vector2(px + 28, py + 118), "?", 44, Color("6476A6"), HORIZONTAL_ALIGNMENT_CENTER, 96.0)
		var tt := String(it2.get("title", "")) if st2 != "hidden" else "???"
		var yy := py + 196.0
		for ln in _wrap(f_title, tt, 34, 318.0): _txt(f_title, Vector2(px + 28, yy + 20), ln, 34, ICE); yy += 40.0
		yy += 10.0
		var cond := String(it2.get("cond", "")) if st2 != "hidden" else "Скрытая грамота: откроется сама."
		yy += _para(f_t6, Vector2(px + 28, yy), cond, 24, SOFT, 318.0, 32.0)
		if String(it2.get("prog", "")) != "": _txt(f_mono, Vector2(px + 28, yy + 22), String(it2["prog"]), 24, ORANGE)
		var wh := String(it2.get("when", "")) if has2 else ""
		var wl: Array = _wrap(f_t7, wh, 20, 318.0) if wh != "" else []                # дата и условие получения могут не уместиться в одну строку: переносим вверх
		var dy := py + 576.0 - 70.0 - 26.0 * maxi(wl.size() - 1, 0)
		draw_dashed_line(Vector2(px + 28, dy - 28), Vector2(px + 346, dy - 28), Color("24335E"), 2.0, 8.0)
		_txt(f_t7, Vector2(px + 28, dy), "Получено" if has2 else "Не получено", 20, STEEL)
		if has2: _para(f_t7, Vector2(px + 28, dy + 18), wh, 20, ICE, 318.0, 26.0)
	_hint_bar(1480.0, 800.0, hint, Color("24335E"))

func _mmss(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]

func _draw_results() -> void:                                                  # финиш: таблица, место и рекорд, новые достижения
	_grad_h(Rect2(0, 0, 1600, 900), [[0.0, Color(0.012, 0.024, 0.063, 0.88)], [0.6, Color(0.012, 0.024, 0.063, 0.72)], [1.0, Color(0.012, 0.024, 0.063, 0.5)]])
	_frame()
	var ttl := "ДИСКВАЛИФИКАЦИЯ" if bool(res.get("dsq", false)) else "ФИНИШ"
	var tsz := 66 if bool(res.get("dsq", false)) else 96
	_txt_sh(f_title, Vector2(120, 72 + 48), ttl, tsz, ORANGE, 6.0)
	_txt(f_t6, Vector2(120 + f_title.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x + 28, 72 + 74), "Сложность: %s" % String(res.get("level", "")), 28, STEEL)
	var x := 120.0; var w := 880.0; var y := 200.0
	_txt(f_t8, Vector2(x + 24, y + 12), "МЕСТО", 22, STEEL); _txt(f_t8, Vector2(x + 24 + 100, y + 12), "ПИЛОТ", 22, STEEL); _txt(f_t8, Vector2(x + w - 24 - 180, y + 12), "ВРЕМЯ", 22, STEEL, HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
	draw_line(Vector2(x, y + 30), Vector2(x + w, y + 30), Color(STEEL.r, STEEL.g, STEEL.b, 0.4), 2.0)
	y += 38.0
	for e in res.get("rows", []):
		var me := bool(e["me"]); var r := Rect2(x, y, w, 44)
		_box(r, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.16) if me else Color(0, 0, 0, 0), ORANGE if me else Color(0, 0, 0, 0), 3 if me else 0, 8)
		_txt(f_title, Vector2(x + 24, y + 22), "%d" % int(e["place"]), 28, ORANGE if me else ASH if bool(e["dnf"]) else ICE)
		_txt(f_t8 if me else f_t6, Vector2(x + 24 + 100, y + 22), String(e["n"]), 26, ICE if not bool(e["dnf"]) else ASH)
		_txt(f_mono, Vector2(x + w - 24 - 220, y + 22), String(e["time"]), 26, ICE if not bool(e["dnf"]) else ASH, HORIZONTAL_ALIGNMENT_RIGHT, 220.0)
		y += 47.0
	var cx := 1064.0; var cy := 200.0; var cw := 432.0
	var rec_new := bool(res.get("rec_new", false))
	var ch := 150.0 + (46.0 if rec_new else 0.0)
	_box(Rect2(cx + 10, cy + 10, cw, ch), DEEP, Color(0, 0, 0, 0), 0, 10); _box(Rect2(cx, cy, cw, ch), ICE, Color(0, 0, 0, 0), 0, 10)
	_txt(f_t8, Vector2(cx + 24, cy + 32), "МЕСТО", 20, NIGHT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	_txt(f_title, Vector2(cx + 24, cy + 98), ("—" if bool(res.get("dsq", false)) else "%d" % int(res.get("place", 1))), 110, NIGHT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	_txt(f_t6, Vector2(cx + 188, cy + 36), "из %d · «%s»" % [int(res.get("of", 1)), String(res.get("ship", ""))], 22, NIGHT)
	_txt(f_mono, Vector2(cx + 188, cy + 80), String(res.get("time_txt", "")), 38, NIGHT)
	_txt(f_t6, Vector2(cx + 188, cy + 116), String(res.get("rec_txt", "")), 20, Color("3B4C7E"))
	if rec_new:
		var br := Rect2(cx, cy + 150, cw, 46)
		draw_rect(br, ORANGE)
		_star(Vector2(cx + 36, br.get_center().y), 10, INK); _txt(f_t8, Vector2(cx + 56, br.get_center().y), "НОВЫЙ РЕКОРД ТРАССЫ", 21, INK)
		if String(res.get("rec_prev", "")) != "": _txt(f_mono, Vector2(cx + cw - 24 - 150, br.get_center().y), String(res["rec_prev"]), 18, INK, HORIZONTAL_ALIGNMENT_RIGHT, 150.0)
	var ay := 442.0
	var na: Array = res.get("ach", [])
	if na.size() > 0:
		_txt(f_t8, Vector2(cx, ay + 10), "НОВЫЕ ДОСТИЖЕНИЯ", 22, STEEL); ay += 34.0
		for a in na.slice(0, 3):                                                       # три компактные плашки; остальные — строкой «и ещё N», чтобы не налезать на кнопки
			_box(Rect2(cx, ay, cw, 50), Color(0.024, 0.039, 0.094, 0.75), Color("3B4C7E"), 2, 8)
			if not _ach_icon(String(a.get("id", "")), Vector2(cx + 30, ay + 25), 44.0):
				draw_circle(Vector2(cx + 30, ay + 25), 17, ORANGE); _star(Vector2(cx + 30, ay + 25), 9, INK)
			_txt(f_t8, Vector2(cx + 62, ay + 19), String(a["name"]), 21, ICE)
			_txt(f_t4, Vector2(cx + 62, ay + 40), String(a["cond"]), 15, SOFT, HORIZONTAL_ALIGNMENT_LEFT, cw - 76.0)
			ay += 56.0
		if na.size() > 3: _txt(f_t4, Vector2(cx, ay + 14), "и ещё %d — смотрите в разделе «Достижения»" % (na.size() - 3), 17, SOFT); ay += 26.0
	_rows(cx, 684, cw, 64, 30, 6.0, 900.0)
	_hint_bar(1480.0, 800.0, "")
