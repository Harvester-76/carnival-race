# Манжета шлюза в кают-компании: «цилиндр» от круглой панели внутренней двери шлюза (SM_Cabin_Doors, окружность R=2.18) до стены.
# Панель стоит на ~0.5-0.8 м от стены, манжета заполняет этот зазор; контур совпадает с панелью по построению. Запуск: exec(open('.../tools/build_airlock_collar.py').read())
import bpy, bmesh, math
from mathutils import Vector

arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
shell=bpy.data.objects['SM_Cabin_Shell']; inv=shell.matrix_world.inverted()
YC,ZC=20.34,-1.13          # центр круглой панели SM_Cabin_Doors (подгонка окружности по её вершинам, остаток 0.00)
R=2.18                     # радиус панели; снизу срезана полом
ZF=-2.13                   # уровень среза (низ панели у пола)
XF=-5.96                   # задняя плоскость панели
N=72

def loop_pts(off):
    pts=[]
    for i in range(N):
        t=i*math.tau/N
        y=YC+(R+off)*math.cos(t); z=ZC+(R+off)*math.sin(t)
        pts.append((y,max(z,ZF)))                  # ниже пола контур сплющен в плоский низ
    return pts
def wall_x(y,z):
    zc=max(-2.0,min(0.8,z))
    ok,loc,n,i=shell.ray_cast(inv@Vector((-5.0,y,zc)),Vector((-1,0,0)),distance=4)
    return (shell.matrix_world@loc).x if ok else -6.6
# сечения от стены к двери: (выступ наружу, смещение вдоль +x от стены или None=до рамки)
SECT=[(0.0,-0.03),(0.07,0.0),(0.07,0.12),(0.0,0.12),(0.0,'frame')]

old=bpy.data.objects.get('SM_Cabin_AirlockCollar')
if old: bpy.data.objects.remove(old,do_unlink=True)
me=bpy.data.meshes.new('SM_Cabin_AirlockCollar'); ob=bpy.data.objects.new('SM_Cabin_AirlockCollar',me); col.objects.link(ob)
ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted()
bm=bmesh.new(); uv=bm.loops.layers.uv.new('UVMap')
rows=[]
for off,dx in SECT:
    pts=loop_pts(off); row=[]
    for (y,z) in pts:
        wx=wall_x(*loop_pts(0.0)[len(row)])           # стена считается по базовому контуру
        x=XF if dx=='frame' else wx+dx
        row.append(bm.verts.new((x,y,z)))
    rows.append(row)
perim=sum(math.dist(loop_pts(0)[i],loop_pts(0)[(i+1)%N]) for i in range(N))
for r in range(len(rows)-1):
    for i in range(N):
        j=(i+1)%N
        f=bm.faces.new((rows[r][i],rows[r][j],rows[r+1][j],rows[r+1][i]))
        for l in f.loops:
            k=rows[r].index(l.vert) if l.vert in rows[r] else rows[r+1].index(l.vert)
            kk=k if k>0 or l.vert!=rows[r][0] else N
            l[uv].uv=((k/N)*perim/2.0,l.vert.co.x/2.0)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
# нормали наружу от оси (в комнату)
for f in bm.faces:
    c=f.calc_center_median(); d=Vector((0,c.y-YC,c.z-ZC))
    if d.dot(Vector((0,f.normal.y,f.normal.z)))<0: f.normal_flip()
for f in bm.faces: f.smooth=True
bm.to_mesh(me); bm.free()
mat=bpy.data.materials.get('MAT_Cabin_Steel'); me.materials.append(mat)
result={'faces':len(me.polygons)}
