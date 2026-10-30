extends Node3D
# Тестовый полёт «Третьего шанса»: модель, схема управления (клавиатура + геймпад, 2 схемы), отлёт деталей, чекпоинты.
# Ось корабля в Godot: нос = -Z, верх = +Y, правый борт = +X.
# Моторы: взлётные (днище) держат высоту над уровнем моря и тянут вдоль «верха» корабля; тяговые (корма) тянут вперёд, без тормоза;
# маневровые (концы крыльев, 4 шт.) дают вектор тяги, который задаёт пилот. Атмосферы нет: инерция почти не гасится.

const DETACH_PREFIX := ["SM_Engine_", "SM_Wing_", "SM_Spotlight_", "SM_Glass_", "SM_Hatch_", "SM_Foot_"]
const CAM_MODES := ["chase", "far", "side", "free", "right", "cockpit"]
const CAM_NAMES := ["Сзади", "Далеко сзади", "Сбоку слева", "Облёт корабля", "Сбоку справа", "От первого лица"]
const MASS := 40000.0
# Корабли-участники из книг (порядок от сильнейшего бота к слабейшему): Космоолухи-4 «Космотехнолухи», Космоолухи-9 «Киберканикулы»
const BOT_NAMES := ["Галлюцинация", "Долгоносик", "Звездолов", "Маленькое Стремительное Копье", "Аргамак", "Семикрылый", "Золотая рыбка", "Ломовой Пегас", "Каракатица", "Любовница шторма", "Бешеный Самовар"]
const G := 9.8
const SHIP_NAMES := ["Третий шанс", "Фрея", "Долгоносик", "Аргамак"]
const FREYA_VARIANT := {"cabins": -3}
const SHIP_SCALE := [1.0, 0.8, 1.0, 1.0]
const SHIP_VARIANTS := {1: FREYA_VARIANT, 2: {"nose": [-22.0, 1.55], "nose_engine": true}, 3: {"nose": [-22.0, 0.88], "cabins": 1}}   # корпуса «Долгоносика» и «Аргамака» те же, что у ботов под этими именами
const SHIP_LIVERY := {2: 1, 3: 4}                      # номер бота, чья ливрея у этого корабля
const NOSE_ENG := "SM_Engine_Shunt_Nose"
const NOSE_BRAKE := 0.5                                 # торможение носовым маневровым: доля от максимального ускорения тяговых
const SHIP_SLOGANS := ["Стартует последним, а ставят на него первым", "Мы же Команда, верно?! — КОМАНДА!", "Молодая щучка среди карасей", "Транспортник с лицензией на лазерные пушки"]
const SHIP_DESC := ["Транспортник Стрелка, фаворит списка. Козыря избили накануне гонки, за штурвалом Тед «Гризли».", "Пятьдесят метров металлолома, доставшиеся Натану от деда: подёргивается и вздыхает, как старая ломовая лошадь, зато движок отлажен идеально.", "Переоборудованный транспортник Тощего Грэга: узкий обтекаемый корпус с «зубами»-выступами и отличные движки. Носовой маневровый на кронштейне направлен вперёд и тормозит корабль на форсаже.", "Грузовой транспортник капитана Юрия Гибульского с лицензией на лазерные пушки. Экипаж из пяти человек; корпус шире и тяжелее, чем у соперников, и отбиваться корабль не умеет."]
var ship_id := 0
var ship_sc := 1.0
var hull_pos0 := Vector3.ZERO                       # положение корпуса в исходных (не масштабированных) координатах модели
const GRID_ROWS := 2          # рядов по высоте (в книге шесть при ~60 кораблях; у нас кораблей мало, поэтому два)
const GRID_DX := 300.0         # шаг между кораблями в ряду, м (центр каньона x = 0)
const GRID_DY := 120.0         # шаг между рядами по высоте, м
var player_start := Vector3(0.0, 1700.0, 0.0)
func _grid_pos(slot: Vector2i, cols: int) -> Vector3: return Vector3((float(slot.x) - float(cols - 1) * 0.5) * GRID_DX, START_ALT + GRID_DY * float(slot.y), 0.0)
const START_ALT := 1700.0     # старт над вторым ярусом (полка на ~1100 м), а не в русле
const PLATEAU_Y := 5500.0
const RING_GAP := 1500.0
const MAX_SPEED := 2300.0   # м/с (~8300 км/ч), потолок задаётся и в project.godot (Jolt)
const TILE := 1000.0
const GCELL := 500.0
const INFL := 7500.0        # дальше этого от трассы только плато
const WIDTH_SCALE := 3.5    # ширина каньона (1.0 = базовая)
const LOD0_R := 3500.0
const LOD1_R := 14000.0
const LOD2_FAR := 15000.0         # радиус грубых плиток вокруг дальних точек пути (7, 12 и 20 с полёта): видно трассу далеко вперёд
const AHEAD_T := [1.0, 2.0, 3.5, 7.0, 12.0, 20.0]
const LOD2_R := 24000.0          # очень грубый уровень (шаг 250 м, без коллизии) — далёкий горизонт
const LOD0_AHEAD := 2200.0       # радиус подробных плиток вокруг упреждающих точек впереди по трассе

var ship: RigidBody3D
var parts := {}
var shapes := {}
var cam: Camera3D
var cam_mode := 0
var hull_mats: Array = []                   # материалы обшивки игрока: сюда пишутся вмятины от ударов
var dents: Array = []                       # Vector4: центр (в координатах обшивки) и радиус
var p_back := 0.0                           # статистика заезда для достижений: путь назад, макс. высота и скорость, путь с креном > 60°, детали на старте, «взорвать всё», вид из кабины весь заезд
var p_max_y := 0.0
var p_max_v := 0.0
var p_bank_dist := 0.0
var p_parts0 := -1
var p_boom := false
var p_cam_ck := true
var p_prev_prog := 0.0
var race_dist := 0.0
var ship_sfx: ShipSfx
var start_frozen := false                   # корабль заморожен до старта гонки
var look_in := Vector2.ZERO                 # правый стик геймпада: осмотр из кабины (в этом виде стик не управляет маневровыми)
var look_cur := Vector2.ZERO                # текущий поворот головы: x — влево/вправо, y — вверх/вниз (рад)
const LOOK_YAW := 1.5
const LOOK_PITCH := 0.6
var gravity_on := true
var assist := true
var scheme := 0              # 0 = один джойстик маневровых + гироскоп, 1 = два джойстика (левое/правое крыло), физика без гироскопа
var hud: Label
var ui: CanvasLayer
var music: Node
const INTRO_T := 27.465            # момент старта кораблей в треке Retribution (вступление: 0–21 с катсцена, 21–27.465 с отсчёт)
const INTRO_CUT := 21.0
const INTRO_SKIP_LEFT := 3.0       # пропуск катсцены перематывает на момент, когда в обратном отсчёте горит «3» (за 3 с до старта)
var intro_on := false
var world_env: Environment
const FOG_BASE := 0.00003
var intro_skipped := false
var intro_seen := false
func skip_intro() -> void:                                                  # пропуск катсцены: музыка перематывается на момент, когда в отсчёте «3»
	intro_skipped = true
	music.seek_intro(INTRO_T - INTRO_SKIP_LEFT); cam_snap = true; intro_picks = []
	if Input.is_action_just_pressed("assist"): assist = not assist         # A на геймпаде — и пропуск, и стабилизация: нажатие не должно выключать стабилизацию
	if world_env != null: world_env.fog_density = FOG_BASE
var cam_snap := false
func in_cutscene() -> bool: return intro_on and start_t > INTRO_T - INTRO_CUT
func intro_t() -> float: return INTRO_T - start_t if in_cutscene() else 99.0
func music_ok() -> bool: return not (evo_mode or test_mode or shot_mode or soak or not (ui_shot == "" or ui_shot == "intro"))
func begin_intro() -> void:
	if music == null or not music_ok(): start_t = 4.0; return
	assist = true; start_t = INTRO_T; intro_on = true; cam_snap = true; music.play_intro(); intro_skipped = false; intro_seen = false
var shot_k := 0
var ui_shot := ""
var tour_bot := 1
var tour_ready := false
var tour_targets: Array = []
var tour_i := -1
var tour_phase := ""
var tour_pf0 := 0
var tour_cap := false
var tour_c := 0
var fixed_cam := Transform3D.IDENTITY
var help: Label
var impact_cd := 0.0
var prev_speed := 0.0
var last_contact_f := -999
var shake_imp := 0.0
var prev_v_c := Vector3.ZERO
var prev_vel := Vector3.ZERO                # скорость прошлого кадра: по её изменению определяется, с какой стороны был удар
var acc_s := 0.0                                                            # сглаженное ускорение корабля, м/с²: тряска камеры включается только выше порога
const SHAKE_ACC0 := 500.0                                                   # начало тряски (~51 g) у «Фреи»
const SHAKE_ACC1 := 1300.0                                                  # полная тряска (~133 g)
const SHAKE_SHIP_K := [2.0, 1.0, 2.0, 1.5]                                            # множитель порога по кораблям: у «Третьего шанса» вдвое выше (тяжелее, плавнее), «Фрея» трясётся как есть
const SHAKE_HEALTH_MIN := 0.4                                               # порог у полностью разбитого корабля = 40% от исправного
var health_w0 := 0.0                                                        # суммарный вес деталей целого корабля

func part_weight(nm: String) -> float: return 2.0 if (nm.begins_with("SM_Engine_") or nm.begins_with("SM_Wing_")) else 1.0

func ship_health() -> float:                                                # здоровье 0..1: доля уцелевших деталей (двигатели и крылья весят вдвое)
	if health_w0 <= 0.0: return 1.0
	var w := 0.0
	for n in parts: w += part_weight(String(n))
	return clampf(w / health_w0, 0.0, 1.0)
var det_done := false
var cps: Array[MeshInstance3D] = []
var next_cp := 0
var race_t := 0.0
var racing := false
var interior_vis := true
var shot_mode := false
var soak := false                                                          # автотест: игрок повторяет полёт бота, графика настоящая
var soak_bot := 0
var soak_max := 900.0
var soak_t0 := 0
var soak_fr := 0
var soak_worst := 0.0
var soak_sw := 0.0
var soak_slow := 0
var soak_hitch := 0
var soak_sec := 0
var soak_shot_n := 0
var soak_fps_min := 999.0
var test_mode := false
var frame := 0
var free_yaw := 0.0
var mat_glass: ShaderMaterial
var debris: Array[RigidBody3D] = []
var hull_shader: Shader
var hull_bite_shader: Shader
var flame_shader: Shader
var glow_shader: Shader
var core_shader: Shader
var blade_shader: Shader                                                    # свет внутри мотора на стенках лопастей (оверлей поверх корпуса мотора)
var engines := {}            # имя -> {kind, mi, flame, fmat, pos, mats}
var kind_total := {"main": 0, "lift": 0, "shunt": 0, "nose": 0}
var hold_alt := START_ALT
var kb_thr := 0.0
var thr := 0.0
var lift_ratio := 0.0
var lift_in := 0.0
var lift_hold := 0.0
var kb_t := {}               # орган -> время удержания кнопки, с
var tune = preload("res://tune.gd").new()
var tech_open := false
var tech_shot_n := 0
func P(k: String) -> float: return tune.v[k]
# --- лог полёта: flight_log.csv рядом с проектом (перезаписывается при каждом запуске), 20 Гц; F5 / кнопка B = пометка «здесь что-то не так» ---
var log_f: FileAccess
var log_n := 0
var log_ev := ""
var log_t := 0.0
var dbg := {}
func _log_open() -> void:
	log_f = FileAccess.open(ProjectSettings.globalize_path("res://flight_log.csv"), FileAccess.WRITE)
	if log_f == null: return
	log_f.store_line("# tuning " + JSON.stringify(tune.v) + " scheme=" + str(scheme) + " gravity=" + str(gravity_on))
	log_f.store_line("t,x,y,z,vx,vy,vz,speed,cos_tilt,bank_deg,pitch_deg,slip_deg,thr_cmd,thr,lift_in,lift_hold_s,li,t_lift_g,tmax_g,tmax_limit,boost_g,boost_cap_g,dump_g,inv,hold_alt,clear_ahead,gy_x,gy_y,gy_z,tr_x,tr_z,boost_in,lift_rem,main_rem,shunt_rem,parts,event")
# снос: угол между направлением носа и скоростью в горизонтали (+ = нос правее движения); от него зависит, куда толкают взлётные при крене
func _slip() -> float:
	var f := -ship.global_transform.basis.z
	var v := ship.linear_velocity
	if Vector2(v.x, v.z).length() < 30.0: return 0.0
	var a := Vector2(f.x, f.z).angle_to(Vector2(v.x, v.z))
	return -rad_to_deg(a)
func _log_event(t: String) -> void:
	log_ev += (";" if log_ev != "" else "") + t
func _log_row(ctrl: Dictionary) -> void:
	if log_f == null: return
	var bs := ship.global_transform.basis
	var p := ship.global_position; var v := ship.linear_velocity
	var clr := p.y - height(p.x, p.z)
	for tt in [0.5, 1.0, 2.0, 3.0]: clr = minf(clr, p.y + v.y * tt - height(p.x + v.x * tt, p.z + v.z * tt))
	var gyv: Vector3 = ctrl["gyro"]; var trv: Vector3 = ctrl["tr"]
	var bank := rad_to_deg(asin(clampf(bs.x.y, -1.0, 1.0)))
	var pitch := rad_to_deg(asin(clampf(-bs.z.y, -1.0, 1.0)))
	var mg := MASS * G
	var row := [snappedf(log_t, 0.01), int(p.x), int(p.y), int(p.z), int(v.x), int(v.y), int(v.z), int(v.length()), snappedf(bs.y.y, 0.001), snappedf(bank, 0.1), snappedf(pitch, 0.1), snappedf(_slip(), 0.1),
		snappedf(float(ctrl["thr"]), 0.001), snappedf(thr, 0.001), snappedf(float(ctrl["lift"]), 0.01), snappedf(lift_hold, 0.01), snappedf(float(dbg.get("li", 0.0)), 0.001),
		snappedf(float(dbg.get("t_lift", 0.0)) / mg, 0.01), snappedf(float(dbg.get("tmax", 0.0)) / mg, 0.01), dbg.get("limit", ""), snappedf(float(dbg.get("want", 0.0)) / mg, 0.01), snappedf(float(dbg.get("cap", 0.0)) / mg, 0.01),
		snappedf(float(dbg.get("dump", 0.0)) / mg, 0.01), int(dbg.get("inv", 0)), int(hold_alt), int(clr), snappedf(gyv.x, 0.01), snappedf(gyv.y, 0.01), snappedf(gyv.z, 0.01), snappedf(trv.x, 0.01), snappedf(trv.z, 0.01),
		snappedf(float(ctrl["boost"]), 0.01), snappedf(_remaining("lift"), 0.01), snappedf(_remaining("main"), 0.01), snappedf(_remaining("shunt"), 0.01), parts.size(), log_ev]
	log_f.store_line(",".join(PackedStringArray(row.map(func(x): return str(x)))))
	log_ev = ""
	log_n += 1
	if log_n % 40 == 0: log_f.flush()
const CFG_PATH := "user://controls.cfg"
# Переназначаемые клавиши клавиатуры: [id, название, клавиша по умолчанию]
const KEYBIND := [
	["thr", "Газ (тяговые)", KEY_W], ["lift_up", "Взлётные: форсаж", KEY_SPACE], ["lift_down", "Взлётные: замедление", KEY_CTRL],
	["pitch_up", "Нос вверх", KEY_UP], ["pitch_down", "Нос вниз", KEY_DOWN], ["yaw_left", "Рыскание влево", KEY_LEFT], ["yaw_right", "Рыскание вправо", KEY_RIGHT],
	["roll_left", "Крен влево", KEY_Q], ["roll_right", "Крен вправо", KEY_E],
	["sh_fwd", "Маневровые: вперёд", KEY_I], ["sh_back", "Маневровые: назад", KEY_K], ["sh_left", "Маневровые: влево", KEY_J], ["sh_right", "Маневровые: вправо", KEY_L],
	["boost", "Усиление маневровых", KEY_SHIFT],
	["look_left", "Взгляд влево (из кабины)", KEY_N], ["look_right", "Взгляд вправо (из кабины)", KEY_M], ["look_up", "Взгляд вверх (из кабины)", KEY_B], ["look_down", "Взгляд вниз (из кабины)", KEY_COMMA],
	["cam", "Камера", KEY_V], ["assist", "Стабилизация вращения", KEY_T], ["grav", "Гравитация", KEY_G], ["interior", "Интерьер", KEY_H],
	["detach", "Оторвать деталь", KEY_X], ["boom", "Оторвать всё", KEY_Z], ["reset", "Сброс на старт", KEY_R], ["unstick", "Вернуть на трассу (+20 с)", KEY_Y]]
const KEY_ACTIONS := ["cam", "assist", "grav", "interior", "detach", "boom", "reset", "unstick"]   # из них часть идёт через InputMap
var keys := {}                                                # id -> physical keycode
# кнопки/оси геймпада: [id, название, привязка по умолчанию, вид: "m" = стик/курок/кнопка, "b" = только кнопка]
const PADBIND := [
	["pitch_up", "Нос вверх", {"t": "a", "i": JOY_AXIS_LEFT_Y, "s": 1}, "m"], ["pitch_down", "Нос вниз", {"t": "a", "i": JOY_AXIS_LEFT_Y, "s": -1}, "m"],
	["roll_left", "Крен влево", {"t": "a", "i": JOY_AXIS_LEFT_X, "s": -1}, "m"], ["roll_right", "Крен вправо", {"t": "a", "i": JOY_AXIS_LEFT_X, "s": 1}, "m"],
	["yaw_left", "Рыскание влево", {"t": "b", "i": JOY_BUTTON_LEFT_SHOULDER, "s": 1}, "m"], ["yaw_right", "Рыскание вправо", {"t": "b", "i": JOY_BUTTON_RIGHT_SHOULDER, "s": 1}, "m"],
	["thr", "Газ (тяговые)", {"t": "a", "i": JOY_AXIS_TRIGGER_RIGHT, "s": 1}, "m"], ["boost", "Усиление маневровых", {"t": "a", "i": JOY_AXIS_TRIGGER_LEFT, "s": 1}, "m"],
	["lift_up", "Взлётные: форсаж", {"t": "b", "i": JOY_BUTTON_DPAD_UP, "s": 1}, "m"], ["lift_down", "Взлётные: замедление", {"t": "b", "i": JOY_BUTTON_DPAD_DOWN, "s": 1}, "m"],
	["assist", "Стабилизация вращения", {"t": "b", "i": JOY_BUTTON_A, "s": 1}, "b"], ["detach", "Оторвать деталь", {"t": "b", "i": JOY_BUTTON_X, "s": 1}, "b"],
	["cam", "Камера", {"t": "b", "i": JOY_BUTTON_RIGHT_STICK, "s": 1}, "b"], ["interior", "Интерьер", {"t": "b", "i": JOY_BUTTON_BACK, "s": 1}, "b"],
	["scheme", "Схема геймпада 1/2", {"t": "b", "i": JOY_BUTTON_Y, "s": 1}, "b"]]
const PAD_BTN_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →"]
var pad := {}                                                 # id -> {t: "a"|"b", i: индекс, s: знак}

func pad_name(b: Dictionary) -> String:
	if b["t"] == "b": return PAD_BTN_NAMES[int(b["i"])] if int(b["i"]) < PAD_BTN_NAMES.size() else "кнопка %d" % int(b["i"])
	var i := int(b["i"]); var s := int(b["s"])
	match i:
		0: return "Л. стик ←" if s < 0 else "Л. стик →"
		1: return "Л. стик ↑" if s < 0 else "Л. стик ↓"
		2: return "П. стик ←" if s < 0 else "П. стик →"
		3: return "П. стик ↑" if s < 0 else "П. стик ↓"
		4: return "LT"
		5: return "RT"
	return "ось %d" % i

func _load_pad(cf: ConfigFile = null) -> void:
	for pb in PADBIND:
		pad[pb[0]] = (pb[2] as Dictionary).duplicate()
		if cf != null and cf.has_section_key("pad", pb[0]):
			var p := String(cf.get_value("pad", pb[0])).split(":")
			if p.size() == 3 and p[0] in ["a", "b"]: pad[pb[0]] = {"t": p[0], "i": int(p[1]), "s": int(p[2])}

func apply_pad() -> void:                                     # кнопочные действия InputMap берут кнопки из pad
	for pb in PADBIND:
		if pb[3] != "b" or not InputMap.has_action(pb[0]): continue
		for ev in InputMap.action_get_events(pb[0]): if ev is InputEventJoypadButton: InputMap.action_erase_event(pb[0], ev)
		if pad[pb[0]]["t"] == "b":
			var e := InputEventJoypadButton.new(); e.button_index = int(pad[pb[0]]["i"]); InputMap.action_add_event(pb[0], e)

var pad_fake := {}
func _pa(d: int, id: String) -> float:                        # аналоговое значение 0..1 (ось), для кнопки 0
	if not pad_fake.is_empty(): return float(pad_fake.get(id + ":a", 0.0))
	var b: Dictionary = pad[id]
	if b["t"] != "a": return 0.0
	var i := int(b["i"]); var v := Input.get_joy_axis(d, i)
	if i < 4:
		if cfg[["inv_lx", "inv_ly", "inv_rx", "inv_ry"][i]]: v = -v
		v = _dz(v)
	return maxf(v * float(b["s"]), 0.0)

func _pb(d: int, id: String) -> float:                        # нажата ли кнопка (1/0)
	if not pad_fake.is_empty(): return float(pad_fake.get(id + ":b", 0.0))
	var b: Dictionary = pad[id]
	return 1.0 if b["t"] == "b" and Input.is_joy_button_pressed(d, int(b["i"])) else 0.0

func _load_keys(cf: ConfigFile = null) -> void:
	for kb in KEYBIND: keys[kb[0]] = kb[2]
	if cf != null:
		for kb in KEYBIND:
			var kc := int(cf.get_value("keys", kb[0], keys[kb[0]]))
			if OS.get_keycode_string(kc as Key) != "" and kc > 0: keys[kb[0]] = kc          # битые значения в файле игнорируются

func _kd(id: String) -> float:
	return 1.0 if Input.is_physical_key_pressed(keys[id]) else 0.0

func apply_keys() -> void:                                    # действия InputMap берут клавиши из keys
	for a in KEY_ACTIONS:
		if not InputMap.has_action(a): continue
		for ev in InputMap.action_get_events(a): if ev is InputEventKey: InputMap.action_erase_event(a, ev)
		var e := InputEventKey.new(); e.physical_keycode = keys[a]; InputMap.action_add_event(a, e)
	apply_pad()
const MENU_ITEMS := [
	["inv_lx", "Левый стик, влево-вправо (рыскание): инвертировать"],
	["inv_ly", "Левый стик, вверх-вниз (тангаж): инвертировать"],
	["inv_rx", "Правый стик, влево-вправо (отдача вбок): инвертировать"],
	["inv_ry", "Правый стик, вверх-вниз (отдача вперёд-назад): инвертировать"],
	["swap_roll", "Крен: поменять местами LB и RB"],
	["inv_kb_pitch", "Клавиатура: инвертировать тангаж (стрелки вверх/вниз)"],
	["level", "Уровень сложности управления (Салага … Киборг)"],
	["scheme", "Схема геймпада (1 = всё через хвост, 2 = два джойстика)"],
	["deadzone", "Мёртвая зона стиков"],
	["tech", "Технический экран моторов и кривых: клавиша F4"]]
const MENU_NUM := {}
const LEVEL_NAMES := ["Турист", "Дальнобойщик", "Любимец букмекеров", "Ветеран", "Киборг"]
const LEVEL_TAGS := ["Случайно попал на трассу", "Честный работяга с опытом дальних перелётов", "Ставки один к трём!", "Видел всякое", "Ощущает корабль, как продолжение своего тела"]
# гашение «неносовой» инерции: [вбок, вверх-вниз, усиление при тяге главных], 1/с; Ветеран = как раньше; Киборг = как Ветеран, но без помощи
const LEVEL_SLIP := [[4.0, 4.0, 2.0], [0.25, 0.25, 1.0], [0.05, 0.05, 1.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]     # Дальнобойщик = прежний Любимец (на полной тяге τ = 2 с), Любимец в 5 раз слабее (τ = 10 с); было 2.5 и 1.2
const LEVEL_DAMP := [3.0, 2.0, 1.0, 1.0, 1.0]           # множитель гашения вращения стабилизацией: Турист и Дальнобойщик быстрее останавливают вращение
const LEVEL_ROLL := [2.5, 1.5, 0.0, 0.0, 0.0]            # самовыравнивание по крену (Салага, Ученик), 1/с
var prev_lvl := -1
func _lvl() -> int: return clampi(int(cfg["level"]), 0, 4)
const DEADZONES := [0.05, 0.08, 0.12, 0.18, 0.25]
var cfg := {"hud_mode": 0, "hud_alpha": 0.72, "hud_margin": 0.0, "hud_level": true, "hud_chip": true, "inv_lx": false, "inv_ly": false, "inv_rx": false, "inv_ry": false, "swap_roll": false, "inv_kb_pitch": false, "deadzone": 0.12, "level": 3, "vol": 1.0, "music": 0.8, "menu_music": 0.5, "sfx": 1.0, "rumble": true, "ship_sfx": 0.8, "cam_view": 0, "stats": {}, "ship": 0, "ach": {}, "rec": {}}
var esc_prev := false
var menu_open := false
var menu_i := 0
var menu_label: Label
const N_BOTS := 11
# вариации корпусов ботов (подробности в ship_variant.gd): нос/каюты/корма/размер; у «Долгоносика» ещё маневровый на кронштейне под носом
const BOT_VARIANTS := {
	1: {"nose": [-22.0, 1.55], "nose_engine": true},
	2: {"nose": [-22.0, 1.2], "cabins": -1, "rear": [26.0, 1.15, 1.0]},
	3: {"scale": 0.82, "cabins": -2, "nose": [-22.0, 1.1]},
	4: {"nose": [-22.0, 0.88], "cabins": 1},
	6: {"nose": [-22.0, 1.3], "cabins": -2},
	7: {"cabins": 2, "rear": [24.0, 1.12, 1.18]},
	8: {"rear": [22.0, 1.0, 1.28], "scale": 0.95}}
const RIM_Y := 5350.0       # выше этого высота «запретная»: ограничения не видно, но надо уйти за RIM_GRACE секунд
const RIM_GRACE := 8.0
var bots: Array = []
var ship_scene: PackedScene
var bot_tex := {}
var bot_hull_shape: ConvexPolygonShape3D
var start_t := 4.0
var use_loading := false                                                    # экран загрузки и поэтапная сборка сцены (в обучении и тестовых снимках выключены)
var loading: LoadingScreen
var reload_title := "Перезапуск"
var p_dsq := false                                                          # игрок дисквалифицирован: заезд для него окончен, показывается таблица
var unstick_n := 0
var unstick_cd := 0.0
var msg_t := 0.0
var msg_txt := ""
const UNSTICK_PENALTY := 20.0                                               # штраф к времени за возврат на трассу
const UNSTICK_MAX := 3
const UNSTICK_BACK := 250.0                                                 # возвращаем назад по трассе: прогресс не выигрывается
var rim_t := 0.0
var dsq_t := 0.0
var p_last_s := -1.0
var p_lap := 0
var s0 := -1.0           # s линии старта/финиша
var p_prog := 0.0        # накопленный путь игрока вдоль трассы, м (назад — минус)
var p_rel := 0.0
var rank := 1
var warn_label: Label
var eng_force := {}          # имя маневрового -> вектор силы в осях корабля (0..1)
var last_ctrl := {}
var _reset_now := false
var terr_mat: ShaderMaterial
var chunks := {}
var trk_pts := PackedVector2Array()
var trk_s := PackedFloat32Array()
var trk_len := 0.0
var seg_grid := {}
var track_tiles := {}
var lap := 0
var arch_s: Array = []
var chunk_jobs := {}
var chunk_data := {}
var chunk_mutex := Mutex.new()

const GENE_R := {"v_max": [800.0, 3600.0], "lat_acc": [60.0, 600.0], "a_cap": [150.0, 1500.0], "look_k": [1.0, 4.0], "look_min": [500.0, 3000.0], "a_gain": [0.6, 4.0], "align_lo": [0.3, 0.9], "att_gain": [0.8, 4.0], "alt_pref": [0.0, 1.0], "alt_free": [0.0, 1.0], "clear_m": [100.0, 600.0], "lane": [-700.0, 700.0], "apex": [0.0, 1.0], "sep_w": [0.0, 3.0], "bank": [0.0, 1.0], "bank_max": [0.3, 1.45], "bank_scale": [50.0, 600.0], "lift_brake": [0.0, 0.0], "avoid": [0.0, 2.0], "route": [0.0, 1.0]}
const GENE_DEF := {"v_max": 1400.0, "lat_acc": 130.0, "a_cap": 350.0, "look_k": 2.5, "look_min": 900.0, "a_gain": 1.2, "align_lo": 0.7, "att_gain": 1.2, "alt_pref": 0.5, "alt_free": 0.0, "clear_m": 220.0, "lane": 0.0, "apex": 0.3, "sep_w": 1.0, "bank": 0.0, "bank_max": 0.9, "bank_scale": 200.0, "lift_brake": 0.0, "avoid": 0.0, "route": 0.5}
var track_seed := 0           # 0 = нарисованная трасса, N>0 = генератор trackgen.gd (с len=N — открытая трасса заданной длины)
var evo_mode := false
var genes_path := ""
var evo_secs := 180.0
var evo_out := ""
var evo_skill := false
var narrow_s: Array = [36000.0, 58000.0, 84000.0]
var wv: Array = []
var seg_a := PackedVector2Array()          # отрезки всех путей (главный + объезд): концы, s в системе главного пути, номер пути
var seg_b := PackedVector2Array()
var seg_sa := PackedFloat32Array()
var seg_sb := PackedFloat32Array()
var seg_path := PackedInt32Array()
var branches: Array = []                   # рукава-объезды: {"pts","s","in","out"}; путь 1..N; s у точек = s главного пути в том же месте
const SPUR_BASE := 1000                    # номера путей ≥ SPUR_BASE — тупиковые ответвления срезок (spurs), не входящие в разметку трассы, карту и прогресс
const SPURS_PER_CUT := 2                    # тупиков на срезку (0 — выключить)
const PILLAR_CELL := 420.0                  # шаг сетки столбов, м
const PILLAR_DENS := 0.62                   # доля заполненных ячеек в центре чаши
const PILLAR_ZONE_DD := 620.0               # столбы растут только на дне и первой террасе ущелья
var spurs: Array = []                      # тупики: {"pts","cum","sj","parent","w","ph","len"}; в seg_sa/seg_sb хранится путь вдоль тупика, а s в _tq3 = s развилки (прогресс не растёт)
var spur_grid := {}                         # сетка отрезков тупиков (отдельно от seg_grid, чтобы рельеф вне тупиков остался прежним)
var forks: Array = []                      # развилки по порядку: {"in","out","ids":[номера путей]}
var track_open := false                    # true = открытая трасса (старт и финиш в разных местах), false = замкнутая петля
var gen_len_km := 0.0
const FIN_TAIL_PTS := 8                       # на сколько точек (по ≈3,44 км) трасса продлена прямой за конец сгенерированной
var explicit_track := false
var race_len := 1e12                       # длина гонки по s: финиш до возврата к старту
var evo_t := 0.0
var p_fin := false
var p_fin_t := 0.0
var p_hits := 0                                                              # удары игрока за заезд (для достижений)
var p_hit_pv := 0.0
var p_hit_cd := 0.0
var p_rim_ever := false                                                      # хоть раз выше края каньона
var p_side := false                                                          # хоть раз на боковой ветке трассы

func _build_track() -> void:
	var km := [Vector2(0, -0), Vector2(0, -3.44), Vector2(0, -6.88), Vector2(0.43, -10.32), Vector2(1.89, -13.33), Vector2(4.47, -15.31), Vector2(7.91, -16.17), Vector2(11.35, -16.17), Vector2(14.62, -17.37), Vector2(18.06, -19.44), Vector2(21.5, -20.3), Vector2(24.77, -18.23), Vector2(27.18, -14.79), Vector2(28.38, -10.75), Vector2(27.78, -7.31), Vector2(25.8, -4.47), Vector2(25.37, -1.29), Vector2(27.35, 2.15), Vector2(29.07, 6.02), Vector2(28.21, 9.89), Vector2(25.11, 12.21), Vector2(21.5, 12.21), Vector2(18.23, 10.32), Vector2(14.96, 10.84), Vector2(11.52, 13.59), Vector2(8.08, 16.34), Vector2(4.82, 15.65), Vector2(1.89, 11.7), Vector2(0.09, 6.02)]
	track_open = false
	var gen_cuts: Array = []
	if track_seed > 0:
		if gen_len_km > 0.0:
			var gen: Dictionary = preload("res://trackgen.gd").generate_open(track_seed, gen_len_km)
			km = gen["pts"]; gen_cuts = gen["cuts"]; track_open = true
			var kl: Vector2 = km[km.size() - 1]; var kd: Vector2 = (kl - km[km.size() - 2]).normalized()
			for ti in FIN_TAIL_PTS: km.append(kl + kd * 3.44 * float(ti + 1))      # прямой хвост: последняя срезка заканчивается до финиша, и за ним остаётся участок торможения
		else: km = preload("res://trackgen.gd").generate(track_seed)
	var n := km.size()
	var nseg := n - 1 if track_open else n
	var sub := 4 if track_open else 16
	for i in nseg:
		var p0: Vector2 = km[maxi(i - 1, 0) if track_open else (i - 1 + n) % n] * 1000.0; var p1: Vector2 = km[i] * 1000.0
		var p2: Vector2 = km[i + 1 if track_open else (i + 1) % n] * 1000.0; var p3: Vector2 = km[mini(i + 2, n - 1) if track_open else (i + 2) % n] * 1000.0
		for k in sub:
			var t := float(k) / float(sub)
			trk_pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	if track_open: trk_pts.append(km[n - 1] * 1000.0)
	var m := trk_pts.size()
	trk_s.resize(m)
	var acc := 0.0
	for i in m:
		trk_s[i] = acc
		if track_open and i == m - 1: break
		acc += trk_pts[i].distance_to(trk_pts[(i + 1) % m])
	trk_len = acc
	if track_seed > 0:
		var nr := RandomNumberGenerator.new(); nr.seed = track_seed * 31 + 5
		narrow_s = []
		var n_narrow := clampi(int(trk_len / 40000.0), 3, 24)
		for tries in 400:
			var cs := nr.randf_range(30000.0, trk_len - 10000.0); var okn := true
			for o in narrow_s: if absf(float(o) - cs) < 15000.0: okn = false
			if okn and narrow_s.size() < n_narrow: narrow_s.append(cs)
		wv = [nr.randf_range(0.15, 0.4), nr.randf_range(0.00006, 0.00018), nr.randf_range(0.0, TAU), nr.randf_range(0.08, 0.25), nr.randf_range(0.0003, 0.0009), nr.randf_range(0.0, TAU)]   # ширина каньона плавает по участкам
	race_len = trk_len - (24000.0 if track_open else 6000.0)                 # у открытой трассы финиш за 24 км до конца: там прямая для торможения
	if track_open: _make_cuts(gen_cuts, sub); _make_spurs()
	else: _make_branches(track_seed if track_seed > 0 else 7)
	for i in (m - 1 if track_open else m):
		seg_a.append(trk_pts[i]); seg_b.append(trk_pts[(i + 1) % m]); seg_sa.append(trk_s[i]); seg_sb.append(trk_s[i + 1] if i + 1 < m else trk_len); seg_path.append(0)
	for bi in branches.size():
		var br: Dictionary = branches[bi]; var bp: PackedVector2Array = br["pts"]; var bs: PackedFloat32Array = br["s"]
		for j in range(bp.size() - 1):
			seg_a.append(bp[j]); seg_b.append(bp[j + 1]); seg_sa.append(bs[j]); seg_sb.append(bs[j + 1]); seg_path.append(bi + 1)
	var n_main_segs := seg_a.size()
	for si in spurs.size():
		var sp: Dictionary = spurs[si]; var spp: PackedVector2Array = sp["pts"]; var spc: PackedFloat32Array = sp["cum"]
		for j in range(spp.size() - 1):
			seg_a.append(spp[j]); seg_b.append(spp[j + 1]); seg_sa.append(spc[j]); seg_sb.append(spc[j + 1]); seg_path.append(SPUR_BASE + si)
	for i in seg_a.size():
		var a := seg_a[i]; var b := seg_b[i]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(INFL, INFL); var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(INFL, INFL)
		for cx in range(int(floor(lo.x / GCELL)), int(floor(hi.x / GCELL)) + 1):
			for cz in range(int(floor(lo.y / GCELL)), int(floor(hi.y / GCELL)) + 1):
				var key := Vector2i(cx, cz)
				var gr: Dictionary = seg_grid if i < n_main_segs else spur_grid
				var lst: PackedInt32Array = gr.get(key, PackedInt32Array())
				lst.append(i); gr[key] = lst
		var tx0 := int(floor((a.x - INFL - 3500.0) / TILE)); var tx1 := int(floor((a.x + INFL + 3500.0) / TILE))
		var tz0 := int(floor((a.y - INFL - 3500.0) / TILE)); var tz1 := int(floor((a.y + INFL + 3500.0) / TILE))
		if i % 4 == 0:
			for tx in range(tx0, tx1 + 1):
				for tz in range(tz0, tz1 + 1): track_tiles[Vector2i(tx, tz)] = true

# Развилки: рукав-объезд уходит вбок от главного пути и сливается обратно; между ними остаётся скальный остров. Бывают одиночные (один объезд)
# и двойные (объезды с двух сторон — три канала). Размещаются по всей трассе, после длинного разгона.
# Срезающие ветки (открытая трасса): короткая узкая хорда от начала «широкого блока» основной трассы к его концу.
# s у точек ветки растёт линейно по длине ветки от s_in до s_out главного пути, поэтому прогресс и ранги сопоставимы.
func _make_cuts(cuts: Array, sub: int) -> void:
	branches.clear(); forks.clear()
	for ct in cuts:
		var kp: Array = ct["pts"]
		var n := kp.size()
		var pts := PackedVector2Array()
		for i in n - 1:
			var p0: Vector2 = kp[maxi(i - 1, 0)] * 1000.0; var p1: Vector2 = kp[i] * 1000.0; var p2: Vector2 = kp[i + 1] * 1000.0; var p3: Vector2 = kp[mini(i + 2, n - 1)] * 1000.0
			for k in sub:
				var t := float(k) / float(sub)
				pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
		pts.append(kp[n - 1] * 1000.0)
		var s_in: float = trk_s[int(ct["a"]) * sub]; var s_out: float = trk_s[int(ct["b"]) * sub]
		var cum := PackedFloat32Array(); cum.resize(pts.size()); var acc := 0.0
		for i in pts.size():
			cum[i] = acc
			if i + 1 < pts.size(): acc += pts[i].distance_to(pts[i + 1])
		var ss := PackedFloat32Array(); ss.resize(pts.size())
		for i in pts.size(): ss[i] = s_in + (s_out - s_in) * cum[i] / maxf(acc, 1.0)
		var ctype: String = ct.get("type", "wind")
		var br := {"pts": pts, "s": ss, "in": s_in, "out": s_out, "w": 0.4, "ph": float(branches.size()) * 1.7 + 0.4, "type": ctype, "ceil": 99999.0, "needle_s": -1.0, "needle_y": 700.0, "sc": acc / maxf(s_out - s_in, 1.0)}
		if ctype == "needle":
			var cum2 := 0.0; var half := acc * 0.5
			for i in range(1, pts.size()):
				cum2 += pts[i].distance_to(pts[i - 1])
				if cum2 >= half: br["needle_s"] = ss[i]; break
		branches.append(br)
		forks.append({"in": s_in, "out": s_out, "ids": [branches.size()], "gain": 1.0 - acc / maxf(s_out - s_in, 1.0), "type": ctype})

# Тупиковые ответвления срезок (открытая трасса): такое же узкое ущелье с изломанными краями, уходит под углом от срезки и кончается каменной чашей
# со «лесом» столбов. Сами срезки и основная трасса не меняются: тупики строятся отдельным генератором с запасом расстояния до них (кроме устья).
const SPUR_MAIN_GAP := 8000.0               # до основной трассы, м
const SPUR_CUT_GAP := 7500.0                # до других срезок, тупиков и до своей срезки (дальше 3,5 км от устья)
func _min_dist_to(p: Vector2, arr: PackedVector2Array, step: int = 1) -> float:
	var dm := 1e18
	for i in range(0, arr.size(), step): dm = minf(dm, p.distance_squared_to(arr[i]))
	return sqrt(dm)

func _make_spurs() -> void:
	spurs.clear()
	if not track_open or branches.is_empty() or SPURS_PER_CUT <= 0: return
	var rng := RandomNumberGenerator.new(); rng.seed = maxi(track_seed, 1) * 131 + 17
	var mainp := PackedVector2Array(trk_pts)
	for bi in branches.size():
		var br: Dictionary = branches[bi]; var bp: PackedVector2Array = br["pts"]; var bs: PackedFloat32Array = br["s"]
		var made := 0
		for attempt in 260:
			if made >= SPURS_PER_CUT: break
			var i := rng.randi_range(int(bp.size() * 0.12), int(bp.size() * 0.88))
			var P := bp[i]; var T := (bp[mini(i + 3, bp.size() - 1)] - bp[maxi(i - 3, 0)]).normalized()
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var hd := T.rotated(side * deg_to_rad(rng.randf_range(38.0, 68.0)))
			var want_len := rng.randf_range(11000.0, 19000.0)
			var pts := PackedVector2Array([P]); var cum := PackedFloat32Array([0.0])
			var cur := P; var dd := 0.0
			while dd < want_len:
				if dd > 2200.0:
					hd = hd.rotated(rng.randf_range(-0.2, 0.2) + (rng.randf_range(-0.7, 0.7) if rng.randf() < 0.14 else 0.0))   # изломы
				cur += hd * 500.0; dd += 500.0; pts.append(cur); cum.append(dd)
			var ok := true
			for k in range(1, pts.size()):
				var pk := pts[k]; var dk := cum[k]
				if _min_dist_to(pk, mainp, 2) < (SPUR_MAIN_GAP if dk > 2500.0 else 6500.0): ok = false; break
				for oj in branches.size():
					var op: PackedVector2Array = (branches[oj] as Dictionary)["pts"]
					var gap := SPUR_CUT_GAP
					if oj == bi: gap = minf(0.5 * maxf(dk - 1000.0, 0.0), 3000.0) if dk < want_len * 0.45 else 5000.0     # от своей срезки уходим постепенно, чаша — подальше
					if gap > 0.0 and _min_dist_to(pk, op, 2) < gap: ok = false; break
				if not ok: break
				for os in spurs:
					if _min_dist_to(pk, (os as Dictionary)["pts"], 1) < SPUR_CUT_GAP: ok = false; break
				if not ok: break
				for j in range(0, k):                                             # не сворачивать к самому себе
					if dk - cum[j] > 3500.0 and pk.distance_to(pts[j]) < 0.5 * (dk - cum[j]): ok = false; break
				if not ok: break
			if not ok: continue
			spurs.append({"pts": pts, "cum": cum, "sj": bs[i], "parent": bi + 1, "ssc": maxf(float(br["sc"]), 0.3), "w": 0.4, "ph": rng.randf_range(0.0, TAU), "len": dd})
			made += 1

func _hash2(i: int, j: int, k: int) -> float:                             # детерминированный шум 0..1 по целочисленной ячейке
	return fposmod(sin(float(i) * 127.1 + float(j) * 311.7 + float(k) * 74.7) * 43758.5453, 1.0)

# «Лес» столбов в конце тупика (как в Чжанцзяцзе): вертикальные колонны с плоскими вершинами растут со дна; к стенам ущелья сливаются с ними
func _spur_pillars(x: float, z: float, h: float, dd: float, d: float, sl: float) -> float:
	var cf := smoothstep(sl * 0.30, sl * 0.62, d)
	if cf <= 0.0 or dd >= PILLAR_ZONE_DD: return h
	var zf := 1.0 - smoothstep(PILLAR_ZONE_DD * 0.62, PILLAR_ZONE_DD, dd)
	var cs := PILLAR_CELL
	var ix0 := int(floor(x / cs)); var iz0 := int(floor(z / cs))
	var best := 0.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var ci := ix0 + dx; var cj := iz0 + dz
			if _hash2(ci, cj, 11) > PILLAR_DENS * cf: continue
			var cx := (float(ci) + 0.15 + 0.7 * _hash2(ci, cj, 23)) * cs; var cz := (float(cj) + 0.15 + 0.7 * _hash2(ci, cj, 29)) * cs
			var rad := lerpf(55.0, 150.0, _hash2(ci, cj, 37))
			var dist := Vector2(x - cx, z - cz).length()
			if dist >= rad: continue
			var prof := 1.0 - smoothstep(rad * 0.72, rad, dist)
			var top := lerpf(800.0, 4400.0, pow(_hash2(ci, cj, 51), 0.8)) * (1.0 + 0.05 * sin(x * 0.11 + z * 0.09))
			best = maxf(best, prof * top)
	return maxf(h, best * zf - 8.0)

func _make_branches(sd: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = sd * 97 + 11
	var mm := trk_pts.size()
	branches.clear(); forks.clear()
	var s_end := race_len - 14000.0
	var cur := 30000.0
	var guard := 0
	while guard < 200:
		guard += 1
		var s_in := cur + rng.randf_range(4000.0, 34000.0)
		var span := rng.randf_range(6500.0, 15000.0)
		var s_out := s_in + span
		if s_out > s_end: break
		var want := 2 if rng.randf() < 0.38 else 1
		var sides := [1.0, -1.0] if rng.randf() < 0.5 else [-1.0, 1.0]
		var got: Array = []
		for side in sides:
			if got.size() >= want: break
			var amp := rng.randf_range(2800.0, 4200.0)
			for attempt in 3:
				var pts := PackedVector2Array(); var ss := PackedFloat32Array()
				for i in mm:
					if trk_s[i] < s_in or trk_s[i] > s_out: continue
					var u := (trk_s[i] - s_in) / (s_out - s_in)
					var tg := (trk_pts[mini(i + 1, mm - 1)] - trk_pts[maxi(i - 1, 0)]).normalized()
					pts.append(trk_pts[i] + Vector2(-tg.y, tg.x) * float(side) * amp * pow(sin(PI * u), 0.9)); ss.append(trk_s[i])
				if pts.size() < 10: break
				var ok := true
				for k in range(1, pts.size() - 1):                                     # без крутых изломов
					var d0 := (pts[k] - pts[k - 1]).normalized(); var d1 := (pts[k + 1] - pts[k]).normalized()
					if acos(clampf(d0.dot(d1), -1.0, 1.0)) > 0.6: ok = false; break
				if ok:                                                                   # рукав не должен подходить к другим частям трассы
					for k in range(0, pts.size(), 2):
						for i in range(0, mm, 2):
							if (trk_s[i] < s_in - 5000.0 or trk_s[i] > s_out + 5000.0) and pts[k].distance_to(trk_pts[i]) < 3500.0: ok = false; break
						if not ok: break
				if ok: got.append({"pts": pts, "s": ss, "in": ss[0], "out": ss[ss.size() - 1]}); break
				amp *= 0.8
		if got.size() > 0:
			var ids: Array = []
			for g in got: branches.append(g); ids.append(branches.size())
			forks.append({"in": float(got[0]["in"]), "out": float(got[0]["out"]), "ids": ids})
			cur = s_out + 4000.0
		else: cur = s_in + 3000.0

func _track_query(x: float, z: float) -> Vector2:
	var r := _tq3(x, z)
	return Vector2(r.x, r.y)

func _tq3(x: float, z: float) -> Vector3:                                   # (расстояние до ближайшего пути, s в системе главного пути, номер пути)
	var r := _tq3_raw(x, z)
	if r.z >= float(SPUR_BASE) - 0.5: r.y = float((spurs[int(r.z) - SPUR_BASE] as Dictionary)["sj"])    # в тупике прогресс стоит на месте: s развилки
	return r

func _tq3_cls(x: float, z: float, grid: Dictionary) -> Vector3:              # ближайший отрезок из сетки grid: (расстояние, s или путь вдоль тупика, номер пути)
	var key := Vector2i(int(floor(x / GCELL)), int(floor(z / GCELL)))
	if not grid.has(key): return Vector3(1e9, 0.0, 0.0)
	var best := 1e18; var bs := 0.0; var bp := 0
	var pt := Vector2(x, z)
	for i in (grid[key] as PackedInt32Array):
		var a := seg_a[i]; var ab := seg_b[i] - a
		var l2 := ab.length_squared()
		var t := clampf((pt - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
		var d2 := pt.distance_squared_to(a + ab * t)
		if d2 < best: best = d2; bs = lerpf(seg_sa[i], seg_sb[i], t); bp = seg_path[i]
	return Vector3(sqrt(best), bs, float(bp))

func _tq3_raw(x: float, z: float) -> Vector3:                               # ближайший путь с учётом тупиков (в них s = путь вдоль тупика)
	var r := _tq3_cls(x, z, seg_grid)
	if spur_grid.is_empty(): return r
	var r2 := _tq3_cls(x, z, spur_grid)
	return r2 if r2.x < r.x else r

func _track_at_p(sv: float, path: int) -> Array:                          # точка и направление пути; рукав задан только между его in и out
	if path >= SPUR_BASE: path = int((spurs[path - SPUR_BASE] as Dictionary)["parent"])      # из тупика возвращаются на его срезку
	if path >= 1 and path <= branches.size():
		var br: Dictionary = branches[path - 1]; var bs: PackedFloat32Array = br["s"]; var bp: PackedVector2Array = br["pts"]
		if sv >= float(br["in"]) and sv <= float(br["out"]):
			var lo := 0; var hi := bs.size() - 2
			while lo < hi:
				var mid := (lo + hi + 1) / 2
				if bs[mid] <= sv: lo = mid
				else: hi = mid - 1
			var a := bp[lo]; var b := bp[lo + 1]
			var t := clampf((sv - bs[lo]) / maxf(0.001, bs[lo + 1] - bs[lo]), 0.0, 1.0)
			return [a.lerp(b, t), (b - a).normalized()]
	return _track_at(sv)

func _track_at(sv: float) -> Array:
	sv = clampf(sv, 0.0, trk_len - 0.01) if track_open else fposmod(sv, trk_len)
	var lo := 0; var hi := trk_s.size() - (2 if track_open else 1)
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if trk_s[mid] <= sv: lo = mid
		else: hi = mid - 1
	var m := trk_pts.size()
	var a := trk_pts[lo]; var b := trk_pts[(lo + 1) % m]
	var seg := b - a
	var t := (sv - trk_s[lo]) / maxf(0.001, seg.length())
	return [a + seg * t, seg.normalized()]

const SHELF_EXTRA := 240.0   # расширение второго яруса: полка втрое шире прежней (было 120 ед. dd)
# NARROW_S заменён переменной narrow_s   # редкие места, где ярусы сужены почти до прежнего (первый поворот s=9..24 км всегда широкий)
func _wk(sv: float) -> float:                                              # множитель ширины каньона на участке (1 = базовая); у ручной трассы всегда 1
	if wv.is_empty(): return 1.0
	var k := clampf(1.0 + float(wv[0]) * sin(sv * float(wv[1]) + float(wv[2])) + float(wv[3]) * sin(sv * float(wv[4]) + float(wv[5])), 0.55, 1.5)
	return maxf(k, 1.0) if sv < 25000.0 else k

func _shelf_extra(sv: float) -> float:
	var k := 0.0
	for c in narrow_s: k = maxf(k, 1.0 - smoothstep(1500.0, 3500.0, absf(sv - c)))
	return SHELF_EXTRA * (1.0 - 0.85 * k)

func height(x: float, z: float) -> float:
	var h := _h_at(x, z, _tq3_cls(x, z, seg_grid))                       # основная трасса и срезки: как раньше
	if not spur_grid.is_empty():
		var qs := _tq3_cls(x, z, spur_grid)
		if qs.x < INFL: h = minf(h, _h_at(x, z, qs))                       # тупики врезаются в рельеф как объединение ущелий (швов нет)
	return h

func _h_at(x: float, z: float, q3: Vector3) -> float:
	# профиль в духе Гранд-каньона: сухое русло, ступенчатые склоны-террасы, плато
	var q := Vector2(q3.x, q3.y)
	if q.x >= INFL: return PLATEAU_Y
	var spk := int(q3.z) - SPUR_BASE if q3.z >= float(SPUR_BASE) - 0.5 else -1
	var spd := 0.0                                                       # путь вдоль тупика
	var pw := 1.0 if q3.z < 0.5 else (float((spurs[spk] as Dictionary)["w"]) if spk >= 0 else float((branches[int(q3.z) - 1] as Dictionary).get("w", 1.0)))
	var sv := q.y
	if spk >= 0:
		var spr: Dictionary = spurs[spk]; spd = q.y; sv = float(spr["sj"]) + spd / float(spr["ssc"]); var sl := float(spr["len"])
		pw *= (1.0 + 0.2 * sin(sv * 0.0021 + float(spr["ph"])) + 0.1 * sin(sv * 0.0057 + 2.0 * float(spr["ph"]))) * (1.0 + 0.6 * smoothstep(sl * 0.55, sl * 0.9, spd))     # к концу тупик расширяется в чашу
	elif q3.z >= 0.5: pw *= 1.0 + 0.2 * sin(sv * 0.0021 + float((branches[int(q3.z) - 1] as Dictionary).get("ph", 0.0))) + 0.1 * sin(sv * 0.0057 + 2.0 * float((branches[int(q3.z) - 1] as Dictionary).get("ph", 0.0)))     # ширина расщелины плавает по длине среза
	var ds := minf(sv, trk_len - sv)                                     # расстояние до линии старта вдоль трассы
	var startw := 1.0 + 0.9 * exp(-(ds / 2200.0) * (ds / 2200.0))        # на старте каньон шире
	var dd: float = q.x / (WIDTH_SCALE * startw * _wk(sv) * pw) * (1.0 + 0.22 * sin(sv * 0.00045 + 0.5) + 0.12 * sin(sv * 0.0013))
	var hs := PLATEAU_Y / 700.0
	var ex := _shelf_extra(sv)                                           # на сколько расширен второй ярус (в тех же единицах dd); русло и первая стенка прежние
	var h := hs * (140.0 * smoothstep(60.0, 300.0, dd) + 160.0 * smoothstep(420.0 + ex, 480.0 + ex, dd) + 170.0 * smoothstep(650.0 + ex, 710.0 + ex, dd) + 230.0 * smoothstep(900.0 + ex, 970.0 + ex, dd))
	h -= 12.0 * exp(-(dd / 22.0) * (dd / 22.0))
	var fade := 1.0 - smoothstep(940.0 + ex, 1000.0 + ex, dd)
	var nz := sin(x * 0.071 + z * 0.053) * sin(z * 0.067 - x * 0.031) + 0.5 * sin(x * 0.19 + z * 0.13) + 0.6 * sin((x + z) * 0.013)
	h += nz * 6.0 * fade
	if spk >= 0: h = _spur_pillars(x, z, h, dd, spd, float((spurs[spk] as Dictionary)["len"]))
	return PLATEAU_Y + (h - PLATEAU_Y) * (1.0 - smoothstep(INFL * 0.8, INFL, q.x))

func _loading_node() -> LoadingScreen:
	var n = Engine.get_meta("loading_node") if Engine.has_meta("loading_node") else null
	if n == null or not is_instance_valid(n):
		n = LoadingScreen.new(); Engine.set_meta("loading_node", n)
		get_tree().root.add_child.call_deferred(n)
	return n

func _lt(f: float, txt: String) -> void:                                    # этап сборки сцены: обновить прогресс и дать кадр на отрисовку экрана загрузки
	if not use_loading: return
	loading.progress(f, txt)
	await get_tree().process_frame

func _reload_game() -> void:                                                # перезагрузка сцены с экраном загрузки (перезапуск, возврат в меню, смена корабля)
	set_process(false); set_physics_process(false)
	if not use_loading: get_tree().reload_current_scene.call_deferred(); return
	print("RELOAD t=", Time.get_ticks_msec())
	var ld := _loading_node()
	await get_tree().process_frame
	ld.begin(reload_title)
	await get_tree().process_frame; await get_tree().process_frame
	get_tree().reload_current_scene()

# Корпуса с вариациями строятся долго (разрезание сетки в GDScript), поэтому готовый набор частей хранится в Engine и копируется при перезагрузке сцены
func _fill_variant(target: Node3D, key: String, spec: Dictionary) -> Dictionary:
	if not spec.is_empty():                                                    # готовый корпус из tools/bake_variants.gd (разрезание сетки в игре занимает секунды)
		var bp := "res://ship/variants/%s.scn" % key
		if ResourceLoader.exists(bp):
			var pk: PackedScene = Engine.get_meta("vp_" + key) if Engine.has_meta("vp_" + key) else (load(bp) as PackedScene)
			Engine.set_meta("vp_" + key, pk)                                    # держим в памяти: при перезагрузке сцены не читать десятки мегабайт заново
			var inst := pk.instantiate()
			if str(inst.get_meta("spec", "")) == JSON.stringify(spec):
				for n in inst.get_children():
					inst.remove_child(n); n.owner = null; target.add_child(n)
				inst.free()
				var bres := {}
				var lod := target.get_node_or_null("SM_Hull_Body_LOD1") as MeshInstance3D
				var hb := target.get_node_or_null("SM_Hull_Body") as MeshInstance3D
				if lod != null: bres["shape"] = lod.mesh.create_convex_shape(true, true)
				if hb != null: bres["com"] = hb.position + hb.mesh.get_aabb().get_center()
				return bres
			inst.free()
	var mk := "vc_" + key
	if not spec.is_empty() and Engine.has_meta(mk):
		var c: Dictionary = Engine.get_meta(mk)
		for ch in (c["holder"] as Node3D).get_children(): target.add_child(ch.duplicate())
		return c["res"]
	var root := ship_scene.instantiate()
	for n in root.get_children():
		root.remove_child(n); n.owner = null; target.add_child(n)
	root.free()
	var res := {}
	if not spec.is_empty():
		res = ShipVariant.apply(target, spec)
		var holder := Node3D.new()
		for ch in target.get_children():
			if not ch.is_queued_for_deletion(): holder.add_child(ch.duplicate())
		Engine.set_meta(mk, {"holder": holder, "res": res})
	return res

func _ready() -> void:
	_load_cfg()
	var ua := OS.get_cmdline_user_args()
	shot_mode = "shot" in ua
	test_mode = "test" in ua
	evo_mode = "evo" in ua
	fly = "fly" in ua
	ram = "ram" in ua
	soak = "soak" in ua or fly or ram
	for a in ua:
		if a.begins_with("cam="): cam_mode = int(a.substr(4))
		if a.begins_with("scheme="): scheme = int(a.substr(7))
		if a.begins_with("level="): cfg["level"] = int(a.substr(6))
		if a.begins_with("ship="): cfg["ship"] = int(a.substr(5))
		if a.begins_with("track="): track_seed = int(a.substr(6)); explicit_track = true
		if a.begins_with("len="): gen_len_km = float(a.substr(4))
		if a.begins_with("secs="): evo_secs = float(a.substr(5))
		if a.begins_with("out="): evo_out = a.substr(4)
		if a.begins_with("genes="): genes_path = a.substr(6)
		if a == "skill": evo_skill = true
		if a.begins_with("bot="): soak_bot = int(a.substr(4))
		if a.begins_with("soakv="): soak_vmax = float(a.substr(6))
		if a.begins_with("soakmax="): soak_max = float(a.substr(8))
	ship_id = clampi(int(cfg.get("ship", 0)), 0, SHIP_NAMES.size() - 1)
	var has_shot := false
	for a2 in ua: if a2.begins_with("uishot="): has_shot = true
	use_loading = not (evo_mode or test_mode or shot_mode or soak or has_shot)
	if use_loading:
		set_process(false); set_physics_process(false)
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		loading = _loading_node()
		await get_tree().process_frame
		if not loading.active: loading.begin("Загрузка игры")                      # если экран уже показан перед перезагрузкой, название остаётся прежним
		await get_tree().process_frame
	if not explicit_track and not evo_mode:                                    # по умолчанию: длинная открытая трасса с развилками (около 650 км)
		track_seed = 11; gen_len_km = 650.0
	await _lt(0.02, "Шейдеры")
	_make_shaders()
	_setup_input()
	await _lt(0.04, "Трасса")
	_build_track()
	await _lt(0.08, "Мир")
	_build_world()
	await _lt(0.10, "Ваш корабль")
	_build_ship()
	await _lt(0.30, "Рельеф")
	if evo_mode: _preload_evo()
	else: _preload_chunks()
	await _spawn_bots()
	await _lt(0.94, "Интерфейс")
	_build_arches()
	_build_cut_props()
	_build_hud()
	if not evo_mode: _log_open()
	cam = Camera3D.new(); cam.far = 90000.0; cam.fov = 70.0; add_child(cam)
	_reset()
	if evo_mode: ship.freeze = true; ship.global_position = Vector3(300000.0, 1000.0, 300000.0)
	for ua2 in OS.get_cmdline_user_args():
		if ua2.begins_with("uishot="): ui_shot = ua2.substr(7)
		if ua2.begins_with("tourc="): tour_c = int(ua2.substr(6))
	if soak: _soak_begin()
	elif not (evo_mode or test_mode or shot_mode or ui_shot != "" or Engine.has_meta("skip_menu")):
		ui.open_menu()
		if Engine.has_meta("menu_sel"): ui.sel = int(Engine.get_meta("menu_sel")); Engine.remove_meta("menu_sel"); ui._refresh_items()
	elif Engine.has_meta("skip_menu") and music_ok(): begin_intro()
	if use_loading:
		loading.progress(1.0, "Готово"); loading.finish(); print("LOADED t=", Time.get_ticks_msec())
		set_process(true); set_physics_process(true)

func _setup_input() -> void:
	if InputMap.has_action("cam"): return                     # после перезагрузки сцены действия уже есть
	var m := {"cam": keys["cam"], "grav": keys["grav"], "assist": keys["assist"], "detach": keys["detach"], "boom": keys["boom"], "reset": keys["reset"], "unstick": keys["unstick"], "interior": keys["interior"], "scheme": KEY_F2, "menu": KEY_F3, "tech": KEY_F4, "mark": KEY_F5, "help": KEY_F1}
	for a in m:
		InputMap.add_action(a)
		var ev := InputEventKey.new(); ev.physical_keycode = m[a]; InputMap.action_add_event(a, ev)
	var jb := {"cam": JOY_BUTTON_RIGHT_STICK, "scheme": JOY_BUTTON_Y, "assist": JOY_BUTTON_A, "detach": JOY_BUTTON_X, "interior": JOY_BUTTON_BACK, "menu": JOY_BUTTON_LEFT_STICK, "mark": JOY_BUTTON_B}
	for a in jb:
		var ev := InputEventJoypadButton.new(); ev.button_index = jb[a]; InputMap.action_add_event(a, ev)
	apply_pad()
	var evs := InputEventJoypadButton.new(); evs.button_index = JOY_BUTTON_START; InputMap.action_add_event("menu", evs)      # Start = пауза
	for pr in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:                          # в этой сборке у ui_accept/ui_cancel нет кнопок геймпада: A = подтвердить, B = назад
		var evx := InputEventJoypadButton.new(); evx.button_index = pr[1]; InputMap.action_add_event(pr[0], evx)

func _make_shaders() -> void:
	hull_shader = Shader.new()
	hull_shader.code = """shader_type spatial;
uniform sampler2D alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rgh : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D mtl : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 offset = vec3(0.0);
uniform sampler2D decal : source_color, filter_linear_mipmap;
uniform vec3 dec_o = vec3(0.0);
uniform float W = 1.2;
uniform float two_sided = 0.0;                                     // 1 = наклейка и на левом борту (ливреи ботов); у «Третьего шанса» только на правом
uniform float hex_k = 0.35;        // контрастность шестигранников (1 = как было)
uniform float rear_y = -30.0;
uniform float rear_x = 9.5;
uniform float wbot = 0.0;                                           // 1 = нижние крылья: исходные косые полоски убираются, вместо них полоски параллельно задней кромке
uniform float wb_y = -33.3;                                         // где идут полоски (координата Blender y = −z корабля)
uniform float wb_x0 = 11.4;
uniform float wb_x1 = 18.4;                                         // от корпуса до этой |x|
uniform vec4 dents[8];                                             // вмятины от ударов: xyz — центр в координатах po, w — радиус
uniform float dent_n = 0.0;
float h3(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vn(vec3 p){ vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y), mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z); }
varying vec3 po; varying vec3 no;
void vertex(){
  po = VERTEX + offset; no = NORMAL;
  float dep = 0.0;
  for (int i = 0; i < 8; i++){ if (float(i) >= dent_n) break; vec4 dd = dents[i]; float k = 1.0 - smoothstep(0.0, dd.w, distance(po, dd.xyz)); dep = max(dep, k * dd.w * (0.16 + 0.14 * vn(po * 2.3))); }
  VERTEX -= NORMAL * dep;
}
float hexedge(vec2 ab){
  float H = W * 0.8660254;
  float j0 = floor(ab.y / H);
  float d1 = 1e9; float d2 = 1e9;
  for (int dj = 0; dj < 2; dj++){
    float j = j0 + float(dj);
    float off = (mod(j, 2.0) > 0.5) ? W * 0.5 : 0.0;
    float i0 = floor((ab.x - off) / W);
    for (int di = 0; di < 2; di++){
      vec2 c = vec2((i0 + float(di)) * W + off, j * H);
      float d = distance(ab, c);
      if (d < d1){ d2 = d1; d1 = d; } else if (d < d2){ d2 = d; }
    }
  }
  return d2 - d1;
}
void fragment(){
  vec3 p = vec3(po.x, -po.z, po.y);      // координаты Blender
  vec3 n = vec3(no.x, -no.z, no.y); vec3 an = abs(n);
  vec2 ab = (an.x >= an.y && an.x >= an.z) ? p.yz : ((an.y >= an.z) ? p.xz : p.xy);
  float e = hexedge(ab);
  float line = 1.0 - smoothstep(0.0, 0.07, e);
  float rear = (1.0 - smoothstep(rear_y - 3.0, rear_y, p.y)) * (1.0 - smoothstep(rear_x - 1.0, rear_x, abs(p.x)));   // задняя часть корпуса (к ней крепятся моторы): шестигранников нет
  line *= (1.0 - rear) * hex_k;
  vec3 base = texture(alb, UV).rgb;
  if (wbot > 0.5) {
    float lum = dot(base, vec3(0.3333));
    float old = 1.0 - smoothstep(0.30, 0.52, lum);                          // тёмные полоски исходной текстуры
    base = mix(base, vec3(0.86, 0.85, 0.83), old);                          // убираем их
    float ax = abs(p.x);
    float inner = smoothstep(wb_x0 - 0.3, wb_x0, ax) * (1.0 - smoothstep(wb_x1, wb_x1 + 0.3, ax));
    // полосы берём прямо из текстуры: чистый горизонтальный блок полос верхних крыльев в атласе (строки 3042..3137, 32 текселя на единицу модели), поэтому рваность и сколы те же
    float tx = 300.0 + (ax - 11.4) * 32.0;
    float ty = 3089.5 + (p.y - wb_y) * 32.0;
    vec3 stamp = texture(alb, vec2(tx, ty) / 4096.0).rgb;
    float within = 1.0 - smoothstep(1.55, 1.7, abs(p.y - wb_y));
    float st = (1.0 - smoothstep(0.30, 0.55, dot(stamp, vec3(0.3333)))) * inner * within;
    base = mix(base, stamp, st);
  }
  vec3 ob = vec3(po.x - dec_o.x, -(po.z - dec_o.z), po.y - dec_o.y);   // координаты Blender относительно начала корпуса
  float sd = n.x >= 0.0 ? 1.0 : -1.0;                                   // с левого борта наклейка зеркальная: читается слева направо
  float c0 = sd > 0.0 ? 0.8 : -3.8; float k0 = sd > 0.0 ? 1.0 : 0.78;          // слева наклейка меньше и сдвинута к корме: там круглый люк
  vec2 dv = vec2(sd * (ob.y - c0), ob.z - 0.9);
  float ca = cos(0.262); float sa = sin(0.262) * sd;
  vec2 rr = vec2(dv.x * ca + dv.y * sa, -dv.x * sa + dv.y * ca);
  vec2 uvd = rr / (vec2(12.5, 9.7) * k0) + 0.5;
  float inside = step(0.0, uvd.x) * step(uvd.x, 1.0) * step(0.0, uvd.y) * step(uvd.y, 1.0);
  vec4 dc = texture(decal, vec2(uvd.x, 1.0 - uvd.y));
  float da = dc.a * inside * step(0.85, mix(n.x, abs(n.x), two_sided));   // правый борт (нормаль +X); при two_sided и левый
  base = mix(base, dc.rgb, da);
  ALBEDO = base * (1.0 - 0.55 * line);
  ROUGHNESS = clamp(texture(rgh, UV).r + 0.15 * line, 0.0, 1.0);
  METALLIC = texture(mtl, UV).r;
  float dm = 0.0;
  for (int i = 0; i < 8; i++){ if (float(i) >= dent_n) break; vec4 dd = dents[i]; float dr = dd.w; float dj = vn(po * 1.3 + float(i)) * 0.6 + vn(po * 3.7) * 0.4; dm = max(dm, 1.0 - smoothstep(dr * 0.35, dr * (0.75 + 0.55 * dj), distance(po, dd.xyz))); }
  if (dm > 0.0){
    float rim = smoothstep(0.02, 0.2, dm) * (1.0 - smoothstep(0.2, 0.55, dm));          // кромка вмятины: ржавая полоса
    vec3 dark = ALBEDO * vec3(0.22, 0.2, 0.19);
    ALBEDO = mix(ALBEDO, dark, smoothstep(0.1, 0.5, dm) * 0.92);
    ALBEDO = mix(ALBEDO, vec3(0.38, 0.17, 0.07), rim * 0.6);
    ROUGHNESS = mix(ROUGHNESS, 0.92, dm); METALLIC = mix(METALLIC, 0.15, dm * 0.7);
    NORMAL = normalize(NORMAL + dm * (vec3(vn(po * 2.2), vn(po * 2.2 + 5.0), vn(po * 2.2 + 11.0)) - 0.5) * 2.6);
  }
}"""
	hull_bite_shader = Shader.new()                                           # корпус с «откусом»: дырявим по зашумлённой сфере, изнутри видна тёмная ржавчина
	var bc: String = hull_shader.code
	bc = bc.replace("shader_type spatial;", "shader_type spatial; render_mode cull_disabled;")
	bc = bc.replace("uniform float W = 1.2;", "uniform float W = 1.2; uniform float bite_on = 0.0; uniform vec3 bite_c = vec3(0.0); uniform float bite_r = 4.0;")
	bc = bc.replace("void fragment(){", "void fragment(){\n  if (bite_on > 0.5) { float rr0 = length(po - bite_c); float jag = vn(po * 0.9) * 0.7 + vn(po * 2.9) * 0.3; if (rr0 < bite_r * (0.5 + 0.95 * jag)) discard; }")
	bc = bc.replace("METALLIC = texture(mtl, UV).r;", "METALLIC = texture(mtl, UV).r;\n  if (!FRONT_FACING) { ALBEDO = vec3(0.17, 0.09, 0.05); ROUGHNESS = 0.95; METALLIC = 0.0; }")
	hull_bite_shader.code = bc
	flame_shader = Shader.new()
	flame_shader.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform float power = 0.0;
uniform vec3 col_core = vec3(0.85, 0.95, 1.0);
uniform vec3 col_edge = vec3(0.1, 0.35, 1.0);
uniform float fast = 0.0;                 // 1 = быстрая тонкая струя (маневровые)
varying float t;
void vertex(){ t = VERTEX.y + 0.5; }
void fragment(){
  float sp = 1.0 + fast * 2.2;
  float f = 0.8 + 0.2 * sin(TIME * 55.0 * sp + t * 20.0 * (1.0 + fast * 3.0)) * sin(TIME * 31.0 * sp);
  f = mix(f, 0.55 + 0.45 * sin(TIME * 170.0 - t * 70.0), fast * 0.6);
  float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.2);
  vec3 c = mix(col_edge, col_core, (1.0 - t) * edge);
  ALBEDO = c * (1.5 + power * 3.0);
  ALPHA = clamp(pow(1.0 - t, 1.4) * edge * f * clamp(power * 2.5, 0.0, 1.0), 0.0, 1.0);
}"""
	glow_shader = Shader.new()
	glow_shader.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform float power = 0.0;
void fragment(){
  // плоский мерцающий диск у среза мотора, как было раньше, но чуть прозрачнее прежнего: поверх него светятся лопасти (blade_shader)
  float f = 0.6 + 0.34 * sin(TIME * 40.0) + 0.26 * sin(TIME * 23.7 + 1.3) + 0.2 * sin(TIME * 67.0 + 0.4);       // сильное неровное мерцание: три несоизмеримые частоты, яркость гуляет от почти нуля до ~1,4
  f = max(f, 0.05);
  f *= f * 0.6 + 0.7;                                                                                   // провалы глубже, пики резче
  vec3 col = mix(vec3(0.02, 0.2, 1.0), vec3(0.35, 0.65, 1.0), clamp(power * 1.4, 0.0, 1.0));   // в покое мерцает синим, с тягой светлеет к голубому
  ALBEDO = col * (0.4 + power * 2.5) * f;
  ALPHA = clamp(0.1 + power * 0.6, 0.0, 1.0);
}"""
	blade_shader = Shader.new()
	blade_shader.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform float power = 0.0;
instance uniform vec3 ctr = vec3(0.0);
instance uniform vec3 axis = vec3(0.0, 0.0, 1.0);
instance uniform float rad_g = 0.0;
instance uniform float t_lo = 0.0;
instance uniform float t_hi = 1.0;
varying vec3 lp;
varying vec3 ln;
void vertex(){ lp = VERTEX; ln = NORMAL; }
void fragment(){
  // свет ядра на стенках и дне лопастей, как настоящее освещение: сильнее у ядра, по мере удаления слабеет и холоднеет, грани, повёрнутые от ядра, остаются тёмными
  if (rad_g < 0.0001) discard;
  vec3 a = normalize(axis);
  vec3 d = lp - ctr;
  float t = dot(d, a);
  float r = length(d - a * t) / rad_g;
  vec3 src = ctr + a * (t_lo * 0.35);                                                // условный источник света в ядре
  vec3 toL = src - lp;
  float dist = length(toL) / rad_g;
  float lam = clamp(dot(normalize(ln), normalize(toL)), 0.0, 1.0);
  float ring = smoothstep(0.5, 0.7, r) * (1.0 - smoothstep(1.3, 1.45, r));        // кольцо лопастей вокруг ядра, наружные стенки корпуса сюда не попадают
  float atten = 1.0 / (1.0 + 3.0 * dist * dist);
  float fade = 1.0 - smoothstep(0.6, 1.5, dist);                                     // у внешнего конца свет сходит на нет
  vec3 rdir = normalize(d - a * t + vec3(0.0001));
  float outw = 1.0 - smoothstep(0.15, 0.55, dot(normalize(ln), rdir));               // наружные стенки корпуса мотора не светим
  float k = pow(lam, 0.7) * atten * fade * ring * 3.0;
  float amb = atten * fade * ring * outw * 1.7;                                      // грани в тени ядра (прожилки между лопастями) тоже светятся, но глубоким холодным синим
  vec3 c = mix(vec3(0.60, 0.95, 1.0), vec3(0.0, 0.20, 0.95), smoothstep(0.1, 1.1, dist));   // у ядра горячий голубой, дальше холодный синий
  float flick = 0.85 + 0.07 * sin(TIME * (2.0 + power * 20.0)) + 0.08 * sin(TIME * 41.0 + 0.7) + 0.05 * sin(TIME * 23.7 + 1.3);      // свет на лопастях заметно дрожит вместе с диском
  ALBEDO = (c * k + vec3(0.0, 0.14, 0.95) * amb) * (1.8 + power * 3.5) * flick;
  ALPHA = 1.0;
}"""
	core_shader = Shader.new()
	core_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float power = 0.0;
instance uniform vec3 ctr = vec3(0.0);
instance uniform vec3 axis = vec3(0.0, 0.0, 1.0);
instance uniform float rad = 0.0;
varying vec3 lp;
void vertex(){ lp = VERTEX; }
float h31(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x){
  vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float ember(vec3 p, float rate){                                                    // «тлеющий уголёк»: два случайных поля плавно перетекают друг в друга на месте, без бегущих волн
  float ti = TIME * rate; float a = floor(ti); float b = smoothstep(0.0, 1.0, fract(ti));
  return mix(vnoise(p + a * vec3(7.1, 3.3, 5.7)), vnoise(p + (a + 1.0) * vec3(7.1, 3.3, 5.7)), b);
}
void fragment(){
  // гладкий яркий голубой диск (как дефлектор на кадрах из кино): плоский рисунок вокруг оси мотора, а не объёмный шар; лучи рисуют лопасти, а не само ядро;
  // яркость выше 1, поэтому свечение (glow) даёт ореол вокруг диска; рисунок неподвижный, только общее лёгкое «дыхание»
  float nv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
  float r = clamp(acos(nv) / 1.5708, 0.0, 1.0);                     // запасной вариант без геометрии: радиус по углу к взгляду
  float ang = 0.0;
  if (rad > 0.0001) {
    vec3 a = normalize(axis);
    vec3 d = lp - ctr;
    vec3 pr = d - a * dot(d, a);
    r = clamp(length(pr) / rad, 0.0, 1.0);
    vec3 t1 = normalize(abs(a.y) < 0.9 ? cross(a, vec3(0.0, 1.0, 0.0)) : cross(a, vec3(1.0, 0.0, 0.0)));
    vec3 t2 = cross(a, t1);
    ang = atan(dot(pr, t2), dot(pr, t1));
  }
  float flick = 0.95 + 0.05 * sin(TIME * (2.0 + power * 20.0));
  vec3 deep = vec3(0.30, 0.03, 0.85); vec3 mid = vec3(0.09, 0.18, 1.0); vec3 hot = vec3(0.40, 0.70, 1.0);        // край индиго (синий с заметной фиолетовой примесью)
  float s1 = smoothstep(0.1, 0.65, r);                               // центр горячий голубой -> середина яркий голубой
  float s2 = smoothstep(0.55, 1.0, r);                              // к краю глубокий синий (цвет остаётся насыщенным, потому что и яркость к краю падает)
  vec3 c = mix(hot, mid, s1);
  c = mix(c, deep, s2);
  vec3 q = (lp - ctr) / max(rad, 0.001) * 2.2;
  float e = ember(q, 0.5) * 0.6 + ember(q * 2.4 + 11.0, 0.9) * 0.4;                 // пятна жара: медленные, на месте, угасают и разгораются
  float zone = 1.0 - smoothstep(0.3, 0.62, r);                                      // тление только в самой центральной области ядра, дальше прежний градиент без изменений
  float m = mix(1.0, 0.72 + 0.56 * smoothstep(0.2, 0.8, e), zone);
  c = mix(c, vec3(0.45, 0.78, 1.0), clamp((m - 1.0) * 0.9, 0.0, 0.3));              // в разгоревшихся пятнах чуть светлее и горячее
  ALBEDO = c * (1.3 + power * 1.5) * (1.0 - 0.4 * s2) * flick * m;
}"""

func _build_world() -> void:
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.78, 0.58, 0.36); sky.sky_horizon_color = Color(0.95, 0.75, 0.48)
	sky.ground_horizon_color = Color(0.9, 0.68, 0.42); sky.ground_bottom_color = Color(0.5, 0.33, 0.2)
	var s := Sky.new(); s.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.9
	env.fog_enabled = true; env.fog_light_color = Color(0.85, 0.68, 0.5); env.fog_density = 0.00012
	env.glow_enabled = true; env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if "nofog" in OS.get_cmdline_user_args(): env.fog_enabled = false
	var we := WorldEnvironment.new(); we.environment = env; add_child(we); world_env = env
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 35, 0); sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.3; sun.shadow_enabled = true; sun.directional_shadow_max_distance = 600.0; add_child(sun)
	var sh := Shader.new()
	sh.code = """shader_type spatial; render_mode cull_disabled;
varying vec3 wp; varying vec3 wn;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz); }
vec3 pal(float i){
  float a = 0.5 + 0.5 * sin(i * 2.3); float b = 0.5 + 0.5 * sin(i * 5.1 + 1.0);
  vec3 c = mix(vec3(0.56, 0.24, 0.12), vec3(0.84, 0.58, 0.34), a);
  return mix(c, vec3(0.88, 0.76, 0.56), b * 0.45);
}
void fragment(){
  float b = wp.y * 0.012 + 0.5 * sin(wp.x * 0.002 + wp.z * 0.0017);
  float k = floor(b); float f = fract(b);
  float edge = smoothstep(0.0, 0.1, f) * (1.0 - smoothstep(0.9, 1.0, f));
  vec3 c = pal(k) * (0.82 + 0.18 * edge);
  float flat_ = smoothstep(0.55, 0.95, clamp(wn.y, 0.0, 1.0));
  vec3 sand = vec3(0.66, 0.5, 0.36);
  c = mix(c, sand * (0.9 + 0.1 * sin(wp.x * 0.05) * sin(wp.z * 0.05)), flat_ * 0.75);
  c *= mix(0.7, 1.0, clamp(wn.y, 0.0, 1.0));
  ALBEDO = c; ROUGHNESS = 0.95; }"""
	terr_mat = ShaderMaterial.new(); terr_mat.shader = sh
	# бесконечное плато вокруг каньона (следует за кораблём)

func _gen_tile(key: Vector3i) -> void:
	# считается в потоке: вершины/нормали/индексы плитки рельефа 1000x1000 м (lod 0: шаг ~31 м, lod 1: ~62 м, lod 2: 250 м)
	var n := 32 if key.z == 0 else (16 if key.z == 1 else 4)
	var step := TILE / n
	var w := n + 3
	var hgt := PackedFloat32Array(); hgt.resize(w * w)
	var x0 := key.x * TILE; var z0 := key.y * TILE
	for j in w:
		for i in w: hgt[j * w + i] = height(x0 + (i - 1) * step, z0 + (j - 1) * step)
	var verts := PackedVector3Array(); verts.resize((n + 1) * (n + 1))
	var norms := PackedVector3Array(); norms.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var gi := (j + 1) * w + (i + 1)
			var dhx := (hgt[gi + 1] - hgt[gi - 1]) / (2.0 * step)
			var dhz := (hgt[gi + w] - hgt[gi - w]) / (2.0 * step)
			verts[j * (n + 1) + i] = Vector3(x0 + i * step, hgt[gi], z0 + j * step)
			norms[j * (n + 1) + i] = Vector3(-dhx, 1.0, -dhz).normalized()
	var idx := PackedInt32Array(); idx.resize(n * n * 6)
	var k := 0
	for j in n:
		for i in n:
			var a := j * (n + 1) + i; var b := a + 1; var c := a + (n + 1); var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c; idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c; k += 6
	chunk_mutex.lock(); chunk_data[key] = [verts, norms, idx]; chunk_mutex.unlock()

var tile_buckets := {}
func _build_buckets() -> void:
	for k in track_tiles.keys():
		var bk := Vector2i(k.x >> 3, k.y >> 3)
		if not tile_buckets.has(bk): tile_buckets[bk] = []
		(tile_buckets[bk] as Array).append(k)

func _ahead_points(sp: Vector2) -> Array:                                   # точки по трассе впереди корабля (1, 2 и 3.5 с полёта): там плитки нужны раньше, чем корабль долетит
	var pts: Array = []
	var spd := ship.linear_velocity.length()
	var q := _tq3(sp.x, sp.y)
	if q.x < 1e8 and spd > 30.0 and q.z >= float(SPUR_BASE) - 0.5:             # в тупике плитки грузятся вдоль самого тупика
		var qr := _tq3_raw(sp.x, sp.y); var spr: Dictionary = spurs[int(qr.z) - SPUR_BASE]; var spp: PackedVector2Array = spr["pts"]; var spc: PackedFloat32Array = spr["cum"]
		var k0 := clampi(int(qr.y / 500.0), 0, spp.size() - 2)
		var tg2 := (spp[k0 + 1] - spp[k0]).normalized()
		var fw2 := Vector2(-ship.global_transform.basis.z.x, -ship.global_transform.basis.z.z)
		var sg2 := 1.0 if tg2.dot(fw2) >= 0.0 else -1.0
		for tt in AHEAD_T:
			var dk := clampf(qr.y + sg2 * maxf(spd, 250.0) * tt, 0.0, float(spr["len"]))
			var kk := clampi(int(dk / 500.0), 0, spp.size() - 2)
			pts.append(spp[kk].lerp(spp[kk + 1], clampf((dk - spc[kk]) / 500.0, 0.0, 1.0)))
	elif q.x < 1e8 and spd > 30.0:
		var path := int(q.z); var sc := 1.0
		if path >= 1 and path <= branches.size(): sc = float(branches[path - 1]["sc"])
		var fw := Vector2(-ship.global_transform.basis.z.x, -ship.global_transform.basis.z.z)
		var tg: Vector2 = (_track_at_p(q.y, path) as Array)[1]
		var sg := 1.0 if tg.dot(fw) >= 0.0 else -1.0
		for tt in AHEAD_T: pts.append((_track_at_p(q.y + sg * maxf(spd, 250.0) * tt / sc, path) as Array)[0])
	return pts

func _desired_lod(c: Vector2, sp: Vector2, ahead: Array) -> int:
	var d := c.distance_to(sp)
	if d < LOD0_R: return 0
	var da := 1e12; var daf := 1e12
	for i in ahead.size():
		var dp := c.distance_to(ahead[i] as Vector2)
		if i < 3: da = minf(da, dp)
		daf = minf(daf, dp)
	if da < LOD0_AHEAD: return 0
	if minf(d, da) < LOD1_R: return 1
	return 2 if (d < LOD2_R or daf < LOD2_FAR) else -1

var stream_f: FileAccess
var stream_max_us := 0
var stream_built := 0
var stream_t := 0
func _slog(msg: String) -> void:                                           # лог подгрузки рельефа: user://stream.log
	if stream_f == null: stream_f = FileAccess.open("user://soak_stream.log" if soak else "user://stream.log", FileAccess.WRITE)
	if stream_f != null: stream_f.store_line("%.1f %s" % [Time.get_ticks_msec() / 1000.0, msg]); stream_f.flush()

func _stream_stats(ahead: Array, sp: Vector2) -> void:
	var n := [0, 0, 0]
	for k in chunks.keys(): n[k.z] += 1
	var tk := Vector2i(int(floor(sp.x / TILE)), int(floor(sp.y / TILE)))
	var have := ""
	for l in 3: if chunks.has(Vector3i(tk.x, tk.y, l)): have += str(l)
	var ah := ""
	for p in ahead:
		var ak := Vector2i(int(floor((p as Vector2).x / TILE)), int(floor((p as Vector2).y / TILE)))
		var hh := ""
		for l in 3: if chunks.has(Vector3i(ak.x, ak.y, l)): hh += str(l)
		ah += (hh if hh != "" else "-") + " "
	chunk_mutex.lock(); var rd := chunk_data.size(); chunk_mutex.unlock()
	_slog("STREAM v=%d lod0=%d lod1=%d lod2=%d jobs=%d ready=%d built=%d upd_max=%.1fms ship_tile=%s ahead=[%s] state=%s" % [int(ship.linear_velocity.length()), n[0], n[1], n[2], chunk_jobs.size(), rd, stream_built, stream_max_us / 1000.0, have if have != "" else "НЕТ", ah.strip_edges(), ui.state if ui != null else ""])
	if not have.contains("0") and ship.linear_velocity.length() > 100.0: _slog("GAP ship над плиткой без подробного уровня: есть=" + have)
	stream_max_us = 0; stream_built = 0

func _update_chunks(max_build: int = 2) -> void:
	var t_us := Time.get_ticks_usec()
	if tile_buckets.is_empty(): _build_buckets()
	var sp := Vector2(ship.global_position.x, ship.global_position.z)
	var ahead := _ahead_points(sp)
	var want := {}; var lod_of := {}
	var score_of := {}; var missing := []
	var spd := maxf(ship.linear_velocity.length(), 300.0)
	var centers: Array = [[sp, int(LOD2_R / TILE) + 2]]
	for ai in ahead.size(): centers.append([ahead[ai], int((LOD1_R if ai < 3 else LOD2_FAR) / TILE) + 2])
	for cr in centers:
		var cp: Vector2 = cr[0]; var rt: int = cr[1]
		var bx0 := (int(floor(cp.x / TILE)) - rt) >> 3; var bx1 := (int(floor(cp.x / TILE)) + rt) >> 3
		var bz0 := (int(floor(cp.y / TILE)) - rt) >> 3; var bz1 := (int(floor(cp.y / TILE)) + rt) >> 3
		for bx in range(bx0, bx1 + 1):
			for bz in range(bz0, bz1 + 1):
				if not tile_buckets.has(Vector2i(bx, bz)): continue
				for tk in (tile_buckets[Vector2i(bx, bz)] as Array):
					if lod_of.has(tk): continue
					var lod := _desired_lod(Vector2((tk.x + 0.5) * TILE, (tk.y + 0.5) * TILE), sp, ahead)
					lod_of[tk] = lod
					if lod < 0: continue
					var key := Vector3i(tk.x, tk.y, lod)
					want[key] = true
					var cc := Vector2((tk.x + 0.5) * TILE, (tk.y + 0.5) * TILE)
					var urg: float = cc.distance_to(sp) / spd                         # срочность: за сколько секунд до плитки долетим
					for ai in ahead.size(): urg = minf(urg, float(AHEAD_T[ai]) + cc.distance_to(ahead[ai] as Vector2) / spd)
					var scr: float = urg + float([0.0, 0.7, 4.0][lod])
					score_of[key] = scr
					if not chunks.has(key) and not chunk_jobs.has(key): missing.append([scr, key])
	missing.sort_custom(func(a, b): return a[0] < b[0])
	var n2 := 0                                                                 # дальние грубые плитки идут отдельной очередью: иначе подробные забивают её и горизонт не грузится
	for jk in chunk_jobs.keys(): if jk.z == 2: n2 += 1
	var n1 := chunk_jobs.size() - n2
	for mk in missing:                                                          # в работу берём только самые срочные, иначе очередь забита ненужным
		if mk[1].z == 2:
			if n2 >= 24 and job_cap < 1000: continue
			n2 += 1
		else:
			if n1 >= job_cap: continue
			n1 += 1
		chunk_jobs[mk[1]] = WorkerThreadPool.add_task(_gen_tile.bind(mk[1]))
	want_c = want; score_c = score_of
	_build_ready(max_build, -1 if max_build >= 1000 else 3500)
	for key in chunks.keys():
		if want.has(key): continue
		var dl: int = int(lod_of.get(Vector2i(key.x, key.y), -1))
		if dl < 0 or chunks.has(Vector3i(key.x, key.y, dl)):               # плитка не нужна или уже заменена нужным уровнем
			chunks[key][0].queue_free()
			if chunks[key][1] != null: chunks[key][1].queue_free()
			chunks.erase(key)
	stream_max_us = maxi(stream_max_us, Time.get_ticks_usec() - t_us)
	if Time.get_ticks_msec() - stream_t > 1000: stream_t = Time.get_ticks_msec(); _stream_stats(ahead, sp)

var job_cap := 48
var want_c := {}
var score_c := {}
func _build_ready(max_build: int, budget_us: int) -> void:
	var t_us := Time.get_ticks_usec()
	chunk_mutex.lock()
	var ready := chunk_data.keys()
	chunk_mutex.unlock()
	ready.sort_custom(func(a, b): return float(score_c.get(a, 1e9)) < float(score_c.get(b, 1e9)))
	var r2 := ready.filter(func(k): return k.z == 2)                           # грубые без коллизии строятся дёшево: у них свой бюджет
	var r1 := ready.filter(func(k): return k.z != 2)
	var built := 0
	for pass_i in 2:
		var lst: Array = r2 if pass_i == 0 else r1
		var bud := 1500 if (pass_i == 0 and budget_us > 0) else budget_us
		var mxb := 12 if (pass_i == 0 and budget_us > 0) else max_build
		built = 0; t_us = Time.get_ticks_usec()
		_build_list(lst, mxb, bud, t_us)
	stream_max_us = maxi(stream_max_us, Time.get_ticks_usec() - t_us)

func _build_list(ready: Array, max_build: int, budget_us: int, t_us: int) -> void:
	var built := 0
	for key in ready:
		if built >= max_build: break
		if budget_us > 0 and built > 0 and Time.get_ticks_usec() - t_us > budget_us: break
		var want := want_c
		chunk_mutex.lock(); var arr = chunk_data[key]; chunk_data.erase(key); chunk_mutex.unlock()
		if chunk_jobs.has(key):
			WorkerThreadPool.wait_for_task_completion(chunk_jobs[key]); chunk_jobs.erase(key)
		if not want.has(key): continue                                      # пока считалась, плитка стала не нужна
		var am := ArrayMesh.new(); var ar := []; ar.resize(Mesh.ARRAY_MAX)
		ar[Mesh.ARRAY_VERTEX] = arr[0]; ar[Mesh.ARRAY_NORMAL] = arr[1]; ar[Mesh.ARRAY_INDEX] = arr[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
		var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = terr_mat; add_child(mi)
		var body: StaticBody3D = null
		if key.z <= 1:                                                      # подробные плитки и грубые (шаг 50 м) имеют коллизию; грубая — страховка, пока подробная не готова
			body = StaticBody3D.new(); var cs := CollisionShape3D.new(); var tri := am.create_trimesh_shape(); tri.backface_collision = true
			cs.shape = tri; body.add_child(cs); add_child(body)
		chunks[key] = [mi, body]; built += 1; stream_built += 1
		if key.z == 0: detail_swap_t = 1.2                                   # появилась подробная коллизия: на секунду включаем выталкивание из рельефа

var detail_swap_t := 0.0
var chunk_tick := 0                      # свой счётчик кадров отрисовки: frame стоит, когда время остановлено (меню, пауза)
var hull_aabb := AABB(Vector3(-24, -6, -28), Vector3(48, 12, 56))
func _depenetrate(dt: float) -> void:                                      # корабль оказался внутри рельефа (подробная плитка появилась поверх грубой): выталкиваем по нормали наружу
	if detail_swap_t <= 0.0: return
	detail_swap_t -= dt
	var t := ship.global_transform
	var worst := 0.0; var wn := Vector3.UP
	var c := hull_aabb.get_center(); var h := hull_aabb.size * 0.5 * 0.6
	for sx in [-1.0, 0.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 0.0, 1.0]:
				var pw: Vector3 = t * (c + Vector3(sx * h.x, sy * h.y, sz * h.z))
				var gh := height(pw.x, pw.z)
				var dv := gh - pw.y
				if dv <= 0.0: continue
				var dhx := (height(pw.x + 6.0, pw.z) - height(pw.x - 6.0, pw.z)) / 12.0
				var dhz := (height(pw.x, pw.z + 6.0) - height(pw.x, pw.z - 6.0)) / 12.0
				var nrm := Vector3(-dhx, 1.0, -dhz).normalized()
				var dn := dv * nrm.y
				if dn > worst: worst = dn; wn = nrm
	if worst > 3.0:
		soak_depen += 1
		ship.global_position += wn * (worst + 2.0)
		var vn := ship.linear_velocity.dot(wn)
		if vn < 0.0: ship.linear_velocity -= wn * vn
		_log_event("DEPEN %.1f" % worst)

func _exit_tree() -> void:
	for k in chunk_jobs.keys(): WorkerThreadPool.wait_for_task_completion(chunk_jobs[k])
	chunk_jobs.clear()

func _preload_chunks() -> void:
	var t0 := Time.get_ticks_msec()
	job_cap = 1000000
	var ids := []
	for tx in range(-2, 2):
		for tz in range(-2, 2):
			if track_tiles.has(Vector2i(tx, tz)):
				var key := Vector3i(tx, tz, 0)
				chunk_jobs[key] = WorkerThreadPool.add_task(_gen_tile.bind(key))
	for key in chunk_jobs.keys(): WorkerThreadPool.wait_for_task_completion(chunk_jobs[key])
	chunk_jobs.clear()
	_update_chunks(0)
	for key in chunk_jobs.keys(): WorkerThreadPool.wait_for_task_completion(chunk_jobs[key])
	chunk_jobs.clear()
	_update_chunks(100000)
	job_cap = 48
	print("preload ms=", Time.get_ticks_msec() - t0, " tiles=", chunks.size())

func _preload_evo() -> void:
	# обучение: рельеф вдоль всей трассы грубой сеткой (lod 1, шаг ~62 м) и только коллизия, без картинки
	var t0 := Time.get_ticks_msec()
	for k in track_tiles.keys(): chunk_jobs[Vector3i(k.x, k.y, 1)] = WorkerThreadPool.add_task(_gen_tile.bind(Vector3i(k.x, k.y, 1)))
	for key in chunk_jobs.keys(): WorkerThreadPool.wait_for_task_completion(chunk_jobs[key])
	chunk_jobs.clear()
	chunk_mutex.lock(); var keys := chunk_data.keys(); chunk_mutex.unlock()
	for key in keys:
		var arr = chunk_data[key]
		var am := ArrayMesh.new(); var ar := []; ar.resize(Mesh.ARRAY_MAX)
		ar[Mesh.ARRAY_VERTEX] = arr[0]; ar[Mesh.ARRAY_NORMAL] = arr[1]; ar[Mesh.ARRAY_INDEX] = arr[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
		var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var tri := am.create_trimesh_shape(); tri.backface_collision = true
		cs.shape = tri; body.add_child(cs); add_child(body)
	chunk_data.clear()
	print("evo terrain ms=", Time.get_ticks_msec() - t0, " tiles=", keys.size())

func _spawn_bots() -> void:                                                  # корутина: между кораблями обновляется экран загрузки
	var n_all := N_BOTS + (0 if evo_mode else 1)                          # стартовая сетка: ровные шеренги по высоте (книга: шесть рядов от края до края каньона), места по жеребьёвке, в том числе у игрока
	var cols := ceili(float(n_all) / float(GRID_ROWS))
	var slots := []
	for r in GRID_ROWS:
		for c in cols: slots.append(Vector2i(c, r))
	slots = slots.slice(0, n_all)                                      # ряды заполняются подряд: свободное место только в конце последнего ряда
	slots.shuffle()                                                    # жеребьёвка: кто на каком месте
	var off := 0
	if not evo_mode: player_start = _grid_pos(slots[0], cols); off = 1
	var hull_inst := ship_scene.instantiate()
	var lod := hull_inst.get_node("SM_Hull_Body_LOD1") as MeshInstance3D
	bot_hull_shape = lod.mesh.create_convex_shape(true, true)
	hull_aabb = lod.mesh.get_aabb()
	hull_aabb = AABB(hull_aabb.position * ship_sc, hull_aabb.size * ship_sc)
	hull_inst.queue_free()
	bot_tex = {"alb": load("res://ship/tex/hull_albedo_4096.png"), "rgh": load("res://ship/tex/hull_roughness_4096.png"), "mtl": load("res://ship/tex/hull_metallic_4096.png"), "dec": load("res://ship/tex/decal_third_chance.png")}
	var glow := ShaderMaterial.new(); glow.shader = glow_shader; glow.set_shader_parameter("power", 0.6)
	var core := ShaderMaterial.new(); core.shader = core_shader; core.set_shader_parameter("power", 0.6)
	var blade := ShaderMaterial.new(); blade.shader = blade_shader; blade.set_shader_parameter("power", 0.6)
	for i in N_BOTS:
		var slot: Vector2i = slots[i + off]
		var rb := RigidBody3D.new(); rb.name = "Bot%d" % i; rb.mass = MASS; rb.gravity_scale = 1.0
		rb.collision_layer = 8; rb.collision_mask = 1 | 8
		rb.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; rb.linear_damp = 0.01
		rb.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; rb.angular_damp = 0.0
		rb.continuous_cd = true; rb.can_sleep = false; rb.freeze = true
		rb.contact_monitor = true; rb.max_contacts_reported = 4
		var btex := bot_tex.duplicate()                                     # своя ливрея: краска, полосы, номер, имя и эмблема (tools/make_liveries.py)
		var swapped: bool = int(SHIP_LIVERY.get(ship_id, -1)) == i                    # игрок выбрал корабль этого бота: на его месте летит «Третий шанс», чтобы не было двойников
		if not evo_mode and not swapped and ResourceLoader.exists("res://ship/tex/livery_%d_albedo.png" % i):
			btex["alb"] = load("res://ship/tex/livery_%d_albedo.png" % i); btex["dec"] = load("res://ship/tex/livery_%d_decal.png" % i); btex["two_sided"] = true
		await _lt(0.30 + 0.62 * float(i) / float(N_BOTS), "Соперники: %d из %d" % [i + 1, N_BOTS])
		var vspec: Dictionary = BOT_VARIANTS.get(i, {}) if not (evo_mode or swapped or "novariants" in OS.get_cmdline_user_args()) else {}
		var vres := _fill_variant(rb, "ship0" if swapped else "bot%d" % i, vspec)
		for n in rb.get_children():
			if n is not MeshInstance3D: continue
			var nm := String(n.name)
			var is_int := nm.begins_with("SM_Cabin") or nm.begins_with("SM_Cargo") or nm.begins_with("SM_Corridor") or nm.begins_with("SM_Room")
			if (is_int and evo_mode) or nm.begins_with("SM_HexPlate") or nm.begins_with("SM_Hull_Body_LOD1"):                 # интерьер у ботов виден в катсцене и при обгонах; в обучении (без картинки) убираем
				n.queue_free(); continue
			var mi := n as MeshInstance3D
			for ch in _mesh_children(n): ch.queue_free()
			_fix_materials(mi, btex)
			for k in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(k)
				if m == null: continue
				if m.resource_name == "MAT_Engine_Glow": mi.set_surface_override_material(k, glow)
				elif m.resource_name == "MAT_Engine_Core": mi.set_surface_override_material(k, core); _core_instance_params(mi, k); mi.material_overlay = blade
			if nm.begins_with("SM_Glass"): mi.material_override = _glass_mat()
		var bparts := {}; var beng := {}; var btot := {"main": 0, "lift": 0, "shunt": 0}
		for n in rb.get_children():
			if n is not MeshInstance3D or n.is_queued_for_deletion(): continue
			var nm2 := String(n.name)
			var det2 := false
			for p in DETACH_PREFIX:
				if nm2.begins_with(p): det2 = true
			if not det2: continue
			bparts[nm2] = n
			if nm2.begins_with("SM_Engine_"):
				var kd := "shunt"
				if nm2.contains("Traction"): kd = "main"
				elif nm2.contains("TakeOff"): kd = "lift"
				beng[nm2] = {"kind": kd, "pos": (n as MeshInstance3D).transform * (n as MeshInstance3D).get_aabb().get_center()}
				btot[kd] += 1
		var cs := CollisionShape3D.new(); cs.shape = vres.get("shape", bot_hull_shape); rb.add_child(cs)
		rb.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM; rb.center_of_mass = vres.get("com", ship.center_of_mass / ship_sc)
		add_child(rb)
		rb.global_transform = Transform3D(Basis.IDENTITY, _grid_pos(slot, cols))
		var gg := _bot_genes(i)
		bots.append({"rb": rb, "g": gg, "lane_x": float(gg["lane"]), "lane_y": lerpf(250.0, 1700.0, float(gg["alt_pref"])), "hits": 0, "resp": 0, "vbase": 0.0, "last_s": 0.0, "lap": 0, "prog": 0.0, "rel": 0.0, "rel_init": false, "ct": -999, "path": 0, "fk": 0, "fkd": -1, "fin": false, "fin_t": 0.0, "still": 0.0, "parts": bparts, "ptot": bparts.size(), "eng": beng, "tot": btot, "thr": 0.0, "hold": _grid_pos(slot, cols).y, "pv": 0.0, "icd": 0.0, "name": "Третий шанс" if swapped else BOT_NAMES[i % BOT_NAMES.size()]})

func _bot_genes(i: int) -> Dictionary:
	var lst: Array = []
	var path := genes_path if genes_path != "" else "res://bot_genes.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array: lst = parsed
	var g: Dictionary = GENE_DEF.duplicate()
	if lst.size() > 0:
		var src: Dictionary = lst[i % lst.size()]
		for k in src: if g.has(k): g[k] = float(src[k])
	else:                                                              # по умолчанию три характера
		var tier := 2 if i < 3 else (1 if i < 6 else 0)
		g["v_max"] = [1000.0, 1400.0, 1800.0][tier]; g["lat_acc"] = [100.0, 140.0, 180.0][tier]; g["a_cap"] = [250.0, 350.0, 450.0][tier]
		g["alt_pref"] = randf(); g["lane"] = randf_range(-700.0, 700.0)
	if not evo_mode or evo_skill:                                       # уровни мастерства: бот 1 сильнейший, последний слабейший; обучение идёт без них
		var sk := lerpf(P("bot_skill_max"), P("bot_skill_min"), float(i) / float(maxi(1, N_BOTS - 1)))
		for k in ["v_max", "lat_acc", "a_cap"]: g[k] = float(g[k]) * sk
		if P("bot_chars") > 0.5:                                        # характеры по высоте: низкий / высокий / ищущий свободную высоту
			match i % 3:
				0: g["alt_pref"] = 0.08; g["alt_free"] = 0.0
				1: g["alt_pref"] = 0.75; g["alt_free"] = 0.0
				2: g["alt_free"] = 0.9
	return g

func _rel_s(sv: float) -> float:
	if s0 < 0.0: s0 = _track_query(0.0, 0.0).y
	if track_open: return sv - s0
	return fposmod(sv - s0 + trk_len * 0.5, trk_len) - trk_len * 0.5

func _acc_prog(prog: float, rel_last: float, rel: float) -> float:
	var d := rel - rel_last
	if track_open: return prog + d
	if d > trk_len * 0.5: d -= trk_len
	elif d < -trk_len * 0.5: d += trk_len
	return prog + d

# После финиша: торможение вдоль скорости с запасом до ближайшей стены (по формуле высоты), затем зависание
func _finish_brake(body: RigidBody3D, mass: float) -> void:
	var v := body.linear_velocity; var sp := v.length()
	if sp < 8.0: return
	var vd := v / sp; var pos := body.global_position; var dstop := 7000.0
	for dd in range(400, 9001, 400):
		var q := pos + vd * float(dd)
		if height(q.x, q.z) > pos.y - 150.0: dstop = maxf(float(dd) - 400.0, 500.0); break
	var a := clampf(maxf(sp * sp / (2.0 * dstop * 0.7), 480.0), 160.0, 2400.0)
	body.apply_central_force(-vd * mass * a)

func _bot_progress(b: Dictionary) -> float:
	return float(b["prog"])

func _bot_rem(b: Dictionary, kind: String) -> float:
	var n := 0
	for k in b["eng"]: if b["eng"][k]["kind"] == kind and b["parts"].has(k): n += 1
	return float(n) / maxf(1.0, float(b["tot"][kind]))

# Боты летят на тех же моторах и параметрах (tuning.json), что и игрок; ИИ выдаёт усилия моторов напрямую (кривые органов управления — только для человека)
func _step_bots(dt: float) -> void:
	var pos_all: Array = [ship.global_position]
	var vel_all: Array = [ship.linear_velocity]
	for b in bots: pos_all.append((b["rb"] as RigidBody3D).global_position); vel_all.append((b["rb"] as RigidBody3D).linear_velocity)
	if start_t <= 0.0 and racing: bot_run_t += dt
	for bi in bots.size():
		var b: Dictionary = bots[bi]
		var rb: RigidBody3D = b["rb"]
		if start_t > 0.0 or b.get("dnf", false) or b.get("done", false) or (ui_shot == "tour" and (tour_phase == "settle" or tour_phase == "fixed_wait") and bi == tour_bot): continue
		var virt := bool(b.get("virt", false))                                  # вне зоны видимости: упрощённый режим без физики (см. _bot_virtual)
		if rb.freeze and not virt: rb.freeze = false
		var pos := rb.global_position; var vel := rb.linear_velocity
		if pos.y > RIM_Y and not bool(b.get("fin", false)): b["above"] = float(b.get("above", 0.0)) + dt                  # время выше потолка гонки (обучение штрафует улёт вверх)
		if vel.length() > P("max_speed"): vel = vel.limit_length(P("max_speed")); rb.linear_velocity = vel
		if not evo_mode and not virt and Vector2(pos.x - ship.global_position.x, pos.z - ship.global_position.z).length() > LOD0_R - 400.0:
			var hg := height(pos.x, pos.z)                                     # далеко от игрока физического рельефа нет: считаем землю по формуле высоты
			if pos.y < hg + 25.0:
				var e := 30.0
				var nrm := Vector3((height(pos.x - e, pos.z) - height(pos.x + e, pos.z)) / (2.0 * e), 1.0, (height(pos.x, pos.z - e) - height(pos.x, pos.z + e)) / (2.0 * e)).normalized()
				var vn := vel.dot(nrm)
				if vn < 0.0:
					vel -= nrm * vn * 1.4; rb.linear_velocity = vel
					if -vn > 8.0 and float(b["icd"]) <= 0.0:
						b["icd"] = 0.25; b["hits"] = int(b["hits"]) + 1; _bot_impact(b, pos - nrm * 20.0, -vn * 2.4)
				rb.global_position.y = maxf(pos.y, hg + 25.0); pos = rb.global_position
		var gn: Dictionary = b["g"]; var gn_pre := gn
		var q := Vector2(0.0, float(b["vs"])) if virt else _track_query(pos.x, pos.z)
		var sv := q.y
		var relb := _rel_s(sv)
		if not b["rel_init"]: b["rel"] = relb; b["prog"] = relb; b["rel_init"] = true
		b["prog"] = _acc_prog(float(b["prog"]), float(b["rel"]), relb); b["rel"] = relb
		b["lap"] = int(floor(float(b["prog"]) / trk_len))
		b["last_s"] = sv
		if not b["fin"] and float(b["prog"]) >= race_len: b["fin"] = true; b["fin_t"] = evo_t if evo_mode else race_t
		if b["fin"] and virt:                                                   # финиш в упрощённом режиме: просто встаёт на линии финиша
			rb.linear_velocity = Vector3.ZERO; rb.freeze = true; rb.visible = true; b["done"] = true; continue
		if b["fin"]:                                                           # финишировавший бот тормозит, зависает и стоит
			if vel.length() > 8.0:
				_finish_brake(rb, MASS); rb.gravity_scale = 0.0; rb.angular_velocity *= 0.95
			else:
				rb.linear_velocity = Vector3.ZERO; rb.angular_velocity = Vector3.ZERO; rb.freeze = true; b["done"] = true
			continue
		var pth := int(b["path"])                                              # развилки: выбор рукава на подлёте
		if forks.size() > 0:
			var fi := int(b["fk"])
			if fi > 0 and sv < float(forks[fi - 1]["in"]) - 7000.0: fi = 0       # начался новый круг (у замкнутой трассы)
			while fi < forks.size() and sv > float(forks[fi]["out"]) + 2000.0: fi += 1
			if fi < forks.size():
				var fk: Dictionary = forks[fi]
				if int(b["fkd"]) != fi and sv > float(fk["in"]) - 3500.0 and sv < float(fk["in"]) + 300.0:
					b["fkd"] = fi
					var ids: Array = fk["ids"]; var rr := float(gn_pre["route"]); var pick := 0
					var gain := float(fk.get("gain", 0.0))
					if gain > 0.0:                                                          # срезка: чем она короче основного пути, тем охотнее её выбирают
						var thr := 1.2 if String(fk.get("type", "")) == "needle" else 0.62
						if rr + 0.9 * gain + 0.3 * (1.0 - float(bi) / float(maxi(1, N_BOTS - 1))) > thr: pick = int(ids[0])
					elif rr > 0.5: pick = int(ids[clampi(int((rr - 0.5) / 0.5 * ids.size()), 0, ids.size() - 1)])
					if not evo_mode and P("fork_flip") > 0.5 and (bi + fi) % 3 == 1: pick = int(ids[0]) if pick == 0 else 0
					b["path"] = pick; pth = pick
					if pick != 0: b["det"] = int(b.get("det", 0)) + 1
				if pth > 0 and sv > float(fk["out"]) + 200.0: b["path"] = 0; pth = 0
			b["fk"] = fi
		if _bots_adapt_ok():                                                    # зона видимости игрока: далеко — без физики, близко — честный полёт
			var dpl := Vector2(pos.x - ship.global_position.x, pos.z - ship.global_position.z).length()
			if not virt and dpl > P("virt_on") and P("bot_virtual") > 0.5 and not b["fin"]:
				virt = true; b["virt"] = true; b["vs"] = sv; b["v_ema"] = maxf(float(b.get("v_ema", 0.0)), 0.55 * float(gn["v_max"]))
				rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC; rb.freeze = true; rb.visible = false
			elif virt and dpl < P("virt_off"):
				virt = false; b["virt"] = false; rb.freeze = false; rb.visible = true
				var vtg := (_track_at_p(sv, pth))[1] as Vector2
				vel = Vector3(vtg.x, 0.0, vtg.y) * float(b.get("v_virt", 600.0)); rb.linear_velocity = vel; rb.angular_velocity = Vector3.ZERO
				b["pv"] = vel.length(); b["still"] = 0.0; b["icd"] = 0.5; b["thr"] = clampf(vel.length() / maxf(float(gn["v_max"]), 1.0), 0.0, 1.0)
			if virt: _bot_virtual(b, dt, pth); continue
		var la := 500.0 + vel.length() * 0.9
		var cl := maxf(float(gn["look_min"]), vel.length() * float(gn["look_k"]))   # на скорости смотрим дальше вперёд
		var tg0: Vector2 = (_track_at_p(sv, pth))[1]; var tg1: Vector2 = (_track_at_p(sv + cl, pth))[1]
		var ang := acos(clampf(tg0.dot(tg1), -1.0, 1.0))
		var cross := tg0.x * tg1.y - tg0.y * tg1.x
		var lane := clampf(float(b["lane_x"]) + float(gn["apex"]) * clampf(ang / 0.6, 0.0, 1.0) * signf(cross) * 900.0, -900.0, 900.0)   # срезаем поворот по внутренней
		if pth > 0: lane = clampf(lane, -60.0, 60.0)                           # на срезке русло узкое: держимся оси
		var at: Array = _track_at_p(sv + la, pth)
		var p2: Vector2 = at[0]; var tg: Vector2 = at[1]
		var perp := Vector2(-tg.y, tg.x)
		var tp := Vector3(p2.x + perp.x * lane, 0.0, p2.y + perp.y * lane)
		var dirv := Vector3(tp.x - pos.x, 0.0, tp.z - pos.z).normalized()
		var vcurve := sqrt(float(gn["lat_acc"]) * cl / maxf(ang, 0.02))
		var vdes := minf(float(gn["v_max"]), vcurve)
		var lk := _bot_launch(b, bi)                                           # «втопить на старте»: первые секунды часть ботов жмёт на полную
		if lk > 0.0: vdes = lerpf(vdes, maxf(vdes, P("max_speed") * 0.9), lk)
		vdes = minf(vdes * _rubber(b), P("max_speed") * 0.97)                  # подстройка: игрок оторвался — боты быстрее, игрок отстал — медленнее
		var cutb: Dictionary = branches[pth - 1] if (pth > 0 and pth <= branches.size()) else {}
		var needle_d := 1e9
		if not cutb.is_empty() and float(cutb["needle_s"]) > 0.0:
			needle_d = absf(sv - float(cutb["needle_s"])) * float(cutb["sc"])          # в метрах по самой срезке (s растянут)
			if needle_d < 14000.0: vdes = minf(vdes, 420.0 + needle_d * 0.08); lane = 0.0      # «игольное ухо»: замедляемся и выходим на ось
		var bs := rb.global_transform.basis
		var m := MASS
		var g := G if gravity_on else 0.0
		rb.gravity_scale = 1.0 if gravity_on else 0.0
		var fwd := -bs.z; var up := bs.y; var right := bs.x
		# --- желаемая высота: полоса, но не ниже рельефа впереди ---
		var hmax := height(tp.x, tp.z)
		for tt in [0.6, 1.2, 2.4, 4.0]: hmax = maxf(hmax, height(pos.x + vel.x * tt, pos.z + vel.z * tt))
		var tgt_alt := lerpf(250.0, 1700.0, float(gn["alt_pref"]))
		if float(gn["alt_free"]) > 0.01:                                      # идём на высоте, где меньше всего соперников рядом
			var bestc := 1e18; var base_alt := tgt_alt
			for ci in 8:
				var cand := lerpf(300.0, 1900.0, ci / 7.0)
				var md := 600.0
				for j in pos_all.size():
					var o: Vector3 = pos_all[j]; var dd2 := (o - pos).length()
					if dd2 > 1.0 and dd2 < 5000.0: md = minf(md, absf(cand - o.y))
				var cost := absf(cand - base_alt) * 0.4 - float(gn["alt_free"]) * minf(md, 400.0) * 1.5
				if cost < bestc: bestc = cost; tgt_alt = cand
		if not cutb.is_empty() and sv > float(cutb["in"]) + 600.0 and sv < float(cutb["out"]) - 600.0:
			tgt_alt = minf(tgt_alt, float(cutb["ceil"]) - 200.0)                     # под карнизами срезки
			if needle_d < 14000.0: tgt_alt = float(cutb["needle_y"]) + 8.0                  # заранее снижаемся и выходим точно на щель
		tgt_alt = minf(maxf(tgt_alt, hmax + (60.0 if not cutb.is_empty() else float(gn["clear_m"]))), RIM_Y - 300.0)
		for ar in arch_s:                                                    # боты арки облетают поверху (перемычка на высоте 670–890 м)
			if absf(sv - float(ar)) < 2500.0 and tgt_alt < 1050.0: tgt_alt = 1050.0
		b["hold"] = move_toward(float(b["hold"]), tgt_alt, (400.0 if tgt_alt > float(b["hold"]) else ((220.0 if absf(float(b["hold"]) - tgt_alt) > 150.0 else 50.0) if needle_d < 14000.0 else 80.0)) * dt)
		# --- желаемое горизонтальное ускорение ---
		var vh := Vector3(vel.x, 0.0, vel.z)
		b["v_ema"] = lerpf(float(b.get("v_ema", vh.length())), vh.length(), 1.0 - exp(-dt / 8.0))      # средняя скорость: с ней бот едет по рельсам вне зоны видимости
		var a_des := (dirv * vdes - vh) * float(gn["a_gain"])
		for j in pos_all.size():                                           # расхождение с соседями
			var d: Vector3 = pos - pos_all[j]
			var l := d.length()
			if l > 0.1 and l < 160.0:
				var dh := Vector3(d.x, 0.0, d.z)
				if dh.length() > 0.1: a_des += dh.normalized() * (160.0 - l) / 160.0 * 45.0 * float(gn["sep_w"])
		if float(gn["avoid"]) > 0.01:                                          # упреждающее уклонение: кто сблизится меньше 260 м в ближайшие 6 с, от того уходим вбок
			for j in pos_all.size():
				var pr: Vector3 = pos_all[j] - pos
				if pr.length() < 1.0 or pr.length() > 2500.0: continue
				var rv: Vector3 = vel_all[j] - vel
				var rv2 := rv.length_squared()
				if rv2 < 100.0: continue
				var tc := clampf(-pr.dot(rv) / rv2, 0.0, 6.0)
				var cp := pr + rv * tc
				var dm := cp.length()
				if dm < 260.0 and -pr.dot(rv) > 0.0:
					var away := Vector3(-cp.x, 0.0, -cp.z)
					if away.length() < 5.0: away = Vector3(-dirv.z, 0.0, dirv.x)
					a_des += away.normalized() * (1.0 - dm / 260.0) * (1.0 - tc / 6.0) * 180.0 * float(gn["avoid"])
		var acap := lerpf(float(gn["a_cap"]), maxf(float(gn["a_cap"]), P("main_acc") * 0.9), lk)
		if a_des.length() > acap: a_des = a_des.normalized() * acap
		# --- часть ускорения отдаём взлётным: крен даёт боковой сдвиг без рыскания, наклон носом вверх — торможение ---
		var a_lift := Vector3.ZERO
		var hd := (vh.normalized() if vh.length() > 30.0 else dirv)
		if gravity_on and (float(gn["bank"]) > 0.01 or float(gn["lift_brake"]) > 0.01) and pos.y - height(pos.x, pos.z) > float(gn["clear_m"]) * 0.7:
			var rh0 := Vector3(-hd.z, 0.0, hd.x)
			a_lift = rh0 * a_des.dot(rh0) * float(gn["bank"]) + hd * minf(a_des.dot(hd), 0.0) * float(gn["lift_brake"])
		var a_main := a_des - a_lift
		# --- потолок: прогноз через 3 с; при flip: перевернуться пузом кверху и дать взлётными вниз, иначе пикирование носом вниз ---
		var ceil_y := RIM_Y - 300.0
		var u_dn := 0.0
		if gravity_on:
			if vel.y > 0.0: u_dn = clampf((pos.y + vel.y * 3.0 - ceil_y) / 600.0, 0.0, 1.0)
			elif vel.y > -150.0: u_dn = clampf((pos.y - ceil_y) / 300.0, 0.0, 1.0)
		var flip_mode := true                                                  # переворот у потолка включён всегда (гены обучены с ним)
		var fl := int(b.get("fl", 0))                                         # 0 штатно, 1 перевёрнут (тянем вниз взлётными), 2 возврат в нормальное положение
		var cos_t := up.dot(Vector3.UP)
		if flip_mode and gravity_on:
			if fl == 0 and vel.y > 0.0 and pos.y + vel.y * 5.0 > ceil_y: fl = 1             # переворот занимает ~2,5 с, поэтому прогноз на 5 с
			elif fl == 1 and vel.y < 50.0 and pos.y < ceil_y - 900.0: fl = 2
			elif fl == 2 and cos_t > 0.6: fl = 0
			b["fl"] = fl
		var tmax := m * G * P("lift_max") * _bot_rem(b, "lift") * (1.0 + P("lift_side") * (1.0 - maxf(cos_t, 0.0)))
		var t_lift := 0.0
		if gravity_on:
			var a_c := P("hold_kp") * (float(b["hold"]) - pos.y) - P("hold_kd") * vel.y
			if "botcap" in OS.get_cmdline_user_args() and P("hold_acc_max") > 0.0: a_c = minf(a_c, P("hold_acc_max") * pow(maxf(cos_t, 0.0), P("hold_tilt_pow")))
			t_lift = m * (g + a_c) / clampf(cos_t, P("lift_cos"), 1.0)
			if cos_t < P("lift_inv_cos") and t_lift > 0.0: t_lift = tmax
			var sin_t := sqrt(maxf(0.0, 1.0 - cos_t * cos_t))
			if a_lift.length() > 1.0 and sin_t > 0.1:                          # форсаж взлётных в сторону уже наклонённого «верха»
				var uh := Vector3(up.x, 0.0, up.z)
				if uh.dot(a_lift.normalized()) > 0.5 * uh.length(): t_lift = maxf(t_lift, minf(m * a_lift.length() / sin_t, m * (g + 3.0 * G) / maxf(cos_t, 0.2)))
		if fly and bi == soak_bot: b["dbg"] = "a_lift=%d a_des=%d t_lift/mg=%.2f tmax/mg=%.1f cos=%.2f hold=%d y=%d vy=%d tgt_alt=%d hmax=%d" % [int(a_lift.length()), int(a_des.length()), t_lift / (m * G), tmax / (m * G), cos_t, int(b["hold"]), int(pos.y), int(vel.y), int(tgt_alt), int(hmax)]
		if flip_mode and fl != 0:
			if fl == 1 and cos_t < -0.3:                                        # вверх ногами: тянем вниз, гасим вертикальную скорость до целевой
				var hmx := height(pos.x, pos.z)
				var vy_t := clampf((ceil_y - 1200.0 - pos.y) * 0.3, -300.0, 100.0)
				if pos.y - hmx < 700.0: vy_t = maxf(vy_t, 0.0)
				t_lift = clampf(m * ((vel.y - vy_t) * 3.0 - g), 0.0, tmax) / maxf(-cos_t, 0.3)
			else: t_lift = 0.0                                                 # в переходе взлётные выключены (иначе тянут вбок)
		rb.apply_central_force(up * clampf(t_lift, 0.0, tmax))
		rb.apply_torque(_skew_torque(b["eng"], b["parts"], "lift", up, clampf(t_lift, 0.0, tmax), bs, rb.center_of_mass))
		# --- курс: нос туда, куда нужно ускоряться (если не нужно тормозить) ---
		var vdir := vh.normalized() if vh.length() > 30.0 else dirv
		var nd := a_main.normalized() if a_main.length() > 5.0 else vdir      # нос туда, куда нужно ускорение: тяговые работают и как поворот, и как торможение (разворот кормой)
		var up_t := Vector3.UP
		if a_lift.length() > 1.0:
			var tilt := float(gn["bank_max"]) * clampf(a_lift.length() / float(gn["bank_scale"]), 0.0, 1.0)
			up_t = (Vector3.UP * cos(tilt) + a_lift.normalized() * sin(tilt)).normalized()
		if flip_mode and fl == 1: up_t = Vector3.DOWN
		var fproj := (nd - up_t * nd.dot(up_t))
		fproj = fproj.normalized() if fproj.length() > 0.05 else nd
		if u_dn > 0.0 and not flip_mode: fproj = (fproj * cos(0.8 * u_dn) - Vector3.UP * sin(0.8 * u_dn)).normalized()
		var tq := Basis.looking_at(fproj, up_t).get_rotation_quaternion()
		var qe := tq * bs.get_rotation_quaternion().inverse()
		if qe.w < 0.0: qe = Quaternion(-qe.x, -qe.y, -qe.z, -qe.w)
		qe = qe.normalized()
		var eang := 2.0 * acos(clampf(qe.w, -1.0, 1.0))
		var eax := Vector3(qe.x, qe.y, qe.z).normalized() if eang > 0.0001 else Vector3.ZERO
		var el := bs.inverse() * (eax * eang)
		var wl := bs.inverse() * rb.angular_velocity
		var wd := el * float(gn["att_gain"])
		if wd.length() > 1.5: wd = wd.normalized() * 1.5
		var gy := (wd - wl) * 1.5
		gy = Vector3(clampf(gy.x, -1.0, 1.0), clampf(gy.y, -1.0, 1.0), clampf(gy.z, -1.0, 1.0))
		# --- тяговые ---
		var fh := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var a_fwd := a_main.dot(fh)
		var a_mag := a_main.length()
		var align := clampf((fh.dot(nd) - float(gn["align_lo"])) / (1.0 - float(gn["align_lo"])), 0.0, 1.0)
		var thr_cmd := clampf(a_mag / P("main_acc"), 0.0, 1.0) * align
		if fl != 0 and (fl == 2 or cos_t > -0.8): thr_cmd = 0.0              # в развороте у потолка основные выключены: иначе нос уходит вверх и подъём растёт
		b["thr"] = move_toward(float(b["thr"]), thr_cmd, P("main_spool") * dt)
		rb.apply_central_force(fwd * m * P("main_acc") * float(b["thr"]) * _bot_rem(b, "main"))
		rb.apply_torque(_skew_torque(b["eng"], b["parts"], "main", fwd, m * P("main_acc") * float(b["thr"]) * _bot_rem(b, "main"), bs, rb.center_of_mass))
		# --- маневровые: тангаж/рыскание/крен, боковая подвижка, торможение ---
		var rs := maxf(0.05, _bot_rem(b, "shunt"))
		var strafe := clampf(1.0 - eang / 0.5, 0.0, 1.0)             # боковая подвижка только когда нос уже почти по курсу, иначе она гасит разворот
		var trv := Vector3(clampf(a_main.dot(Vector3(right.x, 0.0, right.z).normalized()) / (4.0 * P("shunt_acc") * rs), -1.0, 1.0) * strafe, 0.0, clampf(-a_fwd / (4.0 * P("shunt_acc") * rs), 0.0, 1.0))
		for k in b["eng"]:
			if b["eng"][k]["kind"] != "shunt" or not b["parts"].has(k): continue
			var epos: Vector3 = b["eng"][k]["pos"]
			var left := epos.x < 0.0
			var sg := 1.0 if epos.z >= rb.center_of_mass.z else -1.0                  # носовой маневровый (впереди центра масс) толкает в обратную сторону: момент тот же, поворот «за нос»
			var rsg := 0.0 if absf(epos.x) < 1.0 else (-1.0 if left else 1.0)           # крен только от крыльевых (на оси корабля плеча по крену нет)
			var f := Vector3(trv.x + sg * gy.y, -sg * gy.x + rsg * gy.z, trv.z).limit_length(1.0)
			rb.apply_force(bs * f * m * P("shunt_acc"), bs * epos)
		var av := bs.inverse() * rb.angular_velocity
		if assist and gy.length() < 0.02: av = av.move_toward(Vector3.ZERO, P("assist_damp") * dt)
		if av.length() > P("max_spin"): av = av.normalized() * P("max_spin")
		rb.angular_velocity = bs * av
		# --- повреждения: резкая потеря скорости = удар ---
		var sp := vel.length()
		if rb.get_contact_count() > 0: b["ct"] = frame
		if float(b["icd"]) > 0.0: b["icd"] = float(b["icd"]) - dt
		elif float(b["pv"]) - sp > 8.0 and float(b["pv"]) > 0.0 and frame - int(b["ct"]) <= 24:
			b["icd"] = 0.25
			b["hits"] = int(b["hits"]) + 1
			_log_event("BOT_HIT %s drop=%d s=%d" % [b["name"], int(float(b["pv"]) - sp), int(sv)])
			_bot_impact(b, pos + vel.normalized() * 25.0 if sp > 1.0 else pos, (float(b["pv"]) - sp) * 2.4)
		b["pv"] = sp
		# застрял или вылетел — вернуть на трассу
		b["still"] = float(b["still"]) + dt if vel.length() < 25.0 else 0.0
		if (float(b["still"]) > 3.0 and start_t <= 0.0) or q.x > 6000.0:
			if pth > 0 and pth <= branches.size() and float((branches[pth - 1] as Dictionary)["needle_s"]) > 0.0 and absf(sv - float((branches[pth - 1] as Dictionary)["needle_s"])) < 1500.0:
				sv = float((branches[pth - 1] as Dictionary)["in"]) - 200.0; pth = 0; b["path"] = 0        # разбился об «ушко» — дальше по длинной основной трассе
			var rs2: Array = _track_at_p(sv, pth)
			var rp: Vector2 = rs2[0]; var rt: Vector2 = rs2[1]
			var ry := minf(maxf(float(b["lane_y"]), height(rp.x, rp.y) + 300.0), RIM_Y - 300.0)
			rb.global_transform = Transform3D(Basis.looking_at(Vector3(rt.x, 0.0, rt.y), Vector3.UP), Vector3(rp.x, ry, rp.y))
			rb.linear_velocity = Vector3(rt.x, 0.0, rt.y) * 150.0; rb.angular_velocity = Vector3.ZERO
			b["still"] = 0.0; b["pv"] = 0.0; b["hold"] = ry; b["thr"] = 0.0
			b["resp"] = int(b["resp"]) + 1
			_log_event("BOT_RESPAWN %s s=%d" % [b["name"], int(sv)])
			if not evo_mode and P("bot_max_resp") > 0.5 and int(b["resp"]) >= int(P("bot_max_resp")):   # слишком много вылетов: бот сходит с дистанции и стоит на месте
				b["dnf"] = true; rb.linear_velocity = Vector3.ZERO; rb.freeze = true
				_log_event("BOT_DNF %s" % b["name"])

# --- Подстройка ботов под игрока (только в настоящей гонке; в обучении и тестах боты честные) ---
var bot_run_t := 0.0                                                       # секунд с момента старта (для «втопить на старте»)
func _bots_adapt_ok() -> bool:
	return not (evo_mode or soak or test_mode or shot_mode) and (ui_shot == "" or ui_shot == "intro")

func _rubber(b: Dictionary) -> float:                                      # множитель скорости: >1 бот отстаёт от игрока, <1 бот впереди игрока
	if not _bots_adapt_ok() or not racing or p_fin or p_dsq or P("bot_virtual") < 0.5: return 1.0
	var gap := p_prog - float(b["prog"])
	if gap > 0.0:                                                              # бот позади игрока: догон зависит от отрыва в секундах (при нашей скорости), а не в метрах: на скорости 2000 м/с минута отрыва это 120 км
		var vp := maxf(ship.linear_velocity.length(), 500.0)
		return 1.0 + P("rubber_up") * clampf(gap / (vp * maxf(P("rubber_t"), 1.0)), 0.0, 1.0)
	return 1.0 + P("rubber_dn") * clampf(gap / maxf(P("rubber_r"), 1.0), -1.0, 0.0)

func _bot_launch(b: Dictionary, bi: int) -> float:                         # ген старта 0..1 у каждого бота (сильные бонус) × затухание за bot_launch_t секунд
	var tl := P("bot_launch_t")
	if tl <= 0.0 or not _bots_adapt_ok() or bot_run_t >= tl: return 0.0
	if not b.has("launch"): b["launch"] = lerpf(P("bot_launch_min"), 1.0, clampf(0.35 * (1.0 - float(bi) / float(maxi(1, N_BOTS - 1))) + 0.65 * _hash2(bi, 7, 3), 0.0, 1.0))
	return float(b["launch"]) * (1.0 - smoothstep(0.6 * tl, tl, bot_run_t))

# Упрощённый режим бота вне зоны видимости: едет по рельсам трассы со средней скоростью × подстройка, без физики и столкновений
func _bot_virtual(b: Dictionary, dt: float, pth: int) -> void:
	var rb: RigidBody3D = b["rb"]; var gn: Dictionary = b["g"]
	var cut := pth > 0 and pth <= branches.size()
	var sc := float((branches[pth - 1] as Dictionary)["sc"]) if cut else 1.0
	var v := maxf(float(b["v_ema"]), 300.0) * _rubber(b) * (0.8 if cut else 1.0)
	if _bots_adapt_ok() and racing and not p_fin and not p_dsq:                  # игрок оторвался дальше rubber_t секунд: бот едет почти с его скоростью, отрыв больше не растёт
		var vpl := maxf(ship.linear_velocity.length(), 500.0)
		if (p_prog - float(b["prog"])) > vpl * P("rubber_t"): v = maxf(v, vpl * P("rubber_floor"))
	b["v_virt"] = v
	var vs := float(b["vs"]) + v * dt / maxf(sc, 0.3)
	b["vs"] = vs
	var at: Array = _track_at_p(vs, pth)
	var p2: Vector2 = at[0]; var tg: Vector2 = at[1]
	var lane := 0.0 if cut else clampf(float(b["lane_x"]), -600.0, 600.0)
	var px := p2.x - tg.y * lane; var pz := p2.y + tg.x * lane
	var alt := minf(maxf(float(b["hold"]), height(px, pz) + float(gn["clear_m"])), RIM_Y - 300.0)
	b["hold"] = alt
	rb.global_transform = Transform3D(Basis.looking_at(Vector3(tg.x, 0.0, tg.y), Vector3.UP), Vector3(px, alt, pz))
	rb.linear_velocity = Vector3(tg.x, 0.0, tg.y) * v; rb.angular_velocity = Vector3.ZERO

func _bot_impact(b: Dictionary, pos: Vector3, power: float) -> void:
	var rb: RigidBody3D = b["rb"]
	var local := rb.to_local(pos)
	var cand := []
	for n in b["parts"]: cand.append([((b["parts"][n]) as MeshInstance3D).position.distance_to(local), n])
	cand.sort_custom(func(x, y): return x[0] < y[0])
	var cnt := clampi(int(power / 25.0), 0, 4)
	for i in mini(cnt, cand.size()):
		if not b["parts"].has(cand[i][1]): continue                    # деталь уже отлетела каскадом (крыло уносит моторы)
		if cand[i][0] < 14.0 + power * 0.3: _bot_detach(b, cand[i][1], (local - ((b["parts"][cand[i][1]]) as MeshInstance3D).position).normalized() * -1.0)

func _bot_detach(b: Dictionary, nm: String, dir: Vector3) -> void:
	var bparts: Dictionary = b["parts"]
	if not bparts.has(nm): return
	var rb: RigidBody3D = b["rb"]
	var mi: MeshInstance3D = bparts[nm]; bparts.erase(nm)
	if nm.begins_with("SM_Wing_"):
		var tag := nm.substr(nm.length() - 2)
		var top := nm.begins_with("SM_Wing_Top")
		for other in bparts.keys():
			if other.ends_with(tag) and ((top and (other.begins_with("SM_Engine_Shunt_Top") or other.begins_with("SM_Spotlight_Top"))) or (not top and other.begins_with("SM_Engine_Shunt_Bot"))): _bot_detach(b, other, dir)
	var is_eng := nm.begins_with("SM_Engine")
	if is_eng:
		_dead_engine_look(mi)
		var bp: Vector3 = (b["eng"][nm]["pos"] as Vector3) if b["eng"].has(nm) else Vector3.ZERO
		var od := Vector3(bp.x, 0.0, bp.z).normalized() if Vector2(bp.x, bp.z).length() > 0.1 else Vector3.UP
		_spark_fx(rb, bp, od, 0.0, 0.35)                                                               # из бота, где был мотор
	var d := RigidBody3D.new(); d.mass = 800.0 if nm.begins_with("SM_Engine") or nm.begins_with("SM_Wing") else 100.0
	d.collision_layer = 2; d.collision_mask = 1 | 2; d.gravity_scale = 1.0 if gravity_on else 0.0
	add_child(d)
	d.global_transform = mi.global_transform
	var ab := mi.get_aabb(); var bx := BoxShape3D.new(); bx.size = ab.size.max(Vector3.ONE * 0.1)
	var cs := CollisionShape3D.new(); cs.shape = bx; cs.position = ab.get_center(); d.add_child(cs)
	mi.get_parent().remove_child(mi); mi.transform = Transform3D.IDENTITY; d.add_child(mi)
	d.linear_velocity = rb.linear_velocity + rb.global_transform.basis * (dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)) * 12.0
	d.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 3.0
	debris.append(d)
	if is_eng: _spark_fx(d, mi.get_aabb().get_center(), Vector3.UP, 6.0, 0.3)

func _mesh_children(n: Node) -> Array:
	var r := []
	for c in n.get_children():
		if c is MeshInstance3D: r.append(c)
	return r

func _build_ship() -> void:
	var ps: PackedScene = load("res://ship/ship.glb")
	ship_scene = ps
	ship = RigidBody3D.new(); ship.name = "Ship"; ship.mass = MASS; ship.gravity_scale = 1.0
	ship.collision_layer = 8; ship.collision_mask = 1 | 2 | 8
	ship.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; ship.linear_damp = 0.01
	ship.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE; ship.angular_damp = 0.0
	add_child(ship)
	var hull_shape: ConvexPolygonShape3D = null
	_fill_variant(ship, "ship%d" % ship_id, SHIP_VARIANTS.get(ship_id, {}))     # по книге у «Фреи» четыре каюты (у базового корабля десять): подрезка по схеме ботов
	ship_sc = float(SHIP_SCALE[ship_id])                                      # «Фрея» меньше: все части уменьшаются вместе с их положениями
	if ship_sc != 1.0:
		for n in ship.get_children():
			if n is Node3D: (n as Node3D).position *= ship_sc; (n as Node3D).scale = Vector3.ONE * ship_sc
	hull_pos0 = (ship.get_node("SM_Hull_Body") as Node3D).position / ship_sc
	var hull_tex := {"alb": load("res://ship/tex/hull_albedo_4096.png"), "rgh": load("res://ship/tex/hull_roughness_4096.png"), "mtl": load("res://ship/tex/hull_metallic_4096.png"), "dec": load("res://ship/tex/decal_third_chance.png")}
	if ship_id == 1:
		hull_tex = {"alb": load("res://ship/tex/freya_albedo.png"), "rgh": load("res://ship/tex/freya_rough.png"), "mtl": load("res://ship/tex/freya_metal.png"), "dec": load("res://ship/tex/freya_decal.png"), "two_sided": true,
			"bite": {"part": "SM_Wing_Top_R", "c": Vector3(21.0, 8.5, 27.0), "r": 7.5}}
	if SHIP_LIVERY.has(ship_id):                                                # «Долгоносик» и «Аргамак» летят в своих ливреях
		var li: int = SHIP_LIVERY[ship_id]
		if ResourceLoader.exists("res://ship/tex/livery_%d_albedo.png" % li):
			hull_tex["alb"] = load("res://ship/tex/livery_%d_albedo.png" % li); hull_tex["dec"] = load("res://ship/tex/livery_%d_decal.png" % li); hull_tex["two_sided"] = true
	for n in ship.get_children():
		if n is not MeshInstance3D or n.is_queued_for_deletion(): continue       # вырезанные при подрезке корпуса окна ещё числятся детьми до конца кадра: в части разрушения их брать нельзя
		var mi := n as MeshInstance3D
		var nm: String = n.name
		if nm.begins_with("SM_HexPlate"): n.visible = false
		_fix_materials(mi, hull_tex, ship_sc)
		for k in mi.mesh.get_surface_count():
			var hm := mi.get_surface_override_material(k) as ShaderMaterial
			if hm != null and hm.shader != null and hm.shader.code.contains("dents"): hull_mats.append(hm)
		if nm == "SM_Hull_Body_LOD1":
			hull_shape = _scaled_shape(mi.mesh.create_convex_shape(true, true), ship_sc); n.visible = false
		var det := false
		for p in DETACH_PREFIX:
			if nm.begins_with(p): det = true
		if not det: continue
		parts[nm] = n
		var shp: Shape3D = null
		for ch in _mesh_children(n):
			shp = _scaled_shape((ch as MeshInstance3D).mesh.create_convex_shape(true, true), ship_sc); ch.queue_free()
		if shp == null and not nm.begins_with("SM_Glass"):
			shp = _scaled_shape(mi.mesh.create_convex_shape(true, true), ship_sc)
		if shp != null:
			var cs := CollisionShape3D.new(); cs.shape = shp; cs.transform = Transform3D(n.transform.basis.orthonormalized(), n.position); cs.name = "COL_" + nm
			ship.add_child(cs); shapes[nm] = cs
		if nm.begins_with("SM_Glass"): mi.material_override = _glass_mat()
		if nm.begins_with("SM_Engine_"): _setup_engine(mi)
	health_w0 = 0.0
	for pn in parts: health_w0 += part_weight(String(pn))
	var hc := CollisionShape3D.new(); hc.shape = hull_shape; ship.add_child(hc)
	var aabb := AABB()
	if ship.has_node("SM_Hull_Body"): aabb = (ship.get_node("SM_Hull_Body") as MeshInstance3D).get_aabb()
	ship.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM; ship.center_of_mass = (ship.get_node("SM_Hull_Body") as Node3D).position + aabb.get_center() * ship_sc
	ship.can_sleep = false; ship.continuous_cd = true
	ship.contact_monitor = true; ship.max_contacts_reported = 4      # удар = настоящее касание; торможение двигателями ударом не считается
	if ship_id == 1:                                                           # «Фрея»: два мотора дымят уже со старта
		for nm2 in ["SM_Engine_Shunt_Bot_L", "SM_Engine_TakeOff_Back_L2"]:
			if engines.has(nm2): _spark_fx(ship, engines[nm2]["pos"], Vector3.UP, 0.0, 0.4, false)

func _scaled_shape(shp: ConvexPolygonShape3D, sc: float) -> ConvexPolygonShape3D:
	if sc != 1.0:
		var pts := shp.points
		for i in pts.size(): pts[i] *= sc
		shp.points = pts
	return shp

func _fix_materials(mi: MeshInstance3D, tex: Dictionary, sc: float = 1.0) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == null: continue
		if m.resource_name == "Material":                       # обшивка: свои текстуры + шестигранники по формуле
			var sm := ShaderMaterial.new(); sm.shader = hull_shader
			var bt: Dictionary = tex.get("bite", {})
			if not bt.is_empty() and String(mi.name) == String(bt["part"]):
				sm.shader = hull_bite_shader; sm.set_shader_parameter("bite_on", 1.0); sm.set_shader_parameter("bite_c", bt["c"]); sm.set_shader_parameter("bite_r", float(bt["r"]))
			sm.set_shader_parameter("two_sided", 1.0 if tex.get("two_sided", false) else 0.0); sm.set_shader_parameter("alb", tex["alb"]); sm.set_shader_parameter("rgh", tex["rgh"]); sm.set_shader_parameter("mtl", tex["mtl"])
			sm.set_shader_parameter("offset", mi.position / sc); sm.set_shader_parameter("decal", tex["dec"]); sm.set_shader_parameter("dec_o", hull_pos0)
			if String(mi.name).begins_with("SM_Wing_Bot_") and (tex["alb"] as Texture2D).resource_path.contains("hull_albedo"): sm.set_shader_parameter("wbot", 1.0)       # у «Третьего шанса» и ботов без ливреи: новые полоски на нижних крыльях
			mi.set_surface_override_material(i, sm)

func _glass_mat() -> ShaderMaterial:
	if mat_glass == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial; render_mode cull_disabled, depth_draw_always;
void fragment(){ ALBEDO=vec3(0.06,0.15,0.25); ROUGHNESS=0.04; SPECULAR=0.6; ALPHA=FRONT_FACING?0.5:0.03; }"""
		mat_glass = ShaderMaterial.new(); mat_glass.shader = sh
	return mat_glass

var core_geo_cache := {}                                                   # меш + поверхность -> [центр, ось, радиус] светящегося ядра (в осях меша)
func _core_instance_params(mi: MeshInstance3D, surf: int) -> void:         # рисунок ядра и света лопастей строится вокруг оси мотора: центр, направление наружу и радиусы берём из геометрии
	var key := "%d:%d" % [mi.mesh.get_instance_id(), surf]
	if not core_geo_cache.has(key):
		var cv: PackedVector3Array = mi.mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]
		var c := Vector3.ZERO; var ax := Vector3(0, 0, 1)
		var rad_g := 0.0
		var gi := -1                                                       # ось и центр берём по диску MAT_Engine_Glow: он плоский и симметричный, нормаль диска точно вдоль оси (у купола ядра среднее по нормалям уходит в сторону)
		for si in mi.mesh.get_surface_count():
			var gm := mi.mesh.surface_get_material(si)
			if gm != null and gm.resource_name == "MAT_Engine_Glow": gi = si; break
		if gi >= 0:
			var ga := mi.mesh.surface_get_arrays(gi)
			var gv: PackedVector3Array = ga[Mesh.ARRAY_VERTEX]; var gn: PackedVector3Array = ga[Mesh.ARRAY_NORMAL]
			var nav := Vector3.ZERO
			for k in gv.size(): c += gv[k]; nav += gn[k]
			c /= float(maxi(gv.size(), 1))
			if nav.length() > 0.01:
				ax = nav.normalized()
				if ax.dot(c - mi.mesh.get_aabb().get_center()) < 0.0: ax = -ax          # наружу: от середины мотора к диску
			for v in gv: rad_g = maxf(rad_g, (v - c - ax * (v - c).dot(ax)).length())
		else:
			for v in cv: c += v
			c /= float(maxi(cv.size(), 1))
		var rad := 0.0; var t_lo := -1e9                                    # радиус ядра и где оно кончается по оси
		for v in cv:
			rad = maxf(rad, (v - c - ax * (v - c).dot(ax)).length()); t_lo = maxf(t_lo, (v - c).dot(ax))
		var ts := []                                                       # где кончаются лопасти: 95-й процентиль координат вершин корпуса в кольце лопастей
		for si in mi.mesh.get_surface_count():
			var bm := mi.mesh.surface_get_material(si)
			if bm == null or bm.resource_name == "MAT_Engine_Glow" or bm.resource_name == "MAT_Engine_Core": continue
			for v in (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var tt := (v - c).dot(ax); var rr := (v - c - ax * tt).length()
				if tt > t_lo and rr > rad_g * 0.85 and rr < rad_g * 1.45: ts.append(tt)
		ts.sort()
		var t_hi: float = float(ts[int(float(ts.size() - 1) * 0.95)]) if ts.size() > 8 else t_lo + rad_g * 0.8
		core_geo_cache[key] = [c, ax, rad, rad_g, t_lo, maxf(t_hi, t_lo + 0.05)]
	var g: Array = core_geo_cache[key]
	mi.set_instance_shader_parameter("ctr", g[0]); mi.set_instance_shader_parameter("axis", g[1]); mi.set_instance_shader_parameter("rad", g[2]); mi.set_instance_shader_parameter("rad_g", g[3]); mi.set_instance_shader_parameter("t_lo", g[4]); mi.set_instance_shader_parameter("t_hi", g[5])

func _setup_engine(mi: MeshInstance3D) -> void:
	var nm := String(mi.name)
	var kind := "shunt"
	if nm.contains("Traction"): kind = "main"
	elif nm.contains("TakeOff"): kind = "lift"
	elif nm == NOSE_ENG: kind = "nose"                                           # носовой маневровый «Долгоносика»: только тормозит, в управление не входит
	var ab := mi.get_aabb()
	var c := ab.get_center()
	var noz := c; var dir := Vector3.ZERO; var r := 0.3
	for i in mi.mesh.get_surface_count():                    # центр и ось сопла берём по диску свечения
		var gm := mi.mesh.surface_get_material(i)
		if gm == null or gm.resource_name != "MAT_Engine_Glow": continue
		var arr := mi.mesh.surface_get_arrays(i)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		if vs.is_empty(): continue
		var cen := Vector3.ZERO; var nav := Vector3.ZERO
		for k in vs.size(): cen += vs[k]; nav += ns[k]
		cen /= vs.size(); nav = nav.normalized()
		if nav.dot(cen - c) < 0.0: nav = -nav
		var rad := 0.0
		for k in vs.size(): rad = maxf(rad, vs[k].distance_to(cen))
		noz = cen; dir = nav; r = rad * 0.85
	if dir == Vector3.ZERO:
		if kind == "main": noz = Vector3(c.x, c.y, ab.end.z); dir = Vector3(0, 0, 1); r = 0.3 * minf(ab.size.x, ab.size.y)
		elif kind == "lift": noz = Vector3(c.x, ab.position.y, c.z); dir = Vector3(0, -1, 0); r = 0.3 * ab.size.x
	var mats: Array = []
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == null: continue
		if m.resource_name == "MAT_Engine_Glow":
			var sm := ShaderMaterial.new(); sm.shader = glow_shader; mi.set_surface_override_material(i, sm); mats.append(sm)
		elif m.resource_name == "MAT_Engine_Core":
			var sm := ShaderMaterial.new(); sm.shader = core_shader; mi.set_surface_override_material(i, sm); mats.append(sm); _core_instance_params(mi, i)
			var bl := ShaderMaterial.new(); bl.shader = blade_shader; mi.material_overlay = bl; mats.append(bl)
	var pivot := Node3D.new(); pivot.position = noz; mi.add_child(pivot)
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 1.0; cone.height = 1.0
	cone.radial_segments = 24; cone.rings = 1; cone.cap_top = false; cone.cap_bottom = false
	var fm := MeshInstance3D.new(); fm.mesh = cone; fm.position = Vector3(0, 0.5, 0); fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var smf := ShaderMaterial.new(); smf.shader = flame_shader; fm.material_override = smf; pivot.add_child(fm)
	if kind == "shunt" or kind == "nose": smf.set_shader_parameter("fast", 1.0)
	if "flames" in OS.get_cmdline_user_args(): print("FLAME ", nm, " pos=", mi.transform * noz, " dir=", dir, " r=", snappedf(r, 0.01))
	engines[nm] = {"kind": kind, "mi": mi, "pivot": pivot, "fmat": smf, "pos": mi.transform * c, "dir": dir, "r": r, "mats": mats, "cen": c, "ext": ab.size}
	kind_total[kind] += 1

func _build_checkpoints() -> void:
	var tor := TorusMesh.new(); tor.inner_radius = 170.0; tor.outer_radius = 188.0
	var nring := int(trk_len / RING_GAP)
	for k in range(1, nring + 1):
		var sv := k * RING_GAP
		var at := _track_at(sv)
		var pos2: Vector2 = at[0]; var tg2: Vector2 = at[1]
		var y := 420.0 + 160.0 * sin(k * 0.7)
		for ar in arch_s:
			if absf(sv - ar) < 400.0: y = 330.0
		var mi := MeshInstance3D.new(); mi.mesh = tor
		mi.position = Vector3(pos2.x, y, pos2.y)
		mi.basis = Basis(Quaternion(Vector3.UP, Vector3(tg2.x, 0.0, tg2.y)))
		var m := StandardMaterial3D.new(); m.emission_enabled = true; mi.material_override = m; add_child(mi); cps.append(mi)
	_color_cps()

# Препятствия срезок: у извилистых — карнизы-козырьки над руслом (верхние ярусы смыкаются в узкую щель, русло внизу шире), у «ушка» — поперечная стенка
# с очень узкой горизонтальной расщелиной (60 × 24 м) и огнями по краям.
const PROPS := false                 # false: срезки и трасса только рельефом (без крыши, выступов, «уха» и арок); true вернёт прежние объекты
const NEEDLE_W := 100.0
const NEEDLE_H := 32.0
# Съёмка прохождения бота по срезкам: -- uishot=tour. Бот телепортируется на подлёт к точке, камера за ним, снимок в момент прохождения.
func _tour_step(pf: int) -> void:
	if pf == 20:
		ui._show_state("hud"); start_t = 0.0; racing = true; Engine.time_scale = 1.0
		ship.freeze = true; ship.collision_layer = 0; ship.collision_mask = 0; ship.visible = false
		for k in branches.size():
			if tour_c > 0 and k + 1 != tour_c: continue
			var br: Dictionary = branches[k]; var sin_: float = br["in"]; var sout: float = br["out"]
			tour_targets.append({"name": "c%d_a_podlet" % (k + 1), "path": 0, "s": sin_ - 800.0, "start": sin_ - 4200.0})
			tour_targets.append({"name": "c%d_b_vhod" % (k + 1), "path": k + 1, "s": sin_ + 3000.0, "start": sin_ + 300.0})
			tour_targets.append({"name": "c%d_c_seredina" % (k + 1), "path": k + 1, "s": (sin_ + sout) * 0.5, "start": (sin_ + sout) * 0.5 - 3200.0})
			if float(br["needle_s"]) > 0.0:
				var ns: float = br["needle_s"]
				tour_targets.append({"name": "c%d_d_ushko_izdali" % (k + 1), "path": k + 1, "fixed": [-1100.0, 0.0, 700.0, 0.0], "ns": ns})
				tour_targets.append({"name": "c%d_e_ushko_blizko" % (k + 1), "path": k + 1, "fixed": [-260.0, 0.0, 700.0, 0.0], "ns": ns})
				tour_targets.append({"name": "c%d_f_ushko_sboku" % (k + 1), "path": k + 1, "fixed": [-90.0, 520.0, 700.0, 0.0], "ns": ns})
				tour_targets.append({"name": "c%d_g_ushko_za_stenkoy" % (k + 1), "path": k + 1, "fixed": [190.0, 0.0, 700.0, 0.0], "ns": ns})
			else:
				tour_targets.append({"name": "c%d_d_vyhod" % (k + 1), "path": k + 1, "s": sout - 2500.0, "start": sout - 5600.0})
		tour_i = -1; tour_phase = "next"
	if pf < 25 or tour_i >= tour_targets.size() and tour_phase != "next": return
	var b: Dictionary = bots[tour_bot]; var rb := b["rb"] as RigidBody3D
	if tour_phase != "":
		ship.global_position = rb.global_position + Vector3(0, 600, 0)
	if tour_phase == "next":
		tour_i += 1
		if tour_i >= tour_targets.size(): get_tree().quit(); return
		var tg: Dictionary = tour_targets[tour_i]
		if tg.has("fixed"):                                                  # статичный кадр: камера у стенки «ушка», бот убран
			var fx: Array = tg["fixed"]; var br2: Dictionary = branches[int(tg["path"]) - 1]
			var tot2 := 0.0; var bp2: PackedVector2Array = br2["pts"]
			for i2 in range(1, bp2.size()): tot2 += bp2[i2].distance_to(bp2[i2 - 1])
			var nf2 := _cut_frame(bp2, tot2 * 0.5); var pw: Vector2 = nf2[0]; var tw: Vector2 = nf2[1]; var nw: Vector2 = nf2[2]
			var cpos2 := Vector3(pw.x, float(fx[2]), pw.y) + Vector3(tw.x, 0, tw.y) * float(fx[0]) + Vector3(nw.x, 0, nw.y) * float(fx[1])
			fixed_cam = Transform3D(Basis.IDENTITY, cpos2).looking_at(Vector3(pw.x, 700.0, pw.y), Vector3.UP)
			ship.global_position = Vector3(pw.x, 800.0, pw.y); rb.global_position = Vector3(pw.x, 3000.0, pw.y); rb.freeze = true
			tour_pf0 = pf; tour_phase = "fixed_wait"; tour_ready = true; return
		var fr := _track_at_p(float(tg["start"]), int(tg["path"])); var p2: Vector2 = fr[0]; var d2: Vector2 = fr[1]
		var alt := 430.0 if int(tg["path"]) > 0 else 1100.0
		if int(tg["path"]) > 0 and float((branches[int(tg["path"]) - 1] as Dictionary)["needle_s"]) > 0.0: alt = 900.0      # как в гонке: на срезку бот входит сверху
		rb.freeze = true; rb.global_transform = Transform3D(Basis.looking_at(Vector3(d2.x, 0, d2.y), Vector3.UP), Vector3(p2.x, alt, p2.y))
		rb.linear_velocity = Vector3(d2.x, 0, d2.y) * 700.0; rb.angular_velocity = Vector3.ZERO
		b["hold"] = alt; b["thr"] = 0.0; b["path"] = int(tg["path"]); b["fin"] = false; b["done"] = false; b["dnf"] = false; rb.freeze = false; b["resp"] = 0; b["fk"] = forks.size(); b["fkd"] = forks.size()
		var rl := _rel_s(float(tg["start"])); b["rel"] = rl; b["prog"] = rl; b["rel_init"] = true; b["still"] = 0.0; b["pv"] = 0.0; b["icd"] = 1.0
		tour_pf0 = pf; tour_phase = "settle"; tour_ready = true
	elif tour_phase == "fixed_wait" and pf - tour_pf0 > 300:
		var tgf: Dictionary = tour_targets[tour_i]
		get_viewport().get_texture().get_image().save_png("/private/tmp/tour_%02d_%s.png" % [tour_i, String(tgf["name"])])
		print("TOUR ", tour_i, " ", tgf["name"], " fixed")
		tour_phase = "next"
	elif tour_phase == "settle" and pf - tour_pf0 > 300:
		rb.freeze = false; rb.linear_velocity = (-rb.global_transform.basis.z) * 700.0; tour_phase = "run"; tour_pf0 = pf
	elif tour_phase == "run":
		var tg2: Dictionary = tour_targets[tour_i]
		var cur_s := float(b["last_s"])
		if cur_s >= float(tg2["s"]) or pf - tour_pf0 > 1500:
			tour_phase = "shot"; tour_pf0 = pf
			var nm := "/private/tmp/tour_%02d_%s.png" % [tour_i, String(tg2["name"])]
			get_viewport().get_texture().get_image().save_png(nm)
			print("TOUR ", tour_i, " ", tg2["name"], " s=", int(cur_s), " v=", int((b["rb"] as RigidBody3D).linear_velocity.length()), " y=", int(rb.global_position.y), " hits=", b["hits"], " resp=", b["resp"])
			tour_phase = "next"

func _rock_blob(center: Vector3, r: Vector3, basis: Basis, mat: Material, rs: RandomNumberGenerator) -> void:
	# органичный нарост: суперэллипсоид с шумом (не выступает за номинальный размер, чтобы щель не перекрывалась)
	var nl := 12; var nr := 18; var nn_ := 3.0
	var ph := rs.randf() * TAU; var fx := rs.randf_range(1.5, 3.0); var fy := rs.randf_range(1.5, 3.0)
	var pts: PackedVector3Array = PackedVector3Array()
	for a in range(nl + 1):
		var th := PI * float(a) / float(nl)
		for b in range(nr):
			var ph2 := TAU * float(b) / float(nr)
			var u := Vector3(sin(th) * cos(ph2), cos(th), sin(th) * sin(ph2))
			var nrm := pow(pow(absf(u.x), nn_) + pow(absf(u.y), nn_) + pow(absf(u.z), nn_), 1.0 / nn_)
			var k := 0.84 + 0.16 * sin(fx * ph2 + ph) * cos(fy * th * 2.0 + ph * 0.7)
			pts.append(Vector3(u.x / nrm * r.x, u.y / nrm * r.y, u.z / nrm * r.z) * k)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in nl:
		for b in nr:
			var b2 := (b + 1) % nr
			var p00 := pts[a * nr + b]; var p01 := pts[a * nr + b2]; var p10 := pts[(a + 1) * nr + b]; var p11 := pts[(a + 1) * nr + b2]
			for tri in [[p00, p10, p01], [p01, p10, p11]]: for v in tri: st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := ConvexPolygonShape3D.new(); sh.points = pts; cs.shape = sh; body.add_child(cs)
	add_child(mi); add_child(body)
	var tr := Transform3D(Basis(basis.x, basis.y, -basis.z), center); mi.global_transform = tr; body.global_transform = tr      # базис хода правый

func _static_box(center: Vector3, size: Vector3, basis: Basis, mat: Material) -> void:
	var bm := BoxMesh.new(); bm.size = size
	var mi := MeshInstance3D.new(); mi.mesh = bm; mi.material_override = mat
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = size; cs.shape = bx; body.add_child(cs)
	add_child(mi); add_child(body)
	var tr := Transform3D(basis, center); mi.global_transform = tr; body.global_transform = tr

func _cut_frame(pts: PackedVector2Array, dist: float) -> Array:               # точка, касательная и нормаль на расстоянии dist вдоль ветки
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if acc + seg >= dist:
			var t := (dist - acc) / maxf(seg, 0.001); var tg := (pts[i] - pts[i - 1]).normalized()
			return [pts[i - 1].lerp(pts[i], t), tg, Vector2(-tg.y, tg.x)]
		acc += seg
	var tg2 := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	return [pts[pts.size() - 1], tg2, Vector2(-tg2.y, tg2.x)]

func _wall_dist(p: Vector2, n: Vector2, side: float, y: float) -> float:       # на каком расстоянии от оси стена каньона достигает высоты y
	for d in range(60, 3200, 40):
		var q := p + n * side * float(d)
		if height(q.x, q.y) >= y: return float(d)
	return -1.0

func _roof_y(dist: float, bi: int) -> float:
	return clampf(1250.0 + 650.0 * sin(dist * 0.0006 + float(bi)) + 200.0 * sin(dist * 0.0017 + 1.7 * float(bi)), 650.0, 2300.0)

func _build_cut_props() -> void:
	if not PROPS or branches.is_empty() or track_open == false: return
	var rng := RandomNumberGenerator.new(); rng.seed = track_seed * 13 + 3
	var mat: Material = terr_mat
	for bi in branches.size():
		var br: Dictionary = branches[bi]; var pts: PackedVector2Array = br["pts"]
		var total := 0.0
		for i in range(1, pts.size()): total += pts[i].distance_to(pts[i - 1])
		if br["type"] == "wind":                                                 # узкая органичная расщелина: сверху сомкнута «крышей», ширина и ярусы плавают по длине, с боков выступы
			var step := 80.0; var dist := 2200.0; var ymin := 99999.0; var side_n := 0
			while dist < total - 2200.0:
				var fr := _cut_frame(pts, dist); var p: Vector2 = fr[0]; var tg: Vector2 = fr[1]; var nn: Vector2 = fr[2]
				var yr := _roof_y(dist, bi)      # высота «потолка» меняется по длине
				var dl := _wall_dist(p, nn, -1.0, yr); var dr := _wall_dist(p, nn, 1.0, yr)
				if dl > 0.0 and dr > 0.0:
					var off := (dr - dl) * 0.5
					var basis := Basis(Vector3(nn.x, 0.0, nn.y), Vector3.UP, Vector3(tg.x, 0.0, tg.y))
					_static_box(Vector3(p.x + nn.x * off, yr + (5700.0 - yr) * 0.5, p.y + nn.y * off), Vector3(dl + dr + 240.0, 5700.0 - yr, step * 1.15), basis, mat)
					ymin = minf(ymin, yr)
					if int(dist / step) % 11 == 0 and rng.randf() < 0.75:                    # выступ с одной из стен: сужает щель на высоте, заставляет «змейкой» идти по центру/низу
						var sd := 1.0 if side_n % 2 == 0 else -1.0; side_n += 1
						var dw := dr if sd > 0.0 else dl
						var rx := dw * rng.randf_range(0.34, 0.46)
						var cy := rng.randf_range(260.0, maxf(yr - 260.0, 300.0))
						var lat := off + sd * (dw - rx * 0.9)
						_rock_blob(Vector3(p.x + nn.x * lat, cy, p.y + nn.y * lat), Vector3(rx, rng.randf_range(50.0, 90.0), step * rng.randf_range(1.4, 2.4)), basis, mat, rng)
				dist += step
			br["ceil"] = ymin
		elif br["type"] == "needle":
			var fr2 := _cut_frame(pts, total * 0.5); var p2: Vector2 = fr2[0]; var tg2: Vector2 = fr2[1]; var n2: Vector2 = fr2[2]
			var tq := _tq3(p2.x, p2.y)
			if int(tq.z) == bi + 1: br["needle_s"] = tq.y                            # привязываем «ушко» к реальному положению стенки
			var yc: float = br["needle_y"]
			var dwl := _wall_dist(p2, n2, -1.0, 3300.0); var dwr := _wall_dist(p2, n2, 1.0, 3300.0)
			if dwl < 0.0: dwl = 3200.0
			if dwr < 0.0: dwr = 3200.0
			var basis2 := Basis(Vector3(n2.x, 0.0, n2.y), Vector3.UP, Vector3(tg2.x, 0.0, tg2.y))
			var gy0 := yc - NEEDLE_H * 0.5; var gy1 := yc + NEEDLE_H * 0.5
			var ylow := -60.0; var yhigh := 5700.0; var thick := 150.0
			var half_w := maxf(dwl, dwr) + 120.0
			var ctr := Vector3(p2.x, 0.0, p2.y)
			_static_box(ctr + Vector3(0, (ylow + gy0) * 0.5, 0), Vector3(half_w * 2.0, gy0 - ylow, thick), basis2, mat)
			_static_box(ctr + Vector3(0, (gy1 + yhigh) * 0.5, 0), Vector3(half_w * 2.0, yhigh - gy1, thick), basis2, mat)
			for side in [-1.0, 1.0]:
				var lat := (NEEDLE_W * 0.5 + half_w) * 0.5
				var c3: Vector3 = ctr + Vector3(n2.x, 0.0, n2.y) * float(side) * lat + Vector3(0, yc, 0)
				_static_box(c3, Vector3(half_w - NEEDLE_W * 0.5, NEEDLE_H, thick), basis2, mat)
			# огни по краям щели, чтобы её было видно издали
			var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color = Color(1.0, 0.55, 0.12)
			var fz := Vector3(tg2.x, 0.0, tg2.y) * (thick * 0.5 + 1.0)
			for sgn in [-1.0, 1.0]:
				for zz in [-1.0, 1.0]:
					var bm := BoxMesh.new(); bm.size = Vector3(2.0, NEEDLE_H + 6.0, 2.0)
					var mi := MeshInstance3D.new(); mi.mesh = bm; mi.material_override = lm; add_child(mi)
					mi.global_transform = Transform3D(basis2, ctr + Vector3(n2.x, 0.0, n2.y) * sgn * (NEEDLE_W * 0.5 + 1.0) + Vector3(0, yc, 0) + fz * zz)
			var bm2 := BoxMesh.new(); bm2.size = Vector3(NEEDLE_W + 6.0, 2.0, 2.0)
			for yy in [gy0 - 1.0, gy1 + 1.0]:
				for zz in [-1.0, 1.0]:
					var mi2 := MeshInstance3D.new(); mi2.mesh = bm2; mi2.material_override = lm; add_child(mi2)
					mi2.global_transform = Transform3D(basis2, ctr + Vector3(0, yy, 0) + fz * zz)

func _build_arches() -> void:
	if not PROPS: return
	# каменные перемычки над трассой: пролететь надо под ними
	var asvs: Array = [7000.0, trk_len * 0.77] if not track_open else []
	if track_open:
		var ak := 0
		while 7000.0 + ak * 70000.0 < race_len - 15000.0:
			var cand := 7000.0 + ak * 70000.0 + (float((ak * 7919) % 20) - 10.0) * 700.0
			for fk in forks:                                                       # арка не должна перекрывать развилку
				if cand > float(fk["in"]) - 6000.0 and cand < float(fk["out"]) + 6000.0: cand = float(fk["out"]) + 7000.0
			asvs.append(cand); ak += 1
	for asv in asvs:
		var bi := 0
		for i in trk_pts.size():
			if trk_s[i] <= asv: bi = i
		var at := _track_at(trk_s[bi])
		var pos2: Vector2 = at[0]; var tg2: Vector2 = at[1]
		arch_s.append(trk_s[bi])
		var bm := BoxMesh.new(); bm.size = Vector3(7000, 220, 200)
		var mi := MeshInstance3D.new(); mi.mesh = bm; mi.material_override = terr_mat
		var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = bm.size; cs.shape = bx; body.add_child(cs)
		var basis := Basis(Vector3(-tg2.y, 0.0, tg2.x), Vector3.UP, Vector3(tg2.x, 0.0, tg2.y))    # длинная ось поперёк трассы
		var tr := Transform3D(basis, Vector3(pos2.x, 780.0, pos2.y))
		add_child(mi); add_child(body); mi.global_transform = tr; body.global_transform = tr

func _color_cps() -> void:
	for i in cps.size():
		var m := cps[i].material_override as StandardMaterial3D
		var col := Color(0.2, 1.0, 0.4) if i == next_cp else (Color(0.3, 0.3, 0.35) if i > next_cp else Color(0.15, 0.4, 0.8))
		m.albedo_color = col; m.emission = col; m.emission_energy_multiplier = 3.0 if i == next_cp else 0.6

func _build_hud() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	hud = Label.new(); hud.position = Vector2(16, 12); hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_outline_color", Color.BLACK); hud.add_theme_constant_override("outline_size", 6)
	cl.add_child(hud)
	help = Label.new(); help.position = Vector2(16, 130); help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_outline_color", Color.BLACK); help.add_theme_constant_override("outline_size", 5)
	cl.add_child(help)
	tune.build(cl)
	menu_label = Label.new(); menu_label.position = Vector2(300, 220); menu_label.visible = false
	menu_label.add_theme_font_size_override("font_size", 22)
	menu_label.add_theme_color_override("font_outline_color", Color.BLACK); menu_label.add_theme_constant_override("outline_size", 8)
	cl.add_child(menu_label)
	warn_label = Label.new(); warn_label.position = Vector2(420, 330); warn_label.visible = false
	warn_label.add_theme_font_size_override("font_size", 40); warn_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	warn_label.add_theme_color_override("font_outline_color", Color.BLACK); warn_label.add_theme_constant_override("outline_size", 10)
	cl.add_child(warn_label)
	var dbg := shot_mode or test_mode or "debughud" in OS.get_cmdline_user_args()
	hud.visible = dbg; help.visible = dbg
	ui = preload("res://demo_ui.gd").new(); ui.main = self; add_child(ui)
	if music_ok(): ship_sfx = ShipSfx.new(); add_child(ship_sfx); ship_sfx.setup(self)
	music = preload("res://music.gd").new(); music.cfg = cfg; add_child(music); music.track_done.connect(ui.on_track_done)

func _help_text() -> String:
	var kb := "КЛАВИАТУРА: W газ (тяговые, тормоза нет) | Space/Ctrl форсаж/замедление взлётных | стрелки тангаж+рыскание, Q/E крен | I/K/J/L вектор маневровых, Shift усиление\n"
	var s1 := "ГЕЙПАД (схема 1): RT газ | RB/LB... см. ниже | левый стик: тангаж+рыскание (толкает хвост) | правый стик: отдача маневровых (стик вправо = струи влево) | LB/RB крен, LT усиление | D-pad вверх/вниз: форсаж/замедление взлётных\n"
	var s2 := "ГЕЙПАД (схема 2): RT газ | левый стик: левые маневровые (вперёд-назад, вправо = вверх) | правый стик: правые | LT усиление | RB/LB форсаж/замедление взлётных | A гироскоп-стабилизация\n"
	return kb + (s1 if scheme == 0 else s2) + "F2/Y переключить схему | V/R3 камера | T/A стабилизация | G гравитация | X оторвать | Z оторвать всё | R/Start сброс | H интерьер | F3/Esc/L3 настройки управления (инверсии) | F1 скрыть подсказку"

func _reset() -> void:
	for d in debris: if is_instance_valid(d): d.queue_free()
	debris.clear()
	if frame > 0:
		_reload_game(); return
	ship.global_transform = Transform3D(Basis.IDENTITY, player_start)
	ship.linear_velocity = Vector3.ZERO; ship.angular_velocity = Vector3.ZERO
	hold_alt = player_start.y
	next_cp = 0; race_t = 0.0; racing = false; _color_cps()

func _load_cfg() -> void:
	var cf := ConfigFile.new()
	var has_cf := cf.load(CFG_PATH) == OK
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("tuning="): tune.path_override = ua.substr(7)
	if not tune.load_file() and has_cf:                       # перенос прежних настроек взлётных
		for k in ["lift_max", "lift_boost", "hold_kp", "hold_kd", "lift_cos", "lift_side"]:
			if cf.has_section_key("controls", k): tune.v[k] = float(cf.get_value("controls", k))
		if cf.has_section_key("controls", "lift_ramp"): tune.v["lift.time"] = float(cf.get_value("controls", "lift_ramp"))
		tune.save_file()
	_load_keys(cf if has_cf else null)
	_load_pad(cf if has_cf else null)
	if not has_cf: return
	for k in cfg: cfg[k] = cf.get_value("controls", k, cfg[k])
	scheme = int(cf.get_value("controls", "scheme", scheme))
	cam_mode = clampi(int(cfg["cam_view"]), 0, CAM_MODES.size() - 1)
	var stored := String(cf.get_value("controls", "sig", "")); var side := _read_sig_file(); var now := _progress_sig()
	var ok := (stored == now and (side == "" or side == now)) or (stored == "" and (side == "" or side == now))        # без подписи — старый файл (подпишем при сохранении)
	if not ok and not (evo_mode or test_mode or soak or shot_mode):          # прогресс правили руками: всё обнуляем, ui выдаст взамен «Мамкин хацкер»
		cfg["ach"] = {}; cfg["rec"] = {}; cfg["stats"] = {}; tamper_flag = true; _save_cfg()
	elif stored == "": _save_cfg()

# Подпись прогресса (достижения, рекорды, статистика): если файл правили руками, при старте подпись не сойдётся
const SIG_SALT := "kk-race-7f3a91-прогресс"
const SIG_PATH := "user://progress.sig"
var tamper_flag := false
func _canon(v) -> String:
	if v is Dictionary:
		var ks := (v as Dictionary).keys(); ks.sort_custom(func(a, b): return String(a) < String(b))
		var s := "{"
		for k in ks: s += String(k) + ":" + _canon(v[k]) + ","
		return s + "}"
	if v is Array:
		var s2 := "["
		for e in v: s2 += _canon(e) + ","
		return s2 + "]"
	if v is float or v is int: return "%.9g" % float(v)
	return str(v)

func _progress_sig() -> String:
	return (SIG_SALT + _canon({"ach": cfg.get("ach", {}), "rec": cfg.get("rec", {}), "stats": cfg.get("stats", {})})).sha256_text()

func _read_sig_file() -> String:
	if not FileAccess.file_exists(SIG_PATH): return ""
	var f := FileAccess.open(SIG_PATH, FileAccess.READ)
	return f.get_as_text().strip_edges() if f != null else ""

func _save_cfg() -> void:
	var cf := ConfigFile.new()
	for k in cfg: cf.set_value("controls", k, cfg[k])
	cf.set_value("controls", "scheme", scheme)
	var sig := _progress_sig(); cf.set_value("controls", "sig", sig)
	var sf := FileAccess.open(SIG_PATH, FileAccess.WRITE)
	if sf != null: sf.store_string(sig)
	for kb in KEYBIND: cf.set_value("keys", kb[0], keys[kb[0]])
	for pb in PADBIND: cf.set_value("pad", pb[0], "%s:%d:%d" % [pad[pb[0]]["t"], pad[pb[0]]["i"], pad[pb[0]]["s"]])
	cf.save(CFG_PATH)

func _dz(v: float) -> float:
	var z: float = cfg["deadzone"]
	return 0.0 if absf(v) < z else signf(v) * (absf(v) - z) / (1.0 - z)

func _menu_text() -> String:
	var t := "НАСТРОЙКИ УПРАВЛЕНИЯ (сохраняются автоматически)\n\n"
	for i in MENU_ITEMS.size():
		var key: String = MENU_ITEMS[i][0]
		var val := ""
		if key == "scheme": val = "схема %d" % (scheme + 1)
		elif key == "level": val = LEVEL_NAMES[_lvl()]
		elif key == "deadzone": val = "%.2f" % cfg[key]
		elif key == "tech": val = "F4"
		else: val = "ВКЛ" if cfg[key] else "выкл"
		t += ("▶ " if i == menu_i else "   ") + MENU_ITEMS[i][1] + "  [" + val + "]\n"
	t += "\nВверх/вниз выбрать, Enter / A / вправо изменить, F3 / Esc / L3 закрыть"
	return t

func _menu_step(dir: int) -> void:
	var key: String = MENU_ITEMS[menu_i][0]
	if key == "scheme": scheme = 1 - scheme
	elif key == "level": cfg[key] = posmod(int(cfg[key]) + dir, 5)
	elif key == "deadzone":
		var i := DEADZONES.find(cfg[key]); if i < 0: i = 2
		cfg[key] = DEADZONES[clampi(i + dir, 0, DEADZONES.size() - 1)]
	elif key == "tech": menu_open = false; _set_tech(true)
	else: cfg[key] = not cfg[key]
	_save_cfg()

# Перекос тяги при потере моторов: оставшиеся моторы несут общую тягу поровну, и их общий момент относительно центра масс сдвигается
func _skew_torque(eng: Dictionary, have: Dictionary, kind: String, dir_w: Vector3, thrust: float, bs: Basis, com: Vector3) -> Vector3:
	var n_all := 0; var n_alive := 0; var s_all := Vector3.ZERO; var s_alive := Vector3.ZERO
	for k in eng:
		if eng[k]["kind"] != kind: continue
		var tq: Vector3 = (bs * ((eng[k]["pos"] as Vector3) - com)).cross(dir_w)
		n_all += 1; s_all += tq
		if have.has(k): n_alive += 1; s_alive += tq
	if n_alive == 0 or n_all == 0 or n_alive == n_all: return Vector3.ZERO
	return thrust * P("eng_skew") * (s_alive / float(n_alive) - s_all / float(n_all))

func _remaining(kind: String) -> float:
	var n := 0
	for k in engines: if engines[k]["kind"] == kind and parts.has(k): n += 1
	return float(n) / maxf(1.0, float(kind_total[kind]))

func _read_controls(dt: float) -> Dictionary:
	var c := {"thr": 0.0, "lift": 0.0, "gyro": Vector3.ZERO, "tr": Vector3.ZERO, "shl": Vector3.ZERO, "shr": Vector3.ZERO, "boost": 0.0}
	var pad := Input.get_connected_joypads().size() > 0
	# --- клавиатура ---
	var held := func(organ: String, on: bool) -> float:      # кнопка: усилие по времени удержания
		kb_t[organ] = (float(kb_t.get(organ, 0.0)) + dt) if on else 0.0
		return tune.effort(organ, float(kb_t[organ]) / tune.time_of(organ)) if on else 0.0
	var stk := func(organ: String, x: float) -> float:       # стик/курок: усилие по отклонению
		return signf(x) * tune.effort(organ, absf(x))
	var lift: float = _kd("lift_up") - _kd("lift_down")
	var gyro := Vector3((_kd("pitch_down") - _kd("pitch_up")) * (-1.0 if cfg["inv_kb_pitch"] else 1.0), _kd("yaw_left") - _kd("yaw_right"), _kd("roll_left") - _kd("roll_right"))
	var sh := Vector3(_kd("sh_right") - _kd("sh_left"), 0.0, _kd("sh_back") - _kd("sh_fwd"))     # x вправо, z назад
	sh = sh.normalized() * held.call("shunt", sh.length() > 0.0)
	var gyro_s := Vector3.ZERO
	var boost: float = held.call("boost", _kd("boost") > 0.0)
	var thr_v: float = held.call("thr", _kd("thr") > 0.0)
	var shl := sh; var shr := sh; var tr := sh
	# --- геймпад ---
	look_in = Vector2.ZERO
	if CAM_MODES[cam_mode] == "cockpit": look_in = Vector2(_kd("look_right") - _kd("look_left"), _kd("look_down") - _kd("look_up"))      # клавиатура: осмотр из кабины
	if pad:
		var d := 0
		var lx := _dz(Input.get_joy_axis(d, JOY_AXIS_LEFT_X)); var ly := _dz(Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		var rx := _dz(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X)); var ry := _dz(Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
		if CAM_MODES[cam_mode] == "cockpit": look_in = (look_in + Vector2(rx, ry)).limit_length(1.0); rx = 0.0; ry = 0.0
		var lb := Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER); var rb := Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
		if cfg["inv_lx"]: lx = -lx
		if cfg["inv_ly"]: ly = -ly
		if cfg["inv_rx"]: rx = -rx
		if cfg["inv_ry"]: ry = -ry
		thr_v = maxf(thr_v, stk.call("thr", clampf(_pa(d, "thr") + _pb(d, "thr"), 0.0, 1.0))); boost = maxf(boost, stk.call("boost", clampf(_pa(d, "boost") + _pb(d, "boost"), 0.0, 1.0)))
		if scheme == 0:                                              # привязки из pad: нос вверх = +x, рыскание влево = +y, крен влево = +z
			gyro_s = Vector3(stk.call("pitch", _pa(d, "pitch_up") - _pa(d, "pitch_down")), stk.call("yaw", _pa(d, "yaw_left") - _pa(d, "yaw_right")), stk.call("roll", _pa(d, "roll_left") - _pa(d, "roll_right")))
			gyro += Vector3(_pb(d, "pitch_up") - _pb(d, "pitch_down"), _pb(d, "yaw_left") - _pb(d, "yaw_right"), _pb(d, "roll_left") - _pb(d, "roll_right"))
			tr += Vector3(rx, 0.0, ry).normalized() * tune.effort("shunt", Vector3(rx, 0.0, ry).length())
			lift += _pa(d, "lift_up") + _pb(d, "lift_up") - _pa(d, "lift_down") - _pb(d, "lift_down")
		else:
			shl += Vector3(0.0, lx, ly).normalized() * tune.effort("shunt", Vector2(lx, ly).length()); shr += Vector3(0.0, rx, ry).normalized() * tune.effort("shunt", Vector2(rx, ry).length())      # стик вперёд = тяга вперёд (-Z), вправо = вверх
			lift += (1.0 if rb else 0.0) - (1.0 if lb else 0.0)
	# вектор тяги: в осях корабля, z>0 «назад» -> сила вперёд = -Z
	c["thr"] = thr_v; c["lift"] = clampf(lift, -1.0, 1.0); c["boost"] = boost
	var gcl := Vector3.ZERO
	var gnames := ["pitch", "yaw", "roll"]
	for i in 3:                                              # кнопки (2 состояния): усилие по времени удержания; стик уже пересчитан по отклонению
		var kv := clampf(gyro[i], -1.0, 1.0)
		gcl[i] = clampf(signf(kv) * float(held.call(gnames[i], absf(kv) > 0.0)) + gyro_s[i], -1.0, 1.0)
	c["gyro"] = gcl
	c["shl"] = shl.limit_length(1.0); c["shr"] = shr.limit_length(1.0); c["tr"] = tr.limit_length(1.0)
	return c

func _physics_process(dt: float) -> void:
	frame += 1
	if unstick_cd > 0.0: unstick_cd -= dt
	if frame > 3 and dt > 0.0:
		var vv := ship.linear_velocity
		acc_s = lerpf(acc_s, (vv - prev_v_c).length() / dt, 1.0 - exp(-dt / 0.12)); prev_v_c = vv
	if evo_mode:                                                      # обучение: игрока нет, считаем только ботов
		if start_t > 0.0: start_t -= dt
		else: evo_t += dt
		_step_bots(dt)
		if frame > (evo_secs + 4.0) * 60.0:
			var res := []
			for b in bots: res.append({"prog": (race_len * (1.0 + (evo_t - float(b["fin_t"])) / maxf(evo_t, 1.0)) if b["fin"] else minf(float(b["prog"]), race_len)), "fin": float(b["fin_t"]) if b["fin"] else -1.0, "det": int(b.get("det", 0)), "br": branches.size(), "path": int(b["path"]), "hits": int(b["hits"]), "resp": int(b["resp"]), "lost": int(b["ptot"]) - (b["parts"] as Dictionary).size(), "above": float(b.get("above", 0.0))})
			var f := FileAccess.open(evo_out, FileAccess.WRITE); f.store_string(JSON.stringify(res)); f.close()
			get_tree().quit()
		return
	if ram: _ram_step(dt); return
	if fly: _fly_step(dt); return
	if soak: _soak_sync()
	if impact_cd > 0.0: impact_cd -= dt
	if ship.get_contact_count() > 0: last_contact_f = frame
	if racing and not p_fin:
		var psp := ship.linear_velocity.length()
		if p_hit_cd > 0.0: p_hit_cd -= dt
		elif p_hit_pv - psp > 8.0 and frame - last_contact_f <= 24: p_hits += 1; p_hit_cd = 0.25
		p_hit_pv = psp
	if ship.linear_velocity.length() > P("max_speed"): ship.linear_velocity = ship.linear_velocity.limit_length(P("max_speed"))
	if frame > 10 and ship.global_position.y < -30.0:                  # спасалка: корабль провалился под рельеф (отрицательная высота) — поднять над землёй
		var sp0 := ship.global_position; var hr := height(sp0.x, sp0.z)
		ship.global_position = Vector3(sp0.x, hr + 400.0, sp0.z)
		ship.linear_velocity = Vector3(ship.linear_velocity.x, maxf(ship.linear_velocity.y, 0.0), ship.linear_velocity.z)
		_log_event("RESCUE below ground y=%d" % int(sp0.y))
	var ctrl := _read_controls(dt)
	if (ui != null and ui.state == "results") or p_fin or p_dsq: ctrl = {"thr": 0.0, "lift": 0.0, "gyro": Vector3.ZERO, "tr": Vector3.ZERO, "shl": Vector3.ZERO, "shr": Vector3.ZERO, "boost": 0.0}
	if start_t > 0.0: ctrl["thr"] = 0.0
	var hold_start := start_t > 0.0 and not (soak or ram or fly or evo_mode or test_mode)           # до старта корабль стоит намертво: ни взлётные, ни маневровые, ни случайные нажатия его не сдвинут
	if hold_start:
		ctrl = {"thr": 0.0, "lift": 0.0, "gyro": Vector3.ZERO, "tr": Vector3.ZERO, "shl": Vector3.ZERO, "shr": Vector3.ZERO, "boost": 0.0}
		if not ship.freeze: ship.freeze = true; start_frozen = true
		ship.linear_velocity = Vector3.ZERO; ship.angular_velocity = Vector3.ZERO
	elif start_frozen:
		start_frozen = false; ship.freeze = false; ship.linear_velocity = Vector3.ZERO; ship.angular_velocity = Vector3.ZERO; hold_alt = ship.global_position.y
	if _reset_now: _reset_now = false; _reset()
	if test_mode: ctrl = _test_controls()
	last_ctrl = ctrl
	_track_stats(dt)
	var bs := ship.global_transform.basis
	var m := MASS
	# --- тяговые: вперёд (-Z), без тормоза ---
	thr = move_toward(thr, ctrl["thr"], P("main_spool") * dt)
	var f_main := bs * Vector3(0, 0, -1) * m * P("main_acc") * thr * _remaining("main")
	ship.apply_central_force(f_main)
	var lv := _lvl()
	if (p_fin or p_dsq) and lv == 4: lv = 3                                             # после финиша автопилот работает как у Ветерана: тормозит и держит высоту
	if prev_lvl < 0: prev_lvl = lv
	if lv != 4 and prev_lvl == 4: scheme = 0; assist = true; _save_cfg()     # ушли с Киборга: вернуть схему 1 и стабилизацию
	prev_lvl = lv
	if lv == 4: scheme = 1; assist = false                                  # Киборг: схема 2, никаких стабилизаций
	if p_fin or p_dsq: _finish_brake(ship, m); ship.angular_velocity *= 0.985
	var sl: Array = LEVEL_SLIP[lv]
	if float(sl[0]) > 0.0 or float(sl[1]) > 0.0:                          # гашение скорости поперёк носа: вбок и вверх-вниз по осям корабля, сильнее при тяге главных
		var lvel := ship.linear_velocity
		var fs := -(bs.x * bs.x.dot(lvel) * float(sl[0]) + bs.y * bs.y.dot(lvel) * float(sl[1])) * P("slip_scale") * (1.0 + float(sl[2]) * thr)
		if fs.length() > P("slip_amax"): fs = fs.normalized() * P("slip_amax")
		ship.apply_central_force(fs * m)
	if lv > 1: ship.apply_torque(_skew_torque(engines, parts, "main", bs * Vector3(0, 0, -1), f_main.length(), bs, ship.center_of_mass))
	# --- взлётные: удержание высоты, тяга вдоль «верха» корабля ---
	var up := bs.y
	var cos_t := up.dot(Vector3.UP)
	var y := ship.global_position.y
	var vy := ship.linear_velocity.y
	var g := G if gravity_on else 0.0
	var tmax := m * G * P("lift_max") * _remaining("lift") * (1.0 + P("lift_side") * (1.0 - maxf(cos_t, 0.0)))   # при крене на бок тяга растёт, чтобы гасить боковую инерцию
	var t_nom := m * g / clampf(cos_t, P("lift_cos"), 1.0)
	var t_lift := 0.0
	var boost_dump := Vector3.ZERO
	var idle_slide := Vector3.ZERO
	var li_raw: float = ctrl["lift"]
	if absf(li_raw) > 0.05: lift_hold += dt
	else: lift_hold = 0.0
	var li := signf(li_raw) * tune.effort("lift", lift_hold / tune.time_of("lift")) if absf(li_raw) > 0.05 else 0.0
	if absf(li_raw) > 0.05:
		hold_alt = y
		# форсаж: полная тяга вдоль верха корабля (боковая составляющая сильная), но вертикальная часть ограничена cos^lift_boost_tilt
		var t_top := m * G * P("lift_max") * _remaining("lift") * P("lift_boost")       # тяга при полном усилии форсажа (в горизонте)
		t_lift = m * g + (t_top - m * g) * li if li > 0 else m * g * (1.0 + P("lift_down") * li)
		dbg["want"] = t_lift
		if li > 0 and cos_t > 0.0:
			var cap := t_lift * pow(cos_t, P("lift_boost_tilt"))
			dbg["cap"] = cap
			var fv := minf(t_lift, tmax) * cos_t
			if fv > cap: boost_dump = Vector3.DOWN * (fv - cap)
	elif gravity_on:
		dbg["want"] = 0.0; dbg["cap"] = 0.0
		var a_c := P("hold_kp") * (hold_alt - y) - P("hold_kd") * vy
		if P("hold_acc_max") > 0.0: a_c = minf(a_c, P("hold_acc_max") * pow(maxf(cos_t, 0.0), P("hold_tilt_pow")))      # в крене удержание высоты не раскачивается на полную: корабль больше проваливается
		t_lift = m * (g + a_c) / clampf(cos_t, P("lift_cos"), 1.0)
		idle_slide = Vector3(up.x, 0.0, up.z) * m * g * P("lift_idle_slide")
		if lv == 4: t_lift = 0.0; idle_slide = Vector3.ZERO                  # Киборг: удержания высоты нет, взлётные только вручную      # на холостых взлётных небольшой крен/тангаж даёт усиленный боковой снос
	if cos_t < P("lift_inv_cos") and t_lift > 0.0: t_lift = minf(tmax, m * G * P("lift_max") * _remaining("lift")) * (1.0 if absf(li_raw) > 0.05 else P("lift_inv_power"))          # вверх ногами: само не включается (lift_inv_power), но ручной форсаж работает на полную моторы не держат, а валят корабль вниз на полной тяге
	dbg["inv"] = 1 if cos_t < P("lift_inv_cos") else 0
	dbg["limit"] = "tmax" if t_lift > tmax else ("li_ramp" if (absf(li_raw) > 0.05 and absf(li) < tune.v["lift.max"] * 0.999) else ("li_max" if absf(li_raw) > 0.05 else ""))   # tmax = упёрлись в потолок тяги; li_ramp = форсаж ещё нарастает по времени; li_max = усилие дошло до максимума органа (lift.max)
	t_lift = clampf(t_lift, 0.0, tmax)
	dbg["li"] = li; dbg["t_lift"] = t_lift; dbg["tmax"] = tmax; dbg["dump"] = boost_dump.length()
	lift_ratio = t_lift / maxf(1.0, m * G * P("lift_max"))
	ship.apply_central_force(up * t_lift + boost_dump + idle_slide)
	if lv > 1: ship.apply_torque(_skew_torque(engines, parts, "lift", up, t_lift, bs, ship.center_of_mass))
	# --- маневровые (концы крыльев, у кормы): сила в точке двигателя, поэтому толкают хвост и вращают корабль ---
	var boost: float = 1.0 + P("shunt_boost_gain") * float(ctrl["boost"])
	var gy: Vector3 = ctrl["gyro"]
	var tr: Vector3 = ctrl["tr"]
	eng_force.clear()
	for nm in engines:
		var e = engines[nm]
		if e["kind"] != "shunt" or not parts.has(nm): continue
		var pos: Vector3 = e["pos"]
		var left := pos.x < 0.0
		var f := Vector3.ZERO
		if scheme == 0:
			# хвост толкается: нос вверх = хвост вниз; рыскание влево = хвост вправо; крен влево = левые вниз, правые вверх
			f = Vector3(tr.x + gy.y, -gy.x + (-gy.z if left else gy.z), tr.z)
		else:
			f = Vector3(ctrl["shl"] if left else ctrl["shr"])
		var b01: float = ctrl["boost"]
		var fv := f.limit_length(1.0) * boost + Vector3(0, 0, -P("shunt_boost_fwd") * b01)       # форсаж без команды даёт тягу вперёд (струи назад)
		eng_force[nm] = fv
		ship.apply_force(bs * fv * m * P("shunt_acc"), bs * pos)
	if engines.has(NOSE_ENG) and parts.has(NOSE_ENG):                           # «Долгоносик»: форсаж без команд на маневровые = носовой маневровый тормозит (струя вперёд), сила по оси корабля без перекоса
		var cmd := Vector3(tr.x + gy.y, -gy.x + gy.z, tr.z) if scheme == 0 else Vector3(ctrl["shl"]) + Vector3(ctrl["shr"])
		var b02: float = clampf(float(ctrl["boost"]), 0.0, 1.0) * (1.0 - clampf(cmd.length(), 0.0, 1.0))
		var vfw := -bs.z.dot(ship.linear_velocity)                                   # тормозит только пока корабль движется вперёд: назад не разгоняет
		var fb := Vector3(0, 0, 1) * b02 * NOSE_BRAKE * clampf(vfw / 25.0, 0.0, 1.0)
		eng_force[NOSE_ENG] = fb
		if b02 > 0.0: ship.apply_force(bs * fb * m * P("main_acc"), bs * Vector3(0.0, (ship.center_of_mass).y, (engines[NOSE_ENG]["pos"] as Vector3).z))
	# --- стабилизация: гасит вращение, пока нет команды на вращение ---
	var av := bs.inverse() * ship.angular_velocity
	var stab_on := assist and (lv > 1 or _remaining("shunt") > 0.999)       # Салага/Ученик: при потере маневровых стабилизация отключается
	var lvl_done := false
	if stab_on and float(LEVEL_ROLL[lv]) > 0.0 and ((scheme == 0 and absf(gy.z) < 0.02) or (scheme == 1 and Vector2(ctrl["shl"].y, ctrl["shr"].y).length() < 0.05)):
		var fw := -bs.z                                                      # плавно выравниваем крен: верх корабля к «плоскому» положению вокруг носа
		var flat := Vector3.UP - fw * Vector3.UP.dot(fw)
		if flat.length() > 0.2:
			flat = flat.normalized()
			var th := atan2(fw.dot(bs.y.cross(flat)), bs.y.dot(flat))
			av.z = -move_toward(-av.z, clampf(float(LEVEL_ROLL[lv]) * th, -1.2, 1.2), 3.0 * dt); lvl_done = true      # выравнивание заменяет гашение по крену, иначе они гасят друг друга
	if stab_on and scheme == 0:                                  # гашение по осям: рыскание гасится сильнее и независимо от команд тангажа/крена
		var dk: float = LEVEL_DAMP[lv]
		var ad := [P("assist_damp") * dk, P("assist_damp_yaw") * dk, P("assist_damp") * dk]
		for i in 3:
			if i == 2 and lvl_done: continue
			if absf(gy[i]) < 0.02: av[i] = move_toward(av[i], 0.0, float(ad[i]) * dt)
	elif stab_on and Vector2(ctrl["shl"].y, ctrl["shr"].y).length() < 0.05: av = av.move_toward(Vector3.ZERO, P("assist_damp") * dt)
	if av.length() > P("max_spin"): av = av.normalized() * P("max_spin")
	ship.angular_velocity = bs * av
	log_t += dt
	if frame % 6 == 0: _log_row(ctrl)
	_step_bots(dt)
	if "reset" in OS.get_cmdline_user_args() and frame == 120: _reset_now = true
	if test_mode:
		if frame % 60 == 0: print("t=", frame / 60, " v=", int(ship.linear_velocity.length()), " y=", int(y), " parts=", parts.size(), " thr=", snappedf(thr, 0.01), " lift=", snappedf(lift_ratio, 0.01), " cp=", next_cp, " bots v=", int(bots[0]["rb"].linear_velocity.length()), "/", int(bots[5]["rb"].linear_velocity.length()), " s=", int(bots[0]["last_s"]), " y=", int(bots[0]["rb"].global_position.y), " rank=", rank)
		if frame > (14400 if "long" in OS.get_cmdline_user_args() else 3600):
			for b in bots: print("END ", b["name"], " s=", int(b["last_s"]), " lap=", b["lap"], " v=", int((b["rb"] as RigidBody3D).linear_velocity.length()), " y=", int((b["rb"] as RigidBody3D).global_position.y), " parts=", b["parts"].size())
			get_tree().quit()

func _test_controls() -> Dictionary:
	var t := frame / 60.0
	var c := {"thr": 1.0 if t > 2.0 else 0.0, "lift": 0.0, "gyro": Vector3.ZERO, "tr": Vector3.ZERO, "shl": Vector3.ZERO, "shr": Vector3.ZERO, "boost": 0.0}
	if "side" in OS.get_cmdline_user_args():
		c["thr"] = 0.0
		if frame == 5:
			ship.global_transform = Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), Vector3(0.0, 150.0, 0.0))      # крен 90°: верх корабля = +X
			ship.linear_velocity = Vector3(-300.0, 0.0, 0.0)
		if frame >= 5 and frame % 15 == 0 and frame < 200: print('SIDE vx=', int(ship.linear_velocity.x), ' lift=', snappedf(lift_ratio, 0.01))
		if frame > 20 and frame < 600: c["lift"] = 1.0
	if "drift" in OS.get_cmdline_user_args():                           # проверка гашения сноса: нос на -Z, скорость 400 м/с вбок
		c["thr"] = 0.0
		if frame == 5: ship.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 800.0, 0.0)); ship.linear_velocity = Vector3(400.0, 0.0, 0.0); hold_alt = 800.0
		if frame >= 5 and frame % 30 == 0 and frame < 400: print("DRIFT f=", frame, " vlat=", int(ship.global_transform.basis.x.dot(ship.linear_velocity)), " vvert=", int(ship.global_transform.basis.y.dot(ship.linear_velocity)), " y=", int(ship.global_position.y))
	if "roll" in OS.get_cmdline_user_args():                            # проверка самовыравнивания крена: крен 60°, нос вперёд
		c["thr"] = 0.0
		if frame == 5: ship.global_transform = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(60.0)), Vector3(0.0, 800.0, 0.0)); ship.linear_velocity = Vector3(0.0, 0.0, -200.0); hold_alt = 800.0
		if frame >= 5 and frame % 30 == 0 and frame < 400: print("ROLL f=", frame, " krenDeg=", int(rad_to_deg(asin(clampf(ship.global_transform.basis.x.y, -1.0, 1.0)))), " y=", int(ship.global_position.y))
	if "climb" in OS.get_cmdline_user_args():
		c["thr"] = 0.0
		if frame > 60 and frame < 360: c["lift"] = 1.0
	if "inv" in OS.get_cmdline_user_args():
		c["thr"] = 0.0
		if frame == 5: ship.global_transform = Transform3D(Basis(Vector3(0, 0, 1), PI), ship.global_position)
	if "att" in OS.get_cmdline_user_args():
		c["thr"] = 0.0; gravity_on = false; ship.gravity_scale = 0.0
		if frame < 60: c["gyro"] = Vector3(1, 0, 0)
		elif frame < 120: c["tr"] = Vector3(1, 0, 0)
		if frame == 59 or frame == 119:
			for nm in engines:
				if engines[nm]["kind"] == "shunt": print(nm, " flame_dir(local)=", (engines[nm]["pivot"] as Node3D).basis.y.normalized(), " f=", eng_force.get(nm)); break
			print("ang vel local=", ship.global_transform.basis.inverse() * ship.angular_velocity, " lin local=", ship.global_transform.basis.inverse() * ship.linear_velocity)
	if "shunt" in OS.get_cmdline_user_args():
		c["thr"] = 0.0; c["shl"] = Vector3(0, 0, -1); c["shr"] = Vector3(0, 0, -1)
		if frame == 5:
			ship.global_transform = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(70.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(20.0)), ship.global_position); gravity_on = false; ship.gravity_scale = 0.0
		if frame % 60 == 0: print("local v=", ship.global_transform.basis.inverse() * ship.linear_velocity, " world v=", ship.linear_velocity)
	return c

func _unstick() -> void:                                                    # вернуть корабль на трассу: назад по пути, в центр, горизонтально, без скорости; цена — штраф ко времени и лимит
	if not racing or p_fin or p_dsq or start_t > 0.0 or ui.state != "hud": return
	if unstick_cd > 0.0: msg_txt = "Возврат на трассу доступен через %d с" % int(ceil(unstick_cd)); msg_t = 1.5; ui.sfx.play("error"); return
	if unstick_n >= UNSTICK_MAX: msg_txt = "Лимит возвратов на трассу исчерпан"; msg_t = 2.0; ui.sfx.play("error"); return
	var tq := _tq3(ship.global_position.x, ship.global_position.z)
	var path := int(tq.z)
	var st: float = float(tq.y) - UNSTICK_BACK
	if s0 >= 0.0: st = maxf(st, s0 - 60.0)
	var at := _track_at_p(st, path)
	var pt: Vector2 = at[0]; var dr: Vector2 = at[1]
	var y := height(pt.x, pt.y) + 450.0
	var hd := Vector3(dr.x, 0.0, dr.y)
	if hd.length() < 0.1: hd = Vector3(0, 0, -1)
	ship.linear_velocity = Vector3.ZERO; ship.angular_velocity = Vector3.ZERO
	ship.global_transform = Transform3D(Basis.looking_at(hd.normalized(), Vector3.UP), Vector3(pt.x, y, pt.y))
	hold_alt = y; cam_snap = true; impact_cd = 1.0; prev_speed = 0.0; prev_v_c = Vector3.ZERO; acc_s = 0.0
	unstick_n += 1; unstick_cd = 10.0; race_t += UNSTICK_PENALTY
	msg_txt = "ВОЗВРАТ НА ТРАССУ   +%d с   (%d из %d)" % [int(UNSTICK_PENALTY), unstick_n, UNSTICK_MAX]; msg_t = 3.0
	ui.sfx.play("pop"); _log_event("UNSTICK %d s=%.0f" % [unstick_n, st])

func _disqualify() -> void:                                                 # заезд для игрока окончен: корабль зависает, показывается таблица, как на финише
	msg_t = 0.0; warn_label.visible = false
	p_dsq = true; rim_t = 0.0; hold_alt = ship.global_position.y; assist = true
	ui._show_state("results"); ui._update_results()

func _on_impact(pos: Vector3, power: float) -> void:
	if impact_cd > 0.0: return
	if ship_sfx != null: ship_sfx.impact(power)
	if power >= 10.0: _add_dent(ship.to_local(pos) / ship_sc, clampf(2.5 + power * 0.06, 2.5, 9.0))
	_log_event("IMPACT power=%d" % int(power))
	shake_imp = clampf(power / 80.0, 0.0, 1.6)
	if bool(cfg.get("rumble", true)):                                       # вибрация геймпада: сильнее от силы удара (на Windows работает, на Mac зависит от контроллера)
		for dev in Input.get_connected_joypads():
			Input.start_joy_vibration(dev, clampf(power / 160.0, 0.25, 0.9), clampf(power / 100.0, 0.35, 1.0), clampf(0.15 + power / 300.0, 0.15, 0.6))
	impact_cd = 0.25
	var local := ship.to_local(pos)
	var cand := []
	for n in parts: cand.append([(parts[n] as MeshInstance3D).position.distance_to(local), n])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var cnt := clampi(int(power / 25.0), 0, 4)
	for i in mini(cnt, cand.size()):
		if not parts.has(cand[i][1]): continue
		if cand[i][0] < 14.0 + power * 0.3: _detach(cand[i][1], (local - (parts[cand[i][1]] as MeshInstance3D).position).normalized() * -1.0)

var fx_tex_res: Texture2D
func _fx_tex() -> Texture2D:
	if fx_tex_res == null:
		var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new(); t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL; t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5); t.width = 64; t.height = 64
		fx_tex_res = t
	return fx_tex_res

# Мотор «выключен»: пластина свечения становится полностью прозрачной, ядро получает материал основной части мотора
func _dead_engine_look(mi: MeshInstance3D) -> void:
	if mi.mesh == null or evo_mode: return
	mi.material_overlay = null                                                # мёртвый мотор не светится
	var body: Material = null
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m != null and m.resource_name == "MAT_Engines": body = m; break
	var clear := StandardMaterial3D.new(); clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; clear.albedo_color = Color(1, 1, 1, 0.0)
	clear.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == null: continue
		if m.resource_name == "MAT_Engine_Glow": mi.set_surface_override_material(i, clear)
		elif m.resource_name == "MAT_Engine_Core":
			if body != null: mi.set_surface_override_material(i, body)
			else:
				var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.1, 0.1, 0.11); dm.roughness = 0.8; dm.metallic = 0.6; mi.set_surface_override_material(i, dm)

var smoke_tex_res: Texture2D
func _smoke_tex() -> Texture2D:                              # мягкое облако: радиальный спад × фрактальный шум
	if smoke_tex_res == null:
		var N := 128
		var nz := FastNoiseLite.new(); nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; nz.fractal_type = FastNoiseLite.FRACTAL_FBM; nz.fractal_octaves = 4; nz.frequency = 0.04; nz.seed = 11
		var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
		for y in N:
			for x in N:
				var d := Vector2(x - N * 0.5 + 0.5, y - N * 0.5 + 0.5).length() / (N * 0.5)
				var fall := pow(clampf(1.0 - d, 0.0, 1.0), 1.15)
				var v := clampf(0.55 + 0.75 * nz.get_noise_2d(x, y), 0.0, 1.0)
				var a := clampf(fall * v * 1.5, 0.0, 1.0)
				var c := 0.75 + 0.25 * v
				img.set_pixel(x, y, Color(c, c, c, a))
		smoke_tex_res = ImageTexture.create_from_image(img)
	return smoke_tex_res

func _curve_tex(pts: Array) -> CurveTexture:
	var cv := Curve.new()
	for p in pts: cv.add_point(Vector2(p[0], p[1]))
	var ct := CurveTexture.new(); ct.curve = cv; return ct

func _grad_tex(offs: Array, cols: Array) -> GradientTexture1D:
	var g := Gradient.new(); g.offsets = PackedFloat32Array(offs); g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new(); t.gradient = g; return t

# Дым и искры из места, где был мотор, и из задней стороны оторвавшегося мотора (GPU-частицы с турбулентностью)
func _spark_fx(parent: Node3D, pos: Vector3, dir: Vector3, life_s: float, k: float = 1.0, with_sparks: bool = true) -> void:
	if evo_mode: return
	var aabb := AABB(Vector3(-400, -400, -400), Vector3(800, 800, 800))
	# --- дым: крупные мягкие клубы, расширяются, закручиваются турбулентностью ---
	var smoke := GPUParticles3D.new(); var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 1.2
	pm.direction = dir; pm.spread = 20.0; pm.initial_velocity_min = 7.0; pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, 2.5, 0); pm.damping_min = 0.9; pm.damping_max = 1.8
	pm.scale_min = 5.0; pm.scale_max = 10.0; pm.scale_curve = _curve_tex([[0.0, 0.3], [0.35, 1.0], [1.0, 2.0]])
	pm.color_ramp = _grad_tex([0.0, 0.1, 0.55, 1.0], [Color(0.04, 0.04, 0.04, 0.0), Color(0.05, 0.05, 0.05, 0.95), Color(0.18, 0.17, 0.16, 0.75), Color(0.38, 0.36, 0.34, 0.0)])
	pm.angle_min = -180.0; pm.angle_max = 180.0; pm.angular_velocity_min = -22.0; pm.angular_velocity_max = 22.0
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 2.2; pm.turbulence_noise_scale = 2.4; pm.turbulence_noise_speed = Vector3(0.0, 0.4, 0.0); pm.turbulence_influence_min = 0.04; pm.turbulence_influence_max = 0.14
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; sm.billboard_keep_scale = true; sm.albedo_texture = _smoke_tex(); sm.vertex_color_use_as_albedo = true
	sm.proximity_fade_enabled = true; sm.proximity_fade_distance = 4.0; sm.no_depth_test = false
	var qs := QuadMesh.new(); qs.size = Vector2(1, 1); qs.material = sm
	smoke.process_material = pm; smoke.draw_pass_1 = qs; smoke.amount = maxi(12, int(100.0 * k)); smoke.lifetime = 5.4; smoke.local_coords = false
	smoke.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH; smoke.visibility_aabb = aabb; smoke.position = pos; smoke.fixed_fps = 0
	# --- искры: тонкие полоски по вектору скорости ---
	var sparks := GPUParticles3D.new(); var pm2 := ParticleProcessMaterial.new()
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm2.emission_sphere_radius = 0.6
	pm2.direction = dir; pm2.spread = 65.0; pm2.initial_velocity_min = 22.0; pm2.initial_velocity_max = 65.0; pm2.gravity = Vector3(0, -14.0, 0)
	pm2.scale_min = 0.5; pm2.scale_max = 1.0; pm2.particle_flag_align_y = true
	pm2.color_ramp = _grad_tex([0.0, 0.35, 1.0], [Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.4, 0.07, 0.0, 0.0)])
	var spm := StandardMaterial3D.new(); spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; spm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; spm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; spm.billboard_keep_scale = true; spm.vertex_color_use_as_albedo = true; spm.albedo_texture = _fx_tex()
	var qp := QuadMesh.new(); qp.size = Vector2(0.18, 1.6); qp.material = spm
	sparks.process_material = pm2; sparks.draw_pass_1 = qp; sparks.amount = maxi(6, int(30.0 * k)); sparks.lifetime = 0.9; sparks.local_coords = false
	sparks.visibility_aabb = aabb; sparks.position = pos
	parent.add_child(smoke)
	smoke.emitting = true
	if with_sparks: parent.add_child(sparks); sparks.emitting = true
	if life_s <= 0.0: return                                                   # life_s = 0: дымит до конца заезда (корабль, потерявший мотор, и «Фрея»)
	var tm := get_tree().create_timer(life_s)
	tm.timeout.connect(func():
		if is_instance_valid(smoke): smoke.emitting = false
		if is_instance_valid(sparks): sparks.emitting = false
		await get_tree().create_timer(5.5).timeout
		if is_instance_valid(smoke): smoke.queue_free()
		if is_instance_valid(sparks): sparks.queue_free())

func _detach(nm: String, dir: Vector3 = Vector3.ZERO) -> void:
	if not parts.has(nm): return
	if ship_sfx != null: ship_sfx.part_lost(nm)
	_log_event("DETACH " + nm)
	var mi: MeshInstance3D = parts[nm]; parts.erase(nm)
	if nm.begins_with("SM_Wing_"):                      # вместе с верхним крылом отлетают его маневровый и верхний прожектор, с нижним — его маневровый
		var tag := nm.substr(nm.length() - 2)
		var top := nm.begins_with("SM_Wing_Top")
		for other in parts.keys():
			if other.ends_with(tag) and ((top and (other.begins_with("SM_Engine_Shunt_Top") or other.begins_with("SM_Spotlight_Top"))) or (not top and other.begins_with("SM_Engine_Shunt_Bot"))): _detach(other, dir)
	var fx_info: Dictionary = {}
	if engines.has(nm):
		(engines[nm]["pivot"] as Node3D).visible = false
		var en = engines[nm]
		var ed: Vector3 = en["dir"] if (en["dir"] as Vector3).length() > 0.01 else Vector3.UP
		fx_info = {"spos": en["pos"], "sdir": (mi.transform.basis * ed).normalized(), "cen": en["cen"], "ldir": ed.normalized(), "ext": en["ext"]}
		_dead_engine_look(mi)
	var rb := RigidBody3D.new(); rb.mass = 800.0 if nm.begins_with("SM_Engine") or nm.begins_with("SM_Wing") else 100.0
	rb.collision_layer = 2; rb.collision_mask = 1 | 2; rb.gravity_scale = 1.0 if gravity_on else 0.0
	get_tree().current_scene.add_child(rb)
	rb.global_transform = mi.global_transform
	var shp: Shape3D
	if shapes.has(nm):
		shp = (shapes[nm] as CollisionShape3D).shape; shapes[nm].queue_free(); shapes.erase(nm)
	else:
		var ab := mi.get_aabb(); var bx := BoxShape3D.new(); bx.size = ab.size.max(Vector3.ONE * 0.1) * ship_sc; shp = bx
	var cs := CollisionShape3D.new(); cs.shape = shp; rb.add_child(cs)
	mi.get_parent().remove_child(mi); mi.transform = Transform3D.IDENTITY; rb.add_child(mi)
	rb.linear_velocity = ship.linear_velocity + ship.global_transform.basis * (dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)) * 12.0
	rb.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 3.0
	debris.append(rb)
	if not fx_info.is_empty():
		_spark_fx(ship, fx_info["spos"], fx_info["sdir"], 0.0, 1.0)                                  # из корабля, где был мотор
		var back: Vector3 = (fx_info["cen"] as Vector3) - (fx_info["ldir"] as Vector3) * ((fx_info["ext"] as Vector3).dot((fx_info["ldir"] as Vector3).abs()) * 0.5)
		_spark_fx(rb, back, -(fx_info["ldir"] as Vector3), 10.0, 0.8)                                  # из тыльной стороны оторвавшегося мотора
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(rb): rb.collision_mask = 1 | 2 | 8

func _update_engines() -> void:
	for nm in engines:
		var e = engines[nm]
		if not parts.has(nm): continue
		var p := 0.0
		var d: Vector3 = e["dir"]
		var kind: String = e["kind"]
		if kind == "main": p = thr
		elif kind == "lift": p = clampf(lift_ratio * 2.2, 0.0, 1.0)
		else:
			var f: Vector3 = eng_force.get(nm, Vector3.ZERO)
			p = clampf(f.length() * (1.8 if kind == "nose" else 0.45), 0.0, 1.0)
			d = -f.normalized() if f.length() > 0.02 else Vector3.DOWN      # струя бьёт против силы
		var pivot: Node3D = e["pivot"]
		var L := 0.5 + p * (28.0 if kind == "main" else 9.0 if kind == "lift" else 15.0)
		if kind == "shunt" or kind == "nose": L = 1.0 + p * 15.0                           # маневровые: длинные тонкие быстрые струи
		var r: float = e["r"] * (0.55 if (kind == "shunt" or kind == "nose") else 1.0)
		if d.length() > 0.01:
			pivot.basis = Basis(Quaternion(Vector3.UP, d.normalized())) * Basis.from_scale(Vector3(r, L, r))
		(e["fmat"] as ShaderMaterial).set_shader_parameter("power", p)
		for mt in e["mats"]: (mt as ShaderMaterial).set_shader_parameter("power", p)

func _set_tech(on: bool) -> void:
	tech_open = on; tune.root.visible = on
	if not on: get_viewport().gui_release_focus(); tune.save_file()
	_sync_time_scale()

func _sync_time_scale() -> void:
	Engine.time_scale = 0.0 if (tech_open or menu_open or (ui != null and ui.blocking())) else 1.0

func _process(dt: float) -> void:
	if Engine.get_process_frames() == 400 and "reloadtest" in OS.get_cmdline_user_args() and not Engine.has_meta("rt_done"):          # проверка перезапуска с экраном загрузки
		Engine.set_meta("rt_done", true); reload_title = "Возврат в главное меню"; _reset()
	if "reloadtest" in OS.get_cmdline_user_args() and Engine.has_meta("rt_done") and Engine.get_process_frames() == 1500:
		get_viewport().get_texture().get_image().save_png("/private/tmp/after_reload.png"); print("AFTER visible=", loading.visible, " state=", ui.state); get_tree().quit()
	if soak: _soak_frame(dt)
	if ui_shot != "":                                                          # снимки экранов интерфейса: -- uishot=menu|pause|hud|results
		var pf := Engine.get_process_frames()
		if pf == 20:
			match ui_shot:
				"menu":
					ui.open_menu()
					for ma in OS.get_cmdline_user_args():
						if ma.begins_with("msel="): ui.sel = int(ma.substr(5)); ui._refresh_items()
				"pause": ui.open_pause()
				"results": p_fin = true; p_fin_t = 71.4; rank = 3; ui._show_state("results"); ui._update_results()
		if pf == 20 and ui_shot.begins_with("page_"):
			ui.open_menu(); cfg["level"] = 2; ui.goto_page(ui_shot.substr(5).replace("_", ":"))
		if pf == 20 and ui_shot == "results": for b in bots: b["name"] = "Маленькое Стремительное Копье" if b["name"] == "Аргамак" else b["name"]
		if ui_shot == "tilebench" and pf == 5:
			var tk := track_tiles.keys(); var t0 := Time.get_ticks_msec()
			for q in 100: _gen_tile(Vector3i(tk[q * 7 % tk.size()].x, tk[q * 7 % tk.size()].y, 1))
			var t1 := Time.get_ticks_msec(); var t2 := t1
			for q in 20: _gen_tile(Vector3i(tk[q * 7 % tk.size()].x, tk[q * 7 % tk.size()].y, 0))
			print("TILEBENCH tiles=", tk.size(), " lod1_ms_per=", (t1 - t0) / 100.0, " lod0_ms_per=", (Time.get_ticks_msec() - t2) / 20.0, " cores=", OS.get_processor_count()); get_tree().quit()
		if ui_shot == "dump" and pf == 5:
			var dd := {"main": [], "cuts": [], "needle": [], "len": trk_len, "race": race_len, "s0": s0}
			for i in range(0, trk_pts.size(), 2): dd["main"].append([trk_pts[i].x, trk_pts[i].y])
			for br in branches:
				var arr := []; for p in (br["pts"] as PackedVector2Array): arr.append([p.x, p.y])
				dd["cuts"].append({"pts": arr, "type": br["type"], "in": br["in"], "out": br["out"], "needle_s": br["needle_s"]})
				if float(br["needle_s"]) > 0.0:
					var nf := _track_at_p(float(br["needle_s"]), branches.find(br) + 1); dd["needle"].append([(nf[0] as Vector2).x, (nf[0] as Vector2).y])
			var fdd := FileAccess.open("/private/tmp/track_dump.json", FileAccess.WRITE); fdd.store_string(JSON.stringify(dd)); fdd.close(); get_tree().quit()
		if ui_shot == "intro":                                                     # проверка вступления: отсчёт от позиции трека, кадры катсцены
			if pf == 20: AudioServer.set_bus_mute(0, true); ui._start_race()
			if pf == 700 and OS.get_cmdline_user_args().has("skiptest"): skip_intro()
			if pf >= 20 and pf % 120 == 0: print("INTRO pf=", pf, " start_t=", snappedf(start_t, 0.001), " pos=", snappedf(music.intro_pos(), 0.001), " racing=", racing, " cut=", in_cutscene(), " y=", int(ship.global_position.y), " v=", int(ship.linear_velocity.length()))
			for tt in [[1.0, "a"], [3.0, "b"], [5.0, "c"], [10.0, "d"], [14.4, "e"], [15.8, "f"], [17.2, "g"], [18.5, "h"], [20.3, "i"], [23.0, "j"], [26.5, "k"]]:
				if intro_on and absf(INTRO_T - start_t - float(tt[0])) < 0.012 and not FileAccess.file_exists("/private/tmp/intro_%s.png" % tt[1]): get_viewport().get_texture().get_image().save_png("/private/tmp/intro_%s.png" % tt[1])
			if racing and pf > 100: print("INTRO racing at pf=", pf); get_tree().quit()
		if ui_shot == "padlog":                                                     # снимает сырые оси и итоговые команды вращения при ручном управлении
			if pf == 20: AudioServer.set_bus_mute(0, true); ui._show_state("hud"); start_t = 0.0; racing = true; assist = true
			if pf >= 60 and pf % 30 == 0 and pf < 2400:
				var cg: Vector3 = last_ctrl.get("gyro", Vector3.ZERO)
				print("PL pf=", pf, " raw L=", snappedf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), 0.001), ",", snappedf(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y), 0.001), " LB=", Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER), " RB=", Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER), " gyro=", snappedf(cg.x, 0.001), ",", snappedf(cg.y, 0.001), ",", snappedf(cg.z, 0.001), " dz=", cfg["deadzone"], " lvl=", cfg["level"], " assist=", assist, " av=", snappedf(ship.angular_velocity.length(), 0.001), " pads=", Input.get_connected_joypads().size())
			if pf == 2400: get_tree().quit()
		if ui_shot.begins_with("padtest"):                                          # проверка стабилизации: padtest_roll / _yaw / _pitch; команда 1 с, потом отпускаем
			var what := ui_shot.substr(8)
			if pf == 20: ui._show_state("hud"); start_t = 0.0; racing = true; cfg["level"] = 0; assist = true
			if pf == 21: pad_fake = {"x": 0}
			if pf == 200 and what == "level": ship.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(40.0))
			if pf == 200: pad_fake = {("pitch_up:a" if what == "pitch" else what + "_left:a"): 0.7} if what != "yaw" else {"yaw_left:b": 1.0}
			if pf == 320: pad_fake = {"x": 0}
			if pf >= 180 and pf % 20 == 0 and pf <= 800:
				var avl: Vector3 = ship.global_transform.basis.inverse() * ship.angular_velocity
				print("PT ", what, " pf=", pf, " av=", snappedf(avl.x, 0.001), ",", snappedf(avl.y, 0.001), ",", snappedf(avl.z, 0.001), " bank=", snappedf(rad_to_deg(asin(clampf(ship.global_transform.basis.x.y, -1.0, 1.0))), 0.1), " assist=", assist, " scheme=", scheme)
			if pf == 800: get_tree().quit()
		if ui_shot == "tour": _tour_step(pf)
		if ui_shot == "cutcam": _cutcam_step(pf)
		if ui_shot == "spurcam": _spurcam_step(pf)
		if ui_shot == "cutship": _cutship_step(pf)
		if ui_shot == "gridcam": _gridcam_step(pf)
		if ui_shot == "liverycam": _liverycam_step(pf)
		if ui_shot == "shippic": _shippic_step(pf)
		if ui_shot == "shipswap":                                              # проверка выбора корабля в меню: переключить на Фрею, сцена пересоберётся, выбор в меню сохранится
			if pf == 30 and not Engine.has_meta("swapped"):
				Engine.set_meta("swapped", true); ui.open_menu(); ui.sel = 2; ui._change_ship(1)
			if pf == 3 and Engine.has_meta("swapped"): ui.open_menu(); ui.sel = int(Engine.get_meta("menu_sel")) if Engine.has_meta("menu_sel") else 0
			if pf == 90 and Engine.has_meta("swapped"): print("SWAP ship_id=", ship_id, " cfg=", cfg["ship"], " sel=", ui.sel); get_viewport().get_texture().get_image().save_png("/private/tmp/shipswap.png"); cfg["ship"] = 0; _save_cfg(); get_tree().quit()
		if ui_shot == "cutwidth" and pf == 5: _cutwidth(); get_tree().quit()
		if ui_shot == "tmap" and pf == 5: _tmap_dump(); get_tree().quit()
		if ui_shot == "hatchcam":
			if pf == 20:
				var hv := [-22.0, 1.0, 10.6, -11.9, 0.97, 10.6]
				for a in OS.get_cmdline_user_args(): if a.begins_with("v="): hv = Array(a.substr(2).split(",")).map(func(x): return float(x))
				var cp0 := ship.global_transform * Vector3(hv[0], hv[1], hv[2]); var tp0 := ship.global_transform * Vector3(hv[3], hv[4], hv[5])
				cc_tf = Transform3D(Basis.IDENTITY, cp0).looking_at(tp0, Vector3.UP); cc_on = true; ui.visible = false
			if pf == 60:
				var outp := "/private/tmp/hatchcam.png"
				for a in OS.get_cmdline_user_args(): if a.begins_with("out="): outp = a.substr(4)
				get_viewport().get_texture().get_image().save_png(outp); get_tree().quit()
		if ui_shot == "fin":
			if pf == 20: ui._show_state("hud"); start_t = 0.0; racing = true; Engine.time_scale = 1.0
			if pf == 40:
				ship.linear_velocity = -ship.global_transform.basis.z * 2400.0
				p_fin = true; p_fin_t = race_t; hold_alt = ship.global_position.y; assist = true
			if pf >= 40 and pf % 40 == 0: print("FIN pf=", pf, " v=", int(ship.linear_velocity.length()), " y=", int(ship.global_position.y), " z=", int(ship.global_position.z), " parts=", parts.size(), " state=", ui.state)
			if pf == 700: get_tree().quit()
		if ui_shot == "flowpad":
			if pf == 20: ui.open_menu()
			if pf == 40:
				var e := InputEventJoypadButton.new(); e.device = 0; e.button_index = JOY_BUTTON_A; e.pressed = true; Input.parse_input_event(e)
				print("INJECT A pf=", pf, " accept_pressed=", Input.is_action_pressed("ui_accept"))
			if pf == 42:
				print("AFTER pf=", pf, " accept_pressed=", Input.is_action_pressed("ui_accept"), " just=", Input.is_action_just_pressed("ui_accept"))
			if pf == 41: print("PF41 just=", Input.is_action_just_pressed("ui_accept"), " pressed=", Input.is_action_pressed("ui_accept"))
			if pf == 60:
				for an in ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right", "menu", "assist", "mark"]:
					var es := []
					for ev3 in InputMap.action_get_events(an): es.append(ev3.as_text())
					print("ACT ", an, " -> ", es)
				print("PADS ", Input.get_connected_joypads(), " names=", Input.get_connected_joypads().map(func(d): return Input.get_joy_name(d)))
			if pf == 120: print("STATE ", ui.state, " ts=", Engine.time_scale, " start_t=", start_t); get_tree().quit()
		if ui_shot == "unstick":                                                   # проверка возврата на трассу и дисквалификации: -- uishot=unstick [dsq]
			if pf == 40: ui._show_state("hud"); start_t = 0.0; racing = true; ship.global_position = ship.global_position + Vector3(0, 0, -6000.0); ship.linear_velocity = Vector3(0, 0, -300.0)
			if pf == 70: print("UNSTICK before pos=", ship.global_position, " v=", ship.linear_velocity.length(), " prog=", int(p_prog), " race_t=", race_t); _unstick()
			if pf == 75: print("UNSTICK after pos=", ship.global_position, " v=", ship.linear_velocity.length(), " prog=", int(p_prog), " race_t=", race_t, " n=", unstick_n, " fwd=", -ship.global_transform.basis.z, " up=", ship.global_transform.basis.y)
			if pf == 80 and "dsq" in OS.get_cmdline_user_args(): _disqualify()
			if pf == 100: get_viewport().get_texture().get_image().save_png("/private/tmp/ui_unstick.png"); get_tree().quit()
		if ui_shot == "flow":
			if pf == 20: ui.open_menu()
			if pf == 40: ui.sel = 0; ui._activate()
			if pf % 60 == 0 and pf >= 40: print("FLOW pf=", pf, " state=", ui.state, " start_t=", snappedf(start_t, 0.1), " race_t=", snappedf(race_t, 0.1), " v=", int(ship.linear_velocity.length()), " ts=", Engine.time_scale)
			if pf == 400: get_tree().quit()
		if pf == 70 and ui_shot != "spurcam" and ui_shot != "hatchcam" and ui_shot != "flow" and ui_shot != "flowpad" and ui_shot != "fin" and ui_shot != "tour" and ui_shot != "dump" and ui_shot != "intro" and not ui_shot.begins_with("padtest") and ui_shot != "padlog" and ui_shot != "tilebench" and ui_shot != "cutcam" and ui_shot != "cutwidth" and ui_shot != "cutship" and ui_shot != "gridcam" and ui_shot != "liverycam" and ui_shot != "shipswap" and ui_shot != "unstick":
			var shot_sfx := ""                                                         # -- hudmock=N: снимок «ui_hud_mN.png», чтобы сценарии можно было снимать параллельно
			for ua in OS.get_cmdline_user_args(): if ua.begins_with("hudmock="): shot_sfx = "_m" + ua.substr(8)
			get_viewport().get_texture().get_image().save_png("/private/tmp/ui_" + ui_shot + shot_sfx + ".png"); get_tree().quit()
	if "tech" in OS.get_cmdline_user_args() and frame >= 40 and tech_shot_n == 0 and not tech_open: _set_tech(true)
	var esc := Input.is_key_pressed(KEY_ESCAPE)
	if Input.is_action_just_pressed("tech") or (tech_open and esc and not esc_prev):
		_set_tech(not tech_open); esc_prev = esc; return
	if tech_open:
		esc_prev = esc
		if "tech" in OS.get_cmdline_user_args():
			tech_shot_n += 1
			if tech_shot_n == 12:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("/private/tmp/shot_tech.png"); get_tree().quit()
		return
	if ui.capturing == "":
		if Input.is_action_just_pressed("menu") and ui.state == "pause": ui.close_pause()
		elif (Input.is_action_just_pressed("menu") or (esc and not esc_prev)) and ui.state == "hud": ui.open_pause()
	esc_prev = esc
	menu_label.visible = false
	var live: bool = ui.state == "hud"
	var sp := ship.linear_velocity.length()
	if impact_cd <= 0.0 and prev_speed - sp > 12.0 and frame - last_contact_f <= 24:
		var dv: Vector3 = ship.linear_velocity - prev_vel                          # толчок направлен от стенки: точка удара на противоположной стороне корпуса
		var hp: Vector3 = ship.global_position
		if dv.length() > 1.0:
			var ld: Vector3 = (ship.global_transform.basis.inverse() * (-dv)).normalized()
			var ex: Vector3 = hull_aabb.size * 0.5
			var tt: float = 1e9
			for ax in 3:
				if absf(ld[ax]) > 0.001: tt = minf(tt, ex[ax] / absf(ld[ax]))
			hp = ship.to_global(hull_aabb.get_center() + ld * tt * 0.9)
		_on_impact(hp, (prev_speed - sp) * 1.2)
	prev_speed = sp; prev_vel = ship.linear_velocity
	if live and Input.is_action_just_pressed("cam"): cam_mode = (cam_mode + 1) % CAM_MODES.size()
	if live and Input.is_action_just_pressed("scheme"): scheme = 1 - scheme
	if live and Input.is_action_just_pressed("help"): help.visible = not help.visible; hud.visible = help.visible
	if live and Input.is_action_just_pressed("mark"): _log_event("MARK")
	if live and Input.is_action_just_pressed("grav"):
		gravity_on = not gravity_on; ship.gravity_scale = 1.0 if gravity_on else 0.0
	if live and Input.is_action_just_pressed("assist"): assist = not assist
	if live and Input.is_action_just_pressed("detach") and not parts.is_empty(): _detach(parts.keys().pick_random(), Vector3(randf() - 0.5, 0.5, randf() - 0.5))
	if live and Input.is_action_just_pressed("boom"): p_boom = true; for n in parts.keys(): _detach(n, Vector3(randf() - 0.5, 0.5, randf() - 0.5))
	if live and Input.is_action_just_pressed("reset"): reload_title = "Сброс на старт"; _reset()
	if live and Input.is_action_just_pressed("unstick"): _unstick()
	if live and in_cutscene() and Input.is_action_just_pressed("ui_accept"): skip_intro()
	if live and Input.is_action_just_pressed("interior"):
		interior_vis = not interior_vis; _apply_interior()
	if start_t > 0.0:
		var ip: float = music.intro_pos() if intro_on else -1.0
		if ip >= 0.0: start_t = maxf(INTRO_T - ip, 0.0)               # отсчёт привязан к позиции трека: рифф ровно в момент старта
		else: start_t -= dt
		if intro_on and not intro_skipped and not intro_seen and start_t <= INTRO_T - INTRO_CUT: intro_seen = true; ui.cutscene_seen()
		if start_t <= 0.0:
			racing = true
			if intro_on: intro_on = false; music.race_started()
	if racing: race_t += dt
	# запретная зона по высоте: границы не видно и не бьёт, но надо выйти за RIM_GRACE секунд
	if ship.global_position.y > RIM_Y and not soak and not p_dsq and dsq_t <= 0.0:       # после дисквалификации (и пока идёт её отсчёт) время выше потолка больше не копится
		rim_t += dt
		if racing: p_rim_ever = true
	else: rim_t = maxf(0.0, rim_t - dt * 2.0)
	if dsq_t > 0.0:
		dsq_t -= dt
		warn_label.visible = true; warn_label.text = "ДИСКВАЛИФИКАЦИЯ"
		if dsq_t <= 0.0: _disqualify()
	elif msg_t > 0.0:
		msg_t -= dt; warn_label.visible = false                                    # сообщение рисует HUD (hud_widgets.gd, полоса внизу)
	elif rim_t > 0.0:
		warn_label.visible = false                                                  # тревогу потолка рисует HUD (hud_widgets.gd)
		if rim_t >= RIM_GRACE and not p_dsq and not p_fin: dsq_t = 3.0; rim_t = 0.0; _log_event("DISQUALIFIED rim")
	else: warn_label.visible = false
	var pq := _track_query(ship.global_position.x, ship.global_position.z)
	var prel := _rel_s(pq.y)
	if racing and not p_fin and _tq3(ship.global_position.x, ship.global_position.z).z > 0.5: p_side = true
	if p_last_s < 0.0: p_rel = prel; p_prog = prel; p_last_s = 0.0
	p_prog = _acc_prog(p_prog, p_rel, prel); p_rel = prel
	var pprog := p_prog
	lap = int(floor(pprog / trk_len)) if pprog > 0.0 else -1
	if not p_fin and not p_dsq and pprog >= race_len: p_fin = true; p_fin_t = race_t; hold_alt = ship.global_position.y; assist = true      # дальше корабль сам тормозит и зависает
	rank = 1
	for b in bots:
		if p_fin:
			if b["fin"] and float(b["fin_t"]) < p_fin_t: rank += 1
		elif b["fin"] or _bot_progress(b) > pprog: rank += 1
	chunk_tick += 1
	if chunk_tick % 4 == 0: _update_chunks(6)
	else: _build_ready(6, 3500)
	_depenetrate(dt)
	_update_engines()
	_camera(dt)
	var h := ship.global_position.y
	var padn := Input.get_connected_joypads().size()
	hud.text = "Скорость %d м/с (%d км/ч)   Высота %d м (держим %d)   Газ %d%% (тяга %d м/с²)   Взлётные %.1f g\nСхема %s   Стабилизация вращения %s   Гравитация %s   Геймпад %s   Снос %+d°   Крен %+d°\nПозиция %d/%d   Круг %d   Время %.1f с   Деталей %d   Камера %s   Уровень %s%s" % [
		ship.linear_velocity.length(), ship.linear_velocity.length() * 3.6, h, hold_alt, thr * 100.0, P("main_acc") * thr, lift_ratio * P("lift_max"), "1 (всё через хвостовые маневровые)" if scheme == 0 else "2 (два джойстика)", "вкл" if assist else "выкл", "вкл" if gravity_on else "выкл", "найден" if padn > 0 else "нет", int(_slip()), int(rad_to_deg(asin(clampf(ship.global_transform.basis.x.y, -1.0, 1.0)))),
		rank, bots.size() + 1, maxi(lap + 1, 1), race_t, parts.size(), CAM_MODES[cam_mode], LEVEL_NAMES[_lvl()], ("\nСТАРТ через %d" % int(ceil(start_t)) if start_t > 0.0 else "") + ("\nФИНИШ! время %.1f с, место %d" % [p_fin_t, rank] if p_fin else "")]
	help.text = _help_text()
	if shot_mode and "detshot" in OS.get_cmdline_user_args() and frame >= 20 and not det_done:
		det_done = true
		for n2 in ["SM_Engine_Traction_Main", "SM_Engine_Traction_L", "SM_Engine_Shunt_Top_L", "SM_Engine_TakeOff_Back_L2"]: _detach(n2, Vector3(0, 0, 1))
	if shot_mode and frame >= (560 if "detshot" in OS.get_cmdline_user_args() else 40):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/shot_" + CAM_MODES[cam_mode] + ".png"); get_tree().quit()

var cam_rel := Vector3(0, 22, 85)
var cam_up := Vector3.UP
var cam_p := Vector3.ZERO
var cam_v := Vector3.ZERO

var intro_picks: Array = []
var intro_u := 99.0
func _intro_cam(u: float) -> void:                                          # u = секунды от начала трека: 0–7 общий план трассы, 7–13.75 облёт решётки, 13.75–21 быстрые пролёты у случайных кораблей, в конце наш
	var o := ship.global_position
	var c := o
	for b in bots: c += (b["rb"] as RigidBody3D).global_position
	c /= float(bots.size() + 1)
	var f := -ship.global_transform.basis.z; f.y = 0.0; f = f.normalized()
	var r := f.cross(Vector3.UP).normalized() * -1.0
	if intro_picks.size() < 4:
		intro_picks = range(bots.size()); intro_picks.shuffle()
	var pos: Vector3; var look := c; var fov := 70.0
	intro_u = u
	if u < 13.757:
		var t := u / 13.757; var a := lerpf(0.5, 1.9, t)
		pos = c + (r * sin(a) - f * cos(a)) * lerpf(330.0, 230.0, t) + Vector3.UP * lerpf(60.0, 35.0, t)
	elif u < 19.2:                                                           # 4 коротких пролёта рядом со случайными кораблями
		var k := mini(int((u - 13.757) / 1.36), 3); var t := fmod(u - 13.757, 1.36) / 1.36
		var tb := (bots[int(intro_picks[k]) % bots.size()]["rb"] as RigidBody3D).global_position
		if world_env != null: world_env.fog_density = FOG_BASE
		if k % 2 == 1:                                                       # сзади: камера догоняет корабль и проскакивает сбоку
			pos = tb - f * lerpf(95.0, 25.0, t) + r * lerpf(-30.0, 38.0, t) * (1.0 if k == 1 else -1.0) + Vector3.UP * (9.0 + 6.0 * t)
			look = tb + f * 40.0
		else:
			var a := lerpf(-0.9, 0.9, t) * (1.0 if k == 0 else -1.0) + (0.0 if k == 0 else 1.57)
			pos = tb + (r * cos(a) + f * sin(a) * 1.4) * lerpf(70.0, 48.0, t) + Vector3.UP * (10.0 + 8.0 * t)
			look = tb
		fov = 62.0 + 10.0 * t
	else:                                                                    # финал: наш корабль, камера заходит ему за корму — как в гонке
		var t := smoothstep(0.0, 1.0, (u - 19.2) / 1.8)
		var a := lerpf(0.6, PI, t)
		pos = o + (r * sin(a) + f * cos(a)) * lerpf(70.0, 85.0, t) + Vector3.UP * lerpf(10.0, 22.0, t)
		look = o + f * 60.0 * t + Vector3.UP * (3.0 + 3.0 * t)
	pos.y = maxf(pos.y, height(pos.x, pos.z) + 15.0)
	cam.global_transform = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)
	cam.fov = fov

func _track_stats(dt: float) -> void:                                       # учёт заезда для достижений
	if not racing or p_fin or p_dsq or start_t > 0.0 or ui == null or ui.state != "hud" or evo_mode or test_mode or soak: return
	if p_parts0 < 0: p_parts0 = parts.size(); p_prev_prog = p_prog
	var d := p_prog - p_prev_prog; p_prev_prog = p_prog
	if absf(d) < 600.0:
		if d < 0.0: p_back += -d
		var bs := ship.global_transform.basis
		if absf(rad_to_deg(atan2(bs.x.y, bs.y.y))) > 60.0: p_bank_dist += absf(d)
	p_max_y = maxf(p_max_y, ship.global_position.y)
	var sp := ship.linear_velocity.length(); p_max_v = maxf(p_max_v, sp); race_dist += sp * dt
	if CAM_MODES[cam_mode] != "cockpit": p_cam_ck = false
	for b in ship.get_colliding_bodies():
		if b != null and String(b.name).begins_with("Bot"): ui.grant("aggressor")
	if p_back >= 20000.0: ui.grant("lost3")
	if p_max_v >= 3000.0: ui.grant("speed")
	if unstick_n >= UNSTICK_MAX: ui.grant("unstick3")
	if parts.is_empty() and not p_boom: ui.grant("crash_total"); ui.ship_wrecked(ship_id)

func _add_dent(po: Vector3, r: float) -> void:                            # вмятина на обшивке игрока (только вид: коллизии не меняются)
	var merged := false
	for i in dents.size():
		var d: Vector4 = dents[i]
		if Vector3(d.x, d.y, d.z).distance_to(po) < d.w * 0.6:                    # рядом уже есть вмятина: она растёт
			dents[i] = Vector4(d.x, d.y, d.z, minf(d.w + r * 0.35, 16.0)); merged = true; break
	if not merged:
		if dents.size() >= 8: dents.pop_front()
		dents.append(Vector4(po.x, po.y, po.z, r))
	var arr := PackedVector4Array(); arr.resize(8)
	for i in dents.size(): arr[i] = dents[i]
	for m in hull_mats:
		(m as ShaderMaterial).set_shader_parameter("dents", arr); (m as ShaderMaterial).set_shader_parameter("dent_n", float(dents.size()))

func _apply_interior() -> void:
	for n in ship.get_children():
		if n is MeshInstance3D and (n.name.begins_with("SM_Cabin") or n.name.begins_with("SM_Cargo") or n.name.begins_with("SM_Corridor") or n.name.begins_with("SM_Room")): n.visible = interior_vis

func _cockpit_eye() -> Vector3:                                           # глаза пилота: по центру мостика над спинками кресел, в координатах корабля
	var sn := ship.get_node_or_null("SM_Cabin_Seats") as MeshInstance3D
	if sn == null: return Vector3(0, 0, -20)
	var b: AABB = sn.transform * sn.get_aabb()
	return Vector3(0.0, b.end.y + 0.25, b.position.z + b.size.z * 0.55)

func _cam_tail(dt: float) -> void:                                          # угол обзора и тряска: общие для всех видов
	cam.fov = 70.0 + 25.0 * clampf(ship.linear_velocity.length() / P("max_speed"), 0.0, 1.0)
	shake_imp = maxf(0.0, shake_imp - dt * 1.4)
	var sk := P("cam_shake")
	if sk > 0.001 and frame > 3 and ui.state != "menu":                         # тряска камеры: от тяги, скорости и ударов
		var tt := Time.get_ticks_msec() * 0.001
		var hp := ship_health()
		var kth: float = float(SHAKE_SHIP_K[ship_id]) * lerpf(SHAKE_HEALTH_MIN, 1.0, hp)     # чем сильнее корабль разбит, тем ниже порог
		var a_amp := 0.0 if (p_fin or p_dsq) else clampf((acc_s - SHAKE_ACC0 * kth) / ((SHAKE_ACC1 - SHAKE_ACC0) * kth), 0.0, 1.0)
		var amp := (a_amp * 0.8 + shake_imp) * sk * (1.0 + (1.0 - hp) * 1.2)             # и сильнее колбасит
		if amp > 0.001:
			var off2 := Vector3(sin(tt * 83.0), sin(tt * 67.0 + 1.7), sin(tt * 97.0 + 0.4)) * 0.5 * amp
			cam.global_position += cam.global_transform.basis * off2
			cam.rotate_object_local(Vector3.FORWARD, sin(tt * 53.0) * 0.004 * amp)

func _camera(dt: float) -> void:
	if (ui_shot == "cutcam" or ui_shot == "hatchcam" or ui_shot == "spurcam" or ui_shot == "cutship" or ui_shot == "gridcam" or ui_shot == "liverycam" or ui_shot == "shippic") and cc_on: cam.global_transform = cc_tf; cam.fov = cc_fov; return
	var t := ship.global_transform
	if ui_shot == "tour" and tour_ready:                                      # режим съёмки: камера за ботом
		if tour_phase == "fixed_wait": cam.global_transform = fixed_cam; return
		var tb: Dictionary = bots[tour_bot]; var trb := tb["rb"] as RigidBody3D
		var tfw := -trb.global_transform.basis.z
		var cpos := trb.global_position - tfw * 190.0 + Vector3(0, 55, 0)
		cam.global_transform = Transform3D(Basis.IDENTITY, cpos).looking_at(trb.global_position + tfw * 260.0, Vector3.UP); return
	if intro_on and start_t > INTRO_T - INTRO_CUT:                           # катсцена под вступление: облёт стартовой решётки
		cam_snap = true; _intro_cam(INTRO_T - start_t); return
	if ui != null and ui.state == "menu":                                    # главное меню: камера медленно облетает корабль
		var ya := Time.get_ticks_msec() / 1000.0 * 0.22
		var cp := t.origin + Vector3(sin(ya) * 125.0, 22.0, cos(ya) * 125.0)
		var look := t.origin + Vector3(0, 2, 0)
		var rgt := Vector3(cp.z - t.origin.z, 0.0, -(cp.x - t.origin.x)).normalized()
		cam.global_transform = Transform3D(Basis.IDENTITY, cp).looking_at(look - rgt * 46.0, Vector3.UP); return        # корабль смещён вправо от тёмной панели меню
	if CAM_MODES[cam_mode] == "cockpit":                                     # вид из кабины: камера жёстко закреплена на корабле
		if not interior_vis: interior_vis = true; _apply_interior()
		var tgt := Vector2(-look_in.x * LOOK_YAW, -look_in.y * LOOK_PITCH)          # стик вправо — взгляд вправо, вверх — вверх
		var kl := 1.0 - exp(-minf(dt, 0.1) * (9.0 if look_in.length() > 0.01 else 3.5))      # за стиком быстро, обратно к «вперёд» плавно
		look_cur = look_cur.lerp(tgt, kl)
		cam.global_transform = Transform3D(t.basis * Basis.from_euler(Vector3(look_cur.y, look_cur.x, 0.0), EULER_ORDER_YXZ), t * _cockpit_eye())
		cam_snap = true; _cam_tail(dt); return
	look_cur = Vector2.ZERO
	var rel: Vector3; var look: Vector3; var up := t.basis.y
	match CAM_MODES[cam_mode]:
		"chase": rel = t.basis * Vector3(0, 22, 85); look = t * Vector3(0, 6, -60)
		"far": rel = t.basis * Vector3(0, 45, 170); look = t * Vector3(0, 0, -30)
		"side": rel = t.basis * Vector3(-95, 12, -5); look = t.origin; up = Vector3.UP
		"right": rel = t.basis * Vector3(95, 12, 15); look = t.origin + t.basis * Vector3(0, 0, 15); up = Vector3.UP
		_:
			free_yaw += dt * 0.35
			rel = Vector3(sin(free_yaw), 0.25, cos(free_yaw)) * 110.0; look = t.origin; up = Vector3.UP
	# камера «следует»: смещение относительно корабля догоняет плавно (на скорости не отстаёт, при манёврах запаздывает)
	var cs := maxf(P("cam_smooth"), 0.0)
	var k_off := 1.0 if cs * P("cam_off_lag") < 0.001 else 1.0 - exp(-dt / (cs * P("cam_off_lag")))
	var fresh := frame < 4 or cam_snap
	cam_rel = rel if fresh else cam_rel.lerp(rel, k_off)
	cam_up = up if fresh else cam_up.lerp(up, k_off).normalized()
	# якорь камеры: пружина по положению + по скорости (предсказание), поэтому на постоянной скорости нет отставания
	var lag := cs * P("cam_pos_lag")
	if fresh or lag < 0.01 or (cam_p - t.origin).length() > 3000.0:
		cam_p = t.origin; cam_v = ship.linear_velocity
	else:
		var w := 1.0 / lag
		var acc := w * w * (t.origin - cam_p) + 2.0 * w * (ship.linear_velocity - cam_v)
		cam_v += acc * dt; cam_p += cam_v * dt
	var pos := cam_p + cam_rel
	# не проваливаться в землю: луч от корабля к камере + не ниже рельефа
	var q := PhysicsRayQueryParameters3D.create(t.origin + t.basis.y * 8.0, pos, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty(): pos = hit["position"] + (hit["normal"] as Vector3) * 6.0
	var off := pos - t.origin                                   # не ближе 70 м к кораблю, иначе при ударе камера оказывается внутри него
	if off.length() < 70.0: pos = t.origin + (off.normalized() if off.length() > 0.5 else Vector3.UP) * 70.0
	pos.y = maxf(pos.y, height(pos.x, pos.z) + 10.0)
	var dir := look - pos
	if dir.length() < 1.0: dir = -t.basis.z
	var want := Transform3D(Basis.IDENTITY, pos).looking_at(pos + dir, cam_up if absf(dir.normalized().dot(cam_up)) < 0.98 else Vector3.UP)
	if not fresh:
		var qq := cam.global_transform.basis.get_rotation_quaternion().slerp(want.basis.get_rotation_quaternion(), 1.0 if cs * P("cam_rot_lag") < 0.001 else 1.0 - exp(-dt / (cs * P("cam_rot_lag"))))
		cam.global_transform = Transform3D(Basis(qq), pos)
	else: cam.global_transform = want
	cam_snap = false
	_cam_tail(dt)

# --- автотест «soak»: -- soak bot=N soakmax=секунд out=папка; окно настоящее, корабль игрока повторяет полёт бота N ---
func _soak_begin() -> void:
	ui._show_state("hud"); start_t = 3.0
	if ram: ship.freeze = true
	if fly: _fly_setup()
	elif ram: pass
	else: ship.collision_layer = 0; ship.collision_mask = 0
	soak_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(evo_out if evo_out != "" else "/private/tmp/soak")
	_slog("SOAK старт bot=%d name=%s max=%.0fс" % [soak_bot, bots[soak_bot]["name"], soak_max])

var soak_s := 0.0
var ram := false                                                           # режим -- ram: пробные удары кораблём в пол и стену на разных скоростях
var ram_i := 0
var ram_f := 0
var ram_go := 0
var ram_depth := 0.0
var ram_cont := 0
var ram_dep0 := 0
var fly := false                                                           # режим -- fly: настоящий корабль со столкновениями ведёт ИИ ботов
var soak_under := 0
var soak_under_max := 0.0
var soak_contact := 0
var soak_depen := 0
var soak_vmax := 3200.0
var soak_v := 0.0
var soak_y := 1700.0
func _soak_sync() -> void:                                                 # автопилот-призрак: идёт по оси трассы на 3 км/с, высота = рельеф впереди + запас
	if start_t > 0.0: return
	var dt := 1.0 / 120.0
	soak_v = minf(soak_v + 600.0 * dt, soak_vmax)
	soak_s += soak_v * dt
	var at: Array = _track_at(soak_s)
	var p: Vector2 = at[0]; var tg: Vector2 = at[1]
	var hmax := 0.0
	for k in range(0, 7): var q: Vector2 = (_track_at(soak_s + k * 500.0))[0]; hmax = maxf(hmax, height(q.x, q.y))
	var tgt := minf(hmax + 350.0, RIM_Y - 100.0)
	var ny := soak_y + clampf(tgt - soak_y, -600.0 * dt, 900.0 * dt)
	var vy := (ny - soak_y) / dt; soak_y = ny
	var fwd := Vector3(tg.x, 0.0, tg.y)
	ship.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(p.x, soak_y, p.y))
	ship.linear_velocity = fwd * soak_v + Vector3(0.0, vy, 0.0); ship.angular_velocity = Vector3.ZERO

func _soak_end(why: String) -> void:
	var b: Dictionary = bots[soak_bot]
	_slog("SOAK конец: %s t=%.0fс прогресс=%.0f/%.0f км кадров_>33мс=%d >100мс=%d худший=%.0fмс мин_fps=%.0f" % [why, (Time.get_ticks_msec() - soak_t0) / 1000.0, _soak_prog() / 1000.0, race_len / 1000.0, soak_slow, soak_hitch, soak_worst * 1000.0, soak_fps_min])
	if fly: _slog("FLY итог " + _fly_txt())
	_soak_shot("end")
	get_tree().quit()

func _soak_shot(tag: String) -> void:
	var d := evo_out if evo_out != "" else "/private/tmp/soak"
	soak_shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/bot%d_%03d_%s.png" % [d, soak_bot, soak_shot_n, tag])

func _soak_frame(dt: float) -> void:
	soak_fr += 1; soak_worst = maxf(soak_worst, dt); soak_sw = maxf(soak_sw, dt)
	if dt > 0.033: soak_slow += 1
	if dt > 0.1:
		soak_hitch += 1
		_slog("HITCH %.0fмс v=%d state=%s lod0=%d jobs=%d" % [dt * 1000.0, int(ship.linear_velocity.length()), ui.state, _count_lod(0), chunk_jobs.size()])
	var el := (Time.get_ticks_msec() - soak_t0) / 1000.0
	if int(el) > soak_sec:
		soak_sec = int(el)
		var fps := soak_fr
		soak_fps_min = minf(soak_fps_min, float(fps))
		var b: Dictionary = bots[soak_bot]
		_slog("SOAK t=%d fps=%d worst=%.0fмс прогресс=%.1fкм v=%d y=%d" % [soak_sec, fps, soak_sw * 1000.0, _soak_prog() / 1000.0, int(ship.linear_velocity.length()), int(ship.global_position.y)])
		soak_fr = 0; soak_sw = 0.0
		if soak_sec % 20 == 0: _soak_shot("t%d" % soak_sec)
		if fly: _slog("FLY " + _fly_txt())
		if _soak_prog() >= race_len: _soak_end("финиш")
		elif fly and bool(bots[soak_bot].get("dnf", false)): _soak_end("корабль выбыл (DNF)")
		elif soak_sec >= soak_max: _soak_end("лимит времени")

func _count_lod(l: int) -> int:
	var n := 0
	for k in chunks.keys(): if k.z == l: n += 1
	return n

func _soak_prog() -> float: return float(bots[soak_bot]["prog"]) if fly else soak_s

func _fly_txt() -> String:
	var b: Dictionary = bots[soak_bot]
	var dbg_s := "hold=%d cos=%.2f vy=%d thr=%.2f " % [int(b["hold"]), ship.global_transform.basis.y.y, int(ship.linear_velocity.y), float(b["thr"])]
	dbg_s += String(b.get("dbg", "")) + " | "
	return dbg_s + "hits=%d вылетов=%d под_рельефом_кадров=%d (макс %.0f м) кадров_с_контактом=%d depen=%d деталей=%d" % [int(b["hits"]), int(b["resp"]), soak_under, soak_under_max, soak_contact, soak_depen, parts.size()]

func _fly_setup() -> void:                                                  # настоящий корабль становится «ботом» с генами бота 0
	var b: Dictionary = bots[0].duplicate()
	var eng := {}
	for nm in engines: eng[nm] = {"kind": engines[nm]["kind"], "pos": engines[nm]["pos"]}
	b["rb"] = ship; b["parts"] = parts; b["eng"] = eng; b["tot"] = kind_total.duplicate(); b["ptot"] = parts.size(); b["name"] = "Корабль-тест"
	for k in ["hits", "resp", "path", "fk", "ct"]: b[k] = 0
	b["ct"] = -999; b["fkd"] = -1; b["fin"] = false; b["done"] = false; b["dnf"] = false; b["rel_init"] = false; b["prog"] = 0.0; b["rel"] = 0.0
	b["still"] = 0.0; b["pv"] = 0.0; b["icd"] = 0.0; b["thr"] = 0.0; b["hold"] = START_ALT
	bots.append(b); soak_bot = bots.size() - 1

func _fly_step(dt: float) -> void:
	_step_bots(dt)
	if start_t > 0.0: return
	var p := ship.global_position
	var dep := height(p.x, p.z) - p.y
	if dep > 2.0: soak_under += 1; soak_under_max = maxf(soak_under_max, dep)
	if ship.get_contact_count() > 0: soak_contact += 1

const RAM_SPEEDS := [500.0, 1000.0, 2000.0, 3000.0, 4500.0]
const RAM_KINDS := [["пол", 15.0], ["пол", 45.0], ["стена", 0.0]]
const RAM_S := [12000.0, 40000.0]
func _ram_step(dt: float) -> void:
	var ns := RAM_SPEEDS.size(); var nk := RAM_KINDS.size()
	if ram_i >= ns * nk * RAM_S.size(): _soak_end("ram: все пробы"); return
	if start_t > 0.0: return
	var spd: float = RAM_SPEEDS[ram_i % ns]; var kd: Array = RAM_KINDS[(ram_i / ns) % nk]; var sv: float = RAM_S[(ram_i / (ns * nk)) % RAM_S.size()]
	var at: Array = _track_at(sv); var p: Vector2 = at[0]; var tg: Vector2 = at[1]
	var nn := Vector2(-tg.y, tg.x)
	var wall: bool = kd[0] == "стена"
	var ang := deg_to_rad(float(kd[1]))
	var dir := Vector3(nn.x, 0.0, nn.y) if wall else Vector3(tg.x * cos(ang), -sin(ang), tg.y * cos(ang))
	ram_f += 1
	if ram_f == 1:
		var y0 := height(p.x, p.y) + (250.0 if wall else 400.0)
		ship.freeze = true
		ship.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(p.x, y0, p.y))
		ship.linear_velocity = Vector3.ZERO; ship.angular_velocity = Vector3.ZERO
		ram_go = 0
	elif ram_go == 0:
		if (ram_f >= 300 and chunk_jobs.size() < 3) or ram_f > 1200:
			ship.freeze = false; ship.linear_velocity = dir * spd; ram_go = ram_f; ram_depth = 0.0; ram_cont = 0; ram_dep0 = soak_depen
	else:
		var q := ship.global_position
		ram_depth = maxf(ram_depth, height(q.x, q.z) - q.y)
		if ship.get_contact_count() > 0: ram_cont += 1
		if ram_f - ram_go >= 480:
			var endd := height(q.x, q.z) - q.y
			_slog("RAM %s %d° v=%d s=%d: глубина_макс=%.1f м конец_под_рельефом=%s v_конец=%d контактных_кадров=%d depen=%d%s" % [kd[0], int(kd[1]), int(spd), int(sv), ram_depth, "ДА" if endd > 5.0 else "нет", int(ship.linear_velocity.length()), ram_cont, soak_depen - ram_dep0, "  ТУННЕЛЬ" if ram_depth > 30.0 else ""])
			ram_i += 1; ram_f = 0; ram_go = 0

# --- съёмка срезок изнутри: -- uishot=cutcam [tourc=N]: камера стоит в расщелине на разных высотах, без интерфейса, кадры в /private/tmp/cuts/ ---
var cc_on := false
var cc_fov := 75.0
var cc_tf := Transform3D.IDENTITY
var cc_list: Array = []
var cc_i := 0
var cc_pf0 := 0
func _cutcam_step(pf: int) -> void:
	if pf == 20:
		ui._show_state("hud"); start_t = 0.0; racing = true; ui.visible = false
		ship.freeze = true; ship.collision_layer = 0; ship.collision_mask = 0; ship.visible = false
		for b in bots: (b["rb"] as RigidBody3D).freeze = true; (b["rb"] as RigidBody3D).visible = false
		DirAccess.make_dir_recursive_absolute("/private/tmp/cuts")
		for k in branches.size():
			if tour_c > 0 and k + 1 != tour_c: continue
			var fr_list: Array = [0.1, 0.3, 0.5, 0.7, 0.9] if branches[k]["type"] == "wind" else [0.15, 0.3, 0.4, 0.46, 0.62]       # у «уха» стенка ровно посередине
			for fr in fr_list:
				for dy in [[0.0, "низ"], [1.0, "середина"], [2.0, "верх"]]: cc_list.append({"k": k, "f": fr, "dy": dy[0], "n": dy[1]})
		cc_i = -1; cc_pf0 = pf; cc_on = false
	if pf < 25 or cc_list.is_empty(): return
	if cc_i >= 0 and pf - cc_pf0 > 260:
		var t: Dictionary = cc_list[cc_i]
		get_viewport().get_texture().get_image().save_png("/private/tmp/cuts/cut%d_f%02d_%s.png" % [int(t["k"]) + 1, int(float(t["f"]) * 100.0), String(t["n"]) if false else ["low", "mid", "high"][int(t["dy"])]])
		cc_i += 1; cc_pf0 = pf
	elif cc_i < 0: cc_i = 0; cc_pf0 = pf
	if cc_i >= cc_list.size(): get_tree().quit(); return
	if pf == cc_pf0:
		var t2: Dictionary = cc_list[cc_i]
		var br: Dictionary = branches[int(t2["k"])]; var pts: PackedVector2Array = br["pts"]
		var tot := 0.0
		for i in range(1, pts.size()): tot += pts[i].distance_to(pts[i - 1])
		var fr2 := _cut_frame(pts, tot * float(t2["f"])); var pp: Vector2 = fr2[0]; var tg: Vector2 = fr2[1]
		var yfl := height(pp.x, pp.y)
		var yroof := _roof_y(tot * float(t2["f"]), int(t2["k"])) if branches[int(t2["k"])]["type"] == "wind" else 1500.0
		var y: float = yfl + [150.0, (yroof - yfl) * 0.5 if yroof - yfl > 400.0 else 600.0, maxf(yroof - 130.0, yfl + 300.0)][int(t2["dy"])]
		ship.global_position = Vector3(pp.x, y, pp.y)
		cc_tf = Transform3D(Basis.looking_at(Vector3(tg.x, -0.05, tg.y), Vector3.UP), Vector3(pp.x, y, pp.y))
		cc_on = true

# --- кадр из тупика: -- uishot=spurcam spur=K f=0..1 y=высота над дном back=м назад по оси (камера смотрит вдоль тупика к чаше); out=путь ---
func _spurcam_step(pf: int) -> void:
	if pf == 20:
		ui._show_state("hud"); start_t = 0.0; racing = true; ui.visible = false
		ship.freeze = true; ship.collision_layer = 0; ship.collision_mask = 0; ship.visible = false
		for b in bots: (b["rb"] as RigidBody3D).freeze = true; (b["rb"] as RigidBody3D).visible = false
		var k := 0; var f := 0.8; var yy := 900.0; var back := 1500.0; var pitch := -0.05
		for a in OS.get_cmdline_user_args():
			if a.begins_with("spur="): k = int(a.substr(5))
			if a.begins_with("f="): f = float(a.substr(2))
			if a.begins_with("y="): yy = float(a.substr(2))
			if a.begins_with("back="): back = float(a.substr(5))
			if a.begins_with("pitch="): pitch = float(a.substr(6))
		var sp: Dictionary = spurs[k]; var spp: PackedVector2Array = sp["pts"]; var spc: PackedFloat32Array = sp["cum"]
		var dk := clampf(float(sp["len"]) * f, 0.0, float(sp["len"]) - 1.0)
		var kk := clampi(int(dk / 500.0), 0, spp.size() - 2)
		var pp := spp[kk].lerp(spp[kk + 1], clampf((dk - spc[kk]) / 500.0, 0.0, 1.0)); var tg := (spp[kk + 1] - spp[kk]).normalized()
		pp -= tg * back
		var y := height(pp.x, pp.y) + yy
		ship.global_position = Vector3(pp.x, y, pp.y)
		cc_tf = Transform3D(Basis.looking_at(Vector3(tg.x, pitch, tg.y), Vector3.UP), Vector3(pp.x, y, pp.y)); cc_on = true
	if pf == 240:
		var outp := "/private/tmp/spurcam.png"
		for a in OS.get_cmdline_user_args(): if a.begins_with("out="): outp = a.substr(4)
		get_viewport().get_texture().get_image().save_png(outp); get_tree().quit()

# --- карта рельефа сверху (тестовая): -- uishot=tmap cut=K [half=м] [res=N] [out=путь]; центр — середина срезки K (1..3) ---
func _tmap_dump() -> void:
	var ua := OS.get_cmdline_user_args(); var k := 1; var half := 14000.0; var rs := 900; var outp := "/private/tmp/tmap.png"; var cxz := Vector2.INF
	for a in ua:
		if a.begins_with("cut="): k = int(a.substr(4))
		if a.begins_with("half="): half = float(a.substr(5))
		if a.begins_with("res="): rs = int(a.substr(4))
		if a.begins_with("out="): outp = a.substr(4)
		if a.begins_with("cx="): cxz.x = float(a.substr(3))
		if a.begins_with("cz="): cxz.y = float(a.substr(3))
	var c := cxz
	if c == Vector2.INF:
		if k <= 0: c = _track_at(trk_len * 0.5)[0]
		else:
			var bp: PackedVector2Array = branches[k - 1]["pts"]; c = bp[bp.size() / 2]
	var img := Image.create(rs, rs, false, Image.FORMAT_RGB8)
	var hm := PackedFloat32Array(); hm.resize(rs * rs)
	var st := half * 2.0 / float(rs)
	for j in rs:
		for i in rs: hm[j * rs + i] = height(c.x - half + i * st, c.y - half + j * st)
	for j in rs:
		for i in rs:
			var h := hm[j * rs + i]
			var hx := hm[j * rs + mini(i + 1, rs - 1)] - hm[j * rs + maxi(i - 1, 0)]
			var hz := hm[mini(j + 1, rs - 1) * rs + i] - hm[maxi(j - 1, 0) * rs + i]
			var sh := clampf(0.62 + (-hx * 0.7 - hz * 0.7) / (2.0 * st) * 0.5, 0.15, 1.0)
			var t := clampf(h / PLATEAU_Y, 0.0, 1.0)
			var col := Color(0.25, 0.3, 0.45).lerp(Color(0.95, 0.7, 0.4), t) * sh
			img.set_pixel(i, j, Color(col.r, col.g, col.b))
	for bi in branches.size():
		var bp2: PackedVector2Array = branches[bi]["pts"]
		for p in bp2:
			var px := int((p.x - c.x + half) / st); var py := int((p.y - c.y + half) / st)
			if px >= 0 and px < rs and py >= 0 and py < rs: img.set_pixel(px, py, Color(1, 0, 0))
	for sp in spurs:
		for p in (sp["pts"] as PackedVector2Array):
			var px3 := int((p.x - c.x + half) / st); var py3 := int((p.y - c.y + half) / st)
			if px3 >= 1 and px3 < rs - 1 and py3 >= 1 and py3 < rs - 1:
				for ox in range(-1, 2): img.set_pixel(px3 + ox, py3, Color(1, 1, 0))
	for p in trk_pts:
		var px2 := int((p.x - c.x + half) / st); var py2 := int((p.y - c.y + half) / st)
		if px2 >= 0 and px2 < rs and py2 >= 0 and py2 < rs: img.set_pixel(px2, py2, Color(0, 1, 0))
	img.save_png(outp)

# --- ширина срезок: -- uishot=cutwidth. Расстояние между стенами на высоте дна + ofs, по центру пути, каждые 60 м ---
func _wallw(p: Vector2, n: Vector2, side: float, y: float) -> float:
	for d in range(2, 3000, 4):
		var q := p + n * side * float(d)
		if height(q.x, q.y) >= y: return float(d)
	return 3000.0

func _cutwidth() -> void:
	var offs := [50.0, 100.0, 200.0, 400.0, 800.0, 1500.0]
	var groups: Array = []
	for k in branches.size(): groups.append([("срезка %d (%s)" % [k + 1, branches[k]["type"]]), (branches[k]["pts"] as PackedVector2Array), -1])
	groups.append(["главная трасса (s 30-300 км)", PackedVector2Array(), 0])
	for g in groups:
		var res := {}
		for o in offs: res[o] = []
		var pts: PackedVector2Array = g[1]
		var samples: Array = []
		if int(g[2]) == 0:
			var sv := 30000.0
			while sv < 300000.0:
				var at := _track_at(sv); samples.append([at[0], at[1]]); sv += 600.0
		else:
			var tot := 0.0
			for i in range(1, pts.size()): tot += pts[i].distance_to(pts[i - 1])
			var dist := 600.0
			while dist < tot - 600.0:
				var fr := _cut_frame(pts, dist); samples.append([fr[0], fr[1]]); dist += 60.0
		for sm in samples:
			var p: Vector2 = sm[0]; var tg: Vector2 = sm[1]; var nn := Vector2(-tg.y, tg.x)
			var fl := height(p.x, p.y)
			for o in offs: res[o].append(_wallw(p, nn, -1.0, fl + o) + _wallw(p, nn, 1.0, fl + o))
		var line := "WIDTH %s:" % g[0]
		for o in offs:
			var a: Array = res[o]; a.sort()
			line += "  +%dм: мин %d / p10 %d / медиана %d" % [int(o), int(a[0]), int(a[int(a.size() * 0.1)]), int(a[a.size() / 2])]
		print(line)

# --- корабль в самых узких и типичных местах срезок: -- uishot=cutship (кадры в /private/tmp/cuts2/) ---
func _cutship_step(pf: int) -> void:
	if pf == 20:
		ui._show_state("hud"); start_t = 0.0; racing = true; ui.visible = false
		ship.freeze = true; ship.collision_layer = 0; ship.collision_mask = 0; ship.visible = true
		for b in bots: (b["rb"] as RigidBody3D).freeze = true; (b["rb"] as RigidBody3D).visible = false
		DirAccess.make_dir_recursive_absolute("/private/tmp/cuts2")
		for k in branches.size():
			var pts: PackedVector2Array = branches[k]["pts"]
			var tot := 0.0
			for i in range(1, pts.size()): tot += pts[i].distance_to(pts[i - 1])
			var ws: Array = []
			var dist := 600.0
			while dist < tot - 600.0:
				var fr := _cut_frame(pts, dist); var p: Vector2 = fr[0]; var nn: Vector2 = fr[2]
				var fl := height(p.x, p.y)
				ws.append([_wallw(p, nn, -1.0, fl + 200.0) + _wallw(p, nn, 1.0, fl + 200.0), dist]); dist += 60.0
			ws.sort_custom(func(a, b): return a[0] < b[0])
			cc_list.append({"k": k, "d": ws[0][1], "w": ws[0][0], "n": "narrowest"})
			cc_list.append({"k": k, "d": ws[ws.size() / 2][1], "w": ws[ws.size() / 2][0], "n": "typical"})
		cc_i = -1; cc_pf0 = pf; cc_on = false
	if pf < 25 or cc_list.is_empty(): return
	if cc_i >= 0 and pf - cc_pf0 > 260:
		var t: Dictionary = cc_list[cc_i]
		get_viewport().get_texture().get_image().save_png("/private/tmp/cuts2/cut%d_%s_w%d.png" % [int(t["k"]) + 1, String(t["n"]), int(t["w"])])
		cc_i += 1; cc_pf0 = pf
	elif cc_i < 0: cc_i = 0; cc_pf0 = pf
	if cc_i >= cc_list.size(): get_tree().quit(); return
	if pf == cc_pf0:
		var t2: Dictionary = cc_list[cc_i]
		var pts2: PackedVector2Array = branches[int(t2["k"])]["pts"]
		var fr2 := _cut_frame(pts2, float(t2["d"])); var pp: Vector2 = fr2[0]; var tg: Vector2 = fr2[1]
		var y := height(pp.x, pp.y) + 200.0
		var fwd := Vector3(tg.x, 0.0, tg.y)
		ship.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(pp.x, y, pp.y))
		ship.linear_velocity = Vector3.ZERO; ship.angular_velocity = Vector3.ZERO
		cc_tf = Transform3D(Basis.IDENTITY, Vector3(pp.x, y + 60.0, pp.y) - fwd * 230.0).looking_at(Vector3(pp.x, y, pp.y) + fwd * 60.0, Vector3.UP)
		cc_on = true

# --- снимки стартовой сетки: -- uishot=gridcam (кадры в /private/tmp/grid/): сзади, спереди, сверху-сбоку ---
func _gridcam_step(pf: int) -> void:
	if pf == 20:
		ui._show_state("hud"); ui.visible = false; start_t = 99.0; racing = false
		DirAccess.make_dir_recursive_absolute("/private/tmp/grid")
	var views := [["back", Vector3(0, 30, 850), Vector3(0, 0, 0)], ["front", Vector3(0, 30, -850), Vector3(0, 0, 0)], ["side", Vector3(1500, 120, 500), Vector3(0, 0, 0)], ["high", Vector3(0, 520, 900), Vector3(0, 0, 0)]]
	var k := (pf - 40) / 90
	if pf >= 40 and k < views.size():
		var v: Array = views[k]
		var c := Vector3(0.0, START_ALT + GRID_DY * 0.5, 0.0)
		cc_fov = 80.0; cc_tf = Transform3D(Basis.IDENTITY, c + (v[1] as Vector3)).looking_at(c, Vector3.UP); cc_on = true
		if (pf - 40) % 90 == 80:
			get_viewport().get_texture().get_image().save_png("/private/tmp/grid/grid_%s.png" % v[0])
	elif k >= views.size(): get_tree().quit()

# --- портреты кораблей: -- uishot=liverycam [nofog] (кадры /private/tmp/liv/): у каждого бота справа-спереди и слева-сзади; затем наш корабль ---
func _shippic_step(pf: int) -> void:                                       # картинка корабля для меню: два прохода на чёрном и белом фоне, альфа считается из разности (tools: menu_v2/mk_shippic.py)
	if pf == 20:
		ui._show_state("hud"); ui.visible = false; start_t = 99.0; racing = false
		for b in bots: (b["rb"] as RigidBody3D).freeze = true; (b["rb"] as RigidBody3D).visible = false
		ship.freeze = true; ship.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 3000, 0))
		cam.far = 700.0; world_env.glow_enabled = false
		world_env.background_mode = Environment.BG_COLOR; world_env.background_color = Color.BLACK
		world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; world_env.ambient_light_color = Color(0.62, 0.66, 0.78); world_env.ambient_light_energy = 1.0
		world_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED; world_env.fog_enabled = false
		cc_fov = 30.0; cc_on = true
		cc_tf = Transform3D(Basis.IDENTITY, Vector3(0, 3000, 0) + Vector3(86, 31, -94)).looking_at(Vector3(0, 3000, 0) + Vector3(0, -3, 0), Vector3.UP)
	if pf == 40:
		get_viewport().get_texture().get_image().save_png("/private/tmp/shippic_black.png"); world_env.background_color = Color.WHITE
	if pf == 52:
		get_viewport().get_texture().get_image().save_png("/private/tmp/shippic_white.png"); get_tree().quit()

func _liverycam_step(pf: int) -> void:
	if pf == 20:
		ui._show_state("hud"); ui.visible = false; start_t = 99.0; racing = false
		DirAccess.make_dir_recursive_absolute("/private/tmp/liv")
	var n := bots.size() + 1
	var k := (pf - 40) / 12
	if pf >= 40 and k < n * 3:
		var bi := k / 3; var side := k % 3
		var tgt: Vector3 = ship.global_position if bi == bots.size() else (bots[bi]["rb"] as RigidBody3D).global_position
		var nm := "ship" if bi == bots.size() else "bot%02d" % bi
		cc_fov = 42.0
		var off := Vector3(95, 22, -80) if side == 0 else (Vector3(-95, 25, 80) if side == 1 else Vector3(60, 85, 40))
		var aim := tgt + Vector3(0, 2, 0)
		if "cabcam" in OS.get_cmdline_user_args(): off = Vector3(46, 4, -10) if side == 0 else (Vector3(46, 22, -10) if side == 1 else Vector3(-46, 4, -10)); aim = tgt + Vector3(0, 2, -10)
		if "nosecam" in OS.get_cmdline_user_args(): off = Vector3(32, -6, -78) if side == 0 else (Vector3(-32, -8, -80) if side == 1 else Vector3(0, -18, -90)); aim = tgt + Vector3(0, -5, -43)
		cc_tf = Transform3D(Basis.IDENTITY, tgt + off).looking_at(aim, Vector3.UP); cc_on = true
		if (pf - 40) % 12 == 10:
			get_viewport().get_texture().get_image().save_png("/private/tmp/liv/%s_%s.png" % [nm, ["R", "L", "T"][side]])
	elif k >= n * 3: get_tree().quit()
