# Разделение SM_Spaceship на части под повреждаемость (работает в spaceship_4.blend, spaceship_3.blend остаётся нетронутым).
# Запуск: blender -b spaceship_4.blend -P tools/split_hull.py -- engines   (этап 1: моторы)
#                                                              -- hull      (этап 2: крылья, прожекторы, стекло, люки)
# Принципы: части сохраняют имена слотов материалов, UV, группы вершин и модификатор Armature; точка вращения (pivot) ставится в место крепления;
# оригинальный меш остаётся скрытым как SM_Spaceship_original (коллекция ARCHIVE).
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix
STAGE=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'engines'
arm=bpy.data.objects['SK_Spaceship']; sc=bpy.context.scene
src=bpy.data.objects.get('SM_Spaceship')
if src is None: raise RuntimeError('нет SM_Spaceship (этап уже выполнен?)')
MATS=[s.material for s in src.material_slots]
# --- архив оригинала
arch=bpy.data.collections.get('ARCHIVE') or bpy.data.collections.new('ARCHIVE')
if arch.name not in sc.collection.children: sc.collection.children.link(arch)
if 'SM_Spaceship_original' not in bpy.data.objects:
    orig=src.copy(); orig.data=src.data.copy(); orig.name='SM_Spaceship_original'; orig.data.name='SM_Spaceship_original_mesh'
    arch.objects.link(orig); orig.hide_render=True; orig.hide_viewport=True
parts=bpy.data.collections.get('COL_Parts') or bpy.data.collections.new('COL_Parts')
if parts.name not in sc.collection.children: sc.collection.children.link(parts)

def islands(bm):
    seen=set(); out=[]
    for f0 in bm.faces:
        if f0.index in seen: continue
        st=[f0]; seen.add(f0.index); fs=[]
        while st:
            f=st.pop(); fs.append(f.index)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen: seen.add(g.index); st.append(g)
        out.append(fs)
    return out
def extract(face_ids, name, pivot):
    """копия части меша SM_Spaceship (по индексам граней) -> новый объект с pivot в точке крепления."""
    me=src.data.copy(); bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    keep=set(face_ids); bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    used=sorted({f.material_index for f in bm.faces}); mp={m:i for i,m in enumerate(used)}
    for f in bm.faces: f.material_index=mp[f.material_index]
    pl=src.matrix_world.inverted()@pivot          # pivot задан в мировых координатах, меш хранится в локальных
    bmesh.ops.translate(bm,verts=bm.verts,vec=-pl)
    me.materials.clear()                           # ВАЖНО: слоты задаём до bm.to_mesh, иначе clear() обнуляет material_index
    for m in used: me.materials.append(MATS[m])
    bm.to_mesh(me); bm.free()
    me.name=name; ob=bpy.data.objects.new(name,me); parts.objects.link(ob)
    ob.parent=arm; ob.matrix_parent_inverse=src.matrix_parent_inverse.copy(); ob.matrix_basis=src.matrix_basis@Matrix.Translation(pl)
    md=ob.modifiers.new('Armature','ARMATURE'); md.object=arm
    for vg in src.vertex_groups: ob.vertex_groups.new(name=vg.name)
    return ob
def decimate_obj_mesh(ob,ratio):
    tmp=bpy.data.objects.new('tmp',ob.data.copy()); sc.collection.objects.link(tmp)
    md=tmp.modifiers.new('d','DECIMATE'); md.ratio=ratio; md.use_collapse_triangulate=False
    dg=bpy.context.evaluated_depsgraph_get(); ev=tmp.evaluated_get(dg); nm=bpy.data.meshes.new_from_object(ev)
    bpy.data.objects.remove(tmp,do_unlink=True)
    from mathutils.bvhtree import BVHTree
    b0=bmesh.new(); b0.from_mesh(ob.data); bvh=BVHTree.FromBMesh(b0); b1=bmesh.new(); b1.from_mesh(nm)
    for v in b1.verts:
        loc,nrm,idx,dist=bvh.find_nearest(v.co)
        if loc is not None: v.co=loc
    b1.to_mesh(nm); b0.free(); b1.free(); return nm

if STAGE=='engines':
    me=src.data; bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    names=[m.name if m else '' for m in MATS]; mw=src.matrix_world
    isl=islands(bm); info=[]
    for fs in isl:
        mats={names[bm.faces[i].material_index] for i in fs}; vs={v for i in fs for v in bm.faces[i].verts}
        P=[mw@v.co for v in vs]; c=sum(P,Vector())/len(P); info.append((fs,mats,c,len(fs)))
    cores=[x for x in info if 'MAT_Engine_Core' in x[1] and x[3]>1000]
    print('ENG cores',len(cores))
    def label(c):
        x,y,z=c
        if y>10: return 'TakeOff_Front_'+('C' if abs(x)<1 else ('L' if x<0 else 'R'))
        if y>-31 and abs(x)>5 and z<0: 
            k=1 if y>-22 else (2 if y>-27 else 3); return 'TakeOff_Back_%s%d'%('L' if x<0 else 'R',k)
        if abs(x)>15: return 'Shunt_%s_%s'%('Top' if z>0 else 'Bot','L' if x<0 else 'R')
        return 'Traction_'+('Main' if abs(x)<1 else ('L' if x<0 else 'R'))
    anchors=[(label(c[2]),c[2]) for c in cores]
    groups={n:[] for n,_ in anchors}
    ENGM={'MAT_Engines','MAT_Engine_Core','MAT_Engine_Glow'}
    for fs,mats,c,n in info:
        if not mats<=ENGM: continue
        best=min(anchors,key=lambda a:(a[1]-c).length)
        if (best[1]-c).length<6.0: groups[best[0]].append((fs,mats,n))
    RATIO={'TakeOff_Back':0.05,'Traction':0.05,'TakeOff_Front':0.07,'Shunt':0.02}
    moved=set(); report=[]
    for lab,anc in anchors:
        fs_all=[i for fs,_,_ in groups[lab] for i in fs]
        pivot=Vector(anc)
        core_ids=[i for i in fs_all if names[bm.faces[i].material_index]=='MAT_Engine_Core']
        body_ids=[i for i in fs_all if names[bm.faces[i].material_index]!='MAT_Engine_Core']
        body=extract(body_ids,'SM_Engine_'+lab,pivot) if body_ids else None
        core=extract(core_ids,'tmpcore',pivot)
        ratio=RATIO[[k for k in RATIO if lab.startswith(k)][0]]
        nm=decimate_obj_mesh(core,ratio); before=len(core.data.polygons); after=len(nm.polygons)
        # склеить ядро с корпусом мотора в один объект (join): слоты MAT_Engines..., MAT_Engine_Core
        core.data=nm
        if body is None: body=core; body.name='SM_Engine_'+lab
        else:
            bpy.ops.object.select_all(action='DESELECT'); body.select_set(True); core.select_set(True); bpy.context.view_layer.objects.active=body
            bpy.ops.object.join()
        # свечение ядра считается по нормалям (Layer Weight): после прореживания вернуть плавное затенение граням ядра
        ci=[i for i,sl in enumerate(body.material_slots) if sl.material and sl.material.name=='MAT_Engine_Core']
        sh=body.data.attributes.get('sharp_face')
        if sh is not None and ci:
            vals=[False if p.material_index==ci[0] else sh.data[p.index].value for p in body.data.polygons]
            sh.data.foreach_set('value',vals)
        report.append((lab,len(fs_all),before,after,len(body.data.polygons)))
        moved.update(fs_all)
    # убрать моторы из корпуса
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in moved],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(me); bm.free()
    for r in report: print('ENG',r)
    print('ENG hull faces left',len(src.data.polygons),'moved',len(moved))

if STAGE=='hull':
    me=src.data; mw=src.matrix_world; names=[m.name if m else '' for m in MATS]
    bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    C=[mw@f.calc_center_median() for f in bm.faces]
    isl=islands(bm); fm=[names[f.material_index] for f in bm.faces]
    taken={}                       # индекс грани -> имя детали
    # 1) стекло: связные куски граней MAT_Glass
    gl=[i for i in range(len(fm)) if fm[i]=='MAT_Glass']; gset=set(gl); seen=set(); panes=[]
    for i in gl:
        if i in seen: continue
        st=[i]; seen.add(i); comp=[]
        while st:
            a=st.pop(); comp.append(a)
            for e in bm.faces[a].edges:
                for g in e.link_faces:
                    if g.index in gset and g.index not in seen: seen.add(g.index); st.append(g.index)
        panes.append(comp)
    panes.sort(key=lambda c:-sum(C[i].y for i in c)/len(c))
    for k,comp in enumerate(panes,1):
        for i in comp: taken[i]='SM_Glass_%02d'%k
    # 2) люки шлюзов A (y<0) и B (y>0): все грани MAT_Airlock
    for i in range(len(fm)):
        if fm[i]=='MAT_Airlock': taken[i]='SM_Hatch_A' if C[i].y<0 else 'SM_Hatch_B'
    # 3) прожекторы: небольшие острова (<=60 граней) вокруг линз MAT_Lamp_Lens
    small=[fs for fs in isl if len(fs)<=60 and all(i not in taken for i in fs)]
    lens=[fs for fs in small if all(fm[i]=='MAT_Lamp_Lens' for i in fs)]
    def cen(fs): return sum((C[i] for i in fs),Vector())/len(fs)
    lamp_names=[]
    for fs in lens:
        c=cen(fs); x,y,z=c
        nm=('SM_Spotlight_Top_%s'%('L' if x<0 else 'R')) if z>0 else ('SM_Spotlight_Belly_%s%s'%('F' if y>0 else 'R','L' if x<0 else 'R'))
        for g in small:
            if all(fm[i] in ('MAT_Engines','MAT_Lamp_Lens','MAT_LED_Strip') for i in g) and (cen(g)-c).length<2.6:
                for i in g: taken[i]=nm
        lamp_names.append(nm)
    # 4) крылья: заливка от |x|>16 по граням с |x|>12.8
    rest=[i for i in range(len(fm)) if i not in taken]
    wing=set(); st=[i for i in rest if abs(C[i].x)>16]; wing.update(st)
    while st:
        a=st.pop()
        for e in bm.faces[a].edges:
            for g in e.link_faces:
                j=g.index
                if j not in taken and j not in wing and abs(C[j].x)>12.8: wing.add(j); st.append(j)
    for i in wing: taken[i]='SM_Wing_L' if C[i].x<0 else 'SM_Wing_R'
    # (мелкие острова-маркеры у кончиков крыльев ушли бы в корпус: прибавляем острова целиком, если центр |x|>12.8)
    for fs in isl:
        if all(i not in taken for i in fs) and abs(cen(fs).x)>12.8:
            for i in fs: taken[i]='SM_Wing_L' if cen(fs).x<0 else 'SM_Wing_R'
    groups={}
    for i,n in taken.items(): groups.setdefault(n,[]).append(i)
    inside=bpy.data.materials.get('MAT_Hull_Inside') or bpy.data.materials.new('MAT_Hull_Inside')
    inside.use_nodes=True; pb=[n for n in inside.node_tree.nodes if n.type=='BSDF_PRINCIPLED'][0]
    pb.inputs['Base Color'].default_value=(0.07,0.06,0.055,1); pb.inputs['Metallic'].default_value=0.6; pb.inputs['Roughness'].default_value=0.7
    def cap_open(ob,xmin=None):
        me2=ob.data; b=bmesh.new(); b.from_mesh(me2); b.edges.ensure_lookup_table()
        edges=[e for e in b.edges if len(e.link_faces)==1 and (xmin is None or all(abs((ob.matrix_world@v.co).x)>=xmin for v in e.verts))]
        if not edges: b.free(); return 0
        me2.materials.append(inside); idx=len(me2.materials)-1
        r=bmesh.ops.holes_fill(b,edges=edges,sides=64)
        for f in r['faces']: f.material_index=idx
        bmesh.ops.recalc_face_normals(b,faces=list(b.faces)); b.to_mesh(me2); b.free(); return len(r['faces'])
    report=[]
    for n,ids in sorted(groups.items()):
        c=sum((C[i] for i in ids),Vector())/len(ids)
        ob=extract(ids,n,c); k=0
        if n.startswith('SM_Wing'): k=cap_open(ob)
        report.append((n,len(ids),tuple(round(v,1) for v in c),k))
    # корпус: оставшееся, с заглушками только у корней крыльев
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in taken],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(me); bm.free(); src.name='SM_Hull_Body'; me.name='SM_Hull_Body'
    kk=cap_open(src,xmin=12.3)
    for r in report: print('HUL',r)
    print('HUL hull body faces',len(src.data.polygons),'cap faces at wing roots',kk,'parts',len(groups))

bpy.ops.wm.save_mainfile()
print('SAVED',STAGE)
