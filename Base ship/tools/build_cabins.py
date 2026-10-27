# Ten rooms behind the corridor doors: 7 crew cabins, medbay, storage, toilet/shower.
# Runs inside Blender. World coordinates, nose = +Y. Local frame per room: u = depth from the corridor wall (x=1.55), v = offset along Y from the door axis, zr = height above the floor.
import bpy, bmesh, math
from mathutils import Matrix, Vector
arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
for ob in [o for o in bpy.data.objects if o.name.startswith('SM_Room_')]:
    me=ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
def mat(name,c,rough=.5,metal=0,emit=None,st=0,alpha=None):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes=True
    b=[n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'][0]
    b.inputs['Base Color'].default_value=c; b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
    if emit is not None: b.inputs['Emission Color'].default_value=emit; b.inputs['Emission Strength'].default_value=st
    if alpha is not None:
        b.inputs['Alpha'].default_value=alpha
        if hasattr(m,'blend_method'): m.blend_method='BLEND'
    return m
M={'wall':mat('MAT_Room_Wall',(.13,.17,.22,1),.55,.5),'panel':mat('MAT_Room_Panel',(.22,.27,.33,1),.5,.5),
 'floor':mat('MAT_Room_Floor',(.07,.08,.09,1),.6,.5),'ceil':mat('MAT_Room_Ceiling',(.16,.19,.23,1),.6,.4),
 'metal':mat('MAT_Room_Metal',(.38,.41,.45,1),.35,.9),'dark':mat('MAT_Room_Dark',(.03,.035,.04,1),.5,.5),
 'bed':mat('MAT_Room_Fabric',(.12,.22,.4,1),.9,0),'bed2':mat('MAT_Room_Fabric2',(.35,.2,.12,1),.9,0),
 'pillow':mat('MAT_Room_Pillow',(.75,.78,.8,1),.9,0),'wood':mat('MAT_Room_Wood',(.45,.33,.22,1),.6,0),
 'white':mat('MAT_Room_White',(.8,.82,.84,1),.4,.1),'crate':mat('MAT_Room_Crate',(.3,.36,.22,1),.65,.3),
 'crate2':mat('MAT_Room_Crate2',(.45,.3,.12,1),.65,.3),'rug':mat('MAT_Room_Rug',(.28,.07,.07,1),1,0),
 'light':mat('MAT_Room_Light',(.8,.9,1,1),.3,0,(.8,.92,1,1),7),'screen':mat('MAT_Room_Screen',(.05,.2,.3,1),.2,0,(.1,.6,1,1),3),
 'cross':mat('MAT_Room_Cross',(.6,.02,.02,1),.4,0,(1,.1,.1,1),3),'glass':mat('MAT_Room_Glass',(.35,.55,.7,1),.05,0,None,0,.3),
 'hazard':mat('MAT_Room_Hazard',(.75,.58,.04,1),.6,.2),'mirror':mat('MAT_Room_Mirror',(.7,.78,.85,1),.05,1)}
Z0=-1.81; ZC=0.90; H=ZC-Z0           # floor, ceiling underside, room height 2.71
X0=1.55; UW=5.1                       # corridor wall face, outer wall inner face at u=UW (x=6.65)
WIN_R=0.55
def win_z(y): return 0.066+(15.41-y)/9.6*0.186     # porthole centres rise linearly from the front (0.066) to the rear (0.252)
DOOR_Y=[15.41,13.01,10.61,8.21,5.81]
class G:
    def __init__(s,name,sg,yd): s.name=name; s.sg=sg; s.yd=yd; s.bm=bmesh.new(); s.mats=[]
    def mi(s,k):
        m=M[k]
        if m not in s.mats: s.mats.append(m)
        return s.mats.index(m)
    def W(s,u,v,zr): return Vector((s.sg*(X0+u),s.yd+v,Z0+zr))
    def box(s,u0,u1,v0,v1,z0,z1,k,bev=.008):
        c=s.W((u0+u1)/2,(v0+v1)/2,(z0+z1)/2); m=Matrix.Translation(c)@Matrix.Diagonal((u1-u0,v1-v0,z1-z0,1))
        res=bmesh.ops.create_cube(s.bm,size=1.0,matrix=m); vs=res['verts']; mi=s.mi(k)
        for f in set(f for v in vs for f in v.link_faces): f.material_index=mi
        if bev:
            es=set(e for v in vs for e in v.link_edges)
            r=bmesh.ops.bevel(s.bm,geom=list(es),offset=min(bev,(min(u1-u0,v1-v0,z1-z0))*.3),segments=1,affect='EDGES',clamp_overlap=True)
            for f in r['faces']: f.material_index=mi
    def cyl(s,u,v,z0,z1,r,k,seg=20):
        c=s.W(u,v,(z0+z1)/2); res=bmesh.ops.create_cone(s.bm,cap_ends=True,cap_tris=False,segments=seg,radius1=r,radius2=r,depth=z1-z0,matrix=Matrix.Translation(c))
        mi=s.mi(k)
        for f in set(f for v_ in res['verts'] for f in v_.link_faces): f.material_index=mi
    def loopv(s,pts,u):  return [s.bm.verts.new(s.W(u,p[0],p[1])) for p in pts]
    def ring(s,ua,ub,outer,inner,k):
        """Slab between u=ua and u=ub with a hole. outer / inner = lists of (v,z) points, same count."""
        mi=s.mi(k); n=len(outer); out=[]
        A=[s.loopv(outer,ua),s.loopv(inner,ua)]; B=[s.loopv(outer,ub),s.loopv(inner,ub)]
        def q(a,b,c,d):
            try: f=s.bm.faces.new((a,b,c,d)); f.material_index=mi; out.append(f)
            except ValueError: pass
        for i in range(n):
            j=(i+1)%n
            q(A[0][i],A[0][j],A[1][j],A[1][i])                 # front annulus
            q(B[0][j],B[0][i],B[1][i],B[1][j])                 # back annulus
            q(A[0][j],A[0][i],B[0][i],B[0][j])                 # outer rim
            q(A[1][i],A[1][j],B[1][j],B[1][i])                 # hole tube
    def build(s):
        bmesh.ops.recalc_face_normals(s.bm,faces=s.bm.faces[:])
        me=bpy.data.meshes.new(s.name); s.bm.normal_update(); s.bm.to_mesh(me); s.bm.free()
        for m in s.mats: me.materials.append(m)
        ob=bpy.data.objects.new(s.name,me); col.objects.link(ob); ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted()
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=0.004); bpy.ops.object.mode_set(mode='OBJECT')
        return ob
def rect_pts(v0,v1,z0,z1,n=24):
    """n points around a rectangle, starting at the lower-left corner, going counter-clockwise; n divisible by 4."""
    k=n//4; P=[]
    for (a,b) in (((v0,z0),(v1,z0)),((v1,z0),(v1,z1)),((v1,z1),(v0,z1)),((v0,z1),(v0,z0))):
        for i in range(k): t=i/k; P.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
    return P
def circ_pts(cv,cz,r,n=24):
    return [(cv+r*math.cos(math.radians(-135+i*360/n)),cz+r*math.sin(math.radians(-135+i*360/n))) for i in range(n)]
# ---------------- shared room shell ----------------
def shell(g):
    g.box(-.15,UW+.1,-1.2,1.2,-.1,0,'floor',bev=0)                         # floor slab, top at zr 0
    g.box(-.15,UW+.1,-1.2,1.2,H,H+.1,'ceil',bev=0)                          # ceiling slab
    for sv in (-1,1):                                                       # partitions between rooms
        a,b=(1.1,1.2) if sv>0 else (-1.2,-1.1)
        g.box(-.15,UW+.1,a,b,0,H,'wall',bev=0)
        va,vb=(1.08,1.1) if sv>0 else (-1.1,-1.08)
        g.box(0,UW,va,vb,.0,.12,'dark',bev=0)                                # skirting
        g.box(0,UW,va,vb,1.05,1.12,'panel',bev=0)                            # wall band
    # outer wall with the round window opening (hull porthole sits behind it)
    outer=rect_pts(-1.1,1.1,0,H); wz=win_z(g.yd)-Z0; inner=circ_pts(0,wz,WIN_R)
    g.ring(UW,UW+.1,outer,inner,'wall')
    g.ring(UW-.06,UW,circ_pts(0,wz,WIN_R+.1),circ_pts(0,wz,WIN_R),'metal')    # window frame
    g.box(1.6,3.4,-.3,.3,H-.04,H,'light',bev=0)                             # ceiling light
# ---------------- room contents ----------------
def bunk_bed(g,v,u0=2.9,u1=4.95,w=.9):
    a,b=v-w/2,v+w/2
    for z,zt in ((.34,'bed'),(1.10,'bed2')):
        g.box(u0,u1,a,b,z,z+.12,'metal'); g.box(u0+.02,u1-.02,a+.02,b-.02,z+.12,z+.2,zt,bev=.03)
        g.box(u1-.4,u1-.02,a+.08,b-.08,z+.2,z+.28,'pillow',bev=.03)
    for pu in (u0+.03,u1-.03):
        for pv in (a+.03,b-.03): g.box(pu-.03,pu+.03,pv-.03,pv+.03,0,1.62,'metal',bev=0)
    g.box(u0+.03,u1-.03,a,a+.02,1.3,1.5,'metal',bev=0)                      # safety rail on the wall side
    for i in range(5): g.box(u0-.06,u0-.02,a+.12,b-.12,.25+i*.28,.29+i*.28,'metal',bev=0)    # ladder rungs at the foot
def single_bed(g,v,u0=3.0,u1=5.0,w=.9):
    a,b=v-w/2,v+w/2
    g.box(u0,u1,a,b,.3,.46,'metal'); g.box(u0+.02,u1-.02,a+.02,b-.02,.46,.58,'bed2',bev=.03)
    g.box(u1-.45,u1-.02,a+.08,b-.08,.58,.68,'pillow',bev=.04)
    g.box(u0,u1,a+.05,b-.05,0,.3,'dark',bev=0)                              # storage drawer base
def desk(g,v0,v1,u0=3.0,u1=5.0,screen=True):
    g.box(u0,u1,v0,v1,.72,.76,'wood'); g.box(u0,u0+.7,v0,v1,0,.72,'panel')   # top + drawer unit
    for i in range(3): g.box(u0+.7,u0+.72,v0+.04,v1-.04,.1+i*.2,.26+i*.2,'metal',bev=0)
    g.box(u1-.04,u1,v0,v1,0,.72,'dark',bev=0)
    if screen:
        sv=(v0+v1)/2; g.box(u1-.3,u1-.26,sv-.2,sv+.2,.9,1.18,'screen',bev=.01); g.box(u1-.32,u1-.3,sv-.03,sv+.03,.76,.9,'metal',bev=0)
    g.box(u0+1.0,u1-.6,v0+.1,v1-.1,.76,.78,'dark',bev=0)                    # desk mat
    g.box(u0+.2,u1-.2,v0+.02,v0+.2,1.35,1.4,'wood',bev=0) if abs(v0)>.5 else None   # shelf board on the wall
def chair(g,u,v):
    g.cyl(u,v,.42,.46,.21,'dark'); g.cyl(u,v,0,.42,.03,'metal',8); g.cyl(u,v,0,.05,.18,'metal',8)
    g.box(u+.15,u+.2,v-.18,v+.18,.46,.95,'dark')
def wardrobe(g,u0,u1,v0,v1):
    g.box(u0,u1,v0,v1,0,2.1,'panel'); mid=(v0+v1)/2
    g.box(u1,u1+.012,mid-.005,mid+.005,.05,2.05,'dark',bev=0)
    for sv in (-1,1): g.box(u1,u1+.03,mid+sv*.03-.01,mid+sv*.03+.01,.9,1.2,'metal',bev=0)
    g.box(u0,u1,v0,v1,2.1,2.14,'metal',bev=0)
def crew_a(g):
    bunk_bed(g,-.63); desk(g,.55,1.08); chair(g,2.4,.8); wardrobe(g,.7,1.4,.5,1.08)
    g.box(1.2,2.8,-.5,.3,0,.012,'rug',bev=0)
def crew_b(g):
    single_bed(g,-.63); desk(g,.35,1.08,2.6,5.0); chair(g,2.1,.7); wardrobe(g,.7,1.4,-1.08,-.5)
    g.box(1.2,2.8,-.3,.5,0,.012,'rug',bev=0)
    g.box(3.0,4.9,-1.08,-.9,1.5,1.55,'wood',bev=0)                           # shelf above the bed
def medbay(g):
    for v in (-.62,.62):
        g.box(2.0,4.1,v-.4,v+.4,.45,.62,'metal'); g.box(2.05,4.05,v-.37,v+.37,.62,.74,'white',bev=.03)
        g.box(2.05,2.5,v-.37,v+.37,.74,.82,'white',bev=.04)
        g.box(2.05,4.05,v-.3,v+.3,0,.45,'dark',bev=0)
        g.cyl(3.7,v,.9,1.55,.03,'metal',8)                                    # drip stand
    g.box(.7,1.4,.5,1.08,0,2.1,'white'); g.box(.7,1.4,-1.08,-.5,0,1.0,'white')
    g.box(.7,1.4,-1.08,-.5,1.0,1.04,'metal',bev=0)
    g.box(1.4,1.42,.6,.98,.8,1.8,'metal',bev=0); g.box(1.42,1.45,.7,.88,1.3,1.5,'screen',bev=0)
    g.box(0.4,3.0,1.06,1.08,1.2,1.5,'white',bev=0)
    g.box(2.9,3.4,1.04,1.08,1.2,1.25,'cross',bev=0); g.box(3.1,3.2,1.04,1.08,1.1,1.35,'cross',bev=0)   # red cross on the partition
    g.box(4.3,4.9,-.3,.3,0,.9,'metal')                                       # scanner console near the window
    g.box(4.3,4.9,-.3,.3,.9,.95,'screen',bev=0)
def storage(g):
    for sv in (-1,1):
        a,b=(.76,1.06) if sv>0 else (-1.06,-.76)
        for pu in (.6,1.9,3.2,4.5): g.box(pu,pu+.05,a,b,0,2.2,'metal',bev=0)
        for z in (.25,.85,1.45,2.05): g.box(.6,4.55,a,b,z,z+.04,'metal',bev=0)
        for i,pu in enumerate((.72,1.4,2.05,2.8,3.4,4.0)):
            for j,z in enumerate((.29,.89,1.49)):
                hh=.28+.04*((i+j)%3); wd=.5+.05*((i*2+j)%3)
                g.box(pu,pu+wd,a+.03,b-.03,z,z+hh,'crate' if (i+j)%2 else 'crate2',bev=.01)
    for k,(u,v) in enumerate(((4.0,-.15),(4.0,.3),(4.5,0.1))): g.box(u,u+.45,v-.2,v+.2,0,.5,'crate2' if k%2 else 'crate',bev=.01)
    g.box(4.0,4.45,-.15,.3,.5,.9,'crate',bev=.01)
    g.cyl(2.5,0,0,.9,.28,'metal',20); g.cyl(2.5,0,.9,.94,.26,'dark',20)
    g.box(.1,.5,-.5,.5,0,.012,'hazard',bev=0)                                # hazard floor marking at the door
def toilet(g):
    g.box(3.9,5.05,-1.08,-.2,0,.05,'white',bev=0); g.box(3.9,5.05,-1.08,-.2,2.1,2.15,'metal',bev=0)    # shower tray + frame top
    g.box(3.9,3.92,-1.08,-.2,0,2.15,'glass',bev=0); g.box(3.9,5.05,-.22,-.2,0,2.15,'glass',bev=0)
    g.cyl(4.7,-.9,1.95,2.0,.12,'metal',16); g.box(4.68,4.72,-.9,-.86,1.4,1.95,'metal',bev=0)
    g.box(4.55,5.0,.5,1.0,0,.4,'white'); g.box(4.9,5.05,.5,1.0,.4,.9,'white')              # toilet pedestal + cistern
    g.cyl(4.55,.75,.4,.45,.22,'white')
    g.box(1.0,1.9,.55,1.08,.85,.9,'white'); g.box(1.0,1.9,.65,1.08,0,.85,'panel')           # basin + cupboard
    g.box(1.0,1.9,1.06,1.08,1.1,1.9,'mirror',bev=0)
    g.box(.2,.5,1.0,1.08,1.2,1.5,'dark',bev=0)
    g.box(1.2,2.8,-.4,.4,0,.012,'floor',bev=0)
TYPES={1:medbay,2:crew_a,3:crew_b,4:crew_a,5:crew_b,6:storage,7:toilet,8:crew_a,9:crew_b,10:crew_a}
made=[]
for n in range(1,11):
    sg=1 if n<=5 else -1; yd=DOOR_Y[(n-1)%5]
    g=G('SM_Room_%02d'%n,sg,yd); shell(g); TYPES[n](g); made.append(g.build())
result={o.name:len(o.data.vertices) for o in made}
