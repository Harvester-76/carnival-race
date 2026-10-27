# Люки шлюзов (SM_Hatch_A грузовой, SM_Hatch_B кают-компании): «домик» (две плоскости под ±17° к вертикали) выпрямляется в плоскость,
# толщина сжимается в k раз, люк заглубляется в проём обшивки (как SM_Cargo_Hatch в старом проекте) и не заходит в интерьер.
# Формулы подогнаны по граням люков: x = a0 + s*|z - z0| (диск), после распрямления u = x - s*|z - z0|, новый x = xd + k*(u - a0).
# Использование: exec(open('tools/flatten_hatches.py').read()); flatten_hatches(); проверка: check_hatches()
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# имя: (z0, s, a0, xd, k, наклон плоскости вдоль z: dx/dz)
HATCH = {
    'SM_Hatch_A': (0.967, 0.3016, -12.638, -11.40, 0.5, 0.0),
    'SM_Hatch_B': (-1.132, 0.2929, -7.303, -6.90, 0.2, 0.0),
}

def flatten_hatches(params=None):
    params = params or HATCH
    for name, (z0, s, a0, xd, k, tilt) in params.items():
        o = bpy.data.objects.get(name)
        if o is None: continue
        if o.get('flattened'): continue                       # уже выпрямлен
        mw = o.matrix_world; inv = mw.inverted()
        for v in o.data.vertices:
            w = mw @ v.co
            u = w.x - s * abs(w.z - z0)
            nx = xd + k * (u - a0) + tilt * (w.z - z0)
            v.co = inv @ Vector((nx, w.y, w.z))
        o.data.update()
        o['flattened'] = True

def check_hatches():
    out = {}
    inner = [o for o in bpy.data.collections['COL_Interior'].objects if o.type == 'MESH']
    dg = bpy.context.evaluated_depsgraph_get()
    trees = {}
    for o in inner:
        bm = BVHTree.FromObject(o, dg); trees[o.name] = bm
    for name in ('SM_Hatch_A', 'SM_Hatch_B'):
        h = bpy.data.objects[name]; hv = [h.matrix_world @ v.co for v in h.data.vertices]
        res = {'x': (round(min(v.x for v in hv), 3), round(max(v.x for v in hv), 3))}
        near = []
        for n, t in trees.items():
            dmin = 1e9
            for v in hv:
                r = t.find_nearest(v)
                if r[0] is not None and r[3] < dmin: dmin = r[3]
            if dmin < 1.0: near.append((n, round(dmin, 3)))
        res['nearest_interior'] = sorted(near, key=lambda a: a[1])
        out[name] = res
    return out
