# Экспорт под Godot: blender -b spaceship_4.blend -P tools/export_godot.py  ->  ../Godot_Test/ship/ship.glb  (файл НЕ сохраняется)
# метры, Y-up (glTF): нос Blender +Y -> -Z Godot (forward). Пивоты частей сохранены, коллизии = <имя>-convcol (дети частей).
import bpy, os
BASE=os.path.dirname(bpy.data.filepath); OUT=os.path.abspath(os.path.join(BASE,'..','Godot_Test','ship','ship.glb'))
exec(open(os.path.join(BASE,'tools','fix_wing_l.py')).read().replace("if __name__=='__main__': fix_wing_l()",''))
if 'SM_Wing_L' in bpy.data.objects: fix_wing_l()                  # у правленного .blend крыло уже разделено и исправлено — пропускается
exec(open(os.path.join(BASE,'tools','split_wings.py')).read()); split_wings()
exec(open(os.path.join(BASE,'tools','build_feet.py')).read()); build_feet()
keep=set()
def col(n): return [o for o in bpy.data.collections[n].objects]
for n in ('COL_Parts','COL_Interior','COL_Debris'): keep|=set(col(n))
keep|={bpy.data.objects['SM_Hull_Body'],bpy.data.objects['SM_Hull_Body_LOD1']}
ucx=col('COL_Collision')
for o in ucx+list(keep):
    m=o.matrix_world.copy(); o.parent=None; o.matrix_world=m
for u in ucx:
    p=bpy.data.objects.get(u.name[4:-3])
    if p and p in keep and 'Glass' not in p.name:
        m=u.matrix_world.copy(); u.name=p.name+'-convcol'; u.parent=p; u.matrix_parent_inverse=p.matrix_world.inverted(); u.matrix_world=m; keep.add(u)
for o in list(bpy.data.objects):
    if o not in keep: bpy.data.objects.remove(o,do_unlink=True)
for o in keep: o.hide_set(False); o.hide_viewport=False; o.hide_render=False
for c in bpy.data.collections: c.hide_viewport=False; c.hide_render=False
for lc in bpy.context.view_layer.layer_collection.children: lc.hide_viewport=False; lc.exclude=False
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_visible=False,export_yup=True,export_apply=False,export_cameras=False,export_lights=False,
    export_extras=False,export_image_format='AUTO',export_materials='EXPORT',export_attributes=True,export_vertex_color='MATERIAL' if False else 'ACTIVE' if hasattr(bpy.types,'x') else 'MATERIAL')
print('GLB',os.path.getsize(OUT)//2**20,'MB')
