# Материалы и развёртка стен/пола/потолка: рубка и кают-компания (MAT_Cabin_*), коридор (MAT_Corr_*), каюты (MAT_Room_*).
# Тайлы 2 x 2 м из textures/interior/tiles (см. textures/tools/make_interior_tiles.py). UV: проекция по осям, 1 единица = 2 м.
# Запуск: exec(open('.../tools/build_interior_materials.py').read())
import bpy, bmesh
from mathutils import Vector

TILES='/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/textures/interior/tiles/'
TILE_M=2.0
# материал -> (имя тайла, металличность)
MAP={'MAT_Cabin_Wall':('wall_bridge',0.1),'MAT_Cabin_Floor':('floor_bridge',0.3),'MAT_Cabin_Ceiling':('ceiling_bridge',0.1),
     'MAT_Corr_Wall':('wall_corr',0.2),'MAT_Corr_Floor':('floor_corr',0.4),'MAT_Corr_Ceiling':('ceiling_corr',0.2),
     'MAT_Room_Wall':('wall_room',0.0),'MAT_Room_Floor':('floor_room',0.0),'MAT_Room_Ceiling':('ceiling_room',0.0)}
def load(fn,nc):
    im=bpy.data.images.load(TILES+fn,check_existing=True); im.reload(); im.colorspace_settings.name='Non-Color' if nc else 'sRGB'; return im
def build_mat(name,tile,metal):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True; nt=m.node_tree; nt.nodes.clear(); N=nt.nodes; L=nt.links
    out=N.new('ShaderNodeOutputMaterial'); bs=N.new('ShaderNodeBsdfPrincipled'); uv=N.new('ShaderNodeUVMap'); uv.uv_map='UVMap'
    a=N.new('ShaderNodeTexImage'); a.image=load(tile+'_albedo.png',False)
    r=N.new('ShaderNodeTexImage'); r.image=load(tile+'_rough.png',True)
    n=N.new('ShaderNodeTexImage'); n.image=load(tile+'_normal.png',True)
    nm=N.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=1.0
    for t in (a,r,n): L.new(uv.outputs[0],t.inputs['Vector'])
    L.new(a.outputs['Color'],bs.inputs['Base Color']); L.new(r.outputs['Color'],bs.inputs['Roughness'])
    L.new(n.outputs['Color'],nm.inputs['Color']); L.new(nm.outputs['Normal'],bs.inputs['Normal'])
    bs.inputs['Metallic'].default_value=metal; L.new(bs.outputs[0],out.inputs[0])
    return m
for name,(tile,metal) in MAP.items(): build_mat(name,tile,metal)

def box_uv(bm,mw,names_of_slot):
    uvl=bm.loops.layers.uv.get('UVMap') or bm.loops.layers.uv.new('UVMap'); n=0
    for f in bm.faces:
        if names_of_slot.get(f.material_index) not in MAP: continue
        nrm=mw.to_3x3()@f.normal; ax=max(range(3),key=lambda i:abs(nrm[i]))
        for l in f.loops:
            w=mw@l.vert.co
            if ax==2: u,v=w.x,w.y
            elif ax==0: u,v=w.y,w.z
            else: u,v=w.x,w.z
            l[uvl].uv=(u/TILE_M,v/TILE_M)
        n+=1
    return n
res={}
objs=['SM_Cabin_Shell','SM_Corridor_Shell','SM_Corridor_Details']+['SM_Room_%02d'%i for i in range(1,11)]
for on in objs:
    o=bpy.data.objects.get(on)
    if not o: continue
    names={i:(s.material.name if s.material else '') for i,s in enumerate(o.material_slots)}
    if o.mode=='EDIT':
        bm=bmesh.from_edit_mesh(o.data); res[on]=box_uv(bm,o.matrix_world,names); bmesh.update_edit_mesh(o.data)
    else:
        bm=bmesh.new(); bm.from_mesh(o.data); res[on]=box_uv(bm,o.matrix_world,names); bm.to_mesh(o.data); bm.free(); o.data.update()
result={'faces_uv':res}
