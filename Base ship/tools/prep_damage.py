# Подготовка корпуса к повреждениям (после split_hull.py). Запуск: blender -b spaceship_4.blend -P tools/prep_damage.py -- all
# Этапы: pivots (крылья в корень), solid (замкнутая копия корпуса под взрыв/Voronoi), dense (зоны урона + уплотнение + UV_Damage),
#        plates (плиты-шестигранники), collision (UCX-выпуклые оболочки отлетающих частей).
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix
STAGE=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'all'
sc=bpy.context.scene; arm=bpy.data.objects['SK_Spaceship']
body=bpy.data.objects['SM_Hull_Body']; parts=bpy.data.collections['COL_Parts']
def want(s): return STAGE in ('all',s)
def newcol(name,hide=False):
    c=bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if name not in sc.collection.children: sc.collection.children.link(c)
    return c
def repivot(ob,pw):
    pl=ob.matrix_world.inverted()@pw
    ob.data.transform(Matrix.Translation(-pl)); ob.matrix_basis=ob.matrix_basis@Matrix.Translation(pl)

if want('pivots'):
    for n in ('SM_Wing_L','SM_Wing_R'):
        ob=bpy.data.objects[n]; mw=ob.matrix_world; P=[mw@v.co for v in ob.data.vertices]; m=min(abs(p.x) for p in P)
        root=[p for p in P if abs(p.x)<m+0.3]; c=sum(root,Vector())/len(root); repivot(ob,c); print('PD pivot',n,tuple(round(v,2) for v in c))

if want('solid') and 'SM_Hull_Solid' not in bpy.data.objects:
    col=newcol('COL_Destruction')
    me=body.data.copy(); me.name='SM_Hull_Solid'; ob=bpy.data.objects.new('SM_Hull_Solid',me); col.objects.link(ob)
    ob.parent=arm; ob.matrix_parent_inverse=body.matrix_parent_inverse.copy(); ob.matrix_basis=body.matrix_basis.copy()
    inside=bpy.data.materials['MAT_Hull_Inside']; k=len(me.materials)
    for _ in range(k): me.materials.append(inside)              # внутренние грани и торцы получают index+k -> MAT_Hull_Inside
    md=ob.modifiers.new('Solidify','SOLIDIFY'); md.thickness=0.35; md.offset=-1; md.use_even_offset=True; md.use_rim=True; md.material_offset=k; md.material_offset_rim=k
    dg=bpy.context.evaluated_depsgraph_get(); ev=ob.evaluated_get(dg); nm=bpy.data.meshes.new_from_object(ev)
    ob.modifiers.remove(md); old=ob.data; ob.data=nm; nm.name='SM_Hull_Solid'; bpy.data.meshes.remove(old)
    b=bmesh.new(); b.from_mesh(nm); bad=sum(1 for e in b.edges if len(e.link_faces)!=2); print('PD solid faces',len(b.faces),'non-manifold edges',bad); b.free()
    ob.hide_render=True; ob.hide_viewport=True

if want('dense'):
    if 'SM_Hull_Body_LOD1' not in bpy.data.objects:                 # облегчённый корпус без вмятин: LOD для дальних NPC
        lod=body.copy(); lod.data=body.data.copy(); lod.name='SM_Hull_Body_LOD1'; lod.data.name='SM_Hull_Body_LOD1'
        newcol('COL_Destruction').objects.link(lod); lod.hide_render=True; lod.hide_viewport=True
    me=body.data; mw=body.matrix_world
    bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.triangulate(bm,faces=bm.faces[:])
    L=float(sys.argv[sys.argv.index('--')+2]) if len(sys.argv)>sys.argv.index('--')+2 else 0.6
    for it in range(8):
        longe=[e for e in bm.edges if e.calc_length()>L]
        if not longe: break
        bmesh.ops.subdivide_edges(bm,edges=longe,cuts=1,use_grid_fill=True)
        bmesh.ops.triangulate(bm,faces=[f for f in bm.faces if len(f.verts)>3])
    # зоны урона по мировой позиции вершины и нормали: сегмент вдоль корабля (0..4) x область (верх, низ, лево, право)
    def seg(y): return 0 if y>30 else (1 if y>17 else (2 if y>3 else (3 if y>-17 else 4)))
    STIFF=[0.15,0.35,0.35,0.25,0.30]
    zid={}; stf={}
    for v in bm.verts:
        w=mw@v.co; n=(mw.to_3x3()@v.normal).normalized()
        reg=0 if n.z>0.5 else (1 if n.z<-0.5 else (2 if w.x<0 else 3)); s=seg(w.y)
        zid[v.index]=s*4+reg; stf[v.index]=STIFF[s]
    bm.to_mesh(me); bm.free()
    if 'DMG' in me.color_attributes: me.color_attributes.remove(me.color_attributes['DMG'])
    ca=me.color_attributes.new('DMG','BYTE_COLOR','CORNER')
    for lp in me.loops:
        v=lp.vertex_index; z=zid[v]; s=z//4; r=z%4
        ca.data[lp.index].color_srgb=(stf[v],s/4.0,r/3.0,1.0)       # R жёсткость, G сегмент/4, B область/3
    if 'dmg_zone' in me.attributes: me.attributes.remove(me.attributes['dmg_zone'])
    za=me.attributes.new('dmg_zone','INT','POINT'); za.data.foreach_set('value',[zid[i] for i in range(len(me.vertices))])
    # UV_Damage: уникальная развёртка без перекрытий (маска повреждений)
    uvn=me.uv_layers.get('UV_Damage') or me.uv_layers.new(name='UV_Damage'); me.uv_layers.active=uvn
    bpy.ops.object.select_all(action='DESELECT'); body.select_set(True); bpy.context.view_layer.objects.active=body
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=0.003,area_weight=0.0,correct_aspect=True,scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT'); me.uv_layers.active_index=0
    import collections; zc=collections.Counter(zid.values()); print('PD zones verts',sorted(zc.items()))
    print('PD dense verts',len(me.vertices),'tris',len(me.polygons),'uv',[u.name for u in me.uv_layers],'zones',len(set(zid.values())))

if want('plates'):
    col=newcol('COL_Debris'); mat=bpy.data.materials['Material']
    for name,var in (('SM_HexPlate_A',0),('SM_HexPlate_B',1),('SM_HexPlate_C',2)):
        if name in bpy.data.objects: continue
        R=1.18/math.sqrt(3); T=0.04
        bm=bmesh.new(); vs=[bm.verts.new((R*math.cos(math.radians(30+60*k)),R*math.sin(math.radians(30+60*k)),0)) for k in range(6)]
        f=bm.faces.new(vs); r=bmesh.ops.extrude_face_region(bm,geom=[f]); top=[e for e in r['geom'] if isinstance(e,bmesh.types.BMVert)]
        bmesh.ops.translate(bm,verts=top,vec=(0,0,T))
        if var==1:                                    # изогнутая плита: два соседних угла приподняты
            for v in top[:2]: v.co.z+=0.07
        if var==2:                                    # смятый угол
            top[0].co.z+=0.11; top[0].co.x*=0.9; top[0].co.y*=0.9
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        bmesh.ops.bevel(bm,geom=[e for e in bm.edges],offset=0.006,segments=1,affect='EDGES')
        uv=bm.loops.layers.uv.new('UVMap')
        for fc in bm.faces:
            for l in fc.loops: l[uv].uv=(l.vert.co.x/1.18+0.5,l.vert.co.y/1.18+0.5)
        me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(mat)
        ob=bpy.data.objects.new(name,me); col.objects.link(ob); ob.hide_render=True; ob.hide_viewport=True
        ob.location=(0,0,30+var)
    print('PD plates',[ (o.name,len(o.data.polygons)) for o in col.objects])

if want('collision'):
    col=newcol('COL_Collision'); made=[]
    for ob in sorted(list(parts.objects),key=lambda o:o.name):
        name='UCX_%s_01'%ob.name
        if name in bpy.data.objects: continue
        mw=ob.matrix_world; inv=mw.inverted(); b=bmesh.new()
        pts=[v.co.copy() for v in ob.data.vertices]
        if ob.name.startswith('SM_Glass'):                           # тонкое стекло: коробка с запасом толщины
            xs=[p.x for p in pts]; ys=[p.y for p in pts]; zs=[p.z for p in pts]; e=0.04
            bm_pts=[Vector((x,y,z)) for x in (min(xs)-e,max(xs)+e) for y in (min(ys)-e,max(ys)+e) for z in (min(zs)-e,max(zs)+e)]
            for p in bm_pts: b.verts.new(p)
        else:
            for p in pts: b.verts.new(p)
        r=bmesh.ops.convex_hull(b,input=b.verts[:],use_existing_faces=False)
        for g in r['geom_interior']+r['geom_unused']:
            try:
                if isinstance(g,bmesh.types.BMVert): b.verts.remove(g)
            except Exception: pass
        bmesh.ops.dissolve_limit(b,angle_limit=math.radians(10),verts=b.verts[:],edges=b.edges[:])
        me=bpy.data.meshes.new(name); b.to_mesh(me); nv=len(me.vertices); nf=len(me.polygons); b.free()
        o2=bpy.data.objects.new(name,me); col.objects.link(o2); o2.parent=ob.parent; o2.matrix_parent_inverse=ob.matrix_parent_inverse.copy(); o2.matrix_basis=ob.matrix_basis.copy()
        o2.display_type='WIRE'; o2.hide_render=True; made.append((name,nv,nf))
    print('PD collision',len(made),made[:6],'...')
bpy.ops.wm.save_mainfile(); print('SAVED prep',STAGE)
