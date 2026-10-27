# Builds the cabin props (dash, seats, lounge, doors). Run inside Blender (needs SM_Cabin_Shell, SK_Spaceship, COL_Interior).
import bpy, bmesh, math, numpy as np
from mathutils import Matrix, Vector
arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
for n in ('SM_Cabin_Dash','SM_Cabin_Seats','SM_Cabin_Lounge','SM_Cabin_Doors','REF_Human_185'):
    ob=bpy.data.objects.get(n)
    if ob: me=ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
def mat(name,c,rough=.5,metal=0,emit=None,st=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes=True
    b=[n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'][0]
    b.inputs['Base Color'].default_value=c; b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
    if emit is not None: b.inputs['Emission Color'].default_value=emit; b.inputs['Emission Strength'].default_value=st
    return m
M={'dash':mat('MAT_Cabin_Dash',(.03,.032,.04,1),.4,.5),'screen':mat('MAT_Cabin_Screen',(.02,.05,.09,1),.2,0,(.1,.45,.9,1),1.2),
 'btn':mat('MAT_Cabin_Buttons',(.02,.02,.02,1),.4,0,(1,.55,.1,1),3),'leather':mat('MAT_Cabin_Leather',(.11,.055,.035,1),.45,0),
 'steel':mat('MAT_Cabin_Steel',(.55,.56,.58,1),.3,1),'fabric':mat('MAT_Cabin_Fabric',(.16,.22,.28,1),.9,0),
 'wood':mat('MAT_Cabin_Wood',(.30,.17,.09,1),.5,0),'rug':mat('MAT_Cabin_Rug',(.45,.12,.10,1),.95,0),
 'lamp':mat('MAT_Cabin_Light',(.9,.8,.6,1),.4,0,(1,.85,.55,1),6),'panel':mat('MAT_Cabin_Panel',(.40,.42,.45,1),.5,.4),
 'leaf':mat('MAT_Cabin_Plant',(.08,.25,.07,1),.7,0),'pot':mat('MAT_Cabin_Pot',(.55,.5,.45,1),.8,0),
 'ref':mat('MAT_Ref_Human',(.9,.5,.1,1),.8,0),'edge':mat('MAT_Cabin_Edge',(.8,.62,.05,1),.6,.2)}
class G:
    def __init__(s,name): s.name=name; s.bm=bmesh.new(); s.mats=[]
    def mi(s,k):
        m=M[k]
        if m not in s.mats: s.mats.append(m)
        return s.mats.index(m)
    def _fin(s,res,k,bev):
        vs=res['verts']; mi=s.mi(k)
        fs=set(f for v in vs for f in v.link_faces)
        for f in fs: f.material_index=mi
        if bev:
            es=set(e for v in vs for e in v.link_edges)
            r=bmesh.ops.bevel(s.bm,geom=list(es),offset=bev,segments=2,affect='EDGES',clamp_overlap=True)
            for f in r['faces']: f.material_index=mi
    def box(s,c,size,k,rz=0,rx=0,bev=.015,tw=False):
        R=(Matrix.Rotation(rx,4,'X')@Matrix.Rotation(rz,4,'Z')) if tw else (Matrix.Rotation(rz,4,'Z')@Matrix.Rotation(rx,4,'X'))
        m=Matrix.Translation(c)@R@Matrix.Diagonal((size[0],size[1],size[2],1))
        s._fin(bmesh.ops.create_cube(s.bm,size=1.0,matrix=m),k,bev)
    def cyl(s,c,r,h,k,r2=None,seg=24,rx=0,rz=0,ry=0):
        m=Matrix.Translation(c)@Matrix.Rotation(rz,4,'Z')@Matrix.Rotation(ry,4,'Y')@Matrix.Rotation(rx,4,'X')
        s._fin(bmesh.ops.create_cone(s.bm,cap_ends=True,cap_tris=False,segments=seg,radius1=r,radius2=r if r2 is None else r2,depth=h,matrix=m),k,0)
    def sph(s,c,r,k,sc=(1,1,1),seg=16):
        m=Matrix.Translation(c)@Matrix.Diagonal((sc[0],sc[1],sc[2],1))
        s._fin(bmesh.ops.create_uvsphere(s.bm,u_segments=seg,v_segments=10,radius=r,matrix=m),k,0)
    def build(s):
        me=bpy.data.meshes.new(s.name); s.bm.normal_update(); s.bm.to_mesh(me); s.bm.free()
        for m in s.mats: me.materials.append(m)
        ob=bpy.data.objects.new(s.name,me); col.objects.link(ob)
        ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted(); return ob
zf=-2.31
sh=bpy.data.objects['SM_Cabin_Shell']
W=np.array([(sh.matrix_world@v.co)[:] for v in sh.data.vertices]); inn=W[np.abs(W[:,2]-zf)<0.005]
wy={y:np.abs(inn[np.abs(inn[:,1]-y)<0.01][:,0]).max() for y in np.unique(np.round(inn[:,1],2))}
def wall(y): k=sorted(wy); return float(np.interp(y,k,[wy[i] for i in k]))
# ---- DASH ----
D=G('SM_Cabin_Dash')
def ztop(y): return -1.21+(y-29.9)*(-0.22)
plan=[(-4.55,33.3),(-4.55,31.8),(-2.4,29.9),(2.4,29.9),(4.55,31.8),(4.55,33.3)]
bm=D.bm; top=[bm.verts.new((x,y,ztop(y))) for x,y in plan]; bot=[bm.verts.new((x,y,zf)) for x,y in plan]; fi=D.mi('dash')
bm.faces.new(top).material_index=fi; bm.faces.new(bot[::-1]).material_index=fi
for i in range(len(plan)):
    j=(i+1)%len(plan); bm.faces.new((bot[i],bot[j],top[j],top[i])).material_index=fi
# front sill: closes the gap between the dash front and the glass bottom edge (everything below is solid)
sill_pts=[(-4.60,33.0,-2.0),(4.60,33.0,-2.0),(4.74,33.91,-2.33),(0,35.2,-2.79),(-4.74,33.91,-2.33)]
sv=[bm.verts.new(q) for q in sill_pts]
sf=bm.faces.new(sv); sf.material_index=fi
ext=bmesh.ops.extrude_face_region(bm,geom=[sf])
newv=[e for e in ext['geom'] if isinstance(e,bmesh.types.BMVert)]
bmesh.ops.translate(bm,verts=newv,vec=(0,0,-1.2))
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
a=math.atan(-0.22)
def scr(x,y,w,d,rz): D.box((x,y,ztop(y)+0.012),(w,d,0.03),'screen',rz=rz,rx=a,bev=0,tw=True)
scr(0,30.6,2.3,0.8,0); scr(-3.5,31.0,1.7,0.75,-math.radians(38)); scr(3.5,31.0,1.7,0.75,math.radians(38))
scr(-1.9,30.35,0.9,0.55,0); scr(1.9,30.35,0.9,0.55,0)
D.box((0,29.95,ztop(29.95)+0.05),(4.8,0.12,0.12),'dash',bev=.02)
for i in range(18): D.box((-1.7+i*0.2,30.12,ztop(30.12)+0.03),(0.09,0.09,0.03),'btn',rx=a,bev=0)
D.box((0,32.2,ztop(32.2)+0.07),(1.8,0.5,0.14),'dash',rx=a,bev=.03); D.box((0,32.2,ztop(32.2)+0.15),(1.5,0.35,0.03),'screen',rx=a,bev=0)
dash=D.build()
# unwrap the dash for later texturing
bpy.ops.object.select_all(action='DESELECT'); dash.select_set(True); bpy.context.view_layer.objects.active=dash
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=0.005); bpy.ops.object.mode_set(mode='OBJECT')
# ---- SEATS ----
S=G('SM_Cabin_Seats')
def chair(x,y,sc=1.0,yaw=0):
    Rz=Matrix.Rotation(yaw,4,'Z')
    def P(dx,dy,dz): v=Rz@Vector((dx*sc,dy*sc,dz*sc)); return (x+v.x,y+v.y,zf+v.z)
    S.cyl(P(0,0,0.04),0.38*sc,0.08*sc,'steel'); S.cyl(P(0,0,0.28),0.06*sc,0.42*sc,'steel')
    S.box(P(0,0,0.5),(0.58*sc,0.54*sc,0.11*sc),'leather',rz=yaw,bev=.04)
    S.box(P(0,-0.27,0.92),(0.56*sc,0.11*sc,0.78*sc),'leather',rz=yaw,rx=math.radians(-8),bev=.04)
    S.box(P(0,-0.31,1.43),(0.30*sc,0.12*sc,0.26*sc),'leather',rz=yaw,rx=math.radians(-8),bev=.04)
    for sg in (-1,1):
        S.box(P(sg*0.34,0.0,0.74),(0.07*sc,0.50*sc,0.06*sc),'leather',rz=yaw,bev=.02)
        S.box(P(sg*0.34,-0.12,0.62),(0.04*sc,0.05*sc,0.2*sc),'steel',rz=yaw,bev=.01)
def pod(x,y,yaw=0):
    S.box((x,y,zf+0.30),(0.34,0.9,0.60),'dash',rz=yaw,bev=.03); S.box((x,y,zf+0.62),(0.30,0.7,0.03),'screen',rz=yaw,bev=0)
chair(0,28.7); pod(-0.75,28.9); pod(0.75,28.9)
S.cyl((0.75,28.6,zf+0.88),0.025,0.22,'steel'); S.sph((0.75,28.6,zf+1.02),0.05,'leather')
chair(-3.1,28.9,yaw=math.radians(-6),sc=1.1); pod(-3.85,29.1,math.radians(-6))
chair(3.1,28.9,yaw=math.radians(6)); pod(3.85,29.1,math.radians(6))
seats=S.build()
# ---- LOUNGE ----
L=G('SM_Cabin_Lounge'); wR=wall(22.0); zl=zf+0.20
L.box((2.6,22.6,zl+0.011),(5.4,4.0,0.022),'rug',bev=0)
sx=wR-0.55
def sofa(cx,cy,length):
    L.box((cx,cy,zl+0.22),(1.0,length,0.34),'fabric',bev=.05); L.box((cx,cy,zl+0.45),(0.9,length-0.3,0.14),'fabric',bev=.06)
    L.box((cx+0.40,cy,zl+0.75),(0.2,length,0.85),'fabric',bev=.06)
    for sy in (-1,1): L.box((cx,cy+sy*(length/2-0.1),zl+0.52),(1.0,0.2,0.55),'fabric',bev=.06)
    for sy in (-1,1):
        for sx2 in (-1,1): L.box((cx+sx2*0.4,cy+sy*(length/2-0.1),zl+0.04),(0.06,0.06,0.08),'steel',bev=0)
sofa(sx,22.1,3.4)
L.box((4.2,22.1,zl+0.40),(1.1,1.7,0.05),'wood',bev=.02)
for sx2 in (-1,1):
    for sy in (-1,1): L.box((4.2+sx2*0.48,22.1+sy*0.75,zl+0.19),(0.06,0.06,0.38),'steel',bev=0)
L.cyl((4.2,22.1,zl+0.45),0.12,0.08,'steel')
def armchair(cx,cy,yaw):
    Rz=Matrix.Rotation(yaw,4,'Z')
    def P(dx,dy,dz): v=Rz@Vector((dx,dy,dz)); return (cx+v.x,cy+v.y,zl+v.z)
    L.box(P(0,0,0.22),(0.8,0.8,0.34),'leather',rz=yaw,bev=.05); L.box(P(0,0,0.45),(0.7,0.7,0.14),'leather',rz=yaw,bev=.05)
    L.box(P(0,-0.38,0.75),(0.8,0.16,0.8),'leather',rz=yaw,bev=.06)
    for sg in (-1,1): L.box(P(sg*0.42,0,0.55),(0.14,0.8,0.4),'leather',rz=yaw,bev=.05)
armchair(1.9,20.9,math.radians(-90)); armchair(1.9,23.4,math.radians(-90))
L.cyl((sx-0.1,25.0,zl+0.04),0.2,0.08,'steel'); L.cyl((sx-0.1,25.0,zl+0.95),0.025,1.8,'steel'); L.cyl((sx-0.1,25.0,zl+1.9),0.28,0.35,'lamp',r2=0.16)
yr=18.0+0.22
for sx2 in (-1,1):
    cx=sx2*3.6; L.box((cx,yr+0.25,zl+1.1),(2.8,0.5,2.2),'panel',bev=.03)
    for k in range(4): L.box((cx,yr+0.52,zl+0.35+k*0.5),(2.6,0.04,0.03),'steel',bev=0)
L.cyl((-5.4,19.3,zl+0.25),0.32,0.5,'pot',r2=0.26)
for i in range(7):
    ang=i*math.tau/7; L.sph((-5.4+0.18*math.cos(ang),19.3+0.18*math.sin(ang),zl+0.85+0.12*(i%3)),0.26,'leaf',sc=(0.6,0.6,1.6))
for yy in (20.5,23.5,26.0): L.box((0,yy,0.84-0.03),(7.0,0.35,0.05),'lamp',bev=0)
L.box((0,26.1,zl+0.015),(2*wall(26.0)-0.5,0.12,0.03),'edge',bev=0)   # yellow edge of the step between the lounge and the crew area
lounge=L.build()
# ---- DOORS ----
Dg=G('SM_Cabin_Doors')
zl=zf+0.20
wl=wall(20.34); ax=-wl+0.03
Dg.cyl((ax,20.34,-1.13),2.18,0.12,'steel',ry=math.radians(90),seg=48)          # outer ring of the airlock
Dg.cyl((ax+0.06,20.34,-1.13),1.98,0.10,'panel',ry=math.radians(90),seg=48)      # disc
# the actual passage is smaller than the disc: a 1.5 x 2.3 m door whose bottom is at the cabin floor
Dg.box((ax+0.14,20.34,zl+1.15),(0.08,1.9,2.6),'dash',bev=.02)
Dg.box((ax+0.17,20.34,zl+1.15),(0.10,1.5,2.3),'steel',bev=.03)
for sy in (-1,1): Dg.box((ax+0.18,20.34+sy*0.86,zl+1.15),(0.14,0.16,2.5),'panel',bev=.03)
Dg.box((ax+0.18,20.34,zl+2.45),(0.14,1.9,0.18),'panel',bev=.03)
Dg.cyl((ax+0.25,20.34+0.45,zl+1.2),0.18,0.08,'steel',ry=math.radians(90),seg=20)   # handwheel
bmesh.ops.bisect_plane(Dg.bm,geom=list(Dg.bm.verts)+list(Dg.bm.edges)+list(Dg.bm.faces),dist=1e-5,plane_co=(0,0,zl-0.02),plane_no=(0,0,1),clear_inner=True)
doors=Dg.build()
# ---- scale reference: 1.85 m person (delete when not needed) ----
R=G('REF_Human_185'); R.cyl((-1.6,25.0,zf+0.9),0.22,1.55,'ref'); R.sph((-1.6,25.0,zf+1.7),0.15,'ref')
ref=R.build(); ref.hide_render=True
print('done')
