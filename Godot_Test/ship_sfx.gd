class_name ShipSfx
extends Node
# Звуки корабля игрока (ship/sfx): гул тяговых (по тяге), шум маневровых (по их усилию), сигнал приближения к земле/стене (парктроник),
# взрывы при ударах и отрыве деталей (вариант зависит от того, что отлетело). Работает только в гонке; на паузе и в меню тихо.

const DB_MAIN := -4.0
const DB_SHUNT := -9.0
const DB_PARK := -10.0
const PARK_TTI := 3.0                       # с до касания, с которых начинается сигнал
const CRASH_DB := {"crash_engine": -2.0, "crash_wing": -3.0, "crash_glass": -5.0, "crash_small": -7.0, "crash_hull": -6.0, "crash_big": -1.0}

var m: Node                                 # main.gd
var streams := {}
var p_main: AudioStreamPlayer
var p_shunt: AudioStreamPlayer
var p_park: AudioStreamPlayer
var pool: Array = []
var nxt := 0
var lv_main := 0.0
var lv_shunt := 0.0
var park_phase := 0.0
var park_tti := 99.0
var pending: Array = []                     # отлетевшие детали за последние мгновения: решаем, какой звук играть, когда набралась пачка
var pending_t := 0.0

func setup(main_node: Node) -> void:
	m = main_node; process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["engine_main", "engine_shunt", "parktronic", "crash_engine", "crash_wing", "crash_glass", "crash_small", "crash_hull", "crash_big"]:
		var p := "res://ship/sfx/%s.wav" % n
		if not ResourceLoader.exists(p): continue
		var st := load(p) as AudioStreamWAV
		if n in ["engine_main", "engine_shunt", "parktronic"]: st.loop_mode = AudioStreamWAV.LOOP_FORWARD; st.loop_begin = 0; st.loop_end = st.data.size() / 2
		streams[n] = st
	p_main = _loop_player("engine_main"); p_shunt = _loop_player("engine_shunt"); p_park = _loop_player("parktronic")
	for i in 8:
		var pl := AudioStreamPlayer.new(); add_child(pl); pool.append(pl)

func _loop_player(n: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new(); add_child(pl)
	if streams.has(n): pl.stream = streams[n]; pl.volume_db = -80.0; pl.play()
	return pl

func _vol() -> float:
	return float(m.cfg.get("ship_sfx", 0.8))

func _play(n: String, db: float, pitch := 1.0) -> void:
	if not streams.has(n): return
	var pl: AudioStreamPlayer = pool[nxt]; nxt = (nxt + 1) % pool.size()
	pl.stream = streams[n]; pl.volume_db = db + CRASH_DB.get(n, 0.0) + linear_to_db(maxf(_vol(), 0.0001)); pl.pitch_scale = pitch * randf_range(0.94, 1.06); pl.play()

func part_lost(nm: String) -> void:                                          # деталь отлетела (вызывает main._detach)
	if pending.is_empty(): pending_t = Time.get_ticks_msec() / 1000.0
	pending.append(nm)

func impact(power: float) -> void:                                           # удар корпусом: глухой взрыв, громче от силы
	if power < 12.0: return
	_play("crash_small", lerpf(-22.0, 0.0, clampf(power / 150.0, 0.0, 1.0)))

func _pick(nm: String) -> String:
	if nm.begins_with("SM_Engine_"): return "crash_engine"
	if nm.begins_with("SM_Wing_"): return "crash_wing"
	if nm.begins_with("SM_Glass_"): return "crash_glass"
	return "crash_hull" if randf() < 0.5 else "crash_small"                   # прожекторы, люки, подножки

func _flush_parts() -> void:
	var engines := 0
	for nm in pending: if String(nm).begins_with("SM_Engine_"): engines += 1
	if pending.size() >= 3: _play("crash_big", 0.0)                          # сразу много деталей: большой взрыв
	if pending.size() >= 3 and engines > 0: _play("crash_engine", -4.0)
	elif pending.size() < 3:
		var played := {}
		for nm in pending:
			var k := _pick(String(nm))
			if played.has(k): continue
			played[k] = true; _play(k, 0.0)
	pending.clear()

func _process(dt: float) -> void:
	if m == null or m.ship == null: return
	var rt := Time.get_ticks_msec() / 1000.0
	if not pending.is_empty() and rt - pending_t > 0.06: _flush_parts()
	var live: bool = m.ui != null and m.ui.state == "hud" and not m.in_cutscene() and m.start_t <= 0.0 and not m.p_dsq
	var k := 1.0 - exp(-minf(dt, 0.1) * 6.0)
	var vdb := linear_to_db(maxf(_vol(), 0.0001))
	# тяговые: гул растёт с тягой, взлётные добавляют низкий фон
	var tgt_main := clampf(float(m.thr) + clampf(float(m.lift_ratio) * 5.0, 0.0, 0.3), 0.0, 1.0) if live else 0.0
	lv_main = lerpf(lv_main, tgt_main, k)
	var rem := 0.4 + 0.6 * float(m._remaining("main"))
	p_main.volume_db = -80.0 if (not live and lv_main < 0.01) else DB_MAIN - 30.0 * (1.0 - lv_main) + linear_to_db(rem) + vdb
	p_main.pitch_scale = 0.78 + 0.5 * lv_main
	# маневровые: шум по суммарному усилию
	var sum := 0.0
	if live:
		for nm in m.eng_force: sum += minf((m.eng_force[nm] as Vector3).length(), 2.0)
	var tgt_sh := clampf(sum * 0.22, 0.0, 1.0)
	lv_shunt = lerpf(lv_shunt, tgt_sh, 1.0 - exp(-minf(dt, 0.1) * 9.0))
	p_shunt.volume_db = -80.0 if lv_shunt < 0.015 else DB_SHUNT - 28.0 * (1.0 - lv_shunt) + vdb
	p_shunt.pitch_scale = 0.88 + 0.3 * lv_shunt
	# сигнал приближения: чем ближе земля или стена по курсу, тем чаще писк
	var tti := 99.0
	if live and m.racing and not m.p_fin: tti = _time_to_obstacle()
	park_tti = lerpf(park_tti, tti, 1.0 - exp(-minf(dt, 0.1) * 12.0)) if tti < park_tti else tti
	if park_tti < PARK_TTI:
		var iv := remap(clampf(park_tti, 0.45, PARK_TTI), 0.45, PARK_TTI, 0.1, 0.9)
		park_phase += dt
		var on := park_tti < 0.5 or fmod(park_phase, iv) < iv * 0.5
		p_park.volume_db = (DB_PARK + vdb + (2.0 if park_tti < 1.0 else 0.0)) if on else -80.0
		p_park.pitch_scale = 1.0 + (PARK_TTI - park_tti) * 0.12
	else:
		p_park.volume_db = -80.0; park_phase = 0.0

func _time_to_obstacle() -> float:                                           # через сколько секунд корабль заденет землю или стену, если полетит как летит
	var v: Vector3 = m.ship.linear_velocity; var sp := v.length()
	if sp < 80.0: return 99.0
	var p: Vector3 = m.ship.global_position
	var t_min := 99.0
	for tt in [0.4, 0.8, 1.3, 2.0, 3.0]:                                       # земля: высота рельефа под предсказанной точкой
		var q: Vector3 = p + v * float(tt)
		if q.y - float(m.height(q.x, q.z)) < 30.0: t_min = minf(t_min, float(tt)); break
	var L := minf(sp * PARK_TTI, 2500.0)
	var rq := PhysicsRayQueryParameters3D.create(p, p + v / sp * L, 1)
	var hit: Dictionary = m.get_world_3d().direct_space_state.intersect_ray(rq)
	if not hit.is_empty(): t_min = minf(t_min, (hit["position"] as Vector3).distance_to(p) / sp)
	return t_min
