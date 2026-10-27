
extends RefCounted
# Генератор трасс: замкнутая петля по часовой стрелке, выпуклые и вогнутые доли даёт левые и правые повороты.
# generate(seed) -> Array[Vector2] контрольных точек в км (x, z), старт в (0,0), нос на -Z.
# Условия: длина 100–118 км, минимальный радиус 2,8 км, не меньше двух левых поворотов (суммарно ≥120°), не меньше двух тугих,
# первые 25 км лёгкие (радиус ≥5 км) и прямой старт, участки трассы не ближе 9 км друг к другу.

static func _stats(pts: PackedVector2Array, w: int) -> Dictionary:
	var n := pts.size()
	var ds := PackedFloat64Array(); ds.resize(n)
	var ang := PackedFloat64Array(); ang.resize(n)
	var total := 0.0
	for i in n:
		var d := pts[(i + 1) % n] - pts[i]
		ds[i] = d.length(); ang[i] = d.angle(); total += ds[i]
	var da := PackedFloat64Array(); da.resize(n)
	for i in n: da[i] = angle_difference(ang[i], ang[(i + 1) % n])
	var cur := PackedFloat64Array(); cur.resize(n)                      # сглаженная кривизна, 1/м (>0 — влево)
	for i in n:
		var a := 0.0; var l := 0.0
		for k in range(-w, w + 1):
			a += da[(i + k + n) % n]; l += ds[(i + k + n) % n]
		cur[i] = a / maxf(l, 1.0)
	return {"ds": ds, "cur": cur, "len": total}

static func generate(seed: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = seed * 7919 + 13
	for attempt in 600:
		var asp := rng.randf_range(0.6, 1.0)
		var amps := []; var phis := []
		for k in range(2, 7):
			amps.append(rng.randf_range(0.0, 0.34 / pow(float(k - 1), 0.8))); phis.append(rng.randf() * TAU)
		var n := 600
		var pts := PackedVector2Array(); pts.resize(n)
		var ok := true
		for i in n:
			var th := -TAU * float(i) / n
			var r := 1.0
			for j in 5: r += float(amps[j]) * sin(float(j + 2) * th + float(phis[j]))
			if r < 0.45: ok = false; break
			pts[i] = Vector2(asp * r * cos(th), r * sin(th))
		if not ok: continue
		var st0 := _stats(pts, 3)
		var target := rng.randf_range(100000.0, 118000.0)
		var sc: float = target / float(st0["len"])
		for i in n: pts[i] *= sc
		var st := _stats(pts, int(1500.0 / (target / n)))
		var cur: PackedFloat64Array = st["cur"]; var ds: PackedFloat64Array = st["ds"]
		# минимальный радиус
		var minr := 1e9; var left_deg := 0.0; var left_cnt := 0; var tight := 0
		var i2 := 0
		while i2 < n:
			var sg := 1 if cur[i2] > 1.0 / 12000.0 else (-1 if cur[i2] < -1.0 / 12000.0 else 0)
			if sg == 0: i2 += 1; continue
			var j := i2; var deg := 0.0; var mr := 1e9
			while j < n + i2 and (1 if cur[j % n] > 1.0 / 12000.0 else (-1 if cur[j % n] < -1.0 / 12000.0 else 0)) == sg:
				deg += absf(cur[j % n]) * ds[j % n]; mr = minf(mr, 1.0 / absf(cur[j % n])); j += 1
			deg = rad_to_deg(deg); minr = minf(minr, mr)
			if deg > 10.0:
				if mr < 4000.0: tight += 1
				if sg > 0: left_deg += deg; left_cnt += 1
			i2 = j
			if j >= n: break
		if minr < 2800.0 or left_cnt < 2 or left_deg < 120.0 or tight < 2: continue
		# расстояние между далёкими участками
		var cum := PackedFloat64Array(); cum.resize(n); var acc := 0.0
		for i in n: cum[i] = acc; acc += ds[i]
		var dmin := 1e9
		for a in range(0, n, 3):
			for b in range(a + 1, n, 3):
				var sd := minf(absf(cum[a] - cum[b]), acc - absf(cum[a] - cum[b]))
				if sd > 12000.0: dmin = minf(dmin, pts[a].distance_to(pts[b]))
		if dmin < 9000.0: continue
		# старт: прямой участок, за ним лёгкие 25 км
		var cands := []
		for i in range(0, n, 2):
			var good := true
			var s := -3000.0
			while s <= 25000.0:
				var idx := (i + int(roundf(s / (acc / n))) + n * 4) % n
				if s >= 0.0 and absf(cur[idx]) > 1.0 / 5000.0: good = false; break
				if s >= -3000.0 and s <= 6000.0 and absf(cur[idx]) > 1.0 / 15000.0: good = false; break
				s += acc / n * 2.0
			if good: cands.append(i)
		if cands.is_empty(): continue
		var si: int = cands[rng.randi() % cands.size()]
		var p0 := pts[si]
		var h := (pts[(si + 1) % n] - p0).angle()
		var out := []
		var cnt := int(roundf(acc / 4000.0))
		for kk in cnt:
			var k := int(roundf(float(kk) * n / cnt))
			var q := pts[(si + k) % n] - p0
			q = q.rotated(PI * 0.5 - h)                     # нос вдоль +Y карты
			out.append(Vector2(q.x / 1000.0, -q.y / 1000.0))   # z = -Y
		return out
	push_warning("TrackGen: не удалось построить трассу для seed %d" % seed)
	return []

# Открытая трасса заданной длины (км): старт в (0,0) нос на -Z, прямой разгон 30 км, дальше случайные участки (прямые, дуги разного радиуса, S-связки)
# и «широкие блоки» (серпантин из шпилек, лопасти, петли), для каждого из которых строится срезающая ветка — короткая хорда от начала блока к его концу.
# Учитываются баланс левых/правых поворотов и самопересечения (другие части трассы не ближе 9 км, хорды не ближе 6 км), в конце прямая для торможения.
# Точки каждый 1 км. Возвращает {"pts": Array[Vector2] (x, z) в км, "cuts": [{"a": индекс начала, "b": индекс конца, "pts": Array[Vector2] хорды в км, "len": длина хорды км, "main": длина блока км}]}.
static func generate_open(seed: int, len_km: float) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed * 104729 + 7
	var pts: Array = [Vector2.ZERO]                      # в картовых координатах (x, y), z = -y в конце
	var cells := {}                                       # сетка 9 км: ячейка -> индексы точек основного пути
	var ccells := {}                                      # сетка хорд: ячейка -> [[x, y, индекс конца блока]]
	var cuts: Array = []
	var st := {"pos": Vector2.ZERO, "h": PI * 0.5, "turn": 0.0}
	var hist: Array = []                                  # для отката при тупике
	cells[Vector2i(0, 0)] = [0]
	var cell_of := func(p: Vector2) -> Vector2i: return Vector2i(int(floor(p.x / 9.0)), int(floor(p.y / 9.0)))
	var rebuild := func() -> void:
		cells.clear(); ccells.clear()
		for i in pts.size():
			var c: Vector2i = cell_of.call(pts[i]); var l: Array = cells.get(c, []); l.append(i); cells[c] = l
		for ct in cuts:
			for p in ct["pts"]:
				var c2: Vector2i = cell_of.call(p); var l2: Array = ccells.get(c2, []); l2.append([p.x, p.y, ct["b"]]); ccells[c2] = l2
	var walk := func(piece: Array) -> Dictionary:           # геометрия куска без применения
		var pos: Vector2 = st["pos"]; var h: float = st["h"]; var cand: Array = []; var turn: float = st["turn"]
		for seg in piece:
			if seg[0] == "s":
				for i in int(seg[1]):
					pos += Vector2(cos(h), sin(h)); cand.append(pos)
			else:
				var r: float = seg[1]; var ang: float = seg[2]; var sg: float = seg[3]
				var n := maxi(2, int(ceil(ang * r)))
				var dth := ang / n * sg
				for i in n:
					var chord := 2.0 * r * sin(absf(dth) * 0.5)
					pos += Vector2(cos(h + dth * 0.5), sin(h + dth * 0.5)) * chord; h += dth; cand.append(pos)
				turn += ang * sg
		return {"cand": cand, "pos": pos, "h": h, "turn": turn}
	var clear := func(cand: Array, base: int) -> bool:
		for ci in cand.size():
			var p: Vector2 = cand[ci]; var c: Vector2i = cell_of.call(p)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var key := Vector2i(c.x + dx, c.y + dy)
					var lst = cells.get(key)
					if lst != null:
						for idx in lst:
							if base + ci - int(idx) > 16 and p.distance_to(pts[idx]) < 9.0: return false
					var cl = ccells.get(key)
					if cl != null:
						for e in cl:
							if base + ci - int(e[2]) > 12 and p.distance_to(Vector2(e[0], e[1])) < 7.0: return false
		for ci in range(16, cand.size()):
			for cj in range(0, ci - 16):
				if (cand[ci] as Vector2).distance_to(cand[cj]) < 9.0: return false
		return true
	var commit := func(w: Dictionary, chord: Dictionary) -> void:
		hist.append({"n": pts.size(), "cn": cuts.size(), "pos": st["pos"], "h": st["h"], "turn": st["turn"]})
		var a_idx := pts.size() - 1
		for p in w["cand"]:
			pts.append(p); var c: Vector2i = cell_of.call(p); var l: Array = cells.get(c, []); l.append(pts.size() - 1); cells[c] = l
		if not chord.is_empty():
			chord["a"] = a_idx; chord["b"] = pts.size() - 1; cuts.append(chord)
			for p in chord["pts"]:
				var c2: Vector2i = cell_of.call(p); var l2: Array = ccells.get(c2, []); l2.append([p.x, p.y, chord["b"]]); ccells[c2] = l2
		st["pos"] = w["pos"]; st["h"] = w["h"]; st["turn"] = w["turn"]
	var try_piece := func(piece: Array) -> bool:
		var w: Dictionary = walk.call(piece)
		if not clear.call(w["cand"], pts.size()): return false
		commit.call(w, {}); return true
	# срезающая ветка: кубическая кривая Безье от начала блока к концу с касательными по курсу
	var make_chord := func(w: Dictionary, ctype: String) -> Dictionary:
		var A: Vector2 = st["pos"]; var B: Vector2 = w["pos"]; var hA: float = st["h"]; var hB: float = w["h"]
		var L := A.distance_to(B)
		var main_len := float((w["cand"] as Array).size())
		if main_len < 30.0 or L < 14.0: return {}
		var ctrl: Array = [A]
		if ctype == "wind":                                                          # извилистая срезка: 3 точки со сменой стороны
			var dv := (B - A).normalized(); var nv := Vector2(-dv.y, dv.x)
			var sgw := 1.0 if rng.randf() < 0.5 else -1.0
			for k in 3:
				var t := (float(k) + 1.0) / 4.0 + rng.randf_range(-0.04, 0.04)
				ctrl.append(A + dv * L * t + nv * sgw * rng.randf_range(1.6, 3.4)); sgw = -sgw
		ctrl.append(B)
		# сплайн Катмулла–Рома с касательными по курсу на концах, потом ресэмплинг через ~1 км
		var tA := Vector2(cos(hA), sin(hA)); var tB := Vector2(cos(hB), sin(hB))
		var cp: Array = [A - tA * 3.0] + ctrl + [B + tB * 3.0]
		var dense: Array = []
		for i in range(1, cp.size() - 2):
			for k in 10:
				var t := float(k) / 10.0
				var p0: Vector2 = cp[i - 1]; var p1: Vector2 = cp[i]; var p2: Vector2 = cp[i + 1]; var p3: Vector2 = cp[i + 2]
				dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
		dense.append(B)
		var ch: Array = []; var acc := 0.0; var last: Vector2 = dense[0]
		for i in range(1, dense.size()):
			acc += (dense[i] as Vector2).distance_to(last); last = dense[i]
			if acc >= 1.0 and (dense[i] as Vector2).distance_to(B) > 0.7: ch.append(dense[i]); acc = 0.0
		var clen := 0.0; var pv := A
		for p in ch + [B]: clen += (p as Vector2).distance_to(pv); pv = p
		if clen / main_len > (0.78 if ctype == "wind" else 0.66): return {}
		var prev := A; var prev_dir := tA
		for p in ch + [B]:                                                            # минимальный радиус хорды ≥ 2,8 км
			var d2: Vector2 = p - prev
			if d2.length() < 0.2: continue
			var da := absf(angle_difference(prev_dir.angle(), d2.angle()))
			if da / maxf(d2.length(), 0.3) > 0.36: return {}
			prev_dir = d2.normalized(); prev = p
		for ci in ch.size():                                                          # хорда не должна подходить к другим частям пути
			var p: Vector2 = ch[ci]; var c: Vector2i = cell_of.call(p)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var lst = cells.get(Vector2i(c.x + dx, c.y + dy))
					if lst != null:
						for idx in lst:
							if int(idx) < pts.size() - 8 and p.distance_to(pts[idx]) < 6.0 and ci > 4 and ci < ch.size() - 4: return {}
		var blk: Array = w["cand"]
		for ci in range(5, ch.size() - 5):                                          # и от собственных точек блока (кроме 8 км у концов)
			for bj in range(8, blk.size() - 8):
				if (ch[ci] as Vector2).distance_to(blk[bj]) < 4.5: return {}
		return {"pts": [A] + ch + [B], "len": clen, "main": main_len, "type": ctype}
	try_piece.call([["s", 30]])                            # длинный прямой разгон
	var guard := 0; var fails := 0; var since_block := 0
	while pts.size() < len_km - 24.0 and guard < 30000:
		guard += 1
		var turn: float = st["turn"]
		var sg := 1.0 if rng.randf() < 0.5 else -1.0
		if absf(turn) > 1.6 and rng.randf() < 0.75: sg = -signf(turn)             # баланс левых и правых поворотов
		var piece: Array
		var want_block := cuts.size() < 3 and pts.size() > 60 + cuts.size() * 150 and since_block > 4
		var is_block := want_block and rng.randf() < 0.8
		if is_block:
			var ctype := "needle" if cuts.size() == 1 else "wind"
			var done := false
			for sgn in [sg, -sg]:                                                   # пробуем обе стороны
				var rb := rng.randf_range(6.0, 8.5)
				var sw := rng.randi_range(8, 16)
				var ear := [["a", rb, PI * 0.5, sgn], ["s", sw], ["a", rb, PI * 0.5, -sgn], ["a", rb, PI * 0.5, -sgn], ["s", sw], ["a", rb, PI * 0.5, sgn]]   # «ухо»: уходит вбок и возвращается на ту же линию
				var piece2: Array
				if ctype == "needle":                                                # два «уха» с разных сторон: длинная прямая срезка между ними
					var ear2 := [["a", rb, PI * 0.5, -sgn], ["s", sw], ["a", rb, PI * 0.5, sgn], ["a", rb, PI * 0.5, sgn], ["s", sw], ["a", rb, PI * 0.5, -sgn]]
					piece2 = ear + [["s", 3]] + ear2
				elif rng.randf() < 0.7: piece2 = ear
				else: piece2 = [["a", rng.randf_range(15.0, 19.0), deg_to_rad(rng.randf_range(300.0, 335.0)), sgn], ["s", rng.randi_range(4, 9)]]
				var w2: Dictionary = walk.call(piece2)
				if not clear.call(w2["cand"], pts.size()): continue
				var ch2: Dictionary = make_chord.call(w2, ctype)
				if ch2.is_empty(): continue
				commit.call(w2, ch2); since_block = 0; fails = 0; done = true; break
			if done: continue
			fails += 1
		else:
			var u := rng.randf()
			var rr := rng.randf()
			var rad := rng.randf_range(2.8, 4.5) if rr < 0.25 else (rng.randf_range(5.0, 9.0) if rr < 0.7 else rng.randf_range(10.0, 18.0))
			if u < 0.22: piece = [["s", rng.randi_range(3, 16)]]
			elif u < 0.78: piece = [["a", rad, deg_to_rad(rng.randf_range(30.0, 170.0 if rad < 5.0 else 130.0)), sg]]
			else:
				var rs := rng.randf_range(4.0, 9.0); var a1 := deg_to_rad(rng.randf_range(40.0, 85.0))
				piece = [["a", rs, a1, sg], ["a", rs * rng.randf_range(0.8, 1.4), a1 * rng.randf_range(0.8, 1.3), -sg]]
			if try_piece.call(piece): fails = 0; since_block += 1; continue
			fails += 1
		if fails > 22 and hist.size() > 2:                                          # тупик: откатываем несколько кусков назад
			var back := mini(rng.randi_range(2, 6), hist.size() - 1)
			var e: Dictionary = hist[hist.size() - back]
			hist.resize(hist.size() - back)
			pts.resize(e["n"]); cuts.resize(e["cn"]); st["pos"] = e["pos"]; st["h"] = e["h"]; st["turn"] = e["turn"]
			rebuild.call(); fails = 0
	try_piece.call([["s", 22]])                            # прямая за финишем: торможение
	# --- срезки v3: объезд крупных участков основного пути. Старые «хорды» блоков служили только ограничениями при генерации и отбрасываются ---
	cuts = []
	var hints := {}
	if seed == 11 and absf(len_km - 650.0) < 1.0: hints = {0: [107, 263], 1: [338, 452], 2: [505, 640]}   # по эскизу
	var types := ["wind", "needle", "wind"]
	var spans := [[110, 170], [60, 120], [100, 160]]
	var fracs := [0.2, 0.5, 0.78]
	var n_pts := pts.size()
	for k in 3:
		var found := {}
		for attempt in 3000:
			var i: int; var j: int
			if hints.has(k):
				i = int(hints[k][0]) + rng.randi_range(-6, 6); j = int(hints[k][1]) + rng.randi_range(-6, 6)
			else:
				i = int(n_pts * fracs[k]) + rng.randi_range(-int(n_pts * 0.1), int(n_pts * 0.1)); j = i + rng.randi_range(int(spans[k][0]), int(spans[k][1]))
				if j >= n_pts - 30: continue
				if pts[i].distance_to(pts[j]) > 0.4 * float(j - i): continue
			if i < 3 or j > n_pts - 6: continue
			if not cuts.is_empty() and i < int((cuts[cuts.size() - 1] as Dictionary)["b"]) + 12: continue
			var A: Vector2 = pts[i]; var B: Vector2 = pts[j]; var L := A.distance_to(B)
			if L < 10.0: continue
			var dv := (B - A) / L; var nv := Vector2(-dv.y, dv.x)
			var hA := ((pts[i + 1] as Vector2) - (pts[i - 1] as Vector2)).normalized(); var hB := ((pts[j + 1] as Vector2) - (pts[j - 1] as Vector2)).normalized()
			var tA := (hA * 0.4 + dv * 0.6).normalized(); var tB := (hB * 0.4 + dv * 0.6).normalized()
			var ctrl: Array = [A]
			var nw := 3 if types[k] == "wind" else 2
			var amp := clampf(L * 0.11, 1.8, 4.5) if types[k] == "wind" else clampf(L * 0.05, 0.8, 1.8)
			var sgw := 1.0 if rng.randf() < 0.5 else -1.0
			for w in nw:
				var t := (float(w) + 1.0) / (float(nw) + 1.0) + rng.randf_range(-0.05, 0.05)
				ctrl.append(A + dv * L * t + nv * sgw * amp * rng.randf_range(0.6, 1.2)); sgw = -sgw
			ctrl.append(B)
			var cp: Array = [A - tA * 3.0] + ctrl + [B + tB * 3.0]
			var dense: Array = []
			for ii in range(1, cp.size() - 2):
				for kk in 10:
					var tt := float(kk) / 10.0
					var p0: Vector2 = cp[ii - 1]; var p1: Vector2 = cp[ii]; var p2: Vector2 = cp[ii + 1]; var p3: Vector2 = cp[ii + 2]
					dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * tt + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * tt * tt + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * tt * tt * tt))
			dense.append(B)
			var ch: Array = []; var acc := 0.0; var last: Vector2 = dense[0]
			for ii in range(1, dense.size()):
				acc += (dense[ii] as Vector2).distance_to(last); last = dense[ii]
				if acc >= 1.0 and (dense[ii] as Vector2).distance_to(B) > 0.7: ch.append(dense[ii]); acc = 0.0
			var clen := 0.0; var pv := A
			for p in ch + [B]: clen += (p as Vector2).distance_to(pv); pv = p
			if clen / float(j - i) > 0.62: continue
			var ok := true; var prev := A; var prev_dir := tA
			for p in ch + [B]:                                                        # минимальный радиус ≥ 2 км
				var d2: Vector2 = p - prev
				if d2.length() < 0.2: continue
				if absf(angle_difference(prev_dir.angle(), d2.angle())) / maxf(d2.length(), 0.3) > 0.5: ok = false; break
				prev_dir = d2.normalized(); prev = p
			if not ok: continue
			for ci in range(4, ch.size() - 4):                                       # не подходит к основному пути ближе 5 км
				var q: Vector2 = ch[ci]
				for idx in pts.size():
					if absi(idx - i) > 6 and absi(idx - j) > 6 and q.distance_to(pts[idx]) < 5.0: ok = false; break
				if not ok: break
			if not ok: continue
			found = {"a": i, "b": j, "pts": [A] + ch + [B], "len": clen, "main": float(j - i), "type": types[k]}
			break
		if not found.is_empty(): cuts.append(found)
		else: print("TRACKGEN: срезка ", k, " не найдена")
	var out: Array = []
	for p in pts: out.append(Vector2(p.x, -p.y))
	var cout: Array = []
	for ct in cuts:
		var cp: Array = []
		for p in ct["pts"]: cp.append(Vector2(p.x, -p.y))
		cout.append({"a": ct["a"], "b": ct["b"], "pts": cp, "len": ct["len"], "main": ct["main"], "type": ct["type"]})
	return {"pts": out, "cuts": cout}
