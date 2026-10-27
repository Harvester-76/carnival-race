# Упрощает двери коридора: убирает жёлтые рейки, окно, ручки и накладки с листа двери.
# Вид двери (окно, ручка, табличка, полоса опасности) рисуется текстурой на лицевой грани листа.
# Запускать ОДИН раз на текущем меше (дальше правки руками). Бэкап меша: SM_Corridor_Doors_mesh_backup.
import bpy, bmesh
from mathutils import Vector

BASE='/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/textures/interior/'
o=bpy.data.objects['SM_Corridor_Doors']; me=o.data; mw=o.matrix_world
if 'SM_Corridor_Doors_mesh_backup' not in bpy.data.meshes:
    b=me.copy(); b.name='SM_Corridor_Doors_mesh_backup'; b.use_fake_user=True

def mat(name,fn):
    m=bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new('ShaderNodeOutputMaterial'); bs=nt.nodes.new('ShaderNodeBsdfPrincipled'); t=nt.nodes.new('ShaderNodeTexImage')
    im=bpy.data.images.get(name+'_img')
    if im: bpy.data.images.remove(im)
    im=bpy.data.images.load(BASE+fn); im.name=name+'_img'; t.image=im
    bs.inputs['Roughness'].default_value=0.5; bs.inputs['Metallic'].default_value=0.3
    nt.links.new(t.outputs['Color'],bs.inputs['Base Color']); nt.links.new(bs.outputs[0],out.inputs[0]); return m
m_cab=mat('MAT_Corr_DoorFront','door_cabin_albedo.png')
m_eng=mat('MAT_Corr_DoorFrontEngine','door_engine_albedo.png')
for m in (m_cab,m_eng):
    if m.name not in [s.material.name for s in o.material_slots if s.material]: me.materials.append(m)
names=[s.material.name for s in o.material_slots]
i_cab=names.index('MAT_Corr_DoorFront'); i_eng=names.index('MAT_Corr_DoorFrontEngine')

bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
uv=bm.loops.layers.uv['UVMap']
slot={i:s.material.name for i,s in enumerate(o.material_slots)}
seen=set(); comps=[]
for f in bm.faces:
    if f.index in seen: continue
    st=[f]; seen.add(f.index); cur=[]
    while st:
        g=st.pop(); cur.append(g)
        for v in g.verts:
            for h in v.link_faces:
                if h.index not in seen: seen.add(h.index); st.append(h)
    comps.append(cur)
def bbox(c):
    vs=[mw@v.co for g in c for v in g.verts]
    return [min(v[k] for v in vs) for k in range(3)],[max(v[k] for v in vs) for k in range(3)]
leaves=[c for c in comps if all(slot[g.material_index]=='MAT_Corr_Door' for g in c)]
kill=[]; info=[]
for lf in leaves:
    mn,mx=bbox(lf); cx=(mn[0]+mx[0])/2; cy=(mn[1]+mx[1])/2
    end=cy<4.5
    # лицевая грань: нормаль в сторону коридора
    d=Vector((0,1,0)) if end else Vector((-1 if cx>0 else 1,0,0))
    best=max(lf,key=lambda g:((mw.to_3x3()@g.normal).dot(d),g.calc_area()))
    # UV: u вправо с точки зрения человека в коридоре
    vs=[mw@v.co for v in best.verts]
    lo=[min(v[k] for v in vs) for k in range(3)]; hi=[max(v[k] for v in vs) for k in range(3)]
    for l in best.loops:
        w=mw@l.vert.co
        if end: u=(hi[0]-w.x)/(hi[0]-lo[0])
        elif cx>0: u=(hi[1]-w.y)/(hi[1]-lo[1])
        else: u=(w.y-lo[1])/(hi[1]-lo[1])
        l[uv].uv=(u,(w.z-lo[2])/(hi[2]-lo[2]))
    best.material_index=i_eng if end else i_cab
    info.append((round(cx,2),round(cy,2),'end' if end else 'cabin'))
    # лишние накладки внутри габарита листа
    ylo,yhi=(mn[0]-0.02,mx[0]+0.02) if end else (mn[1]-0.02,mx[1]+0.02)
    for c in comps:
        if c is lf: continue
        cmn,cmx=bbox(c)
        a0,a1=(cmn[0],cmx[0]) if end else (cmn[1],cmx[1])
        mt={slot[g.material_index] for g in c}
        if a0>=ylo and a1<=yhi and cmn[2]>=mn[2]-0.02 and cmx[2]<=mx[2]+0.02 and not (mt<= {'MAT_Corr_Red','MAT_Corr_Light'}):
            # только то, что стоит на стороне коридора рядом с листом
            near=(cmn[1]<mx[1]+0.25 and cmx[1]>mn[1]-0.02) if end else ((cmn[0]<mx[0]+0.25 and cmx[0]>mn[0]-0.02) if cx>0 else (cmn[0]<mx[0]+0.02 and cmx[0]>mn[0]-0.25))
            if near: kill.append(c)
faces=[g for c in kill for g in c]
n=len(kill)
bmesh.ops.delete(bm,geom=list({g for g in faces}),context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bm.to_mesh(me); me.update(); bm.free()
result={'leaves':info,'removed_components':n,'faces_now':len(me.polygons)}
