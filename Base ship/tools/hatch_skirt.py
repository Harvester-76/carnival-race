# Дырка вокруг люков шлюзов: после flatten_hatches.py люк стал плоским диском на глубине xd, а кромка выреза в обшивке осталась на изогнутой
# поверхности (у грузового A до 1,2 м снаружи диска, у люка кают-компании B до 0,5 м), поэтому между кромкой и диском видна пустота.
# Скрипт достраивает в SM_Hull_Body «стенку проёма»: полоса граней от кромки выреза до плоскости внешней грани люка (вдоль X).
# Там, где кромка уже глубже диска (у B с внутренней стороны), стенка не нужна. UV стенки копируются с кромки, чтобы цвет совпадал с обшивкой.
# Вторая часть («вкладыш»): тонкая цилиндрическая гильза чуть шире проёма (R+0.04 м) от плоскости диска до внутренней стороны обшивки. Она лежит за кромкой
# и закрывает щели в самой кромке (продольный шов обшивки даёт на краях люка ступеньку и просвет), через которые виден интерьер.
# Использование: exec(open('tools/hatch_skirt.py').read()); build_hatch_skirts()   (повторный вызов ничего не делает: стоит метка hatch_skirt)
import bpy, bmesh, math
from mathutils import Vector

HATCHES = {'SM_Hatch_A': 0.25, 'SM_Hatch_B': 0.40}                 # имя: на сколько внутрь от внешнего радиуса диска идёт кольцо-дно (у B в самом диске есть кольцевая щель шириной ~0,2 м)

def _boundary_loop_near(bm, mw, c, tol=0.7, min_n=100):
    be = [e for e in bm.edges if e.is_boundary]
    adj = {}
    for e in be:
        a, b = e.verts[0], e.verts[1]
        adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
    seen = set()
    for s in adj:
        if s in seen: continue
        st = [s]; comp = []; seen.add(s)
        while st:
            v = st.pop(); comp.append(v)
            for w in adj[v]:
                if w not in seen: seen.add(w); st.append(w)
        if len(comp) < min_n: continue
        cc = sum((mw @ v.co for v in comp), Vector()) / len(comp)
        if abs(cc.y - c.y) < tol and abs(cc.z - c.z) < tol:
            order = [comp[0]]; prev = None
            while True:                                           # обход кольца по рёбрам
                nxt = [w for w in adj[order[-1]] if w is not prev and w not in order]
                if not nxt: break
                prev = order[-1]; order.append(nxt[0])
            return order
    return None

def _liner(bm, mw, inv, loop, uv_of, uvl, c, plane, xback, rin, mat_idx, new_faces, N=96, pad=0.04):
    # «стакан» за люком: гильза радиуса R+pad от внутренней стороны обшивки до плоскости xback (сразу за передней гранью обода диска) и КОЛЬЦО-дно на xback
    # от радиуса rin (внутри обода диска, он его перекрывает) до R+pad: закрывает зазор между диском и стенкой проёма. Центр диска не закрыт, люк виден целиком.
    pts = [mw @ v.co for v in loop]
    ang = [math.atan2(p.z - c.z, p.y - c.y) for p in pts]
    rad = sorted(math.hypot(p.y - c.y, p.z - c.z) for p in pts)
    R = rad[len(rad) // 2] + pad
    def cd(a, b): return abs((a - b + math.pi) % (2 * math.pi) - math.pi)
    top = []; bot = []; inn = []; uvs = []
    for k in range(N):
        th = 2 * math.pi * k / N - math.pi
        near = sorted((cd(th, ang[i]), i) for i in range(len(pts)))
        xs = [pts[i].x for d, i in near if d < math.radians(4.0)] or [pts[near[0][1]].x]
        xt = min(max(xs) + 0.03, xback - 0.01)                           # внутренняя сторона обшивки в этом направлении (но не глубже дна)
        co, si = math.cos(th), math.sin(th)
        top.append(bm.verts.new(inv @ Vector((xt, c.y + R * co, c.z + R * si))))
        bot.append(bm.verts.new(inv @ Vector((xback, c.y + R * co, c.z + R * si))))
        inn.append(bm.verts.new(inv @ Vector((xback, c.y + rin * co, c.z + rin * si))))
        uvs.append(uv_of[near[0][1]])
    def setuv(f, kk_of):
        for lp in f.loops:
            kk = kk_of(lp.vert)
            for li, lay in enumerate(uvl): lp[lay].uv = uvs[kk][li] if li < len(uvs[kk]) else lp[lay].uv
    for k in range(N):
        j = (k + 1) % N
        for vs, want_c in (([top[k], top[j], bot[j], bot[k]], c), ([inn[k], inn[j], bot[j], bot[k]], None)):
            try: f = bm.faces.new(vs)
            except ValueError: continue
            f.material_index = mat_idx
            setuv(f, lambda v, k=k, j=j: j if v in (top[j], bot[j], inn[j]) else k)
            new_faces.append((f, want_c))

def build_hatch_skirts(eps=0.01):
    hull = bpy.data.objects['SM_Hull_Body']
    if hull.get('hatch_skirt'): return 'already'
    mw = hull.matrix_world; inv = mw.inverted()
    bm = bmesh.new(); bm.from_mesh(hull.data)
    uvl = list(bm.loops.layers.uv.values())
    new_faces = []
    for hn, ring_w in HATCHES.items():
        h = bpy.data.objects[hn]
        ws = [h.matrix_world @ v.co for v in h.data.vertices]
        c = Vector((0.0, (min(w.y for w in ws) + max(w.y for w in ws)) / 2, (min(w.z for w in ws) + max(w.z for w in ws)) / 2))
        plane = min(w.x for w in ws)                                      # внешняя грань диска (обшивка слева, нос +Y, наружу = -X)
        loop = _boundary_loop_near(bm, mw, c)
        if loop is None: print('нет кромки у', hn); continue
        n = len(loop)
        mat_idx = loop[0].link_faces[0].material_index if loop[0].link_faces else 0
        uv_of = []                                                        # UV кромки: по слою UV у ближайшей грани
        for v in loop:
            f = v.link_faces[0]; d = []
            for lay in uvl:
                for lp in f.loops:
                    if lp.vert is v: d.append(lp[lay].uv.copy())
            uv_of.append(d)
        wv = []
        for v in loop:
            w = mw @ v.co
            tx = plane if w.x < plane - eps else w.x                      # где кромка глубже диска — стенки нет (нулевая длина)
            wv.append(bm.verts.new(inv @ Vector((tx, w.y, w.z))))
        rd = max(math.hypot(w.y - c.y, w.z - c.z) for w in ws)                 # внешний радиус диска
        _liner(bm, mw, inv, loop, uv_of, uvl, c, plane, plane + 0.03, rd - ring_w, mat_idx, new_faces)
        for i in range(n):
            j = (i + 1) % n
            a, b, a2, b2 = loop[i], loop[j], wv[i], wv[j]
            la = (mw @ a.co).x < plane - eps; lb = (mw @ b.co).x < plane - eps
            if not (la or lb): continue
            vs = [a, b, b2, a2] if (la and lb) else ([a, b, b2] if lb else [a, b, a2])
            try: f = bm.faces.new(vs)
            except ValueError: continue
            f.material_index = mat_idx
            for lp in f.loops:                                            # UV: у новой вершины то же, что у соответствующей вершины кромки
                src = loop[i] if lp.vert in (a, a2) else loop[j]
                k = loop.index(src)
                for li, lay in enumerate(uvl): lp[lay].uv = uv_of[k][li] if li < len(uv_of[k]) else lp[lay].uv
            new_faces.append((f, c))
    bm.normal_update()                                                     # без пересчёта f.normal у новых граней нулевой, и разворот ниже не срабатывает (обшивка в игре рисуется с отсечением обратных граней)
    for f, c in new_faces:                                                 # нормаль: стенки — внутрь проёма (к оси люка), дно стакана — наружу (-X)
        fc = mw @ f.calc_center_median()
        want = Vector((-1.0, 0.0, 0.0)) if c is None else Vector((0.0, c.y - fc.y, c.z - fc.z))
        if (mw.to_3x3() @ f.normal).dot(want) < 0: f.normal_flip()
    bm.normal_update()
    bm.to_mesh(hull.data); bm.free(); hull.data.update()
    hull['hatch_skirt'] = True
    return len(new_faces)
