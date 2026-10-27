# Кресла пилотов: скруглённые, с деталями (звезда с колёсиками, газлифт, подушки с валиками, спинка из секций, подголовник,
# подлокотники, ремни). Консоли с джойстиками и экранами в SM_Cabin_Seats не трогаются.
# Запуск: exec(open('.../tools/build_cabin_seats.py').read()). Бэкап меша: SM_Cabin_Seats_mesh_backup.
import bpy, bmesh, math
exec(open('/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/tools/furn_lib.py').read())
P='MAT_Cabin_'
get_mat(P+'Black',(0.015,0.017,0.02,1),0.15,0.0); get_mat(P+'Handle',(0.75,0.77,0.8,1),0.3,0.9)
o=bpy.data.objects['SM_Cabin_Seats']; me=o.data
if o.mode!='OBJECT': raise RuntimeError('SM_Cabin_Seats в режиме редактирования: выйдите из него')
if 'SM_Cabin_Seats_mesh_backup' not in bpy.data.meshes:
    b=me.copy(); b.name='SM_Cabin_Seats_mesh_backup'; b.use_fake_user=True
names=[s.material.name for s in o.material_slots]
bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
def stick(f): return all(0.68<abs(v.co.x)<0.82 and 28.97<v.co.y<29.12 and v.co.z>-1.705 for v in f.verts)
seen=set(); kill=[]
for f in bm.faces:
    if f.index in seen: continue
    st=[f]; seen.add(f.index); cur=[]
    while st:
        g=st.pop(); cur.append(g)
        for v in g.verts:
            for h in v.link_faces:
                if h.index not in seen: seen.add(h.index); st.append(h)
    mt={names[g.material_index] for g in cur}
    if mt<={P+'Leather',P+'Steel'} and not all(stick(g) for g in cur): kill+=cur
bmesh.ops.delete(bm,geom=kill,context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
S=Furn(me,list(names)); S.bm=bm
ZF=-2.31
def chair(cx,cy,sc=1.0,yaw=0.0):
    R=Matrix.Rotation(yaw,3,'Z')
    def Pp(dx,dy,dz): v=R@Vector((dx*sc,dy*sc,dz*sc)); return (cx+v.x,cy+v.y,ZF+v.z)
    def B(c,sz,r,m,rx=0.0,rz=0.0,ry=0.0,seg=3): S.rbox(Pp(*c),(sz[0]*sc,sz[1]*sc,sz[2]*sc),r*sc,rot=(rx,ry,rz+yaw),m=m,seg=seg)
    def C(c,r,h,m,r2=None,bev=0.0): S.cyl(Pp(*c),r*sc,h*sc,m,r2=(None if r2 is None else r2*sc),bev=bev*sc)
    # основание: звезда из 5 лучей, колёсики, втулка
    for k in range(5):
        a=k*math.tau/5+math.radians(18)
        B((0.20*math.cos(a),0.20*math.sin(a),0.075),(0.40,0.07,0.045),0.02,P+'Steel',rz=a)
        S.sph(Pp(0.39*math.cos(a),0.39*math.sin(a),0.040),0.038*sc,P+'Black')
    C((0,0,0.09),0.085,0.07,P+'Steel',bev=0.02)
    C((0,0,0.28),0.045,0.30,P+'Handle'); C((0,0,0.22),0.062,0.16,P+'Black',r2=0.055)
    # сиденье
    B((0,0,0.495),(0.56,0.54,0.07),0.03,P+'Steel')
    B((0,0.01,0.575),(0.54,0.52,0.13),0.065,P+'Leather',seg=4)
    for sx in (-1,1): B((sx*0.255,0.0,0.62),(0.07,0.46,0.11),0.04,P+'Leather',seg=3,rz=sx*0.0)
    # спинка: секции под наклоном (верх назад)
    t=math.radians(9)
    B((0,-0.27,0.80),(0.50,0.10,0.22),0.045,P+'Leather',rx=t,seg=4)
    B((0,-0.29,1.10),(0.54,0.11,0.42),0.06,P+'Leather',rx=t,seg=4)
    B((0,-0.31,1.42),(0.48,0.10,0.26),0.05,P+'Leather',rx=t,seg=4)
    for sx in (-1,1): B((sx*0.27,-0.25,1.12),(0.07,0.16,0.50),0.04,P+'Leather',rx=t,rz=sx*0.22,seg=3)
    B((0,-0.36,1.00),(0.10,0.05,0.80),0.015,P+'Steel',rx=t)
    # подголовник на штоках
    B((0,-0.335,1.69),(0.30,0.11,0.22),0.055,P+'Leather',rx=t,seg=4)
    for sx in (-0.07,0.07): C((sx,-0.335,1.56),0.012,0.16,P+'Handle')
    # подлокотники
    for sx in (-1,1):
        B((sx*0.34,-0.08,0.69),(0.04,0.06,0.22),0.012,P+'Steel')
        B((sx*0.34,0.02,0.80),(0.09,0.36,0.05),0.022,P+'Leather',seg=3)
    # ремни и пряжка
    for sx in (-0.13,0.13):
        B((sx,-0.215,1.17),(0.055,0.012,0.74),0.004,P+'Black',rx=t)
    B((0,-0.20,0.95),(0.09,0.02,0.06),0.01,P+'Handle',rx=t)
chair(0.0,28.7,1.0)
chair(-2.14,28.9,1.1,math.radians(-6))
chair(2.14,28.9,1.1,math.radians(6))
S.write()
result={'faces':len(me.polygons),'mats':[s.material.name for s in o.material_slots]}
