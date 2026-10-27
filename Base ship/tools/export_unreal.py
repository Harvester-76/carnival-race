# Пакет для Unreal: blender -b spaceship_4.blend -P tools/export_unreal.py   ->  Base ship/UNREAL_EXPORT/
# Каждая деталь = отдельный FBX (статик-меш) с пивотом в точке крепления; геометрия повёрнута на -90 градусов вокруг Z
# (нос Blender +Y -> нос Unreal +X); масштаб x100 запечён в вершины (числа в сантиметрах, UnitScaleFactor=1), оси Y/Z.
# UE = (x_b..): Blender (x,y,z) -> Unreal (y, x, z)*100 см (см. Data/assembly.csv).
import bpy, bmesh, os, csv, json, math, shutil, collections
from mathutils import Matrix, Vector
BASE=os.path.dirname(bpy.data.filepath); OUT=os.path.join(BASE,'UNREAL_EXPORT')
for d in ('Meshes/Ship','Meshes/Parts','Meshes/Interior','Meshes/Debris','Textures','Data'): os.makedirs(os.path.join(OUT,d),exist_ok=True)
sc=bpy.context.scene; tmpcol=bpy.data.collections.new('TMP_EXPORT'); sc.collection.children.link(tmpcol)
RZ=Matrix.Scale(100.0,4)@Matrix.Rotation(math.radians(-90),4,'Z')      # масштаб 100 запечён в геометрию: числа в см, единица FBX = 1 (см)
def ue(p): return (round(p.y*100,2),round(p.x*100,2),round(p.z*100,2))          # (x,y,z)_blender -> UE, см
def make_temp(src,name,pivot):
    me=src.data.copy(); me.name=name; me.transform(RZ@Matrix.Translation(-pivot)@src.matrix_world); me.update()
    ob=bpy.data.objects.new(name,me); tmpcol.objects.link(ob); return ob
def export(objs,path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_NONE',apply_unit_scale=False,global_scale=1.0,
        axis_forward='Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_tspace=False,add_leaf_bones=False,bake_anim=False,
        colors_type='SRGB',use_custom_props=False,path_mode='STRIP',bake_space_transform=False)
    for o in objs: bpy.data.objects.remove(o,do_unlink=True)
rows=[]; used_mats=set(); used_by=collections.defaultdict(list)
def do(src,sub,pivot_mode,role,ucx=True):
    pivot=src.matrix_world.translation.copy() if pivot_mode=='origin' else Vector((0,0,0))
    name0=src.name; u=bpy.data.objects.get('UCX_%s_01'%name0) if ucx else None; ucxn=''
    src.name=name0+'__src'                                   # освободить имя, иначе временный объект получит суффикс .001 и сломает сопоставление UCX
    if u: u.name=u.name+'__src'
    objs=[make_temp(src,name0,pivot)]
    if u: objs.append(make_temp(u,'UCX_%s_01'%name0,pivot)); ucxn='UCX_%s_01'%name0
    export(objs,os.path.join(OUT,'Meshes',sub,name0+'.fbx'))
    src.name=name0
    if u: u.name='UCX_%s_01'%name0
    for m in src.data.materials:
        if m: used_mats.add(m.name); used_by[m.name].append(src.name)
    rows.append((src.name,sub+'/'+src.name+'.fbx',role,ue(pivot),(0,0,0),(1,1,1),ucxn,len(src.data.polygons)))
# корпус и вариации
for n,role in (('SM_Hull_Body','hull'),('SM_Hull_Body_LOD1','hull LOD1 (NPC вдали, без вмятин)'),('SM_Hull_Solid','hull explosion proxy (замкнутый, под Voronoi)')):
    do(bpy.data.objects[n],'Ship','world',role,ucx=False)
for o in sorted(bpy.data.collections['COL_Parts'].objects,key=lambda o:o.name): do(o,'Parts','origin','part')
for o in sorted(bpy.data.collections['COL_Interior'].objects,key=lambda o:o.name):
    if o.type=='MESH': do(o,'Interior','world','interior',ucx=False)
for o in sorted(bpy.data.collections['COL_Debris'].objects,key=lambda o:o.name): do(o,'Debris','world','debris plate',ucx=False)
bpy.data.collections.remove(tmpcol)
with open(os.path.join(OUT,'Data','assembly.csv'),'w',newline='') as f:
    w=csv.writer(f); w.writerow(['name','fbx','role','ue_location_cm_x','ue_location_cm_y','ue_location_cm_z','ue_rot_x','ue_rot_y','ue_rot_z','scale','ucx_collision','faces'])
    for r in rows: w.writerow([r[0],r[1],r[2],*r[3],*r[4],1,r[6],r[7]])
# сокеты: кости скелета
arm=bpy.data.objects['SK_Spaceship']
with open(os.path.join(OUT,'Data','sockets.csv'),'w',newline='') as f:
    w=csv.writer(f); w.writerow(['bone','blender_head_x','blender_head_y','blender_head_z','ue_head_cm_x','ue_head_cm_y','ue_head_cm_z','ue_tail_cm_x','ue_tail_cm_y','ue_tail_cm_z'])
    for b in arm.data.bones:
        h=arm.matrix_world@b.head_local; t=arm.matrix_world@b.tail_local; w.writerow([b.name,*[round(v,3) for v in h],*ue(h),*ue(t)])
# материалы
notes={
 'MAT_Glass':'ОДНОСТОРОННЕЕ стекло: Translucent + Two Sided. Opacity = saturate(TwoSidedSign)*0.47+0.03 (снаружи 0.5, изнутри 0.03). Base Color (0.06,0.15,0.25), Roughness 0.04, Specular 0.6. Если эффект вывернут, поменять знак.',
 'MAT_Engine_Core':'Свечение по взгляду: Layer Weight(Facing, Blend 0.5) -> Color Ramp (0.0: 0.45,0.75,1.0 ; 0.6: 0.06,0.32,1.0) -> Base Color и Emission Color; Emission Strength 3.0. В UE: Fresnel/ dot(normal,camera) -> Lerp двух цветов -> Emissive.',
 'MAT_Engine_Glow':'Диск свечения у сопла (эмиссия).',
 'Material':'Обшивка. Базовые текстуры по UV (UVMap): hull_albedo_4096/roughness/metallic; поверх шестигранники, наклейка decal_third_chance.png и маска выбитых ячеек hull_fallen_mask_4096.png (UV). В UE шестигранники рисовать ПО ФОРМУЛЕ из Data/hex_lattice.json (WorldAligned по доминирующей оси нормали), а не из hex_tile_*.',
 'MAT_Airlock':'Использует ТРЕТИЙ UV-канал UV_Airlock (в UE индекс 2, TexCoord[2]).',
 'MAT_Hull_Inside':'Тёмный потёртый металл для граней изломов и торцов (скелет разлома).',
 'MAT_Holo':'Голо-окна: прозрачность по яркости, Additive/Translucent, атлас holo_atlas_2048x1280.png.',
 'MAT_Holo_Column':'Цилиндр голограммы: прозрачность по яркости, 4 панели по окружности.',
 'MAT_Cargo_Hatch':'Диск внутренней двери люка A (airlock_disc_cargo.png).',
 'MAT_Cabin_Light':'Эмиссия светильников (в UE MI с параметром яркости + Rect Light).',
 'MAT_Cargo_Light':'Эмиссия светильников грузового отсека.'}
def par(n,names):
    d={}
    for i in n.inputs:
        if i.name in names and hasattr(i,'default_value'):
            v=i.default_value; d[i.name]=[round(x,3) for x in v] if hasattr(v,'__len__') else round(v,3)
    return d
mats={}
for mn in sorted(used_mats):
    m=bpy.data.materials[mn]; info={'users':sorted(used_by[mn])[:6]+(['...'] if len(used_by[mn])>6 else []),'blend':getattr(m,'surface_render_method',None),'textures':[],'uv':[],'note':notes.get(mn,'')}
    if m.node_tree:
        for n in m.node_tree.nodes:
            if n.type=='BSDF_PRINCIPLED': info['principled']=par(n,('Base Color','Metallic','Roughness','Emission Color','Emission Strength','Alpha','IOR'))
            if n.type=='TEX_IMAGE' and n.image: info['textures'].append({'file':os.path.basename(n.image.filepath),'colorspace':n.image.colorspace_settings.name,'size':list(n.image.size),'projection':n.projection})
            if n.type=='UVMAP': info['uv'].append(n.uv_map)
    mats[mn]=info
json.dump(mats,open(os.path.join(OUT,'Data','materials.json'),'w'),indent=1,ensure_ascii=False)
# текстуры (только используемые)
copied={}; 
for mn in used_mats:
    m=bpy.data.materials[mn]
    if not m.node_tree: continue
    for n in m.node_tree.nodes:
        if n.type=='TEX_IMAGE' and n.image and n.image.filepath:
            p=bpy.path.abspath(n.image.filepath)
            if os.path.exists(p) and os.path.basename(p) not in copied: shutil.copy2(p,os.path.join(OUT,'Textures',os.path.basename(p))); copied[os.path.basename(p)]=p
for extra in ('hull_fallen_mask_4096.png','hull_uv_region_map_4k.png'):
    p=os.path.join(BASE,'textures',extra)
    if os.path.exists(p): shutil.copy2(p,os.path.join(OUT,'Textures',extra)); copied[extra]=p
shutil.copy2(os.path.join(BASE,'damage','hex_cells.csv'),os.path.join(OUT,'Data','hex_cells.csv'))
json.dump({'cell_width_m':1.2,'row_pitch_m':round(1.2*math.sqrt(3)/2,4),'orientation':'pointy-top','odd_row_offset':'W/2','projection':'dominant axis of normal: X->(y,z), Y->(x,z), Z->(x,y) (Blender-координаты)','cell':'(axis,i,j): b=j*H, a=(i+0.5*(j&1))*W','note':'координаты в таблице hex_cells.csv даны в метрах Blender; в UE (x,y,z)->(y,x,z)*100 см'},open(os.path.join(OUT,'Data','hex_lattice.json'),'w'),indent=1,ensure_ascii=False)
tot=sum(os.path.getsize(os.path.join(dp,f)) for dp,_,fs in os.walk(OUT) for f in fs)
print('EX fbx',len(rows),'textures',len(copied),'materials',len(mats),'size MB',round(tot/2**20,1))
