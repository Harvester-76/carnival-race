class_name HudWidgets
extends Control
# HUD по дизайну Claude Design (холст «Карнавальская гонка — HUD», 30.10.2026; исходники в design_brief/claude_design_result).
# Каждый виджет — свой Control; внутри координаты в px базы 1600×900 от левого верхнего угла виджета, как в спецификации.
# Данные собираются один раз за кадр в _update_state() (словарь S). Для скриншотов есть подмена сценариями: -- hudmock=1..5.
# Контур схемы корабля берётся из настоящих мешей модели (выпуклые оболочки вида сверху), а не из нарисованного в дизайне корабля.

# ---------- токены ----------
const INK := Color("060A18")
const INK2 := Color("121A36")
const STEEL := Color("93A9D9")
const CREAM := Color("F7E6BF")
const WHITE := Color("FFFFFF")
const ORANGE := Color("FF8A1E")
const CYAN := Color("8CD9F2")
const GOOD := Color("59E673")
const WARN := Color("F2CC40")
const DANGER := Color("F24033")
const SKY := Color("2F6FC2")
const EARTH := Color("8A5428")
const GROUND := Color("4A3220")
const TERRAIN := Color("C08A55")

const CEIL_Y := 5350.0                                                       # потолок гонки (main.RIM_Y)
const ALT_K := 0.168                                                         # px/м на ленте высоты
const SPEED_MAX := 2400.0
const MARKER_MAX_DIST := 40000.0                                             # подписи соперников: дальше этого скрыты, последняя четверть гаснет
const MARKER_LOS_MIN := 1500.0                                               # ближе подпись видна всегда, дальше проверяется видимость по рельефу
const MARKER_MAX_N := 6                                                      # не больше стольких подписей одновременно (ближайшие)
const ZONE_NAMES := {"nose": "НОС", "rear": "ХВОСТ", "wing_l": "ЛЕВОЕ КРЫЛО", "wing_r": "ПРАВОЕ КРЫЛО", "top": "ВЕРХ", "belly": "НИЗ"}

# сценарии для скриншотов: -- hudmock=N (значения подменяют живые данные)
const MOCK := {
	1: {"speed": 1200.0, "alt": 1703.0, "agl": 1703.0, "vs": 0.0, "pitch": 2.0, "roll": -6.0, "az": 2.0, "el": -1.0, "dev": 3.0, "devv": 4.0, "zone": "", "cmd": Vector3(0.1, 0.0, 0.15), "ra": ["Вега", 340.0, 0.3], "rb": ["Галлюцинация", 120.0, 0.1], "delta": -3.4, "rank": 7, "prog": 0.06, "hp_lost": []},
	2: {"speed": 1900.0, "alt": 5150.0, "agl": 5150.0, "vs": 180.0, "pitch": 14.0, "roll": 0.0, "az": 1.0, "el": 6.0, "dev": 0.0, "devv": 2.0, "zone": "top", "ztti": 0.9, "cmd": Vector3(0.6, 0.0, 0.0), "ra": ["Аргамак", 210.0, 0.1], "rb": ["Чайка", 560.0, 0.3], "delta": 6.0, "rank": 5, "prog": 0.2, "hp_lost": []},
	3: {"speed": 1600.0, "alt": 120.0, "agl": 122.0, "vs": -140.0, "ground_t": 0.9, "pitch": -9.0, "roll": 20.0, "az": 8.0, "el": -12.0, "dev": -18.0, "devv": -6.0, "zone": "belly", "ztti": 2.4, "cmd": Vector3(-0.4, 0.0, -0.5), "lost": ["SM_Wing_Top_L", "SM_Engine_TakeOff_Back_L2"], "ra": ["Вега", 1300.0, 0.8], "rb": ["Долгоносик", 80.0, 0.05], "delta": 1.8, "rank": 9, "prog": 0.39},
	4: {"speed": 2100.0, "alt": 1700.0, "agl": 1700.0, "vs": 20.0, "pitch": 4.0, "roll": 38.0, "az": 14.0, "el": 3.0, "dev": 24.0, "devv": 30.0, "zone": "wing_r", "ztti": 0.7, "cmd": Vector3(0.0, 0.5, -0.9), "ra": ["Звёздная пыль", 90.0, 0.04], "rb": ["Межгалактический Странник Удачи", 700.0, 0.3], "delta": -0.6, "rank": 4, "prog": 0.52},
	5: {"speed": 700.0, "alt": 5407.0, "agl": 5407.0, "vs": 60.0, "pitch": 22.0, "roll": -4.0, "az": -3.0, "el": 10.0, "dev": -40.0, "devv": -35.0, "zone": "nose", "ztti": 2.8, "cmd": Vector3(1.0, -0.3, -0.1), "lost": ["SM_Wing_Top_L", "SM_Wing_Top_R", "SM_Engine_Main_L", "SM_Engine_TakeOff_Back_R2", "SM_Engine_Shunt_Nose"], "ra": ["Вега", 4800.0, 3.0], "rb": [], "delta": 21.0, "rank": 11, "prog": 0.8, "out_left": 6.0},
}

var main: Node
var ui: Node
var S := {}                                                                  # состояние кадра
var mock_id := 0
var mode := 0                                                                # 0 полный · 1 минимальный · 2 стрим
var fonts := {}
var W := {}                                                                  # имя -> Control виджета
var sb_plaque: StyleBoxFlat
var sb_alarm: StyleBoxFlat
var tex_hatch_r: ImageTexture
var tex_hatch_g: ImageTexture
var hold := {}                                                               # имя -> секунд до скрытия (минимальный режим и стрим)
var prev_rank := 0
var rank_flash := 0.0
var rank_flash_kind := 0                                                     # 1 обогнали, -1 потеряли место
var prev_parts := 0
var lost_t := 0.0                                                            # сколько осталось показывать панель здоровья после потери детали
var disp_speed := 0.0                                                        # сглаженная скорость для числа на спидометре
var plan_ship_id := 0
var plan_polys := {}                                                         # деталь -> контур вида сверху в координатах виджета здоровья
var plan_hull := PackedVector2Array()
var plan_box := Rect2()
var plan_wing_l := Vector2()
var plan_wing_r := Vector2()
var plan_lift := {}                                                          # взлётные моторы: имя -> центр контура
var marker_los := {}                                                         # номер бота -> [время проверки, виден]
var markers: Array = []                                                      # подписи соперников этого кадра
var horizon: Control
var map_cache := {"id": 0, "pts": PackedVector2Array(), "s": PackedFloat32Array(), "cuts": [], "lo": Vector2(), "k": 1.0, "off": Vector2()}

func setup(main_node: Node, ui_node: Node) -> void:
	main = main_node; ui = ui_node
	set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ua in OS.get_cmdline_user_args(): if ua.begins_with("hudmock="): mock_id = int(ua.substr(8))
	_load_fonts(); _make_styles(); _make_hatch()
	mode = clampi(int(main.cfg.get("hud_mode", 0)), 0, 2)
	for ua in OS.get_cmdline_user_args(): if ua.begins_with("hudmode="): mode = clampi(int(ua.substr(8)), 0, 2)      # -- hudmode=0|1|2 для скриншотов
	W["pos"] = _mk(Vector2(24, 24), Vector2(128, 96), _draw_pos)
	W["riv"] = _mk(Vector2(164, 24), Vector2(320, 96), _draw_riv)
	W["timer"] = _mk(Vector2(620, 24), Vector2(360, 96), _draw_timer)
	W["pace"] = _mk(Vector2(1296, 24), Vector2(280, 96), _draw_pace)
	W["alt"] = _mk(Vector2(24, 132), Vector2(128, 452), _draw_alt)
	W["spd"] = _mk(Vector2(24, 596), Vector2(280, 280), _draw_spd)
	W["att"] = _mk(Vector2(316, 676), Vector2(216, 200), _draw_att)
	W["hp"] = _mk(Vector2(1296, 132), Vector2(280, 280), _draw_hp)
	W["chip"] = _mk(Vector2(1296, 420), Vector2(280, 32), _draw_chip)
	W["map"] = _mk(Vector2(1296, 596), Vector2(280, 280), _draw_map)
	W["alarm"] = _mk(Vector2(560, 132), Vector2(480, 72), _draw_alarm)
	W["msg"] = _mk(Vector2(480, 812), Vector2(640, 40), _draw_msg)
	var mask := Panel.new(); mask.position = Vector2(12, 54); mask.size = Vector2(192, 110); mask.mouse_filter = Control.MOUSE_FILTER_IGNORE    # скруглённое окно горизонта (радиус 12)
	var mk := StyleBoxFlat.new(); mk.bg_color = WHITE; mk.set_corner_radius_all(12); mask.add_theme_stylebox_override("panel", mk)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY; (W["att"] as Control).add_child(mask)
	horizon = Control.new(); horizon.size = Vector2(192, 110); horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE; mask.add_child(horizon)
	horizon.draw.connect(_draw_horizon)
	W["marks"] = _mk(Vector2.ZERO, Vector2(1600, 900), _draw_marks)
	(W["marks"] as Control).get_parent().remove_child(W["marks"]); (ui.marker_root as Control).add_child(W["marks"])      # подписи — под плашками HUD и видны и в паузе

func _mk(pos: Vector2, sz: Vector2, drawer: Callable) -> Control:
	var c := Control.new(); c.position = pos; c.size = sz; c.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(c)
	c.draw.connect(drawer.bind(c)); return c

func _load_fonts() -> void:
	var load_f: Callable = func(n: String) -> Font:
		var r = load("res://menu_v2/fonts/" + n)
		return r if r is Font else ThemeDB.fallback_font
	fonts["dela"] = load_f.call("DelaGothicOne-400.ttf")
	fonts["g4"] = load_f.call("GolosText-400.ttf"); fonts["g6"] = load_f.call("GolosText-600.ttf")
	fonts["g7"] = load_f.call("GolosText-700.ttf"); fonts["g8"] = load_f.call("GolosText-800.ttf")
	fonts["m7"] = load_f.call("JetBrainsMono-700.ttf")
	var fv := FontVariation.new(); fv.base_font = fonts["m7"]; fv.variation_embolden = 0.35; fonts["m8"] = fv   # «800» — утолщённый 700, начертания 800 у шрифта нет

func _make_styles() -> void:
	sb_plaque = StyleBoxFlat.new(); sb_plaque.bg_color = Color(INK, 0.72); sb_plaque.border_color = Color(STEEL, 0.28); sb_plaque.set_border_width_all(1); sb_plaque.set_corner_radius_all(10)
	sb_alarm = StyleBoxFlat.new(); sb_alarm.bg_color = Color(INK, 0.86); sb_alarm.set_border_width_all(2); sb_alarm.set_corner_radius_all(6)

func _make_hatch() -> void:                                                  # штриховка 45°: красная с тёмными полосами / землистая со светлыми
	var ir := Image.create(6, 6, false, Image.FORMAT_RGBA8); var ig := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var dark := Color(DANGER.r * 0.45, DANGER.g * 0.45, DANGER.b * 0.45, 1.0)
	for y in 6:
		for x in 6: ir.set_pixel(x, y, dark if (x + y) % 6 < 2 else DANGER)
	for y in 8:
		for x in 8: ig.set_pixel(x, y, GROUND.lerp(TERRAIN, 0.35) if (x - y + 8) % 8 < 2 else GROUND)
	tex_hatch_r = ImageTexture.create_from_image(ir); tex_hatch_g = ImageTexture.create_from_image(ig)

# ---------- помощники рисования ----------
func _plaque(c: Control, r: Rect2) -> void: c.draw_style_box(sb_plaque, r)

func _alarm_box(c: Control, r: Rect2, col: Color) -> void:
	var sb := sb_alarm.duplicate() as StyleBoxFlat; sb.border_color = col; c.draw_style_box(sb, r)

func _tx(c: Control, key: String, size: int, s: String, x: float, top: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, lh := 0.0, outline := 0, ocol := INK) -> void:
	var f: Font = fonts[key]; var asc := f.get_ascent(size); var desc := f.get_descent(size)
	var h := lh if lh > 0.0 else (asc + desc)
	var p := Vector2(x, top + (h - (asc + desc)) * 0.5 + asc)
	if outline > 0: c.draw_string_outline(f, p, s, align, w, size, outline, ocol)
	c.draw_string(f, p, s, align, w, size, col)

func _txr(c: Control, key: String, size: int, s: String, right: float, top: float, col: Color, lh := 0.0) -> void:   # текст, прижатый правым краем к right
	_tx(c, key, size, s, right - 400.0, top, col, HORIZONTAL_ALIGNMENT_RIGHT, 400.0, lh)

func _txc(c: Control, key: String, size: int, s: String, cx: float, top: float, col: Color, lh := 0.0, outline := 0) -> void:
	_tx(c, key, size, s, cx - 300.0, top, col, HORIZONTAL_ALIGNMENT_CENTER, 600.0, lh, outline)

func _tw(key: String, size: int, s: String) -> float: return (fonts[key] as Font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _line2(c: Control, a: Vector2, b: Vector2, col: Color, w: float, under := 0.0) -> void:   # линия с тёмной обводкой под ней
	if under > 0.0: c.draw_line(a, b, INK, w + under, true)
	c.draw_line(a, b, col, w, true)

func _dashed(c: Control, pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float, closed := true) -> void:
	var n := pts.size()
	var cnt := n if closed else n - 1
	for i in cnt:
		var a := pts[i]; var b := pts[(i + 1) % n]
		var l := a.distance_to(b)
		if l < 0.01: continue
		var d := (b - a) / l; var t := 0.0
		while t < l:
			c.draw_line(a + d * t, a + d * minf(t + dash, l), col, w, true); t += dash + gap

func _fmt_d(m: float) -> String: return ("%d м" % int(round(m / 10.0) * 10.0)) if m < 1000.0 else (("%.1f км" % (m / 1000.0)).replace(".", ","))
func _fmt_t(t: float) -> String: return ("%.1f с" % t).replace(".", ",")
func _zone_col(tti: float) -> Color: return WARN if tti > 1.2 else DANGER
func _tcol(t: float, calm: Color) -> Color: return DANGER if t < 3.0 else (WARN if t < 6.0 else calm)

# ---------- данные кадра ----------
func _process(dt: float) -> void:
	if main == null or main.ship == null or not visible: return
	_update_state(dt)
	for k in W: (W[k] as Control).queue_redraw()
	horizon.queue_redraw()
	_update_visibility(dt)

func _unhandled_input(ev: InputEvent) -> void:                                # F2: полный → минимальный → стрим (кнопка Back на геймпаде уже занята под «Интерьер»)
	if ui == null or ui.state != "hud": return
	var hit := false
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo and (ev as InputEventKey).keycode == KEY_F2: hit = true
	if hit: mode = (mode + 1) % 3; main.cfg["hud_mode"] = mode; main._save_cfg()

func _update_state(dt: float) -> void:
	var m = main; var sh: RigidBody3D = m.ship
	var tr: Transform3D = sh.global_transform; var b: Basis = tr.basis.orthonormalized()
	var p: Vector3 = tr.origin; var v: Vector3 = sh.linear_velocity
	var f := -b.z
	S["speed"] = v.length(); S["alt"] = p.y
	var gh := float(m.height(p.x, p.z)); S["agl"] = p.y - gh; S["vs"] = v.y
	S["ground_t"] = _ground_time(p, v)
	var terr := []
	for t in [1.0, 2.0, 3.0]:
		var q: Vector3 = p + v * float(t); terr.append(float(m.height(q.x, q.z)))
	S["terr"] = terr; S["ground"] = gh
	S["out_left"] = maxf(float(m.RIM_GRACE) - float(m.rim_t), 0.0)
	S["pitch"] = rad_to_deg(asin(clampf(f.y, -1.0, 1.0))); S["roll"] = rad_to_deg(atan2(-b.x.y, b.y.y))
	S["fpv"] = false; S["az"] = 0.0; S["el"] = 0.0; S["dev"] = 0.0; S["devv"] = 0.0; S["dev_ok"] = false
	if v.length() > 30.0:
		var vl := b.inverse() * v
		S["fpv"] = true; S["az"] = rad_to_deg(atan2(vl.x, -vl.z)); S["el"] = rad_to_deg(atan2(vl.y, Vector2(vl.x, vl.z).length()))
	if m.trk_pts.size() > 1:
		var ta: float = (m._track_at(m.p_prog)[1] as Vector2).angle()
		S["dev"] = rad_to_deg(wrapf(Vector2(f.x, f.z).angle() - ta, -PI, PI)); S["dev_ok"] = true
		if v.length() > 30.0: S["devv"] = rad_to_deg(wrapf(Vector2(v.x, v.z).angle() - ta, -PI, PI))
	var g: Vector3 = (m.last_ctrl.get("gyro", Vector3.ZERO) as Vector3)
	S["cmd"] = Vector3(-g.x, g.y, -g.z)                                      # тангаж: + вверх; рыскание; крен: + вправо
	S["hp"] = m.ship_health()
	S["rank"] = int(m.rank); S["total"] = m.bots.size() + 1
	S["race_t"] = float(m.race_t); S["level"] = String(m.LEVEL_NAMES[m._lvl()]).to_upper()
	var rl: float = float(m.race_len); var pp: float = float(m.p_prog)
	S["prog"] = clampf(pp / rl, 0.0, 1.0) if rl < 1e11 else 0.0; S["to_finish"] = maxf(rl - pp, 0.0)
	var sfx = m.ship_sfx
	S["zone"] = ""; S["zon"] = false; S["ztti"] = 99.0
	if sfx != null and int(sfx.park_zone) >= 0:
		S["zone"] = String(sfx.PARK_ZONES[int(sfx.park_zone)]["n"]); S["zon"] = bool(sfx.park_on); S["ztti"] = float(sfx.park_tti)
	S["lost"] = []
	_update_rivals(v, pp)
	_update_pace(pp, rl)
	if mock_id > 0 and MOCK.has(mock_id): _apply_mock()
	if mock_id == 0:
		if prev_rank > 0 and int(S["rank"]) != prev_rank: rank_flash = 0.6; rank_flash_kind = 1 if int(S["rank"]) < prev_rank else -1
		prev_rank = int(S["rank"])
	rank_flash = maxf(rank_flash - dt, 0.0)
	var np: int = m.parts.size()
	if prev_parts > 0 and np < prev_parts: lost_t = 2.0
	prev_parts = np; lost_t = maxf(lost_t - dt, 0.0)
	disp_speed = lerpf(disp_speed, float(S["speed"]), 1.0 - exp(-12.0 * dt))
	S["ttc"] = ((CEIL_Y - float(S["alt"])) / float(S["vs"])) if (float(S["vs"]) > 5.0 and float(S["alt"]) <= CEIL_Y) else 99.0

func _apply_mock() -> void:
	var d: Dictionary = MOCK[mock_id]
	for k in ["speed", "alt", "agl", "vs", "pitch", "roll", "az", "el", "dev", "devv", "cmd", "ztti", "rank", "prog", "out_left"]:
		if d.has(k): S[k] = d[k]
	S["fpv"] = true; S["dev_ok"] = true; S["zone"] = String(d.get("zone", "")); S["zon"] = S["zone"] != ""
	S["ground_t"] = float(d.get("ground_t", 99.0)); S["terr"] = [float(S["alt"]) - float(S["agl"]) + 30.0, float(S["alt"]) - float(S["agl"]) + 90.0, float(S["alt"]) - float(S["agl"]) + 160.0]
	S["ground"] = float(S["alt"]) - float(S["agl"])
	S["lost"] = d.get("lost", []); S["hp"] = 1.0 - 0.06 * float((S["lost"] as Array).size())
	S["to_finish"] = (1.0 - float(S["prog"])) * 640000.0
	S["race_t"] = float(S["prog"]) * 330.0
	var ra: Array = d.get("ra", []); var rb: Array = d.get("rb", [])
	S["a"] = {"name": ra[0], "dist": ra[1], "time": ra[2]} if ra.size() == 3 else null
	S["b"] = {"name": rb[0], "dist": rb[1], "time": rb[2]} if rb.size() == 3 else null
	S["pace_ready"] = true; S["pace_delta"] = float(d.get("delta", 0.0)); S["pace_dev"] = false
	S["cut_kind"] = "in" if mock_id == 3 else "before"; S["cut_km"] = 5.4 if mock_id == 3 else (60.2 if mock_id != 5 else 0.8)
	S["cut_marks"] = [[0.16, 0.39], [0.47, 0.55], [0.6, 0.71]]

func _ground_time(p: Vector3, v: Vector3) -> float:
	for k in 12:
		var t := 0.5 * float(k + 1)
		var q := p + v * t
		if q.y - float(main.height(q.x, q.z)) < 20.0: return t
	return 99.0

func _update_rivals(v: Vector3, pp: float) -> void:
	var vp := maxf(v.length(), 300.0)
	var a_gap := 1e12; var b_gap := 1e12; var a = null; var b = null
	for bt in main.bots:
		if bool(bt["fin"]): continue
		var g: float = float(bt["prog"]) - pp
		if g > 0.0 and g < a_gap: a_gap = g; a = bt
		elif g <= 0.0 and -g < b_gap: b_gap = -g; b = bt
	S["a"] = {"name": String(a["name"]), "dist": a_gap, "time": a_gap / vp} if (a != null and a_gap < 6000.0) else null
	S["b"] = {"name": String(b["name"]), "dist": b_gap, "time": b_gap / vp} if (b != null and b_gap < 6000.0) else null

func _update_pace(pp: float, rl: float) -> void:
	var rec: Dictionary = main.cfg.get("rec", {}); var key := "%d:%d" % [main._lvl(), int(main.cfg.get("ship", 0))]
	var personal: bool = rec.has(key)
	var ref_t: float = float(rec[key]) if personal else float(ui.DEV_RECORD)
	var frac := clampf(pp / maxf(rl, 1.0), 0.0, 1.0)
	S["pace_ready"] = frac > 0.02 and float(main.race_t) > 5.0
	S["pace_delta"] = float(main.race_t) - ref_t * frac; S["pace_dev"] = not personal
	var kind := ""; var km := 0.0
	for fk in main.forks:
		if pp < float(fk["out"]):
			if pp >= float(fk["in"]): kind = "in"; km = (float(fk["out"]) - pp) / 1000.0
			else: kind = "before"; km = (float(fk["in"]) - pp) / 1000.0
			break
	S["cut_kind"] = kind; S["cut_km"] = km
	var marks := []
	if rl < 1e11: for fk in main.forks: marks.append([clampf(float(fk["in"]) / rl, 0.0, 1.0), clampf(float(fk["out"]) / rl, 0.0, 1.0)])
	S["cut_marks"] = marks

# ---------- режимы: полный / минимальный / стрим ----------
func _near_limit() -> bool:
	var a := float(S.get("alt", 0.0)); var agl := float(S.get("agl", 9999.0))
	return (CEIL_Y - a) < 600.0 or agl < 600.0 or float(S.get("ttc", 99.0)) < 6.0 or float(S.get("ground_t", 99.0)) < 6.0

func _strike() -> bool: return String(S.get("zone", "")) != "" or lost_t > 0.0

func _want(name: String) -> bool:
	match name:
		"pos", "riv", "timer", "pace", "map": return mode != 1
		"spd", "att": return mode != 2
		"alt": return mode == 0 or _near_limit() or float(S.get("alt", 0.0)) > CEIL_Y
		"hp": return mode != 1 or _strike()
		"chip": return true
	return true

func _update_visibility(dt: float) -> void:
	for k in ["pos", "riv", "timer", "pace", "map", "spd", "att", "alt", "hp", "chip"]:
		var want := _want(k)
		var vis: bool = want
		if mode != 0 and k in ["alt", "hp"]:                                 # условные виджеты держатся 2 с после того, как условие прошло
			hold[k] = 2.0 if want else maxf(float(hold.get(k, 0.0)) - dt, 0.0)
			vis = want or float(hold[k]) > 0.0
		var c: Control = W[k]
		c.modulate.a = move_toward(c.modulate.a, 1.0 if vis else 0.0, dt / (0.2 if vis else 0.3))
		c.visible = c.modulate.a > 0.01
	(W["riv"] as Control).visible = (W["riv"] as Control).visible and (S.get("a") != null or S.get("b") != null)
	(W["chip"] as Control).visible = (W["chip"] as Control).visible and String(S.get("zone", "")) != "" and (mode == 0 or (W["hp"] as Control).visible)
	(W["alarm"] as Control).visible = float(S.get("alt", 0.0)) > CEIL_Y and (mock_id > 0 or (not main.p_dsq and not main.p_fin and float(main.dsq_t) <= 0.0))    # после дисквалификации баннера и отсчёта нет
	(W["msg"] as Control).visible = String(_msg_info()[0]) != ""

# ---------- 1. позиция ----------
func _draw_pos(c: Control) -> void:
	var fl := rank_flash > 0.0
	var col := GOOD if (fl and rank_flash_kind > 0) else (ORANGE if fl else CREAM)
	var sb := sb_plaque.duplicate() as StyleBoxFlat
	if fl: sb.border_color = col; sb.set_border_width_all(2)
	c.draw_style_box(sb, Rect2(0, 0, 128, 96))
	_tx(c, "g7", 11, "ПОЗИЦИЯ", 12, 12, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var ps := str(int(S.get("rank", 1))); var wn := _tw("dela", 40, ps)
	_tx(c, "dela", 40, ps, 12, 34, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 44)
	_tx(c, "g7", 18, "/%d" % int(S.get("total", 12)), 12 + wn + 2, 34, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 44)

# ---------- 2. соперники рядом ----------
func _riv_name(nm: String, key: String, size: int, maxw: float) -> String:
	var s := nm
	while s.length() > 3 and _tw(key, size, s) > maxw: s = s.substr(0, s.length() - 1)
	return s if s == nm else s.rstrip(" ") + "…"

func _draw_riv(c: Control) -> void:
	var a = S.get("a"); var b = S.get("b")
	_plaque(c, Rect2(0, 0, 320, 96))
	for i in 2:
		var r = a if i == 0 else b
		var col := ORANGE if i == 0 else CYAN
		var y := 8.0 + 40.0 * i
		var close: bool = r != null and float(r["time"]) < 0.5
		if close: c.draw_style_box(_flat(Color(col, 0.16), 6), Rect2(6, y, 308, 36))
		var tri := PackedVector2Array([Vector2(18, y + 13), Vector2(30, y + 13), Vector2(24, y + 23)]) if i == 1 else PackedVector2Array([Vector2(24, y + 13), Vector2(30, y + 23), Vector2(18, y + 23)])
		c.draw_colored_polygon(tri, col if r != null else Color(STEEL, 0.45))
		if r != null:
			_tx(c, "g6", 16, _riv_name(String(r["name"]), "g6", 16, 132.0), 32, y, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)
			_txr(c, "m7", 15, _fmt_d(float(r["dist"])), 236, y, col, 36); _txr(c, "m7", 15, _fmt_t(float(r["time"])), 308, y, col, 36)
		else:
			var empty := ("Вы лидируете" if int(S.get("rank", 1)) == 1 else "дальше 6 км") if i == 0 else ("Вы последний" if int(S.get("rank", 1)) == int(S.get("total", 12)) else "дальше 6 км")
			_tx(c, "g6", 16, empty, 32, y, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)

func _flat(col: Color, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(r); return sb

# ---------- 3. время и прогресс ----------
func _draw_timer(c: Control) -> void:
	_plaque(c, Rect2(0, 0, 360, 96))
	var t := float(S.get("race_t", 0.0))
	_txc(c, "m7", 36, "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)], 180, 8, CREAM, 42)
	c.draw_style_box(_flat(Color(STEEL, 0.2), 3), Rect2(16, 56, 328, 6))
	var fw := maxf(6.0, float(S.get("prog", 0.0)) * 328.0)
	c.draw_style_box(_flat(ORANGE, 3), Rect2(16, 56, fw, 6))
	for cm in S.get("cut_marks", []): c.draw_line(Vector2(16 + float(cm[0]) * 328, 67), Vector2(16 + float(cm[1]) * 328, 67), Color(ORANGE, 0.75), 2.0)
	for x in [98, 180, 262]: c.draw_line(Vector2(x, 53), Vector2(x, 65), Color(INK, 0.7), 1.0)
	if mode != 2: _tx(c, "g7", 11, String(S.get("level", "")), 16, 72, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var val := _fmt_d(float(S.get("to_finish", 0.0))); var wv := _tw("m7", 13, val)
	_txr(c, "m7", 13, val, 344, 72, CREAM, 16)
	_txr(c, "g7", 11, "ДО ФИНИША ", 344 - wv, 72, STEEL, 16)

# ---------- 4. темп и срезка ----------
func _draw_pace(c: Control) -> void:
	_plaque(c, Rect2(0, 0, 280, 96))
	var ready := bool(S.get("pace_ready", false)); var d := float(S.get("pace_delta", 0.0)); var ahead := d < 0.0
	var col := STEEL if not ready else (GOOD if ahead else DANGER)
	_tx(c, "g7", 11, "К РАЗРАБОТЧИКУ" if bool(S.get("pace_dev", true)) else "К РЕКОРДУ", 12, 12, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var val := "—"
	if ready:
		val = ("−" if ahead else "+") + _fmt_t(absf(d)).replace(" с", "") + " с"
		var chip := "ВПЕРЕДИ" if ahead else "ПОЗАДИ"
		var cw := _tw("g8", 11, chip) + 16.0
		c.draw_style_box(_flat(GOOD if ahead else DANGER, 4), Rect2(12, 32, cw, 20))
		_tx(c, "g8", 11, chip, 20, 32, INK if ahead else WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var ax := 268.0 - _tw("m8", 28, val) - 20.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(ax + 7, 28), Vector2(ax + 14, 40), Vector2(ax, 40)]) if ahead else PackedVector2Array([Vector2(ax, 28), Vector2(ax + 14, 28), Vector2(ax + 7, 40)]), col)
	_txr(c, "m8", 28, val, 268, 10, col, 40)
	c.draw_line(Vector2(12, 62.5), Vector2(268, 62.5), Color(STEEL, 0.2), 1.0)
	var kind := String(S.get("cut_kind", ""))
	if kind != "":
		var cc := ORANGE if kind == "in" else CREAM; var lc := ORANGE if kind == "in" else STEEL
		var km := float(S.get("cut_km", 0.0)); var kt := (("%d м" % int(km * 1000.0)) if km < 1.0 else (("%.1f км" % km).replace(".", ",")))
		var lab := "В срезке · выход через" if kind == "in" else "Срезка через"
		_txr(c, "m7", 13, kt, 268, 70, cc, 18)
		var wk := _tw("m7", 13, kt)
		_txr(c, "g6", 13, lab, 268 - wk - 6, 70, lc, 18)
		var fx := 268.0 - wk - 6.0 - _tw("g6", 13, lab) - 22.0                   # значок развилки
		c.draw_polyline(PackedVector2Array([Vector2(fx + 4, 83), Vector2(fx + 4, 71)]), cc, 2.0, true); c.draw_polyline(PackedVector2Array([Vector2(fx + 4, 77), Vector2(fx + 4, 74), Vector2(fx + 10, 74), Vector2(fx + 10, 71)]), cc, 2.0, true)

# ---------- 5. шкала высоты ----------
func _draw_alt(c: Control) -> void:
	var alt := float(S.get("alt", 0.0)); var agl := float(S.get("agl", 0.0)); var vs := float(S.get("vs", 0.0))
	var above := alt > CEIL_Y; var ground := alt - agl
	var gt := float(S.get("ground_t", 99.0)); var ttc := float(S.get("ttc", 99.0))
	_plaque(c, Rect2(0, 0, 128, 452))
	var gdanger := gt < 3.0
	if above: c.draw_style_box(_flat(DANGER, 10), Rect2(0, 0, 128, 52)); c.draw_rect(Rect2(0, 40, 128, 12), DANGER)
	if gdanger: c.draw_style_box(_flat(DANGER, 10), Rect2(0, 400, 128, 52)); c.draw_rect(Rect2(0, 400, 128, 12), DANGER)
	_tx(c, "g8" if above else "g7", 11, "ЗА ПОТОЛКОМ" if above else "ПОТОЛОК", 10, 10, WHITE if above else STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var hv := ("+%d м" % int(round(alt - CEIL_Y))) if above else ("%d м" % int(round(CEIL_Y - alt)))
	_tx(c, "m7", 18, hv, 10, 26, WHITE if above else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	if above: _txr(c, "m8", 13, "%d с" % int(ceil(float(S.get("out_left", 8.0)))), 118, 28, WHITE, 16)
	elif ttc < 10.0: _txr(c, "m8", 13, _fmt_t(ttc), 118, 28, _tcol(ttc, CREAM), 16)
	c.draw_line(Vector2(0, 52.5), Vector2(128, 52.5), Color(STEEL, 0.2), 1.0); c.draw_line(Vector2(0, 399.5), Vector2(128, 399.5), Color(STEEL, 0.2), 1.0)
	var TOP := 58.0; var BOT := 394.0; var MID := 226.0
	c.draw_rect(Rect2(46, TOP, 32, BOT - TOP), INK2)
	var band: Callable = func(lo: float, hi: float, col: Color, tex = null) -> void:
		var y1 := clampf(MID - (hi - alt) * ALT_K, TOP, BOT); var y2 := clampf(MID - (lo - alt) * ALT_K, TOP, BOT)
		if y2 - y1 < 0.5: return
		if tex != null: c.draw_texture_rect(tex, Rect2(46, y1, 32, y2 - y1), true)
		else: c.draw_rect(Rect2(46, y1, 32, y2 - y1), col)
	var BIG := 1.0e6
	band.call(ground + 250.0, CEIL_Y - 300.0, Color(GOOD, 0.32))
	band.call(maxf(CEIL_Y - 300.0, ground + 250.0), CEIL_Y, Color(WARN, 0.85))
	band.call(CEIL_Y, BIG, WHITE, tex_hatch_r)
	band.call(-BIG, ground, WHITE, tex_hatch_g)
	band.call(ground + 80.0, ground + 250.0, Color(WARN, 0.85))
	band.call(ground, ground + 80.0, WHITE, tex_hatch_r)
	var gy := MID - (ground - alt) * ALT_K
	if gy > TOP and gy < BOT: c.draw_line(Vector2(46, gy), Vector2(78, gy), TERRAIN, 2.0)
	var h0 := int(ceil((alt - 1000.0) / 100.0)) * 100
	for h in range(h0, int(alt + 1000.0) + 1, 100):
		var y := MID - (float(h) - alt) * ALT_K
		if y < TOP + 1.0 or y > BOT - 1.0: continue
		if h % 500 == 0:
			c.draw_line(Vector2(38, y), Vector2(46, y), STEEL, 2.0); _tx(c, "m7", 11, str(h), 0, y - 7, STEEL, HORIZONTAL_ALIGNMENT_RIGHT, 38, 14)
		else: c.draw_line(Vector2(41, y), Vector2(46, y), Color(STEEL, 0.6), 1.0)
	var cy := MID - (CEIL_Y - alt) * ALT_K
	if cy > TOP and cy < BOT: _line2(c, Vector2(40, cy), Vector2(86, cy), DANGER, 4.0, 3.0)
	for hh in S.get("terr", []):
		var y := MID - (float(hh) - alt) * ALT_K
		if y > TOP + 4.0 and y < BOT - 4.0: c.draw_polyline(PackedVector2Array([Vector2(88, y - 4), Vector2(81, y), Vector2(88, y + 4)]), TERRAIN, 2.5, true)
	if absf(vs) > 5.0:
		var tc := _tcol(ttc if vs > 0.0 else gt, WHITE)
		var ay := MID - clampf(vs / 300.0, -1.0, 1.0) * 110.0; var u := -1.0 if vs > 0.0 else 1.0
		c.draw_line(Vector2(62, MID), Vector2(62, ay), INK, 8.0, true); c.draw_line(Vector2(62, MID), Vector2(62, ay), tc, 4.0, true)
		var head := PackedVector2Array([Vector2(62, ay + 5 * u), Vector2(56, ay - 5 * u), Vector2(68, ay - 5 * u)])
		c.draw_colored_polygon(head, tc); c.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), INK, 1.5, true)
	_line2(c, Vector2(42, MID), Vector2(82, MID), WHITE, 2.0, 3.0)
	var mt := PackedVector2Array([Vector2(82, MID), Vector2(92, MID - 6), Vector2(92, MID + 6)])
	c.draw_colored_polygon(mt, WHITE); c.draw_polyline(PackedVector2Array([mt[0], mt[1], mt[2], mt[0]]), INK, 1.5, true)
	_tx(c, "m7", 12, "0" if int(round(vs)) == 0 else (("+" if vs > 0.0 else "−") + str(absi(int(round(vs))))), 94, MID - 8, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	_tx(c, "g7", 11, "ЗЕМЛЯ", 10, 410, WHITE if gdanger else STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	_tx(c, "m7", 18, "%d м" % int(round(maxf(agl, 0.0))), 10, 426, WHITE if gdanger else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	if gt <= 6.0: _txr(c, "m8", 13, _fmt_t(gt), 118, 428, WHITE if gdanger else _tcol(gt, CREAM), 16)

# ---------- 6. спидометр ----------
func _pt(f: float, r: float) -> Vector2:
	var a := deg_to_rad(135.0 + 270.0 * f); return Vector2(140 + r * cos(a), 140 + r * sin(a))

func _draw_spd(c: Control) -> void:
	var v := float(S.get("speed", 0.0)); var vv := clampf(v, 0.0, SPEED_MAX); var f := vv / SPEED_MAX
	c.draw_circle(Vector2(140, 140), 140, Color(INK, 0.72)); c.draw_arc(Vector2(140, 140), 139.5, 0, TAU, 96, Color(STEEL, 0.28), 1.0, true)
	var zones := [[0.0, 0.35, GOOD], [0.35, 0.65, WARN], [0.65, 0.85, ORANGE], [0.85, 1.0, DANGER]]
	var g := 0.004
	for z in zones:
		var z0: float = float(z[0]) + (g if float(z[0]) > 0.0 else 0.0); var z1: float = float(z[1]) - (g if float(z[1]) < 1.0 else 0.0); var col: Color = z[2]
		c.draw_arc(Vector2(140, 140), 118, deg_to_rad(135.0 + 270.0 * z0), deg_to_rad(135.0 + 270.0 * z1), 36, Color(col, 0.28), 12.0, true)
		if f > z0: c.draw_arc(Vector2(140, 140), 118, deg_to_rad(135.0 + 270.0 * z0), deg_to_rad(135.0 + 270.0 * minf(f, z1)), 36, col, 12.0, true)
	for s in range(0, 2401, 100):
		var ff := float(s) / SPEED_MAX
		if s % 500 == 0: c.draw_line(_pt(ff, 98), _pt(ff, 109), CREAM, 2.0, true)
		else: c.draw_line(_pt(ff, 102), _pt(ff, 109), Color(STEEL, 0.6), 1.0, true)
	for s in [0, 500, 1000, 1500, 2000]:
		var p := _pt(float(s) / SPEED_MAX, 84); _tx(c, "m7", 11, str(s), p.x - 20, p.y - 8, STEEL, HORIZONTAL_ALIGNMENT_CENTER, 40, 16)
	c.draw_line(_pt(2300.0 / SPEED_MAX, 126), _pt(2300.0 / SPEED_MAX, 136), WHITE, 3.0, true)
	_line2(c, _pt(f, 100), _pt(f, 132), WHITE, 4.0, 5.0)
	var shown := int(round(disp_speed / 10.0)) * 10 if mock_id == 0 else int(v)
	_txc(c, "m8", 56, str(shown), 140, 106, CREAM, 56)
	_txc(c, "g7", 13, "М/С", 140, 170, STEEL, 16)
	_txc(c, "m7", 13, "%d км/ч" % int(round(v * 3.6)), 140, 226, STEEL, 16)
	if v >= 2290.0:
		c.draw_style_box(_flat(DANGER, 4), Rect2(104, 194, 72, 20)); _txc(c, "g8", 11, "ПРЕДЕЛ", 140, 194, WHITE, 20)

# ---------- 7. прибор положения ----------
func _draw_att(c: Control) -> void:
	var compact := mode == 1
	_plaque(c, Rect2(0, 46, 216, 124) if compact else Rect2(0, 0, 216, 200))
	if not compact:
		_tx(c, "g7", 11, "КУРС К ТРАССЕ", 12, 7, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		for i in 5:
			var a := -60 + 30 * i
			_tx(c, "m7", 11, ("−%d" % -a) if a < 0 else str(a), 108 + a * 1.3 - 10, 22, CREAM if a == 0 else STEEL, HORIZONTAL_ALIGNMENT_CENTER, 20, 13)
		c.draw_line(Vector2(30, 44), Vector2(186, 44), Color(STEEL, 0.6), 1.0)
		for a in range(-60, 61, 10):
			var x := 108.0 + a * 1.3
			if a % 30 == 0: c.draw_line(Vector2(x, 37), Vector2(x, 44), CREAM if a == 0 else STEEL, 2.0)
			else: c.draw_line(Vector2(x, 40), Vector2(x, 44), Color(STEEL, 0.6), 1.0)
		if bool(S.get("dev_ok", false)):
			var hx := 108.0 + clampf(float(S.get("dev", 0.0)), -60.0, 60.0) * 1.3
			var tri := PackedVector2Array([Vector2(hx, 45), Vector2(hx - 5, 53), Vector2(hx + 5, 53)])
			c.draw_colored_polygon(tri, WARN); c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 1.5, true)
			if bool(S.get("fpv", false)):
				var vx := 108.0 + clampf(float(S.get("devv", 0.0)), -60.0, 60.0) * 1.3
				var dm := PackedVector2Array([Vector2(vx, 38), Vector2(vx + 5, 43), Vector2(vx, 48), Vector2(vx - 5, 43)])
				c.draw_colored_polygon(dm, GOOD); c.draw_polyline(PackedVector2Array([dm[0], dm[1], dm[2], dm[3], dm[0]]), INK, 1.5, true)
		var az := float(S.get("az", 0.0))
		var cols := [["ТАНГ", "%+d°" % int(round(float(S.get("pitch", 0.0)))), CREAM], ["КРЕН", "%+d°" % int(round(float(S.get("roll", 0.0)))), CREAM], ["СНОС", "%+d°" % int(round(az)), WARN if absf(az) >= 10.0 else CREAM]]
		for i in 3:
			var x := 12.0 + 64.0 * i
			_tx(c, "g7", 11, cols[i][0], x, 172, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			_tx(c, "m7", 12, String(cols[i][1]).replace("-", "−"), x + _tw("g7", 11, String(cols[i][0])) + 3, 172, cols[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

func _draw_horizon() -> void:                                                # окно горизонта 192×110: координаты окна = координаты виджета − (12, 54)
	var h := horizon; var o := Vector2(12, 54)
	var pitch := float(S.get("pitch", 0.0)); var roll := float(S.get("roll", 0.0))
	var C := Vector2(108, 109) - o
	h.draw_set_transform(C, -deg_to_rad(roll), Vector2.ONE)
	var py := clampf(pitch, -60.0, 60.0) * 2.2
	h.draw_rect(Rect2(-400, -700.0 + py, 800, 700), SKY); h.draw_rect(Rect2(-400, py, 800, 700), EARTH)
	h.draw_line(Vector2(-400, py), Vector2(400, py), WHITE, 2.0)
	for a in range(5, 91, 5):
		for sg in [1, -1]:
			var y := py - float(sg * a) * 2.2
			if absf(y) > 120.0: continue
			var half := 20.0 if a % 10 == 0 else 10.0
			if sg > 0: h.draw_line(Vector2(-half, y), Vector2(half, y), Color(WHITE, 0.9), 1.5)
			else: _dashed(h, PackedVector2Array([Vector2(-half, y), Vector2(half, y)]), Color(WHITE, 0.9), 1.5, 5.0, 3.0, false)
			if a % 10 == 0 and a <= 30:
				_tx(h, "m7", 11, str(a), -half - 24, y - 4 - 3, WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 20, 14)
				_tx(h, "m7", 11, str(a), half + 4, y - 4 - 3, WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	h.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cw := Vector2(96, 55)
	h.draw_arc(cw, 46, deg_to_rad(-150), deg_to_rad(-30), 36, WHITE, 1.5, true)
	for a in [0, 10, 20, 30, 45, 60, -10, -20, -30, -45, -60]:
		var r1 := 54.0 if (a == 0 or absi(a) == 30 or absi(a) == 60) else 51.0
		var ang := deg_to_rad(-90.0 + float(a))
		h.draw_line(cw + Vector2(cos(ang), sin(ang)) * 46.0, cw + Vector2(cos(ang), sin(ang)) * r1, WHITE, 1.5, true)
	var rr := deg_to_rad(roll)
	var rot: Callable = func(p: Vector2) -> Vector2: return cw + (p - Vector2(96, 55)).rotated(rr)
	var drift := float(S.get("az", 0.0)); var s := clampf(drift * 0.8, -10.0, 10.0)
	var ptr := PackedVector2Array([rot.call(Vector2(96, 10)), rot.call(Vector2(91, 18)), rot.call(Vector2(101, 18))])
	h.draw_colored_polygon(ptr, WARN); h.draw_polyline(PackedVector2Array([ptr[0], ptr[1], ptr[2], ptr[0]]), INK, 1.5, true)
	var sl := PackedVector2Array([rot.call(Vector2(90 + s, 21)), rot.call(Vector2(102 + s, 21)), rot.call(Vector2(104 + s, 25)), rot.call(Vector2(88 + s, 25))])
	h.draw_colored_polygon(sl, WHITE); h.draw_polyline(PackedVector2Array([sl[0], sl[1], sl[2], sl[3], sl[0]]), INK, 1.0, true)
	var cmd: Vector3 = S.get("cmd", Vector3.ZERO)
	h.draw_line(Vector2(185, 18), Vector2(185, 92), Color(WHITE, 0.45), 2.0); h.draw_line(Vector2(40, 103), Vector2(152, 103), Color(WHITE, 0.45), 2.0)
	for dp in [Vector2(185, 55.0 - clampf(cmd.x, -1.0, 1.0) * 34.0), Vector2(96.0 + clampf(cmd.z, -1.0, 1.0) * 54.0, 103)]:
		h.draw_circle(dp, 5.5, INK); h.draw_circle(dp, 4.0, CYAN)
	var sym := PackedVector2Array([Vector2(64, 55), Vector2(84, 55), Vector2(84, 62)]); var sym2 := PackedVector2Array([Vector2(128, 55), Vector2(108, 55), Vector2(108, 62)])
	h.draw_polyline(sym, INK, 7.0, true); h.draw_polyline(sym2, INK, 7.0, true); h.draw_polyline(sym, WARN, 3.5, true); h.draw_polyline(sym2, WARN, 3.5, true)
	h.draw_circle(cw, 4.5, INK); h.draw_circle(cw, 3.0, WARN)
	if bool(S.get("fpv", false)):
		var fx := 96.0 + clampf(drift * 2.2, -80.0, 80.0); var fy := 55.0 - clampf(float(S.get("el", 0.0)) * 2.2, -45.0, 45.0)
		for pass_i in 2:
			var col := INK if pass_i == 0 else GOOD; var w := 5.5 if pass_i == 0 else 2.5
			h.draw_arc(Vector2(fx, fy), 5.0, 0, TAU, 20, col, w, true)
			h.draw_line(Vector2(fx - 5, fy), Vector2(fx - 12, fy), col, w, true); h.draw_line(Vector2(fx + 5, fy), Vector2(fx + 12, fy), col, w, true); h.draw_line(Vector2(fx, fy - 5), Vector2(fx, fy - 11), col, w, true)
	h.draw_rect(Rect2(0.5, 0.5, 191, 109), Color(INK, 0.6), false, 1.0)

# ---------- 8. здоровье ----------
func _plan_build() -> void:                                                  # схема «вид сверху» из настоящих мешей корабля: выпуклые оболочки проекции на XZ; контур остаётся контуром нашей модели
	var sh: Node3D = main.ship
	plan_ship_id = sh.get_instance_id(); plan_polys.clear(); plan_hull = PackedVector2Array(); plan_lift.clear()
	var inv := sh.global_transform.affine_inverse()
	var raw := {}
	var lo := Vector2(1e12, 1e12); var hi := Vector2(-1e12, -1e12)
	for ch in sh.get_children():
		if ch is not MeshInstance3D: continue
		var nm: String = ch.name
		if not (nm == "SM_Hull_Body" or nm.begins_with("SM_Wing_") or nm.begins_with("SM_Engine_")): continue
		var mi := ch as MeshInstance3D
		if mi.mesh == null: continue
		var tr: Transform3D = inv * mi.global_transform
		var pts := PackedVector2Array()
		for k in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(k); var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var stp := maxi(1, vs.size() / 1500)
			for vi in range(0, vs.size(), stp):
				var w := tr * vs[vi]; pts.append(Vector2(w.x, w.z))
		if pts.size() < 3: continue
		var hl := Geometry2D.convex_hull(pts)
		if hl.size() > 1 and hl[0] == hl[hl.size() - 1]: hl.remove_at(hl.size() - 1)
		raw[nm] = hl
		for q in hl: lo = lo.min(q); hi = hi.max(q)
	var sz := hi - lo
	if sz.x <= 0.0 or sz.y <= 0.0: return
	var area := Rect2(55, 78, 170, 172)                                      # поле схемы внутри плашки (вокруг место под дуги ударов)
	var k2 := minf(area.size.x / sz.x, area.size.y / sz.y)
	var off := area.position + (area.size - sz * k2) * 0.5
	for nm in raw:
		var out := PackedVector2Array()
		for q in raw[nm]: out.append(off + (q - lo) * k2)
		if nm == "SM_Hull_Body": plan_hull = out
		else: plan_polys[nm] = out
	plan_box = Rect2(off, sz * k2)
	var wl := Rect2(); var wr := Rect2(); var hl_ := false; var hr_ := false
	for nm in plan_polys:
		if not String(nm).begins_with("SM_Wing_"): continue
		var pts2: PackedVector2Array = plan_polys[nm]
		var rc := Rect2(pts2[0], Vector2.ZERO)
		for q in pts2: rc = rc.expand(q)
		if rc.get_center().x < plan_box.get_center().x: wl = rc if not hl_ else wl.merge(rc); hl_ = true
		else: wr = rc if not hr_ else wr.merge(rc); hr_ = true
	plan_wing_l = Vector2(wl.position.x if hl_ else plan_box.position.x, wl.get_center().y if hl_ else plan_box.get_center().y)
	plan_wing_r = Vector2(wr.end.x if hr_ else plan_box.end.x, wr.get_center().y if hr_ else plan_box.get_center().y)
	for nm in plan_polys:
		if String(nm).begins_with("SM_Engine_") and main.engines.has(nm) and String(main.engines[nm]["kind"]) == "lift":
			var cen := Vector2.ZERO
			for q in (plan_polys[nm] as PackedVector2Array): cen += q
			plan_lift[nm] = cen / float((plan_polys[nm] as PackedVector2Array).size())

func _alive(nm: String) -> bool:
	if mock_id > 0 and (S.get("lost", []) as Array).has(nm): return false
	return main.parts.has(nm)

func _cross(c: Control, poly: PackedVector2Array) -> void:
	var rc := Rect2(poly[0], Vector2.ZERO)
	for q in poly: rc = rc.expand(q)
	rc = rc.grow(-minf(rc.size.x, rc.size.y) * 0.2)
	for pass_i in 2:
		var col := INK if pass_i == 0 else DANGER; var w := 5.0 if pass_i == 0 else 2.5
		c.draw_line(rc.position, rc.end, col, w, true); c.draw_line(Vector2(rc.end.x, rc.position.y), Vector2(rc.position.x, rc.end.y), col, w, true)

func _draw_arcs(c: Control, at: Vector2, center_deg: float, col: Color, n: int) -> void:
	for k in n:
		var r := 8.0 + 7.0 * k; var a0 := deg_to_rad(center_deg - 40.0); var a1 := deg_to_rad(center_deg + 40.0)
		c.draw_arc(at, r, a0, a1, 14, INK, 6.5, true)
		c.draw_arc(at, r, a0, a1, 14, col, 3.5, true)

func _draw_hp(c: Control) -> void:
	if plan_ship_id != main.ship.get_instance_id(): _plan_build()
	var hp := float(S.get("hp", 1.0))
	_plaque(c, Rect2(0, 0, 280, 280))
	var hc := GOOD if hp > 0.66 else (WARN if hp > 0.33 else DANGER)
	_tx(c, "g7", 11, "ЗДОРОВЬЕ", 12, 12, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	_txr(c, "m8", 20, "%d%%" % int(round(hp * 100.0)), 268, 6, hc, 24)
	c.draw_style_box(_flat(Color(STEEL, 0.2), 3), Rect2(12, 34, 256, 6)); c.draw_style_box(_flat(hc, 3), Rect2(12, 34, maxf(6.0, 256.0 * hp), 6))
	for x in [96.5, 181.5]: c.draw_line(Vector2(x, 33), Vector2(x, 41), INK, 2.0)
	for gy in range(64, 257, 16): c.draw_line(Vector2(8, gy), Vector2(272, gy), Color(STEEL, 0.08), 1.0)
	for gx in range(28, 253, 16): c.draw_line(Vector2(gx, 52), Vector2(gx, 272), Color(STEEL, 0.08), 1.0)
	var zn := String(S.get("zone", "")); var zon := bool(S.get("zon", false)) or (mock_id > 0 and zn != "")
	var tti := float(S.get("ztti", 99.0)); var zc := _zone_col(tti)
	var top_hit := zon and zn == "top"; var belly := zon and zn == "belly"
	if plan_hull.size() > 2:
		c.draw_colored_polygon(plan_hull, Color(zc, 0.5) if top_hit else Color(CYAN, 0.08))
		var pl := plan_hull.duplicate(); pl.append(pl[0]); c.draw_polyline(pl, zc if top_hit else CYAN, 3.5 if top_hit else 2.0, true)
	for nm in plan_polys:
		var poly: PackedVector2Array = plan_polys[nm]
		if poly.size() < 3: continue
		var ok := _alive(nm); var eng := String(nm).begins_with("SM_Engine_")
		if ok:
			var fillc := Color(GOOD, 0.9) if eng else Color(GOOD, 0.3)
			if belly and plan_lift.has(nm): fillc = Color(zc, 0.95)
			c.draw_colored_polygon(poly, fillc)
			var pl2 := poly.duplicate(); pl2.append(pl2[0]); c.draw_polyline(pl2, INK if eng else GOOD, 1.5 if eng else 2.0, true)
		else:
			_dashed(c, poly, DANGER, 2.0, 4.0, 3.0); _cross(c, poly)
	if belly:
		for nm in plan_lift: if _alive(nm): c.draw_arc(plan_lift[nm], 9.0, 0, TAU, 20, zc, 2.0, true)
	if zon and plan_hull.size() > 2:
		var n := 1 if tti > 2.0 else (2 if tti > 1.2 else 3)
		var mid := plan_box.get_center()
		match zn:
			"nose": _draw_arcs(c, Vector2(mid.x, plan_box.position.y - 2.0), -90.0, zc, n)
			"rear": _draw_arcs(c, Vector2(mid.x, plan_box.end.y + 2.0), 90.0, zc, n)
			"wing_l": _draw_arcs(c, plan_wing_l + Vector2(-2, 0), 180.0, zc, n)
			"wing_r": _draw_arcs(c, plan_wing_r + Vector2(2, 0), 0.0, zc, n)
	var vl: Vector3 = main.ship.global_transform.basis.orthonormalized().inverse() * main.ship.linear_velocity       # вектор скорости в плоскости корабля
	var hv := Vector2(vl.x, vl.z); var hs := hv.length()
	if mock_id == 0 and hs > 15.0 and plan_hull.size() > 2:
		var ctr := plan_box.get_center(); var tip := ctr + hv / hs * clampf(hs / 900.0, 0.08, 1.0) * 46.0
		c.draw_line(ctr, tip, INK, 5.0, true); c.draw_line(ctr, tip, WHITE, 2.5, true)
		var dir := (tip - ctr).normalized(); var sd := Vector2(-dir.y, dir.x)
		c.draw_colored_polygon(PackedVector2Array([tip + dir * 5.0, tip - dir * 7.0 + sd * 5.0, tip - dir * 7.0 - sd * 5.0]), WHITE)
	c.draw_circle(plan_box.get_center(), 3.0, Color(WHITE, 0.9))

func _draw_chip(c: Control) -> void:
	var zn := String(S.get("zone", ""))
	if zn == "": return
	var zc := _zone_col(float(S.get("ztti", 99.0)))
	_alarm_box(c, Rect2(0, 0, 280, 32), zc)
	var tri := PackedVector2Array([Vector2(26, 8), Vector2(34, 22), Vector2(18, 22)])
	c.draw_colored_polygon(tri, zc); c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 1.5, true)
	c.draw_line(Vector2(26, 13), Vector2(26, 17), WHITE, 2.0, true)
	_tx(c, "g8", 14, "УДАР: " + String(ZONE_NAMES.get(zn, zn)), 44, 0, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	_txr(c, "m8", 15, _fmt_t(float(S.get("ztti", 0.0))), 266, 0, zc, 32)

# ---------- 9. карта ----------
func _map_build() -> void:                                                   # трасса от старта до финиша, вписанная в (24…256, 22…262)
	var m = main
	map_cache["id"] = m.trk_pts.size(); var pts := PackedVector2Array(); var ss := PackedFloat32Array()
	var rl: float = float(m.race_len)
	var step := 3
	for i in range(0, m.trk_pts.size(), step):
		if float(m.trk_s[i]) > rl: break
		pts.append(m.trk_pts[i]); ss.append(m.trk_s[i])
	var fin: Vector2 = m._track_at(minf(rl, float(m.trk_len) - 1.0))[0]
	pts.append(fin); ss.append(rl)
	var lo := Vector2(1e12, 1e12); var hi := Vector2(-1e12, -1e12)
	for q in pts: lo = lo.min(q); hi = hi.max(q)
	var sz := hi - lo; var area := Rect2(24, 40, 232, 222)
	var k := minf(area.size.x / maxf(sz.x, 1.0), area.size.y / maxf(sz.y, 1.0))
	map_cache["lo"] = lo; map_cache["k"] = k; map_cache["off"] = area.position + (area.size - sz * k) * 0.5
	var out := PackedVector2Array()
	for q in pts: out.append(_mp(q))
	map_cache["pts"] = out; map_cache["s"] = ss
	var cuts := []
	for br in m.branches:
		var bp: PackedVector2Array = br["pts"]; var o2 := PackedVector2Array()
		for i in range(0, bp.size(), 2): o2.append(_mp(bp[i]))
		o2.append(_mp(bp[bp.size() - 1])); cuts.append(o2)
	map_cache["cuts"] = cuts

func _mp(q: Vector2) -> Vector2: return (map_cache["off"] as Vector2) + (q - (map_cache["lo"] as Vector2)) * float(map_cache["k"])

func _draw_map(c: Control) -> void:
	if int(map_cache["id"]) != main.trk_pts.size() or (map_cache["pts"] as PackedVector2Array).size() < 2: _map_build()
	var pts: PackedVector2Array = map_cache["pts"]
	if pts.size() < 2: return
	_plaque(c, Rect2(0, 0, 280, 280))
	_tx(c, "g7", 11, "ТРАССА", 12, 12, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	_tx(c, "m7", 13, "%d%%" % int(round(float(S.get("prog", 0.0)) * 100.0)), 12, 28, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var ss: PackedFloat32Array = map_cache["s"]; var pp := float(main.p_prog)
	var ix := 0
	while ix < ss.size() - 1 and ss[ix] < pp: ix += 1
	var me := _mp(Vector2(main.ship.global_position.x, main.ship.global_position.z))
	if mock_id > 0: me = pts[mini(int(float(pts.size() - 1) * float(S.get("prog", 0.0))), pts.size() - 1)]
	c.draw_polyline(pts, Color(INK, 0.6), 6.0, true)
	var done := pts.slice(0, ix + 1)
	if ix > 0: done.append(me)
	if done.size() > 1: c.draw_polyline(done, Color(STEEL, 0.55), 3.0, true)
	var rest := PackedVector2Array([me]); rest.append_array(pts.slice(ix))
	if rest.size() > 1: c.draw_polyline(rest, CREAM, 3.0, true)
	for cp in map_cache["cuts"]: _dashed(c, cp as PackedVector2Array, ORANGE, 3.0, 5.0, 3.0, false)
	for bt in main.bots:
		var bp := _mp(Vector2((bt["rb"] as RigidBody3D).global_position.x, (bt["rb"] as RigidBody3D).global_position.z))
		c.draw_circle(bp, 5.0, INK); c.draw_circle(bp, 3.5, STEEL)
	var st := pts[0]; _line2(c, st + Vector2(-7, 0), st + Vector2(7, 0), WHITE, 3.0)
	_tx(c, "g7", 11, "СТАРТ", st.x + 12, st.y - 6, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var fin := pts[pts.size() - 1]
	c.draw_circle(fin, 8.5, WHITE); c.draw_circle(fin, 6.5, DANGER)
	c.draw_rect(Rect2(fin.x - 2.5, fin.y - 2.5, 2.5, 2.5), WHITE); c.draw_rect(Rect2(fin.x, fin.y, 2.5, 2.5), WHITE)
	_tx(c, "g7", 11, "ФИНИШ", fin.x + 12, fin.y - 6, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var fwd: Vector3 = -main.ship.global_transform.basis.z
	var u := Vector2(fwd.x, fwd.z).normalized() if mock_id == 0 else (pts[mini(ix + 1, pts.size() - 1)] - pts[ix]).normalized()
	var sd := Vector2(-u.y, u.x)
	c.draw_circle(me, 12.0, Color(ORANGE, 0.22))
	var tri := PackedVector2Array([me + u * 9.0, me - u * 6.0 + sd * 6.0, me - u * 6.0 - sd * 6.0])
	c.draw_colored_polygon(tri, ORANGE); c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 2.0, true)

# ---------- 10. тревога потолка и сообщения ----------
func _draw_alarm(c: Control) -> void:
	var alt := float(S.get("alt", 0.0))
	if alt <= CEIL_Y: return
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0)
	_alarm_box(c, Rect2(0, 0, 480, 72), Color(DANGER, pulse))
	var tri := PackedVector2Array([Vector2(34, 22), Vector2(46, 44), Vector2(22, 44)])
	c.draw_colored_polygon(tri, DANGER); c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 1.5, true)
	c.draw_line(Vector2(34, 29), Vector2(34, 36), WHITE, 3.0, true); c.draw_line(Vector2(34, 40), Vector2(34, 40.5), WHITE, 3.0, true)
	_tx(c, "g8", 20, "ВЕРНИТЕСЬ В КАНЬОН", 68, 12, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	_tx(c, "g4", 13, "выше потолка 5350 м · иначе дисквалификация", 68, 38, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	_txr(c, "dela", 44, str(int(ceil(float(S.get("out_left", 8.0))))), 460, 12, DANGER, 48)

func _msg_info() -> Array:                                                   # [текст, цвет, стабилизация выкл]
	var stab_off: bool = ui.state == "hud" and not main.assist and int(main.cfg["level"]) < 4 and not main.in_cutscene()
	if stab_off: return ["СТАБИЛИЗАЦИЯ ВЫКЛ", DANGER, true]
	if float(main.msg_t) > 0.0 and String(main.msg_txt) != "": return [String(main.msg_txt), WARN if "Лимит" in String(main.msg_txt) else STEEL, false]
	return ["", STEEL, false]

func _draw_msg(c: Control) -> void:                                          # сообщение внизу: стабилизация выкл (пока выключена) и короткие сообщения (2,5 с)
	var mi := _msg_info(); var txt: String = mi[0]; var col: Color = mi[1]; var stab_off: bool = mi[2]
	if txt == "": return
	var w := _tw("g8", 16, txt) + 32.0 + (52.0 if stab_off else 0.0); var x0 := (640.0 - w) * 0.5
	_alarm_box(c, Rect2(x0, 0, w, 40), col)
	_tx(c, "g8", 16, txt, x0 + 16, 0, col if stab_off else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	if stab_off:
		var kx := x0 + 16 + _tw("g8", 16, txt) + 12
		for k in ["A", "T"]:
			c.draw_circle(Vector2(kx + 9, 20), 10, Color(STEEL, 0.9)); _txc(c, "g8", 12, k, kx + 9, 12, INK, 16); kx += 24.0

# ---------- 11. подписи над соперниками ----------
func _draw_marks(c: Control) -> void:
	markers.clear()
	if mock_id > 0 or main.cam == null: return
	var cam: Camera3D = main.cam
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var sc := Vector2(vs.x / maxf(1.0, float(get_viewport().size.x)), vs.y / maxf(1.0, float(get_viewport().size.y)))
	var me: Vector3 = main.ship.global_position
	var rows := []
	for i in main.bots.size():
		var b: Dictionary = main.bots[i]
		var rb := b["rb"] as RigidBody3D
		var pw := rb.global_position
		var p := pw + Vector3(0, 28, 0)
		if cam.is_position_behind(p): continue
		var d := me.distance_to(p)
		if d > MARKER_MAX_DIST: continue
		if d > MARKER_LOS_MIN and not _los(i, cam.global_position, p): continue
		var sp := cam.unproject_position(p) * sc
		if sp.x < 0.0 or sp.y < 0.0 or sp.x > vs.x or sp.y > vs.y: continue
		rows.append({"i": i, "name": String(b["name"]), "d": d, "sp": sp, "a": clampf((MARKER_MAX_DIST - d) / (MARKER_MAX_DIST * 0.25), 0.0, 1.0), "ahead": float(b["prog"]) > float(main.p_prog), "gap": absf(float(b["prog"]) - float(main.p_prog))})
	rows.sort_custom(func(x, y): return float(x["d"]) < float(y["d"]))
	for k in mini(rows.size(), MARKER_MAX_N):
		var r: Dictionary = rows[k]
		var nm := _riv_name(String(r["name"]), "g7", 13, 170.0)
		var dt := _fmt_d(float(r["d"]))
		var w := 7.0 + 6.0 + _tw("g7", 13, nm) + 6.0 + _tw("m7", 12, dt) + 8.0 + 1.0
		var ahead: bool = bool(r["ahead"]); var pc := ORANGE if ahead else CYAN
		var near_behind: bool = (not ahead) and float(r["gap"]) / maxf(main.ship.linear_velocity.length(), 300.0) < 1.0
		var sp: Vector2 = r["sp"]; var top := sp.y - 12.0 - 22.0
		if top < 132.0: top = sp.y + 36.0                                    # слишком высоко: переворот под корабль
		var rc := Rect2(sp.x - w * 0.5, top, w, 22)
		var a := float(r["a"])
		var sb := _flat(Color(INK, 0.55 * a), 4)
		if near_behind: sb.border_color = Color(CYAN, a); sb.set_border_width_all(2)
		c.draw_style_box(sb, rc)
		c.draw_circle(rc.position + Vector2(10.5, 11), 3.5, Color(pc, a))
		_tx(c, "g7", 13, nm, rc.position.x + 20, rc.position.y, Color(CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		_tx(c, "m7", 12, dt, rc.position.x + 20 + _tw("g7", 13, nm) + 6, rc.position.y, Color(STEEL, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	if float(main.start_t) > 0.0: return                                     # на старте все рядом: индикаторы у края не нужны
	var edge := []                                                           # соперник ближе 1 км вне кадра: чип у края со стрелкой (3 ближайших)
	for i in main.bots.size():
		var b2: Dictionary = main.bots[i]; var p2 := (b2["rb"] as RigidBody3D).global_position + Vector3(0, 28, 0)
		var d2 := me.distance_to(p2)
		if d2 > 1000.0 or bool(b2["fin"]): continue
		var behind := cam.is_position_behind(p2); var sp2 := cam.unproject_position(p2) * sc
		if not behind and sp2.x >= 0.0 and sp2.y >= 0.0 and sp2.x <= vs.x and sp2.y <= vs.y: continue
		edge.append({"name": String(b2["name"]), "d": d2, "loc": cam.to_local(p2)})
	edge.sort_custom(func(x, y): return float(x["d"]) < float(y["d"]))
	for k in mini(edge.size(), 3):
		var e: Dictionary = edge[k]; var loc: Vector3 = e["loc"]
		var dir2 := Vector2(loc.x, -loc.y)
		dir2 = dir2.normalized() if dir2.length() > 0.01 else Vector2(1, 0)
		if absf(dir2.x) < 0.25: dir2.x = 1.0 if dir2.x >= 0.0 else -1.0
		var left := dir2.x < 0.0
		var nm2 := _riv_name(String(e["name"]), "g7", 13, 120.0); var dt2 := _fmt_d(float(e["d"]))
		var w2 := _tw("g7", 13, nm2) + 6.0 + _tw("m7", 12, dt2) + 12.0 + 16.0
		var ep := Vector2(180.0 if left else 1290.0, clampf(vs.y * 0.5 + dir2.y * vs.y * 0.5 + float(k) * 26.0, 220.0, 640.0))
		var rc2 := Rect2(ep.x - (0.0 if left else w2), ep.y - 11, w2, 22)
		c.draw_style_box(_flat(Color(INK, 0.55), 4), rc2)
		_tx(c, "g7", 13, nm2, rc2.position.x + (20.0 if left else 6.0), rc2.position.y, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		_tx(c, "m7", 12, dt2, rc2.position.x + (20.0 if left else 6.0) + _tw("g7", 13, nm2) + 6.0, rc2.position.y, STEEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		var tx := rc2.position.x + (4.0 if left else w2 - 14.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(tx + 10, rc2.position.y + 4), Vector2(tx + 10, rc2.position.y + 18), Vector2(tx, rc2.position.y + 11)]) if left else PackedVector2Array([Vector2(tx, rc2.position.y + 4), Vector2(tx, rc2.position.y + 18), Vector2(tx + 10, rc2.position.y + 11)]), CYAN)

func _los(i: int, from: Vector3, to: Vector3) -> bool:                       # луч камера → бот не должен уходить под рельеф; кеш 0,15 с
	var now := Time.get_ticks_msec() / 1000.0
	var cch = marker_los.get(i)
	if cch != null and now - float(cch[0]) < 0.15: return bool(cch[1])
	var vis := true
	var n := clampi(int(from.distance_to(to) / 500.0), 4, 80)
	for k in range(1, n):
		var q := from.lerp(to, float(k) / float(n))
		if main.height(q.x, q.z) > q.y - 4.0: vis = false; break
	marker_los[i] = [now, vis]
	return vis
