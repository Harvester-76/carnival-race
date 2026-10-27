# Большой экран над диваном (правая стена), климат-экран на левой стене рядом со шлюзом и цилиндрическая голограмма
# от пола до потолка кают-компании. Запуск: exec(open('.../tools/build_cabin_screens.py').read())
import bpy, bmesh, math
from mathutils import Vector, Matrix
exec(open('/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/tools/furn_lib.py').read())
BASE='/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/textures/interior/'
P='MAT_Cabin_'
arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']; shell=bpy.data.objects['SM_Cabin_Shell']
get_mat(P+'Black',(0.015,0.017,0.02,1),0.15,0.0); get_mat(P+'Steel',(0.6,0.62,0.65,1),0.35,0.8)

def img_mat(name,fn,strength,alpha=False,rough=0.2):
    m=bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear(); N=nt.nodes; L=nt.links
    o=N.new('ShaderNodeOutputMaterial'); t=N.new('ShaderNodeTexImage')
    im=bpy.data.images.get(name+'_img')
    if im: bpy.data.images.remove(im)
    im=bpy.data.images.load(BASE+fn); im.name=name+'_img'; im.alpha_mode='STRAIGHT'; t.image=im
    em=N.new('ShaderNodeEmission'); em.inputs['Strength'].default_value=strength
    L.new(t.outputs['Color'],em.inputs['Color'])
    if alpha:
        tr=N.new('ShaderNodeBsdfTransparent'); mx=N.new('ShaderNodeMixShader'); mu=N.new('ShaderNodeMath'); mu.operation='MULTIPLY'; mu.inputs[1].default_value=0.85
        L.new(t.outputs['Alpha'],mu.inputs[0]); L.new(mu.outputs[0],mx.inputs[0]); L.new(tr.outputs[0],mx.inputs[1]); L.new(em.outputs[0],mx.inputs[2]); L.new(mx.outputs[0],o.inputs[0])
        m.surface_render_method='BLENDED'; m.use_backface_culling=False
    else: L.new(em.outputs[0],o.inputs[0])
    return m
m_big=img_mat('MAT_Screen_Big','screen_big.png',3.0)
m_clim=img_mat('MAT_Screen_Climate','screen_climate.png',3.0)
m_col=img_mat('MAT_Holo_Column','holo_column.png',2.5,alpha=True)
get_mat('MAT_Holo_Emitter',(0.2,0.8,1,1),0.5,0,emit=(0.2,0.8,1,1),st=4)

def new_obj(name,mesh_mats):
    old=bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old,do_unlink=True)
    me=bpy.data.meshes.new(name); ob=bpy.data.objects.new(name,me); col.objects.link(ob)
    ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted(); return ob,me

def wall_hit(y,z,dx):
    inv=shell.matrix_world.inverted()
    ok,loc,n,i=shell.ray_cast(inv@Vector((0,y,z)),Vector((dx,0,0)),distance=30)
    return (shell.matrix_world@loc) if ok else None

ref=bpy.data.objects.get('REF_Human_185')
if ref: bpy.data.objects.remove(ref,do_unlink=True)
# ---------- экраны на стенах ----------
ob,me=new_obj('SM_Cabin_Screens',None); S=Furn(me,[]); uv=S.bm.loops.layers.uv.new('UVMap')
def wall_screen(side,yc,zc,w,h,mat):
    dx=1 if side>0 else -1
    hit=wall_hit(yc,zc,dx); hl=wall_hit(yc-0.5,zc,dx); hr=wall_hit(yc+0.5,zc,dx)
    t=(hr-hl); t.z=0; t.normalize()                  # вдоль стены (в сторону +y)
    n=Vector((-t.y,t.x,0));
    if (n.x>0)==(side>0): n=-n                        # внутрь комнаты
    c=Vector((hit.x,hit.y,zc))+n*0.0
    yaw=-math.atan2(t.x,t.y)
    # корпус и рамка
    S.rbox(c+n*0.03,(0.06,w+0.16,h+0.16),0.02,rot=(0,0,yaw),m=P+'Black',seg=2)
    for sgn in (-1,1):
        S.rbox(c+n*0.065+t*sgn*(w/2+0.05),(0.03,0.07,h+0.16),0.012,rot=(0,0,yaw),m=P+'Steel',seg=2)
        S.rbox(c+n*0.065+Vector((0,0,sgn*(h/2+0.05))),(0.03,w+0.16,0.07),0.012,rot=(0,0,yaw),m=P+'Steel',seg=2)
    # экран
    base=c+n*0.065
    right=-t if side>0 else t                       # «вправо» с точки зрения зрителя
    vs=[S.bm.verts.new(base+right*sx*w/2+Vector((0,0,sz*h/2))) for sx,sz in((-1,-1),(1,-1),(1,1),(-1,1))]
    f=S.bm.faces.new(vs); f.material_index=S.mi(mat.name); f.smooth=False
    for l,(u,v) in zip(f.loops,((0,0),(1,0),(1,1),(0,1))): l[uv].uv=(u,v)
    if f.normal.dot(n)<0: f.normal_flip()
    return hit
S.mi(P+'Black'); S.mi(P+'Steel'); S.mi(m_big.name); S.mi(m_clim.name)
wall_screen(+1,22.1,-0.25,2.9,1.63,m_big)           # над диваном
wall_screen(-1,23.45,-0.15,1.1,0.69,m_clim)         # рядом со шлюзом
S.write()

# ---------- цилиндрическая голограмма ----------
CX,CY=-1.6,24.75; ZF=-2.11; ZC=0.916; RB=1.06; RH=1.0   # RH=1.0: человек в T-позе (размах рук ~1.85 м) помещается
ob2,me2=new_obj('SM_Cabin_HoloColumn',None); H=Furn(me2,[])
get_mat('MAT_Console_Body',(0.035,0.07,0.16,1),0.3,0.85)
get_mat('MAT_Console_Dark',(0.01,0.02,0.05,1),0.35,0.5)
get_mat('MAT_Console_Glow',(0.2,0.8,1,1),0.5,0,emit=(0.25,0.85,1,1),st=6)
get_mat('MAT_Console_Orange',(1,0.4,0.1,1),0.5,0,emit=(1,0.42,0.1,1),st=10)
def console(zb,sg):
    """Консоль-диск как на концепте: широкое тонкое светящееся кольцо, тёмно-синий корпус с голубым поясом,
    скошенный верх, углубление с кольцами и светящимся диском, шесть наклонных пилонов с оранжевыми огнями.
    zb - плоскость крепления (пол/потолок), sg=+1 вверх от пола, -1 вниз от потолка."""
    Z=lambda d: zb+sg*d
    H.cyl((CX,CY,Z(0.010)),RB+0.12,0.020,'MAT_Console_Dark',bev=0.006,seg=56)               # широкая тонкая подложка
    H.cyl((CX,CY,Z(0.021)),RB+0.115,0.006,'MAT_Console_Glow',seg=56)                         # светящийся контур подложки
    H.cyl((CX,CY,Z(0.080)),RB,0.120,'MAT_Console_Body',bev=0.02,seg=56)                       # нижний корпус
    H.cyl((CX,CY,Z(0.090)),RB+0.006,0.026,'MAT_Console_Glow',seg=56)                          # голубой пояс
    H.cyl((CX,CY,Z(0.170)),RB-0.05,0.060,'MAT_Console_Body',r2=RB-0.20,bev=0.012,seg=56)      # скошенный верх
    H.cyl((CX,CY,Z(0.203)),RB-0.20,0.010,'MAT_Console_Dark',seg=56)                           # углубление
    for r in (0.84,0.64,0.44):                                                                 # кольца-канавки
        H.cyl((CX,CY,Z(0.210)),r+0.012,0.004,'MAT_Console_Glow',seg=56)
        H.cyl((CX,CY,Z(0.212)),r-0.012,0.004,'MAT_Console_Dark',seg=56)
    H.cyl((CX,CY,Z(0.214)),0.30,0.005,'MAT_Console_Glow',seg=48)                              # центральный диск-излучатель
    for k in range(6):                                                                         # пилоны
        a=k*math.tau/6+math.pi/6; rr=RB-0.14
        px,py=CX+rr*math.cos(a),CY+rr*math.sin(a)
        H.rbox((px,py,Z(0.235)),(0.20,0.11,0.17),0.03,rot=(0,0,a-math.pi/2),m='MAT_Console_Body',seg=3)
        H.sph((CX+(rr+0.045)*math.cos(a),CY+(rr+0.045)*math.sin(a),Z(0.30)),0.022,'MAT_Console_Orange')
        H.rbox((CX+(rr-0.04)*math.cos(a),CY+(rr-0.04)*math.sin(a),Z(0.255)),(0.04,0.12,0.04),0.012,rot=(0,0,a-math.pi/2),m='MAT_Console_Glow',seg=2)
console(ZF,+1); console(ZC,-1)
H.write()
ob3,me3=new_obj('SM_Cabin_HoloTube',None)
bm=bmesh.new(); uv3=bm.loops.layers.uv.new('UVMap'); z0=ZF+0.33; z1=ZC-0.33; N=96
ring0=[];ring1=[]
for i in range(N+1):
    a=i*math.tau/N; x=CX+RH*math.cos(a); y=CY+RH*math.sin(a)
    ring0.append(bm.verts.new((x,y,z0))); ring1.append(bm.verts.new((x,y,z1)))
for i in range(N):
    f=bm.faces.new((ring0[i],ring0[i+1],ring1[i+1],ring1[i]))
    for l,(u,v) in zip(f.loops,((i/N,0),((i+1)/N,0),((i+1)/N,1),(i/N,1))): l[uv3].uv=(u,v)
bm.to_mesh(me3); bm.free(); me3.materials.append(m_col)
result={'screens_faces':len(me.polygons),'col_faces':len(me2.polygons),'tube_faces':len(me3.polygons)}
