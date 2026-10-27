class_name ShipVariant
extends RefCounted
# Вариации модели корабля при загрузке (без отдельных файлов моделей).
# Этап 1, каюты: у корпуса есть настоящие отверстия иллюминаторов, поэтому число кают меняется резкой, а не растяжением: последняя «ячейка» каюты
#   (шаг 2.4 м, ячейка [-7.0, -4.6]) вырезается из корпуса и из коридора, лишние ячейки удаляются либо копируются; передняя часть корабля сдвигается,
#   корма остаётся на месте. Стыки соседних кусков перекрываются на EPS, поэтому щелей нет (корпус сужается и поднимается к корме, края не совпадают на несколько сантиметров).
#   Иллюминаторы (SM_Glass_02..11) и комнаты (SM_Room_01..10) удаляются или копируются по тем же ячейкам, стёкла стоят точно напротив отверстий.
# Этап 2, форма: кусочно-линейная деформация по оси корабля (нос длиннее/короче, корма длиннее и шире) и общий размер. Мелкие детали переносятся целиком, крупные
#   деформируются по вершинам одной функцией, поэтому швы не расходятся.
#
# spec: {"cabins": d (добавить/убрать пары кают), "nose": [z_нос, k], "rear": [z_корма, k, ширина], "scale": s, "nose_engine": true}

const CELL_A := -7.0               # ячейка последней каюты (все пары кают: -16.6 .. -4.6, шаг 2.4)
const CELL_B := -4.6
const PITCH := 2.4
const EPS := 0.2                   # перекрытие соседних кусков корпуса
const ANCHOR := 10.0
const RIGID_PREFIX := ["SM_Engine_", "SM_Spotlight_", "SM_Foot_", "SM_Hatch_", "SM_Glass_"]

static func _is_rigid(nm: String) -> bool:
	if nm == "SM_Glass_01": return false
	for p in RIGID_PREFIX:
		if nm.begins_with(p): return true
	return false

# ---------------------------------------------------------------- этап 2: деформация по оси
static func _slopes(spec: Dictionary, s0: float) -> Array:
	var nz := -22.0 + s0
	var kn := 1.0
	if spec.has("nose"):
		nz = float(spec["nose"][0]) + s0; kn = float(spec["nose"][1])
	var rz := 30.0
	var kr := 1.0
	if spec.has("rear"):
		rz = float(spec["rear"][0]); kr = float(spec["rear"][1])
	return [[-1000.0, nz, rz, 1000.0], [kn, 1.0, kr]]

static func warp_z(z: float, sl: Array) -> float:
	var b: Array = sl[0]
	var k: Array = sl[1]
	var out := ANCHOR
	if z >= ANCHOR:
		for i in k.size():
			var a := maxf(b[i], ANCHOR)
			var c := minf(b[i + 1], z)
			if c > a: out += (c - a) * float(k[i])
	else:
		for i in k.size():
			var a := maxf(b[i], z)
			var c := minf(b[i + 1], ANCHOR)
			if c > a: out -= (c - a) * float(k[i])
	return out

static func width_factor(z: float, spec: Dictionary) -> float:
	if not spec.has("rear"): return 1.0
	var rz: float = float(spec["rear"][0])
	var w: float = float(spec["rear"][2])
	return 1.0 + (w - 1.0) * clampf((z - rz) / 12.0, 0.0, 1.0)

static func warp_point(p: Vector3, spec: Dictionary, sl: Array) -> Vector3:
	return Vector3(p.x * width_factor(p.z, spec), p.y, warp_z(p.z, sl)) * float(spec.get("scale", 1.0))

# root: узел с частями корабля (дети — MeshInstance3D с исходными положениями). Возвращает {"shape": выпуклая оболочка корпуса, "com": центр масс}
static func apply(root: Node3D, spec: Dictionary) -> Dictionary:
	var delta: int = int(spec.get("cabins", 0))
	var s0 := 0.0
	if delta != 0: s0 = _cabin_edit(root, delta)
	var sl := _slopes(spec, s0)
	var s: float = float(spec.get("scale", 1.0))
	var res := {}
	for n in root.get_children():
		if not (n is MeshInstance3D): continue
		var mi := n as MeshInstance3D
		if mi.is_queued_for_deletion(): continue
		var nm := String(mi.name)
		if _is_rigid(nm):
			var pos := mi.position
			mi.position = Vector3(pos.x * width_factor(pos.z, spec), pos.y, warp_z(pos.z, sl)) * s
			mi.scale = Vector3.ONE * s
		else:
			_warp_mesh(mi, spec, sl, res)
	if bool(spec.get("nose_engine", false)): _add_nose_engine(root, sl, s)
	return res

static func _warp_mesh(mi: MeshInstance3D, spec: Dictionary, sl: Array, res: Dictionary) -> void:
	var s: float = float(spec.get("scale", 1.0))
	var pos := mi.position
	var am := ArrayMesh.new()
	for i in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(i)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for k in vs.size(): vs[k] = warp_point(vs[k] + pos, spec, sl) - pos * s
		arr[Mesh.ARRAY_VERTEX] = vs
		for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]: arr[ci] = null      # доп. канал импортированных поверхностей нашим шейдерам не нужен, а с ним нельзя пересобрать поверхность
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(i, mi.mesh.surface_get_material(i))
		am.surface_set_name(i, mi.mesh.surface_get_name(i))
	mi.mesh = am
	mi.position = pos * s
	var nm := String(mi.name)
	if nm == "SM_Hull_Body_LOD1": res["shape"] = am.create_convex_shape(true, true)
	if nm == "SM_Hull_Body": res["com"] = mi.position + am.get_aabb().get_center()

# ---------------------------------------------------------------- этап 1: каюты
# Корпус сужается и опускается к носу, поэтому после вырезания кают нос (сдвинутый назад) в месте стыка меньше кормовой части: на борту ступенька.
# Передняя часть плавно (на MORPH_L метров) растягивается по сечению так, чтобы у стыка совпасть с сечением кормовой части.
const MORPH_L := 16.0
static var _mp: Dictionary = {}

static func _profile(mi: MeshInstance3D, z0: float) -> Vector4:                  # сечение плоскостью z = z0: (макс |x|, мин y, макс y) в координатах корабля
	var out := Vector4(0.0, 1.0e9, -1.0e9, -1.0e9)
	var pos := mi.position
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, I.size(), 3):
			for e in 3:
				var a: Vector3 = V[I[t + e]] + pos
				var b: Vector3 = V[I[t + (e + 1) % 3]] + pos
				if (a.z - z0) * (b.z - z0) > 0.0 or is_equal_approx(a.z, b.z): continue
				var q := a.lerp(b, (z0 - a.z) / (b.z - a.z))
				out.x = maxf(out.x, absf(q.x)); out.y = minf(out.y, q.y); out.z = maxf(out.z, q.y)
				if absf(q.x) > 1.5: out.w = maxf(out.w, q.y)                                  # уровень крыши без центрального гребня-киля
	return out

const NB := 12
static func _bands(mi: MeshInstance3D, z0: float, y0: float, y1: float) -> PackedFloat32Array:     # полуширина сечения по NB высотным слоям
	var w := PackedFloat32Array(); w.resize(NB); w.fill(0.0)
	var pos := mi.position
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, I.size(), 3):
			for e in 3:
				var a: Vector3 = V[I[t + e]] + pos
				var b: Vector3 = V[I[t + (e + 1) % 3]] + pos
				if (a.z - z0) * (b.z - z0) > 0.0 or is_equal_approx(a.z, b.z): continue
				var q := a.lerp(b, (z0 - a.z) / (b.z - a.z))
				var k := clampi(int((q.y - y0) / (y1 - y0) * float(NB)), 0, NB - 1)
				w[k] = maxf(w[k], absf(q.x))
	for k in NB:                                                                    # пустые слои берут соседа
		if w[k] <= 0.0: w[k] = w[k - 1] if k > 0 else 1.0
	return w

static func _morph_setup(root: Node3D, zA: float, zB: float) -> void:
	_mp = {}
	var h := root.get_node_or_null("SM_Hull_Body") as MeshInstance3D
	if h == null: return
	var pa := _profile(h, zA)
	var pb := _profile(h, zB)
	if pa.x < 0.1 or pb.x < 0.1 or pa.w - pa.y < 0.1 or pb.w - pb.y < 0.1 or pa.z - pa.w < 0.1 or pb.z - pb.w < 0.1: return
	_mp = {"zA": zA, "wa": _bands(h, zA, pa.y, pa.w), "wb": _bands(h, zB, pb.y, pb.w), "ya0": pa.y, "yah": pa.w - pa.y, "pa": pa, "pb": pb}

static func _ymap(y: float) -> float:                                              # кусочно-линейно: низ -> низ, крыша -> крыша, верх гребня -> верх гребня кормового сечения
	var pa: Vector4 = _mp["pa"]
	var pb: Vector4 = _mp["pb"]
	if y <= pa.w: return pb.y + (y - pa.y) * (pb.w - pb.y) / (pa.w - pa.y)
	return pb.w + (y - pa.w) * (pb.z - pb.w) / (pa.z - pa.w)

# Добавленные каюты: копии ячейки стоят подряд, а корпус поднимается к корме, поэтому конец одной копии выше начала следующей (ступеньки на крыше).
# Подъём крыши, киля и ширина распределяются по цепочке копий: на копии idx из n точка с долей t по ячейке получает высоту, соответствующую (idx + t) / n всей ячейки.
static var _cp: Dictionary = {}

static func _cell_setup(root: Node3D, zA: float, zB: float, n: int) -> void:
	_cp = {}
	var h := root.get_node_or_null("SM_Hull_Body") as MeshInstance3D
	if h == null: return
	var pa := _profile(h, zA)
	var pb := _profile(h, zB)
	if pa.x < 0.1 or pb.x < 0.1 or pa.w - pa.y < 0.1 or pb.w - pb.y < 0.1 or pa.z - pa.w < 0.1 or pb.z - pb.w < 0.1: return
	_cp = {"zA": zA, "zB": zB, "n": n, "pa": pa, "pb": pb}

static func _cell_pt(p: Vector3, idx: int) -> Vector3:                              # p: исходные координаты точки внутри ячейки
	if _cp.is_empty(): return p
	var zA: float = _cp["zA"]
	var zB: float = _cp["zB"]
	var pa: Vector4 = _cp["pa"]
	var pb: Vector4 = _cp["pb"]
	var tt := clampf((p.z - zA) / (zB - zA), 0.0, 1.0)
	var u := (float(idx) + tt) / float(_cp["n"])
	var roof_s := lerpf(pa.w, pb.w, tt)
	var roof_t := lerpf(pa.w, pb.w, u)
	var fin_s := lerpf(pa.z, pb.z, tt)
	var fin_t := lerpf(pa.z, pb.z, u)
	var y0 := pa.y
	var y := p.y
	if y <= roof_s: y = y0 + (p.y - y0) * (roof_t - y0) / maxf(roof_s - y0, 0.01)
	else: y = roof_t + (p.y - roof_s) * (fin_t - roof_t) / maxf(fin_s - roof_s, 0.01)
	var kx := lerpf(pa.x, pb.x, u) / lerpf(pa.x, pb.x, tt)
	return Vector3(p.x * kx, y, p.z)

static func _morph_pt(p: Vector3) -> Vector3:                                      # p: исходные координаты корабля
	if _mp.is_empty(): return p
	var w := smoothstep(float(_mp["zA"]) - MORPH_L, float(_mp["zA"]), p.z)
	var yn := clampf((p.y - float(_mp["ya0"])) / float(_mp["yah"]), 0.0, 0.999) * float(NB - 1)
	var i0 := int(yn)
	var f := yn - float(i0)
	var wa: PackedFloat32Array = _mp["wa"]; var wb: PackedFloat32Array = _mp["wb"]
	var kx := lerpf(wb[i0] / wa[i0], wb[mini(i0 + 1, NB - 1)] / wa[mini(i0 + 1, NB - 1)], f)
	kx = clampf(kx, 0.93, 1.08)                                                     # у самого верха формы сечений разные (плоская крыша / узкий гребень): там не подгоняем
	return Vector3(p.x * (1.0 + w * (kx - 1.0)), lerpf(p.y, _ymap(p.y), w), p.z)

# возвращает сдвиг передней части вдоль z
static func _cabin_edit(root: Node3D, delta: int) -> float:
	var k := absi(delta)
	var zA := CELL_A
	var zB := CELL_B
	var offsets: Array = []                          # смещения копий ячейки (для добавления: k копий + оригинал)
	var s0: float
	if delta < 0:
		zA = CELL_B - PITCH * float(k)                # вырезаем k ячеек перед концом ряда
		s0 = PITCH * float(k) + EPS                   # передняя часть сдвигается назад и перекрывает корму на EPS
	else:
		for m in range(1, k + 1): offsets.append(-(PITCH - EPS) * float(k - m + 1))
		offsets.append(0.0)
		s0 = -(PITCH - EPS) * float(k) + EPS
	_mp = {}
	if delta < 0: _morph_setup(root, zA, zB)
	var glass: Dictionary = {}
	var rooms: Array = []
	var big: Array = []
	for n in root.get_children():
		if not (n is MeshInstance3D): continue
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.begins_with("SM_Glass_") and nm != "SM_Glass_01": glass[int(nm.substr(9))] = mi
		elif nm.begins_with("SM_Room_"): rooms.append(mi)
		elif _is_rigid(nm):                                                               # люки, прожекторы, подножки, двигатели: жёсткие детали впереди разреза едут вместе с носовой частью
			var rz2 := mi.position.z
			if rz2 < (zB if delta < 0 else zA): mi.position = _morph_pt(mi.position); mi.position.z += s0
		elif not _is_rigid(nm): big.append(mi)
	var pair_nodes: Dictionary = {}
	for id in glass.keys():
		var j := (int(id) - 2) / 2
		if not pair_nodes.has(j): pair_nodes[j] = []
		(pair_nodes[j] as Array).append(glass[id])
	for j in pair_nodes.keys():
		var zc := -15.4 + PITCH * float(j)
		for g in pair_nodes[j]:
			var gm := g as MeshInstance3D
			if delta < 0 and zc > zA and zc < zB: gm.queue_free()                       # окно убранной каюты
			elif zc < zA: gm.position = _morph_pt(gm.position); gm.position.z += s0     # впереди ячейки: подгоняется под сечение и сдвигается
	_cp = {}
	if delta > 0: _cell_setup(root, zA, zB, offsets.size())
	if delta > 0:
		for gm0 in pair_nodes[4]:
			for oi in range(offsets.size() - 1):                                       # копии последней пары по смещениям (оригинал остаётся на месте)
				var c := (gm0 as MeshInstance3D).duplicate() as MeshInstance3D
				c.name = "SM_Glass_X%d_%d" % [oi, root.get_child_count()]
				root.add_child(c)
				c.position = _cell_pt((gm0 as MeshInstance3D).position, oi) + Vector3(0, 0, float(offsets[oi]))
	for rm in rooms:
		var r := rm as MeshInstance3D
		var zc2 := (r.transform * r.get_aabb().get_center()).z
		if delta < 0 and zc2 > zA and zc2 < zB: r.queue_free()
		elif zc2 < zA: r.position.z += s0
		elif delta > 0 and zc2 > zA and zc2 < zB:                                      # комнаты последней каюты (правая и левая) копируются вместе с ячейкой
			for oi in range(offsets.size() - 1):
				var c2 := r.duplicate() as MeshInstance3D
				c2.name = "SM_Room_X%d_%d" % [oi, root.get_child_count()]
				root.add_child(c2)
				c2.position = r.position + Vector3(0, 0, float(offsets[oi]))
	for bm in big:                                                                      # корпус, упрощённый корпус для столкновений, коридор, интерьер
		var b := bm as MeshInstance3D
		var a: AABB = b.transform * b.get_aabb()
		if a.end.z <= zA: b.position.z += s0
		elif a.position.z >= zB: continue
		else: _slice_edit(b, zA, zB, s0, offsets)
	return s0

# Режет поверхности плоскостями z=zA и z=zB (в координатах корабля): впереди сдвиг s0, внутри — копии ячейки по offsets (пусто = ячейка удалена), сзади без изменений
static func _slice_edit(mi: MeshInstance3D, zA: float, zB: float, s0: float, offsets: Array) -> void:
	var pos := mi.position
	var am := ArrayMesh.new()
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var T = arr[Mesh.ARRAY_TANGENT]
		var U = arr[Mesh.ARRAY_TEX_UV]
		var U2 = arr[Mesh.ARRAY_TEX_UV2]
		var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var oV := PackedVector3Array()
		var oN := PackedVector3Array()
		var oT := PackedFloat32Array()
		var oU := PackedVector2Array()
		var oU2 := PackedVector2Array()
		var hasT: bool = T != null and (T as PackedFloat32Array).size() > 0
		var hasU: bool = U != null and (U as PackedVector2Array).size() > 0
		var hasU2: bool = U2 != null and (U2 as PackedVector2Array).size() > 0
		var t := 0
		while t < I.size():
			var ia := I[t]
			var ib := I[t + 1]
			var ic := I[t + 2]
			t += 3
			var za := V[ia].z + pos.z
			var zb := V[ib].z + pos.z
			var zc := V[ic].z + pos.z
			var zmin := minf(za, minf(zb, zc))
			var zmax := maxf(za, maxf(zb, zc))
			var poly: Array = [_vx(V, N, T, U, U2, ia, hasT, hasU, hasU2), _vx(V, N, T, U, U2, ib, hasT, hasU, hasU2), _vx(V, N, T, U, U2, ic, hasT, hasU, hasU2)]
			var pieces: Array = []                                                     # [область: 0 впереди / 1 ячейка / 2 сзади, полигон]
			if zmax <= zA: pieces.append([0, poly])
			elif zmin >= zB: pieces.append([2, poly])
			elif zmin >= zA and zmax <= zB: pieces.append([1, poly])
			else:
				var front := _clip(poly, zA, pos.z, true)
				var rest := _clip(poly, zA, pos.z, false)
				if front.size() >= 3: pieces.append([0, front])
				var cell := _clip(rest, zB, pos.z, true)
				var rear := _clip(rest, zB, pos.z, false)
				if cell.size() >= 3: pieces.append([1, cell])
				if rear.size() >= 3: pieces.append([2, rear])
			for pc in pieces:
				var region: int = pc[0]
				var poly2: Array = pc[1]
				var shifts: Array = []
				if region == 0: shifts = [s0]
				elif region == 2: shifts = [0.0]
				else:
					for o in offsets: shifts.append(float(o))
				for si2 in shifts.size():
					var sh: float = shifts[si2]
					for q in range(1, poly2.size() - 1):                               # веер треугольников
						for vv in [poly2[0], poly2[q], poly2[q + 1]]:
							var f: PackedFloat32Array = vv
							var vp := Vector3(f[0], f[1], f[2])
							if region == 0 and not _mp.is_empty() and String(mi.name).begins_with("SM_Hull_Body"): vp = _morph_pt(vp + pos) - pos
							if region == 1 and not _cp.is_empty() and String(mi.name).begins_with("SM_Hull_Body"): vp = _cell_pt(vp + pos, si2) - pos
							oV.append(Vector3(vp.x, vp.y, vp.z + float(sh)))
							oN.append(Vector3(f[3], f[4], f[5]))
							if hasT: oT.append_array(PackedFloat32Array([f[6], f[7], f[8], f[9]]))
							if hasU: oU.append(Vector2(f[10], f[11]))
							if hasU2: oU2.append(Vector2(f[12], f[13]))
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = oV
		out[Mesh.ARRAY_NORMAL] = oN
		if hasT: out[Mesh.ARRAY_TANGENT] = oT
		if hasU: out[Mesh.ARRAY_TEX_UV] = oU
		if hasU2: out[Mesh.ARRAY_TEX_UV2] = oU2
		var idx := PackedInt32Array()
		idx.resize(oV.size())
		for q in oV.size(): idx[q] = q
		out[Mesh.ARRAY_INDEX] = idx
		if oV.size() > 0:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
			var kk := am.get_surface_count() - 1
			am.surface_set_material(kk, mi.mesh.surface_get_material(si))
			am.surface_set_name(kk, mi.mesh.surface_get_name(si))
	mi.mesh = am

static func _vx(V: PackedVector3Array, N: PackedVector3Array, T, U, U2, i: int, hasT: bool, hasU: bool, hasU2: bool) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(14)
	f[0] = V[i].x; f[1] = V[i].y; f[2] = V[i].z
	f[3] = N[i].x; f[4] = N[i].y; f[5] = N[i].z
	if hasT:
		f[6] = T[i * 4]; f[7] = T[i * 4 + 1]; f[8] = T[i * 4 + 2]; f[9] = T[i * 4 + 3]
	if hasU:
		f[10] = U[i].x; f[11] = U[i].y
	if hasU2:
		f[12] = U2[i].x; f[13] = U2[i].y
	return f

# отсечение полигона плоскостью z (в координатах корабля = локальный z + pz): оставить меньшую или большую сторону
static func _clip(poly: Array, zc: float, pz: float, keep_less: bool) -> Array:
	var out: Array = []
	var n := poly.size()
	for i in n:
		var a: PackedFloat32Array = poly[i]
		var b: PackedFloat32Array = poly[(i + 1) % n]
		var da := (a[2] + pz) - zc
		var db := (b[2] + pz) - zc
		var ina := (da <= 0.0) if keep_less else (da >= 0.0)
		var inb := (db <= 0.0) if keep_less else (db >= 0.0)
		if ina: out.append(a)
		if ina != inb:
			var t := da / (da - db)
			var c := PackedFloat32Array()
			c.resize(14)
			for k in 14: c[k] = a[k] + (b[k] - a[k]) * t
			out.append(c)
	return out

static func _add_nose_engine(root: Node3D, sl: Array, s: float) -> void:
	var src := root.get_node_or_null("SM_Engine_Shunt_Bot_L") as MeshInstance3D
	if src == null: return
	var nose_z := warp_z(-36.5, sl) * s
	var eng := src.duplicate() as MeshInstance3D
	eng.name = "SM_Engine_Shunt_Nose"
	root.add_child(eng)
	eng.position = Vector3(0.0, -6.4 * s, nose_z + 1.5 * s)
	eng.scale = Vector3.ONE * s
	var br := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 2.4, 0.45)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.25)
	mat.metallic = 0.8
	mat.roughness = 0.5
	bm.material = mat
	br.mesh = bm
	br.name = "SM_Bracket_Nose"
	root.add_child(br)
	br.position = Vector3(0.0, -4.9 * s, nose_z + 1.5 * s)
	br.scale = Vector3.ONE * s
