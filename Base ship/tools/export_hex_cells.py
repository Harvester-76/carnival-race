# Таблица ячеек шестигранников обшивки -> damage/hex_cells.csv. Запуск: blender -b spaceship_4.blend -P tools/export_hex_cells.py
# РЕШЁТКА (в Unreal материал обшивки считает ячейку по той же формуле; рисунок шестигранников делается процедурно по ней же):
#   островерхие шестигранники, ширина между гранями W=1.2 м, шаг рядов H=W*sqrt(3)/2=1.0392 м, нечётные ряды сдвинуты на W/2.
#   Проекция по доминирующей оси нормали (как box-проекция): ось X -> (a,b)=(y,z), ось Y -> (x,z), ось Z -> (x,y).
#   Ячейка = (ось, i, j): b=j*H, a=(i+0.5*(j&1))*W.  Центр ячейки в 3D: луч вдоль оси через (a,b) до поверхности.
import bpy, math, csv, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
W=1.2; H=W*math.sqrt(3)/2
objs=[bpy.data.objects[n] for n in ('SM_Hull_Body','SM_Wing_L','SM_Wing_R')]
dg=bpy.context.evaluated_depsgraph_get(); trees=[(o,BVHTree.FromObject(o,dg)) for o in objs]
zattr=objs[0].data.attributes['dmg_zone']; ZN=[d.value for d in zattr.data]
ax_uv={0:(1,2),1:(0,2),2:(0,1)}; rng={0:(-46,40),1:(-46,40),2:(-8,13)}
rows=[]; rid=0
bbmin=Vector((-26,-46,-8)); bbmax=Vector((26,40,13))
for axis in (0,1,2):
    ia,ib=ax_uv[axis]; amin,amax=bbmin[ia],bbmax[ia]; bmin,bmax=bbmin[ib],bbmax[ib]
    j0=int(math.floor(bmin/H)); j1=int(math.ceil(bmax/H))
    for j in range(j0,j1+1):
        b=j*H; i0=int(math.floor(amin/W))-1; i1=int(math.ceil(amax/W))+1
        for i in range(i0,i1+1):
            a=(i+0.5*(j&1))*W
            if a<amin or a>amax: continue
            o=Vector((0,0,0)); o[ia]=a; o[ib]=b; o[axis]=-60.0; d=Vector((0,0,0)); d[axis]=1.0
            p=o.copy(); seen=0
            for _ in range(8):
                best=None
                for ob,t in trees:
                    h=t.ray_cast(p,d)
                    if h[0] is not None and (best is None or h[3]<best[3]): best=(h[0],h[1],h[2],h[3],ob)
                if best is None: break
                loc,n,fi,dist,ob=best
                if abs(n[axis])>=max(abs(n[k]) for k in range(3))-1e-6:
                    me=ob.data; poly=me.polygons[fi]; zone=ZN[poly.vertices[0]] if ob.name=='SM_Hull_Body' else -1
                    rows.append((rid,axis,i,j,round(loc.x,3),round(loc.y,3),round(loc.z,3),round(n.x,3),round(n.y,3),round(n.z,3),zone,ob.name)); rid+=1
                p=loc+d*0.02
out=os.path.join(os.path.dirname(bpy.data.filepath),'damage'); os.makedirs(out,exist_ok=True)
with open(os.path.join(out,'hex_cells.csv'),'w',newline='') as f:
    w=csv.writer(f); w.writerow(['id','axis','i','j','x','y','z','nx','ny','nz','zone','part']); w.writerows(rows)
import collections
print('HX cells',len(rows),dict(collections.Counter(r[1] for r in rows)),dict(collections.Counter(r[11] for r in rows)))
