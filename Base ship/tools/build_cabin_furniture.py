# Угловые кухонные гарнитуры у задней стены кают-компании + скруглённая детальная мебель (диван, кресла, столик, торшер).
# Запуск: exec(open('.../tools/build_cabin_furniture.py').read())  (сначала подключается furn_lib.py)
# Меняет SM_Cabin_Lounge (старые стеллажи, диван, кресла, столик, торшер удаляются; ковёр, цветок и потолочные лампы остаются),
# создаёт SM_Cabin_Kitchen. Бэкап меша лаунжа: SM_Cabin_Lounge_mesh_backup.
import bpy, bmesh, math
exec(open('/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/tools/furn_lib.py').read())

Z0=-2.11
arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
get_mat('MAT_Cabin_Cabinet',(0.80,0.82,0.84,1),0.45)
get_mat('MAT_Cabin_Counter',(0.06,0.07,0.09,1),0.25)
get_mat('MAT_Cabin_Appliance',(0.62,0.64,0.67,1),0.35,0.8)
get_mat('MAT_Cabin_Black',(0.015,0.017,0.02,1),0.15,0.0)
get_mat('MAT_Cabin_Handle',(0.75,0.77,0.8,1),0.3,0.9)
P='MAT_Cabin_'

# ---------------- ЛАУНЖ: убрать старую мебель ----------------
lo=bpy.data.objects['SM_Cabin_Lounge']; lm=lo.data
if 'SM_Cabin_Lounge_mesh_backup' not in bpy.data.meshes:
    b=lm.copy(); b.name='SM_Cabin_Lounge_mesh_backup'; b.use_fake_user=True
names=[s.material.name for s in lo.material_slots]
bm=bmesh.new(); bm.from_mesh(lm); bm.faces.ensure_lookup_table()
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
    if mt<= {P+'Leather',P+'Fabric',P+'Wood',P+'Panel',P+'Steel'} or (mt=={P+'Light'} and len(cur)>10): kill+=cur
bmesh.ops.delete(bm,geom=kill,context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
L=Furn(lm,list(names)); L.bm=bm   # продолжаем в тот же bmesh

# ---- диван у правой стены (спинка к +x), y 20.4..23.8
def sofa(cx,y0,y1,sgn=1):
    cy=(y0+y1)/2; ln=y1-y0; z=Z0
    L.rbox((cx+0.0,cy,z+0.20),(0.96,ln,0.20),0.04,m=P+'Steel')                       # цоколь-рама
    for sy in (y0+0.10,y1-0.10):                                                       # ножки
        for sx in (cx-0.38,cx+0.38): L.cyl((sx,sy,z+0.05),0.03,0.10,P+'Handle',r2=0.02)
    n=3; w=(ln-0.44)/n
    for i in range(n):                                                                  # сиденья
        yy=y0+0.22+w*(i+0.5)
        L.rbox((cx-0.10,yy,z+0.37),(0.72,w-0.03,0.17),0.07,m=P+'Fabric',seg=4)
        L.rbox((cx+0.22,yy,z+0.64),(0.20,w-0.05,0.58),0.08,rot=(0,math.radians(12),0),m=P+'Fabric',seg=4)  # спинки
    for yy in (y0+0.11,y1-0.11):                                                        # подлокотники
        L.rbox((cx-0.02,yy,z+0.40),(0.92,0.22,0.52),0.09,m=P+'Fabric',seg=4)
    L.rbox((cx+0.40,cy,z+0.55),(0.12,ln,0.70),0.04,m=P+'Steel')                         # задняя рама
    for yy,rz in ((y0+0.60,0.3),(y1-0.60,-0.35)):                                       # подушки-«думки»
        L.rbox((cx-0.18,yy,z+0.66),(0.14,0.44,0.44),0.06,rot=(0,math.radians(-18),rz),m=P+'Leather',seg=4)
sofa(5.38,20.4,23.8)

# ---- кресло, лицом к +x
def armchair(cx,cy,yaw=0.0):
    z=Z0; c=Vector((cx,cy,0)); R=Matrix.Rotation(yaw,3,'Z')
    def Pp(dx,dy,dz): v=R@Vector((dx,dy,dz)); return (c.x+v.x,c.y+v.y,z+v.z)
    rz=(0,0,yaw)
    L.rbox(Pp(0,0,0.17),(0.80,0.80,0.20),0.07,rot=rz,m=P+'Leather',seg=4)                                # основание
    L.rbox(Pp(0.04,0,0.33),(0.60,0.60,0.14),0.07,rot=rz,m=P+'Leather',seg=4)                              # подушка
    br=R@Vector((-0.34,0,0.58));
    L.rbox((c.x+br.x,c.y+br.y,z+br.z),(0.16,0.80,0.66),0.08,rot=(0,math.radians(-10),yaw),m=P+'Leather',seg=4)  # спинка
    for sg in (-1,1):
        L.rbox(Pp(0.02,sg*0.35,0.37),(0.74,0.14,0.34),0.065,rot=rz,m=P+'Leather',seg=4)                  # подлокотники
        for dx in (-0.30,0.30): L.cyl(Pp(dx,sg*0.32,0.05),0.025,0.10,P+'Handle',r2=0.018)                 # ножки
armchair(1.95,20.95); armchair(1.95,23.35)

# ---- журнальный столик
tx,ty=4.20,22.10
L.rbox((tx,ty,Z0+0.405),(1.10,1.70,0.05),0.035,m=P+'Wood',seg=4)                           # столешница
L.rbox((tx,ty,Z0+0.37),(1.02,1.62,0.04),0.02,m=P+'Steel')                                  # царга
L.rbox((tx,ty,Z0+0.13),(0.92,1.50,0.025),0.01,m=P+'Wood')                                  # полка
for sx in (-0.46,0.46):
    for sy in (-0.76,0.76): L.cyl((tx+sx,ty+sy,Z0+0.20),0.032,0.40,P+'Handle',r2=0.022)
L.cyl((tx+0.15,ty-0.3,Z0+0.46),0.13,0.05,P+'Pot',r2=0.09,seg=24)                           # чаша
L.rbox((tx-0.25,ty+0.35,Z0+0.45),(0.30,0.22,0.03),0.01,rot=(0,0,0.25),m=P+'Leather')       # книги
L.rbox((tx-0.25,ty+0.35,Z0+0.48),(0.26,0.19,0.03),0.01,rot=(0,0,-0.1),m=P+'Fabric')

# ---- торшер
lx,ly=5.28,25.0
L.cyl((lx,ly,Z0+0.02),0.22,0.04,P+'Steel',bev=0.015,seg=28)
L.cyl((lx,ly,Z0+0.85),0.016,1.62,P+'Handle')
L.sph((lx,ly,Z0+1.68),0.04,P+'Handle')
L.cyl((lx,ly,Z0+1.88),0.24,0.38,P+'Light',r2=0.15,seg=28)

lnames=L.write()
for p in lm.polygons: pass

# ---------------- КУХНИ ----------------
ko=bpy.data.objects.get('SM_Cabin_Kitchen')
if ko: bpy.data.objects.remove(ko,do_unlink=True)
km=bpy.data.meshes.new('SM_Cabin_Kitchen'); ko=bpy.data.objects.new('SM_Cabin_Kitchen',km); col.objects.link(ko)
ko.parent=arm; ko.matrix_parent_inverse=arm.matrix_world.inverted()
K=Furn(km,[])
D=0.62; HB=0.78; TOP=0.90     # глубина шкафа, высота корпуса, высота столешницы над полом
class Run:
    def __init__(s,o,u,n): s.o=Vector(o); s.u=Vector(u); s.n=Vector(n)
    def w(s,uc,vc,zc): p=s.o+s.u*uc+s.n*vc; return (p.x,p.y,Z0+zc)
    def sz(s,su,sv,sz):
        return (su,sv,sz) if abs(s.u.x)>0.5 else (sv,su,sz)
    def box(s,uc,vc,zc,su,sv,sz,r=0.02,m=P+'Cabinet',seg=3): K.rbox(s.w(uc,vc,zc),s.sz(su,sv,sz),r,m=m,seg=seg)
    def cyl(s,uc,vc,zc,r,h,m=P+'Handle',r2=None,rot=(0,0,0),seg=20,bev=0): K.cyl(s.w(uc,vc,zc),r,h,m,r2=r2,rot=rot,seg=seg,bev=bev)

def base(run,u0,w,kind):
    uc=u0+w/2
    run.box(uc,D/2-0.04,0.05,w-0.04,D-0.10,0.10,0.01,P+'Black')                    # цоколь
    run.box(uc,D/2-0.02,0.10+HB/2,w-0.012,D-0.04,HB,0.02)                         # корпус
    if kind=='drawers':
        for i in range(3):
            zc=0.10+0.13+i*0.26
            run.box(uc,D-0.012,zc,w-0.03,0.02,0.23,0.015)
            run.box(uc,D+0.02,zc+0.08,0.20,0.02,0.02,0.008,P+'Handle')
    else:
        run.box(uc,D-0.012,0.10+HB/2,w-0.03,0.02,HB-0.04,0.015)
        run.box(uc,D+0.02,0.10+HB-0.09,0.02,0.02,0.20,0.008,P+'Handle')

def run_tops(run,u0,u1,ov_end=0.0):
    run.box((u0+u1)/2,D/2,TOP-0.02,u1-u0,D+0.03,0.04,0.015,P+'Counter',seg=3)          # столешница
    run.box((u0+u1)/2,0.012,TOP+0.27,u1-u0,0.024,0.50,0.005,P+'Counter')               # фартук

def upper(run,u0,w):
    uc=u0+w/2; z0=1.50; h=0.70
    run.box(uc,0.17,z0+h/2,w-0.012,0.34,h,0.02)
    run.box(uc,0.345,z0+h/2,w-0.03,0.02,h-0.04,0.012)
    run.box(uc,0.36,z0+h/2-0.12,0.02,0.02,0.22,0.007,P+'Handle')

def fridge(run,u0,w):
    uc=u0+w/2
    run.box(uc,(D+0.06)/2,1.00,w-0.012,D+0.06,2.00,0.04,P+'Appliance',seg=4)
    run.box(uc,D+0.05,1.40,w-0.04,0.02,1.0,0.01,P+'Appliance')                      # верхняя дверь
    run.box(uc,D+0.062,0.60,w-0.04,0.02,0.82,0.01,P+'Appliance')
    run.box(uc,D+0.062,0.99,w-0.03,0.004,0.012,0.002,P+'Black')                       # щель
    for zc in (1.55,0.75): run.box(uc+w/2-0.08,D+0.095,zc,0.02,0.03,0.40,0.01,P+'Handle')

def sink(run,u0,w):
    base(run,u0,w,'door'); uc=u0+w/2
    run.box(uc,D/2,TOP+0.002,min(w-0.2,0.70),0.40,0.012,0.004,P+'Appliance')         # мойка
    run.box(uc,D/2,TOP+0.008,min(w-0.28,0.60),0.32,0.006,0.003,P+'Black')
    run.cyl(uc,0.08,TOP+0.19,0.014,0.34,P+'Handle')                                  # кран: стойка
    run.cyl(uc,0.15,TOP+0.35,0.011,0.14,P+'Handle',rot=(math.radians(90),0,0) if abs(run.u.x)>0.5 else (0,math.radians(90),0))

def hob(run,u0,w):
    base(run,u0,w,'door'); uc=u0+w/2
    run.box(uc,D/2,TOP+0.004,w-0.08,0.50,0.008,0.004,P+'Black')                     # панель
    for du,dv in ((-0.12,0.15),(0.12,0.15),(-0.12,0.38),(0.12,0.38)):
        run.cyl(uc+du,dv,TOP+0.01,0.085,0.004,P+'Appliance',seg=24)
        run.cyl(uc+du,dv,TOP+0.012,0.06,0.003,P+'Black',seg=24)
    # вытяжка + короб до потолка
    run.box(uc,0.20,Z0+0+1.62 - Z0*0 ,w-0.02,0.40,0.14,0.03,P+'Appliance',seg=3) if False else None
    run.box(uc,0.20,1.70,w-0.02,0.40,0.14,0.03,P+'Appliance',seg=3)
    run.box(uc,0.12,2.35,0.28,0.24,1.25,0.02,P+'Appliance')

def corner(run,u0,w,top=True):
    uc=u0+w/2
    run.box(uc,w/2-0.0,0.10+HB/2,w-0.012,w-0.012,HB,0.02)
    run.box(uc,w/2,0.05,w-0.06,w-0.06,0.10,0.01,P+'Black')

def kitchen_right():
    R=Run((2.05,18.02),(1,0),(0,1)); u=0.0
    fridge(R,u,0.72); u+=0.72
    base(R,u,0.60,'drawers'); upper(R,u,0.60); u+=0.60
    sink(R,u,1.00); upper(R,u,0.50); upper(R,u+0.50,0.50); u+=1.00
    hob(R,u,0.60); u+=0.60
    base(R,u,0.91,'door'); upper(R,u,0.455); upper(R,u+0.455,0.455); u+=0.91
    run_tops(R,0.72,u)                       # столешница от холодильника до угла
    # угол и боковая часть вдоль правой стены (x=6.5): u вдоль +y, v внутрь (-x)
    S=Run((6.5,18.02),(0,1),(-1,0))
    corner(S,0.0,0.62); R2=Run((6.5,18.64),(0,1),(-1,0))
    base(R2,0.0,0.70,'drawers'); base(R2,0.70,0.70,'door'); upper(R2,0.0,0.70); upper(R2,0.70,0.70)
    S.box(0.31,0.31,TOP-0.02,0.62,0.62,0.04,0.015,P+'Counter')
    run_tops(R2,0.0,1.40)
    # угловой верхний шкаф
    S.box(0.31,0.17,1.85,0.62,0.34,0.70,0.02)

def kitchen_left():
    R=Run((-2.62,18.02),(-1,0),(0,1)); u=0.0
    sink(R,u,0.80); upper(R,u,0.40); upper(R,u+0.40,0.40); u+=0.80
    hob(R,u,0.60); u+=0.60
    base(R,u,0.56,'drawers'); upper(R,u,0.56); u+=0.56
    run_tops(R,0.0,u)
    fridge(R,u,0.72)
    # угловой блок на конце у коридора + полуостров
    S=Run((-2.0,18.02),(0,1),(-1,0))
    corner(S,0.0,0.62); S.box(0.31,0.31,TOP-0.02,0.62,0.62,0.04,0.015,P+'Counter')
    R2=Run((-2.0,18.64),(0,1),(-1,0))
    base(R2,0.0,0.70,'door'); base(R2,0.70,0.70,'drawers')
    R2.box(0.70,D/2+0.06,TOP-0.02,1.40,D+0.16,0.04,0.02,P+'Counter')               # барная столешница с выносом
    for yy in (0.35,1.05): K.cyl(R2.w(yy,D+0.45,0.0),0.17,0.04,P+'Handle',bev=0.01) if False else None
kitchen_right(); kitchen_left()
K.write()
result={'lounge_slots':lnames,'kitchen_faces':len(km.polygons),'lounge_faces':len(lm.polygons)}
