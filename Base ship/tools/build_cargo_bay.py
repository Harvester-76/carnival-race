# Грузовой отсек: примитивный объём, повторяющий сечение корпуса в задней утолщённой части (y -16.6..-5.0),
# плюс внутренняя дверь круглого люка A на плоской левой стене (центр y -10.6, z 0.97, диск A стоит в обшивке с внешней стороны).
# Запуск: exec(open('.../tools/build_cargo_bay.py').read()). Пересобирает SM_Cargo_Shell и SM_Cargo_Lights.
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
BASE=os.path.join(os.path.dirname(bpy.data.filepath),'textures','interior','tiles')
arm=bpy.data.objects['SK_Spaceship']; col=bpy.data.collections['COL_Interior']
Y0,Y1=-16.6,-5.0
YC,ZC=-10.6,0.97; RH=3.95
# сечение (x,z) правой половины, затем зеркало: пол плоский, борта скошены как у корпуса (с запасом ~0.6 м на обшивку)
H=[(9.2,-4.8),(11.3,-3.0),(11.3,4.9),(9.5,5.8)]
SEC=[(x,z) for x,z in H]+[(-x,z) for x,z in H[::-1]]            # правая сторона снизу вверх, левая сверху вниз
XH=-11.3                                                      # плоская левая стена: сюда ставится внутренняя дверь люка A
for n in ('SM_Cargo_Shell','SM_Cargo_Lights','SM_Cargo_Hatch'):
    o=bpy.data.objects.get(n)
    if o: bpy.data.objects.remove(o,do_unlink=True)

def mat_img(name,stem,metal,tile_note=''):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True; nt=m.node_tree; nt.nodes.clear(); N=nt.nodes; L=nt.links
    out=N.new('ShaderNodeOutputMaterial'); b=N.new('ShaderNodeBsdfPrincipled'); uv=N.new('ShaderNodeUVMap'); uv.uv_map='UVMap'
    def img(fn,cs):
        t=N.new('ShaderNodeTexImage'); im=bpy.data.images.load(os.path.join(BASE,fn),check_existing=True); im.reload(); im.colorspace_settings.name=cs; t.image=im
        L.new(uv.outputs[0],t.inputs['Vector']); return t
    a=img(stem+'_albedo.png','sRGB'); r=img(stem+'_rough.png','Non-Color'); n=img(stem+'_normal.png','Non-Color')
    nm=N.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=0.6
    b.inputs['Metallic'].default_value=metal
    L.new(a.outputs['Color'],b.inputs['Base Color']); L.new(r.outputs['Color'],b.inputs['Roughness'])
    L.new(n.outputs['Color'],nm.inputs['Color']); L.new(nm.outputs['Normal'],b.inputs['Normal']); L.new(b.outputs[0],out.inputs[0]); return m
m_wall=mat_img('MAT_Cargo_Wall','wall_cargo',0.7); m_floor=mat_img('MAT_Cargo_Floor','floor_cargo',0.6); m_steel=bpy.data.materials['MAT_Cabin_Steel']
m_light=bpy.data.materials.get('MAT_Cargo_Light') or bpy.data.materials['MAT_Cabin_Light'].copy(); m_light.name='MAT_Cargo_Light'

# 1) объём воздуха: призма сечения + туннель, объединяем, нормали внутрь
bm=bmesh.new(); ring0=[bm.verts.new((x,Y0,z)) for x,z in SEC]; ring1=[bm.verts.new((x,Y1,z)) for x,z in SEC]
n=len(SEC)
for i in range(n):
    j=(i+1)%n; bm.faces.new((ring0[i],ring0[j],ring1[j],ring1[i]))
bm.faces.new(ring0[::-1]); bm.faces.new(ring1)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
me=bpy.data.meshes.new('SM_Cargo_Shell'); bm.to_mesh(me); bm.free()
shell=bpy.data.objects.new('SM_Cargo_Shell',me); col.objects.link(shell)
# (туннеля нет: диск A стоит в обшивке почти вплотную к стене, x ~ -11.9)
# 2) нормали внутрь, материалы, UV по мировым размерам (бокс-проекция)
bm=bmesh.new(); bm.from_mesh(shell.data); bmesh.ops.reverse_faces(bm,faces=bm.faces)
shell.data.materials.clear()
for m in (m_wall,m_floor,m_steel): shell.data.materials.append(m)
uv=bm.loops.layers.uv.new('UVMap'); TW,TF=8.0,4.0
for f in bm.faces:
    nrm=f.normal; c=f.calc_center_median(); ax=max(range(3),key=lambda i:abs(nrm[i]))
    if ax==2 and nrm.z>0.9: f.material_index=1
    else: f.material_index=0
    T=TF if f.material_index==1 else TW
    for l in f.loops:
        p=l.vert.co; u,v={0:(p.y,p.z),1:(p.x,p.z),2:(p.x,p.y)}[ax]; l[uv].uv=(u/T,v/T)
for f in bm.faces: f.smooth=False
bm.to_mesh(shell.data); bm.free()
shell.parent=arm; shell.matrix_parent_inverse=arm.matrix_world.inverted()
# 3) потолочные светильники: три продольные полосы
bm=bmesh.new()
for x in (-6.0,0.0,6.0):
    bmesh.ops.create_cube(bm,size=1.0,matrix=Matrix.Translation((x,-10.8,5.72))@Matrix.Diagonal((0.5,9.6,0.07,1)))
lm=bpy.data.meshes.new('SM_Cargo_Lights'); bm.to_mesh(lm); bm.free(); lm.materials.append(m_light)
lo=bpy.data.objects.new('SM_Cargo_Lights',lm); col.objects.link(lo); lo.parent=arm; lo.matrix_parent_inverse=arm.matrix_world.inverted()
bm=bmesh.new(); bm.from_mesh(lm); uvl=bm.loops.layers.uv.new('UVMap'); bm.to_mesh(lm); bm.free()
print('CARGO',len(shell.data.polygons),'faces; bounds',[round(v,1) for v in shell.bound_box[0]],[round(v,1) for v in shell.bound_box[6]])

# 4) внутренняя дверь люка A: диск-бобышка на левой стене, лицо с текстурой GPT (та же, что снаружи)
mh=bpy.data.materials.get('MAT_Cargo_Hatch') or bpy.data.materials.new('MAT_Cargo_Hatch'); mh.use_nodes=True; nt=mh.node_tree; nt.nodes.clear()
o_=nt.nodes.new('ShaderNodeOutputMaterial'); b_=nt.nodes.new('ShaderNodeBsdfPrincipled'); t_=nt.nodes.new('ShaderNodeTexImage'); u_=nt.nodes.new('ShaderNodeUVMap'); u_.uv_map='UVMap'
t_.image=bpy.data.images.load(os.path.join(BASE,'..','airlock_disc_cargo.png'),check_existing=True); t_.image.reload(); b_.inputs['Metallic'].default_value=0.5; b_.inputs['Roughness'].default_value=0.5
nt.links.new(u_.outputs[0],t_.inputs['Vector']); nt.links.new(t_.outputs['Color'],b_.inputs['Base Color']); nt.links.new(b_.outputs[0],o_.inputs[0])
bm=bmesh.new(); bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=False,segments=64,radius1=RH,radius2=RH,depth=0.15,matrix=Matrix.Identity(4))
for v in bm.verts: v.co=Vector((XH+(v.co.z+0.075),YC+v.co.x,ZC+v.co.y))          # ось по x, от стены внутрь отсека на 0.15
bm.normal_update(); bm.faces.ensure_lookup_table(); uvh=bm.loops.layers.uv.new('UVMap')
for f in bm.faces:
    face=f.normal.x>0.99
    f.material_index=0 if face else 1
    for l in f.loops: l[uvh].uv=(0.5+(l.vert.co.y-YC)/(2*RH),0.5+(l.vert.co.z-ZC)/(2*RH))
hm=bpy.data.meshes.new('SM_Cargo_Hatch'); bm.to_mesh(hm); bm.free(); hm.materials.append(mh); hm.materials.append(m_steel)
ho=bpy.data.objects.new('SM_Cargo_Hatch',hm); col.objects.link(ho); ho.parent=arm; ho.matrix_parent_inverse=arm.matrix_world.inverted()
