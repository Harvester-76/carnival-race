# Подножки корабля (3 шт.: носовая SM_Foot_F и две задние SM_Foot_L / SM_Foot_R): старые выступы вырезаются из SM_Hull_Body,
# вместо них строятся новые отдельные детали (полоз с загнутым носком, поршневые стойки с муфтами, раскос) со своим материалом MAT_Foot
# и текстурой textures/foot_albedo_1024.png; у каждой своя UCX-коллизия. Вызывается из export_godot.py; .blend не сохраняется.
import bpy, bmesh, os, math
from mathutils import Vector

HULL_Z = -5.0                                   # низ корпуса в зоне подножек
ZTOP = []
BOXES = [(-3.2, 3.2, 31.8, 35.2), (-13.4, -9.8, -35.8, -27.5), (9.8, 13.4, -35.8, -27.5)]

def _cut_old_feet():
    o = bpy.data.objects['SM_Hull_Body']; mw = o.matrix_world
    bm = bmesh.new(); bm.from_mesh(o.data)
    kill = []
    for f in bm.faces:
        c = mw @ f.calc_center_median()
        zmin = min((mw @ v.co).z for v in f.verts)
        if (c.z < HULL_Z - 0.1 or zmin < HULL_Z - 0.12) and any(b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] for b in BOXES): kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    edges = [e for e in bm.edges if len(e.link_faces) == 1 and any(b[0] - 0.3 <= (mw @ e.verts[0].co).x <= b[1] + 0.3 and b[2] - 0.3 <= (mw @ e.verts[0].co).y <= b[3] + 0.3 for b in BOXES)]
    if edges: bmesh.ops.holes_fill(bm, edges=edges, sides=2000)
    zs = []
    for b in BOXES:
        cx = (b[0] + b[1]) / 2; cy = (b[2] + b[3]) / 2
        near = [(mw @ f.calc_center_median()).z for f in bm.faces if f.normal.z < -0.7 and -5.3 < (mw @ f.calc_center_median()).z < -2.0 and abs((mw @ f.calc_center_median()).x - cx) < 1.2 and abs((mw @ f.calc_center_median()).y - cy) < 2.5]
        zs.append(max(near) if near else HULL_Z)
    ZTOP.clear(); ZTOP.extend(zs)
    bm.to_mesh(o.data); bm.free()
    return len(kill)

class Builder:
    def __init__(self, origin):
        self.bm = bmesh.new(); self.o = Vector(origin); self.uv = self.bm.loops.layers.uv.verify()
    def face(self, pts, kind='steel'):
        vs = [self.bm.verts.new(p - self.o) for p in pts]
        try: f = self.bm.faces.new(vs)
        except ValueError: return
        f.normal_update()
        n = f.normal; an = [abs(n.x), abs(n.y), abs(n.z)]; ax = an.index(max(an))
        idx = [i for i in range(3) if i != ax]
        co = [(p[idx[0]], p[idx[1]]) for p in pts]
        a0 = min(c[0] for c in co); b0 = min(c[1] for c in co)
        ext = max(max(c[0] for c in co) - a0, max(c[1] for c in co) - b0, 0.01)
        s = min(0.35, 0.95 / ext)
        for loop, c in zip(f.loops, co):
            u = (c[0] - a0) * s; v = (c[1] - b0) * s
            loop[self.uv].uv = (0.02 + u, 0.80 + 0.17 * v / max(1.0, 0.95)) if kind == 'hazard' else (0.02 + u, 0.05 + 0.65 * min(v, 1.0))
        return f
    def prism(self, prof, x0, x1, kind='steel', side_kind=None):
        # профиль в плоскости (y, z), выдавлен по X от x0 до x1
        n = len(prof)
        L = [Vector((x0, p[0], p[1])) for p in prof]; R = [Vector((x1, p[0], p[1])) for p in prof]
        self.face(L[::-1], kind); self.face(R, kind)
        for i in range(n):
            j = (i + 1) % n
            self.face([L[i], R[i], R[j], L[j]][::-1] if False else [L[j], R[j], R[i], L[i]], side_kind or kind)
    def cyl(self, c, r, z0, z1, seg=12, dx=0.0, dy=0.0, kind='steel'):
        lo = [Vector((c[0] + r * math.cos(2 * math.pi * k / seg), c[1] + r * math.sin(2 * math.pi * k / seg), z0)) for k in range(seg)]
        hi = [Vector((c[0] + dx + r * math.cos(2 * math.pi * k / seg), c[1] + dy + r * math.sin(2 * math.pi * k / seg), z1)) for k in range(seg)]
        self.face(lo[::-1], kind); self.face(hi, kind)
        for k in range(seg):
            j = (k + 1) % seg
            self.face([lo[k], lo[j], hi[j], hi[k]], kind)
    def box(self, c, sx, sy, sz, kind='steel'):
        x0, x1 = c[0] - sx / 2, c[0] + sx / 2; y0, y1 = c[1] - sy / 2, c[1] + sy / 2; z0, z1 = c[2] - sz / 2, c[2] + sz / 2
        P = lambda x, y, z: Vector((x, y, z))
        for q in ([P(x0,y0,z0), P(x0,y1,z0), P(x1,y1,z0), P(x1,y0,z0)], [P(x0,y0,z1), P(x1,y0,z1), P(x1,y1,z1), P(x0,y1,z1)],
                  [P(x0,y0,z0), P(x1,y0,z0), P(x1,y0,z1), P(x0,y0,z1)], [P(x1,y0,z0), P(x1,y1,z0), P(x1,y1,z1), P(x1,y0,z1)],
                  [P(x1,y1,z0), P(x0,y1,z0), P(x0,y1,z1), P(x1,y1,z1)], [P(x0,y1,z0), P(x0,y0,z0), P(x0,y0,z1), P(x0,y1,z1)]):
            self.face(q, kind)

def _material():
    m = bpy.data.materials.get('MAT_Foot')
    if m: return m
    m = bpy.data.materials.new('MAT_Foot'); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes['Principled BSDF']
    img = bpy.data.images.load(os.path.join(os.path.dirname(bpy.data.filepath), 'textures', 'foot_albedo_1024.png'))
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Metallic'].default_value = 0.75; bsdf.inputs['Roughness'].default_value = 0.5
    return m

def _publish(b, name, loc):
    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
    me = bpy.data.meshes.new(name); b.bm.to_mesh(me); b.bm.free()
    for p in me.polygons: p.use_smooth = False
    ob = bpy.data.objects.new(name, me); ob.location = loc
    me.materials.append(_material())
    bpy.data.collections['COL_Parts'].objects.link(ob)
    hb = bmesh.new(); hb.from_mesh(me); bmesh.ops.convex_hull(hb, input=hb.verts[:])
    hm = bpy.data.meshes.new('UCX_' + name + '_01'); hb.to_mesh(hm); hb.free()
    u = bpy.data.objects.new('UCX_' + name + '_01', hm); u.location = loc
    bpy.data.collections['COL_Collision'].objects.link(u)
    return ob

def _strut(b, base, top, z0, z1, rp=0.2, rs=0.42):
    # наклонная поршневая стойка: ось от base (низ, z0) до top (верх, z1); поршень снизу, цилиндр сверху, муфта на стыке
    def pt(t): return (base[0] + (top[0] - base[0]) * t, base[1] + (top[1] - base[1]) * t)
    def seg(t0, t1, r, seg_n=14):
        p0 = pt(t0); p1 = pt(t1)
        b.cyl(p0, r, z0 + (z1 - z0) * t0, z0 + (z1 - z0) * t1, seg_n, dx=p1[0] - p0[0], dy=p1[1] - p0[1])
    seg(0.0, 0.62, rp)                      # поршень
    seg(0.40, 1.04, rs)                     # цилиндр (уходит в корпус)
    seg(0.50, 0.58, rs + 0.1)               # муфта

def _rear_foot(name, cx, cy, sgn, zt):
    # sgn: +1 правый борт, -1 левый; стойки наклонены наружу к полозу, как у прежних подножек
    zb = -7.4; c0 = Vector((cx, cy, -6.0)); b = Builder(c0)
    L = 4.3
    prof = [(cy - L, zb), (cy + L - 1.4, zb), (cy + L, zb + 0.55), (cy + L, zb + 1.0), (cy + L - 1.1, zb + 0.7), (cy - L + 0.8, zb + 0.7), (cy - L, zb + 0.45)]
    b.prism(prof, cx - 0.85, cx + 0.85, 'steel', 'hazard')
    lean = sgn * 1.2                                                           # низ стойки дальше от осевой линии корабля, чем верх
    for dy, ly in ((-3.0, -0.5), (2.2, 0.5)):
        base = (cx + lean * 0.0, cy + dy + ly); top = (cx - lean, cy + dy - ly * 0.0)
        _strut(b, (cx, cy + dy), (cx - lean, cy + dy + ly), zb + 0.65, zt, 0.2, 0.42)
        b.box((cx, cy + dy, zb + 0.85), 1.5, 0.9, 0.3, 'hazard')               # башмак на полозе
    b.box((cx - lean * 0.45, cy - 0.5, (zb + zt) / 2 + 0.2), 0.3, 6.0, 0.25, 'steel')   # раскос между стойками
    b.box((cx + sgn * 0.7, cy + L - 0.7, zb + 1.2), 0.22, 0.22, 0.9, 'steel')  # щуп у носка
    return _publish(b, name, c0)

def _front_foot(name, cx, cy, zt):
    zb = -7.4; c0 = Vector((cx, cy, -6.0)); b = Builder(c0); L = 1.7
    prof = [(cy - L, zb), (cy + L - 0.8, zb), (cy + L, zb + 0.5), (cy + L, zb + 0.95), (cy + L - 0.7, zb + 0.65), (cy - L + 0.5, zb + 0.65), (cy - L, zb + 0.4)]
    b.prism(prof, cx - 1.1, cx + 1.1, 'steel', 'hazard')
    _strut(b, (cx, cy + 0.3), (cx, cy - 1.0), zb + 0.6, zt, 0.22, 0.46)        # стойка наклонена: низ вынесен вперёд, как у прежней
    b.box((cx, cy + 0.3, zb + 0.8), 1.5, 1.0, 0.3, 'hazard')
    b.cyl((cx, cy + 1.45), 0.13, zb + 0.6, zb + 1.3, 8)                        # маячок
    return _publish(b, name, c0)

def build_feet():
    if 'SM_Foot_L' in bpy.data.objects: return 0                    # уже внесено в .blend
    n = _cut_old_feet()
    _front_foot('SM_Foot_F', 0.0, 33.45, ZTOP[0])
    _rear_foot('SM_Foot_L', -11.7, -31.65, -1.0, ZTOP[1])
    _rear_foot('SM_Foot_R', 11.7, -31.65, 1.0, ZTOP[2])
    print('FOOT_ZTOP', ZTOP)
    bpy.context.view_layer.update()                                            # иначе matrix_world новых объектов остаётся единичной и экспорт обнуляет положение
    return n
