# UV ковра кают-компании (MAT_Cabin_Rug в SM_Cabin_Lounge): планарная проекция по плану, ковёр 5.4 x 4.0 м (x -0.1..5.3, y 20.6..24.6).
# Картинка: u вдоль +x (слева направо), v вдоль +y (вверх = в сторону мостика). Запуск: exec(open('.../tools/build_rug_uv.py').read())
import bpy, bmesh, os
o=bpy.data.objects['SM_Cabin_Lounge']; me=o.data; mw=o.matrix_world
mi=[m.name if m else '' for m in me.materials].index('MAT_Cabin_Rug')
X0,Y0,W,H=-0.1,20.6,5.4,4.0
bm=bmesh.new(); bm.from_mesh(me); uv=bm.loops.layers.uv.get('UVMap') or bm.loops.layers.uv.new('UVMap')
for f in bm.faces:
    if f.material_index!=mi: continue
    for l in f.loops:
        w=mw@l.vert.co; l[uv].uv=((w.x-X0)/W,(w.y-Y0)/H)
bm.to_mesh(me); bm.free()
fn=os.path.join(os.path.dirname(bpy.data.filepath),'textures','interior','rug_albedo.png')
if os.path.exists(fn):                       # картинка от GPT есть: подключить к материалу
    m=bpy.data.materials['MAT_Cabin_Rug']; m.use_nodes=True; nt=m.node_tree; b=[n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'][0]
    t=nt.nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(fn,check_existing=True); t.image.reload()
    uvn=nt.nodes.new('ShaderNodeUVMap'); uvn.uv_map='UVMap'; nt.links.new(uvn.outputs[0],t.inputs['Vector']); nt.links.new(t.outputs['Color'],b.inputs['Base Color'])
print('RUGUV ok')
