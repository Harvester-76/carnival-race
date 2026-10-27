# Corridor from the bridge rear wall to the engine-room end wall, with 5 cabin doors on each side.
# Runs inside Blender. World coordinates, nose = +Y. Style reference: dark blue-grey sci-fi panels, doors with frames and diagonal ribs.
import bpy, bmesh, math
from mathutils import Matrix, Vector
arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
for n in ('SM_Corridor_Shell','SM_Corridor_Doors','SM_Corridor_Details'):
    ob=bpy.data.objects.get(n)
    if ob: me=ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
def mat(name,c,rough=.5,metal=0,emit=None,st=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes=True
    b=[n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'][0]
    b.inputs['Base Color'].default_value=c; b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
    if emit is not None: b.inputs['Emission Color'].default_value=emit; b.inputs['Emission Strength'].default_value=st
    return m
M={'wall':mat('MAT_Corr_Wall',(.10,.14,.19,1),.55,.6),'panel':mat('MAT_Corr_Panel',(.16,.21,.27,1),.5,.6),
 'floor':mat('MAT_Corr_Floor',(.06,.07,.08,1),.6,.6),'ceil':mat('MAT_Corr_Ceiling',(.14,.17,.21,1),.6,.4),
 'door':mat('MAT_Corr_Door',(.34,.40,.47,1),.45,.7),'hazard':mat('MAT_Corr_Hazard',(.75,.58,.04,1),.6,.2),
 'light':mat('MAT_Corr_Light',(.8,.9,1,1),.3,0,(.75,.9,1,1),8),'red':mat('MAT_Corr_Red',(.5,.02,.02,1),.4,0,(1,.05,.05,1),4),
 'glass':mat('MAT_Corr_DoorGlass',(.1,.25,.5,1),.1,0,(.2,.5,1,1),1.2),'dark':mat('MAT_Corr_Dark',(.02,.025,.03,1),.5,.5)}
class G:
    def __init__(s,name): s.name=name; s.bm=bmesh.new(); s.mats=[]
    def mi(s,k):
        m=M[k]
        if m not in s.mats: s.mats.append(m)
        return s.mats.index(m)
    def _fin(s,res,k,bev):
        vs=res['verts']; mi=s.mi(k)
        for f in set(f for v in vs for f in v.link_faces): f.material_index=mi
        if bev:
            es=set(e for v in vs for e in v.link_edges)
            r=bmesh.ops.bevel(s.bm,geom=list(es),offset=bev,segments=1,affect='EDGES',clamp_overlap=True)
            for f in r['faces']: f.material_index=mi
    def box(s,c,size,k,rz=0,rx=0,bev=.01):
        m=Matrix.Translation(c)@Matrix.Rotation(rz,4,'Z')@Matrix.Rotation(rx,4,'X')@Matrix.Diagonal((size[0],size[1],size[2],1))
        s._fin(bmesh.ops.create_cube(s.bm,size=1.0,matrix=m),k,bev)
    def cyl(s,c,r,h,k,seg=20,rx=0,ry=0,rz=0,r2=None):
        m=Matrix.Translation(c)@Matrix.Rotation(rz,4,'Z')@Matrix.Rotation(ry,4,'Y')@Matrix.Rotation(rx,4,'X')
        s._fin(bmesh.ops.create_cone(s.bm,cap_ends=True,cap_tris=False,segments=seg,radius1=r,radius2=r if r2 is None else r2,depth=h,matrix=m),k,0)
    def build(s):
        me=bpy.data.meshes.new(s.name); s.bm.normal_update(); s.bm.to_mesh(me); s.bm.free()
        for m in s.mats: me.materials.append(m)
        ob=bpy.data.objects.new(s.name,me); col.objects.link(ob); ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted()
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=0.004); bpy.ops.object.mode_set(mode='OBJECT')
        return ob
zf=-1.81; ZC=0.90; HW=1.4; T=0.15; ZL=-2.11   # corridor floor is 0.5 m above the bridge floor, lounge floor ZL is between
Y_START=17.8; Y_END=3.2
DOOR_Y=[15.41,13.01,10.61,8.21,5.81]          # same stations as the portholes, 2.4 m cabin pitch
DW=1.3; DH=2.4
# ---------- SHELL: floor, ceiling, wall blocks between door openings, end wall ----------
S=G('SM_Corridor_Shell')
L=Y_START-Y_END; yc=(Y_START+Y_END)/2
S.box((0,yc,zf-T/2),(2*HW+2*T,L,T),'floor',bev=0)                        # floor slab, top at zf
S.box((0,yc,ZC+T/2),(2*HW+2*T,L,T),'ceil',bev=0)                         # ceiling slab, underside at ZC
S.box((0,Y_END-T/2,(zf+ZC)/2),(2*HW+2*T,T,ZC-zf+2*T),'wall',bev=0)       # end wall (engine room side)
edges=sorted([Y_START]+[y+DW/2+0.45 for y in DOOR_Y]+[y-DW/2-0.45 for y in DOOR_Y]+[Y_END])  # frame zone around each door
# wall blocks (pilasters) between door zones and lintels above doors
for sg in (1,-1):
    zones=[(y-DW/2-0.45,y+DW/2+0.45) for y in DOOR_Y]
    zones.sort()
    prev=Y_END
    for a,b in zones:
        if a>prev: S.box((sg*(HW+T/2),(prev+a)/2,(zf+ZC)/2),(T,a-prev,ZC-zf),'wall',bev=0)
        S.box((sg*(HW+T/2),(a+b)/2,zf+DH+(ZC-zf-DH)/2),(T,b-a,ZC-zf-DH),'wall',bev=0)   # lintel above the door opening
        prev=b
    if Y_START>prev: S.box((sg*(HW+T/2),(prev+Y_START)/2,(zf+ZC)/2),(T,Y_START-prev,ZC-zf),'wall',bev=0)
# two steps from the lounge floor up to the corridor floor (inside the cabin, in front of the doorway)
S.box((0,18.675,(ZL+(zf-0.15))/2),(3.0,0.45,(zf-0.15)-ZL),'floor',bev=0)
S.box((0,18.225,(ZL+zf)/2),(3.0,0.45,zf-ZL),'floor',bev=0)
S.box((0,18.89,zf-0.15+0.012),(3.0,0.05,0.03),'hazard',bev=0)
S.box((0,18.44,zf+0.012),(3.0,0.05,0.03),'hazard',bev=0)
shell=S.build()
# ---------- DOORS ----------
D=G('SM_Corridor_Doors')
def door(axis,sg,pos,num,width=DW,height=DH,sign=None):
    """axis 'x': door in a side wall (sg=+1 right, -1 left), pos = y position.  axis 'y': door in the end wall at y=pos, facing +y."""
    def B(d,u,z,td,tu,tz,k,bev=.01):
        # d: distance from the wall plane towards the corridor; u: position along the wall; td/tu: sizes in those directions
        if axis=='x': D.box((sg*(HW-d),pos+u,z),(td,tu,tz),k,bev=bev)
        else:         D.box((u,pos+d,z),(tu,td,tz),k,bev=bev)
    fz=zf+height/2
    B(-0.06,0,fz,0.12,width+0.9,height+0.2,'dark',0)                      # recess behind the leaf
    B(0.06,0,fz+height/2+0.17,0.14,width+0.55,0.34,'panel',.04)            # frame: top
    B(0.06,0,zf+0.12,0.14,width+0.55,0.24,'panel',.04)                      # frame: threshold
    for s2 in (-1,1): B(0.06,s2*(width/2+0.2),fz,0.14,0.30,height+0.1,'panel',.04)
    B(0.0,0,fz,0.10,width,height,'door',.025)                               # leaf
    for oz in (height*0.22,-height*0.22): B(0.075,0,fz+oz,0.04,width*0.6,0.09,'panel',.01)   # ribs
    B(0.075,0,fz-height*0.05,0.04,width*0.86,0.07,'panel',.01)
    for i in range(5): B(0.08,-width*0.35+i*width*0.17,zf+0.55,0.02,0.09,0.7,'hazard',0)       # hazard stripes
    B(0.075,-width*0.14,zf+height-0.55,0.05,0.62,0.46,'hazard',.01)         # window frame + glass
    B(0.1,-width*0.14,zf+height-0.55,0.02,0.52,0.36,'glass',0)
    B(0.08,width*0.25,zf+1.15,0.03,0.09,0.4,'dark',.01)                    # handle slot
    B(0.08,width*0.09,zf+1.15,0.02,0.16,0.18,'dark',0)                     # PUSH sign area
    B(0.08,width*0.27,zf+0.9,0.02,0.4,0.16,'dark',0)                       # door number area
    B(0.08,width/2-0.12,zf+height-0.2,0.02,0.1,0.1,'red',0)
    B(0.08,width/2-0.12,zf+0.25,0.02,0.1,0.1,'red',0)
    for s2 in (-1,1): B(0.08,s2*(width/2-0.04),zf+0.55,0.02,0.03,0.5,'light',0)
    B(0.1,0,zf+height+0.12,0.04,width*0.7,0.05,'light',0)
    B(0.06,-width/2-0.5,zf+1.25,0.12,0.22,0.5,'dark',.02)                  # control panel beside the door
    B(0.13,-width/2-0.5,zf+1.38,0.02,0.12,0.1,'red',0)
    B(0.13,-width/2-0.5,zf+1.18,0.02,0.12,0.1,'light',0)
    if sign: B(0.1,0,zf+height+0.45,0.04,width*1.2,0.28,'dark',0)           # sign area above the door
for i,y in enumerate(DOOR_Y):
    door('x',1,y,i+1); door('x',-1,y,i+6)
# end wall: engine room door, bigger leaf, same style
door('y',1,Y_END,0,width=1.7,height=2.6,sign=True)
doors=D.build()
# ---------- DETAILS: wall panels, pipes, lights, vents, floor ----------
E=G('SM_Corridor_Details')
for sg in (1,-1):
    X=lambda d: sg*(HW-d)
    prev=Y_END
    zones=sorted([(y-DW/2-0.45,y+DW/2+0.45) for y in DOOR_Y])
    segs=[]; p=Y_END
    for a,b in zones:
        if a>p: segs.append((p,a))
        p=b
    if Y_START>p: segs.append((p,Y_START))
    for a,b in segs:
        yy=(a+b)/2; ln=b-a
        if ln>0.5:
            E.box((X(0.04),yy,zf+1.6),(0.08,ln-0.15,2.6),'panel',bev=.03)                  # raised wall panel
            E.box((X(0.09),yy,zf+2.2),(0.03,ln-0.35,0.12),'dark',bev=0)                     # groove
            E.box((X(0.09),yy,zf+1.0),(0.03,ln-0.35,0.12),'dark',bev=0)
            if ln>0.9:
                E.box((X(0.10),yy,zf+1.7),(0.04,min(ln-0.4,0.5),0.7),'dark',bev=.02)         # vent
                for k in range(5): E.box((X(0.125),yy,zf+1.45+k*0.14),(0.02,min(ln-0.5,0.4),0.05),'wall',bev=0)
    E.box((X(0.05),(Y_START+Y_END)/2,zf+0.12),(0.10,Y_START-Y_END,0.24),'hazard',bev=0)    # hazard skirting
    E.box((X(0.05),(Y_START+Y_END)/2,ZC-0.15),(0.10,Y_START-Y_END,0.3),'panel',bev=.03)    # upper trim
    E.cyl((sg*(HW-0.35),(Y_START+Y_END)/2,ZC-0.35),0.12,Y_START-Y_END,'dark',rx=math.pi/2)  # ceiling duct
# ceiling light rings every 2.4 m (between cabin doors) and a centre light strip
for k in range(6):
    y=Y_START-1.2-k*2.4
    if y<Y_END+0.8: break
    E.cyl((0,y,ZC-0.04),0.38,0.08,'light',seg=28); E.cyl((0,y,ZC-0.02),0.5,0.04,'dark',seg=28)
E.box((0,(Y_START+Y_END)/2,ZC-0.03),(0.12,Y_START-Y_END-0.5,0.04),'light',bev=0)
# floor: centre grating plates and yellow lane lines
E.box((0,(Y_START+Y_END)/2,zf+0.012),(1.2,Y_START-Y_END-0.4,0.02),'dark',bev=0)
for sg in (1,-1): E.box((sg*0.75,(Y_START+Y_END)/2,zf+0.012),(0.06,Y_START-Y_END-0.4,0.02),'hazard',bev=0)
details=E.build()
print('corridor',[ (n,len(bpy.data.objects[n].data.polygons)) for n in ('SM_Corridor_Shell','SM_Corridor_Doors','SM_Corridor_Details')])
