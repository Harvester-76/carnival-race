# Клавиатуры на наклонном столике перед креслами рубки + прозрачные голо-окна за ним.
# Запуск в Blender: exec(open('.../tools/build_cabin_keyboards.py').read())
# Раскладка клавиш и атласы: textures/tools/make_cabin_ui.py (числа должны совпадать).
# Столик (SM_Cabin_Dash, грань между y=29.19 и y=29.96) ищется по вершинам; если его двигали руками, скрипт подстроится.
import bpy, bmesh, math
from mathutils import Vector, Matrix

BASE='/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/textures/interior/'
COLS,ROWS,PITCH,KEY,TOP=16,6,0.042,0.034,0.028
PW,PD=0.69,0.276                      # плата, м (x, y)
X0=(PW-COLS*PITCH)/2; Y0=(PD-ROWS*PITCH)/2
SPANS=[[1]*16,[1]*16,[1]*16,[1]*12+[2,1,1],[2]+[1]*14,[1,1,1,6]+[1]*7]
SEAT_X=[-2.14,0.0,2.14]
PLATE_T=0.012; KEY_H=0.012
# голо-окна: (центр x, номер ячейки атласа 0..3)
HOLOS=[(-2.14,0),(-0.62,1),(0.62,2),(2.14,3)]
HW,HH=1.10,0.69; TILT=math.radians(15); HOLO_Y=30.45; HOLO_Z=-1.10

arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
dash=bpy.data.objects['SM_Cabin_Dash']
# убрать прошлую версию (на тумбах)
for n in ('SM_Cabin_Keyboards','SM_Cabin_Holo'):
    o=bpy.data.objects.get(n)
    if o: bpy.data.objects.remove(o,do_unlink=True)

# --- плоскость столика: передняя-низкая и задняя-высокая вершины по x=+-3.157 ---
mw=dash.matrix_world
tv=[mw@v.co for v in dash.data.vertices if abs(abs((mw@v.co).x)-3.157)<0.01 and 29.0<(mw@v.co).y<30.0]
tv.sort(key=lambda p:p.y)
lo=[p for p in tv if p.y<29.3 and p.z>-1.48]; hi=[p for p in tv if 29.9<p.y<30.0 and p.z>-1.4]
y_lo=sum(p.y for p in lo)/len(lo); z_lo=sum(p.z for p in lo)/len(lo)
y_hi=sum(p.y for p in hi)/len(hi); z_hi=sum(p.z for p in hi)/len(hi)
slope=(z_hi-z_lo)/(y_hi-y_lo); ang=math.atan(slope)
y_c=(y_lo+y_hi)/2; z_c=(z_lo+z_hi)/2

# --- материалы ---
def tex(name,fn):
    im=bpy.data.images.get(name)
    if im: bpy.data.images.remove(im)
    im=bpy.data.images.load(BASE+fn); im.name=name; im.alpha_mode='STRAIGHT'; return im
def mat(name):
    m=bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m=bpy.data.materials.new(name); m.use_nodes=True; m.node_tree.nodes.clear(); return m
mk=mat('MAT_Cabin_Keys'); nt=mk.node_tree; N=nt.nodes; L=nt.links
o=N.new('ShaderNodeOutputMaterial'); b=N.new('ShaderNodeBsdfPrincipled')
a=N.new('ShaderNodeTexImage'); a.image=tex('kb_albedo','kb_albedo_2560x1024.png')
e=N.new('ShaderNodeTexImage'); e.image=tex('kb_emission','kb_emission_2560x1024.png')
b.inputs['Roughness'].default_value=0.45; b.inputs['Emission Strength'].default_value=2.0
L.new(a.outputs['Color'],b.inputs['Base Color']); L.new(e.outputs['Color'],b.inputs['Emission Color']); L.new(b.outputs[0],o.inputs[0])
mh=mat('MAT_Holo'); nt=mh.node_tree; N=nt.nodes; L=nt.links
o=N.new('ShaderNodeOutputMaterial'); t=N.new('ShaderNodeTexImage'); t.image=tex('holo_atlas','holo_atlas_2048x1280.png')
em=N.new('ShaderNodeEmission'); em.inputs['Strength'].default_value=2.5
tr=N.new('ShaderNodeBsdfTransparent'); mx=N.new('ShaderNodeMixShader'); mu=N.new('ShaderNodeMath'); mu.operation='MULTIPLY'; mu.inputs[1].default_value=0.9
L.new(t.outputs['Alpha'],mu.inputs[0]); L.new(mu.outputs[0],mx.inputs[0]); L.new(tr.outputs[0],mx.inputs[1])
L.new(t.outputs['Color'],em.inputs['Color']); L.new(em.outputs[0],mx.inputs[2]); L.new(mx.outputs[0],o.inputs[0])
mh.surface_render_method='BLENDED'; mh.use_backface_culling=False
me_=mat('MAT_Holo_Emitter'); nt=me_.node_tree; N=nt.nodes; L=nt.links
o=N.new('ShaderNodeOutputMaterial'); em=N.new('ShaderNodeEmission'); em.inputs['Color'].default_value=(0.2,0.8,1,1); em.inputs['Strength'].default_value=4
L.new(em.outputs[0],o.inputs[0])

def new_obj(name,mats):
    m=bpy.data.meshes.new(name); ob=bpy.data.objects.new(name,m); col.objects.link(ob)
    for x in mats: m.materials.append(x)
    ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted(); return ob

# --- клавиатуры: строим плоско, потом поворачиваем на угол столика ---
kb=new_obj('SM_Cabin_Keyboards',[mk]); kbm=bmesh.new(); uv=kbm.loops.layers.uv.new('UVMap')
def frustum(cx,cy,z0,w0,d0,z1,w1,d1,ox,oy,M):
    p=[(-1,-1),(1,-1),(-1,1),(1,1)]
    v=[kbm.verts.new(M@Vector((cx+sx*w0/2,cy+sy*d0/2,z0))) for sx,sy in p]+[kbm.verts.new(M@Vector((cx+sx*w1/2,cy+sy*d1/2,z1))) for sx,sy in p]
    loc={}
    for i,(sx,sy) in enumerate(p):
        loc[v[i]]=(cx+sx*w0/2,cy+sy*d0/2); loc[v[i+4]]=(cx+sx*w1/2,cy+sy*d1/2)
    for q in ((4,5,7,6),(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3)):
        f=kbm.faces.new([v[i] for i in q])
        for l in f.loops:
            x,y=loc[l.vert]; l[uv].uv=((x-ox)/PW,(y-oy)/PD)
nkeys=0
for sx in SEAT_X:
    M=Matrix.Translation((sx,y_c,z_c))@Matrix.Rotation(ang,4,'X')
    ox,oy=-PW/2,-PD/2
    frustum(0,0,0,PW,PD,PLATE_T,PW,PD,ox,oy,M)
    for r,row in enumerate(SPANS):
        c=0
        for span in row:
            xl=ox+X0+(c+span/2)*PITCH; yl=oy+Y0+(ROWS-1-r+0.5)*PITCH
            frustum(xl,yl,PLATE_T,KEY+(span-1)*PITCH,KEY,PLATE_T+KEY_H,TOP+(span-1)*PITCH,TOP,ox,oy,M); nkeys+=1
            c+=span
bmesh.ops.recalc_face_normals(kbm,faces=kbm.faces)
kbm.to_mesh(kb.data); kbm.free()
for p in kb.data.polygons: p.use_smooth=False

# --- голо-окна ---
hl=new_obj('SM_Cabin_Holo',[mh,me_]); hbm=bmesh.new(); huv=hbm.loops.layers.uv.new('UVMap')
def surf_z(y): return -1.142-0.302*(y-30.192)     # верх приборной панели за столиком
for cx,k in HOLOS:
    top=Vector((0,math.sin(TILT)*HH,math.cos(TILT)*HH))
    bl=Vector((cx-HW/2,HOLO_Y,HOLO_Z)); br=Vector((cx+HW/2,HOLO_Y,HOLO_Z))
    vs=[hbm.verts.new(p) for p in (bl,br,br+top,bl+top)]
    f=hbm.faces.new(vs)
    if f.normal.y>0: f.normal_flip()
    u0=(k%2)*0.5; v0=0.5-(k//2)*0.5
    uvmap={vs[0]:(u0,v0),vs[1]:(u0+0.5,v0),vs[2]:(u0+0.5,v0+0.5),vs[3]:(u0,v0+0.5)}
    for l in f.loops: l[huv].uv=uvmap[l.vert]
    ez=surf_z(HOLO_Y)+0.006
    ex=[hbm.verts.new((cx+sx*0.45,HOLO_Y+sy*0.012,ez+sz*0.004)) for sz in(-1,1) for sy in(-1,1) for sx in(-1,1)]
    for q in ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)):
        ff=hbm.faces.new([ex[i] for i in q]); ff.material_index=1
        for l in ff.loops: l[huv].uv=(0.5,0.5)
hbm.normal_update(); bmesh.ops.recalc_face_normals(hbm,faces=[f for f in hbm.faces if f.material_index==1])
hbm.to_mesh(hl.data); hbm.free()
result={'keys':nkeys,'table_angle_deg':round(math.degrees(ang),1),'table_center':(round(y_c,3),round(z_c,3))}
