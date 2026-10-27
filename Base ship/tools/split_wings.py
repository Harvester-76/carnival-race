# Разделение крыльев на верхнее и нижнее: SM_Wing_L/R -> SM_Wing_Top_L/R + SM_Wing_Bot_L/R (по знаку Z центра грани), у каждой части своя UCX-коллизия (выпуклая оболочка).
# Вызывается из export_godot.py после fix_wing_l(); .blend не сохраняется.
import bpy, bmesh
def split_wings():
    col_ucx=bpy.data.collections['COL_Collision']
    for side in ('L','R'):
        o=bpy.data.objects.get('SM_Wing_'+side)
        if o is None: continue
        mw=o.matrix_world.copy()
        for part,sign in (('Top',1.0),('Bot',-1.0)):
            n=o.copy(); n.data=o.data.copy(); n.name='SM_Wing_%s_%s'%(part,side); n.data.name=n.name
            for c in o.users_collection: c.objects.link(n)
            bm=bmesh.new(); bm.from_mesh(n.data)
            kill=[f for f in bm.faces if sign*(mw@f.calc_center_median()).z<0.0]
            bmesh.ops.delete(bm,geom=kill,context='FACES')
            loose=[v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm,geom=loose,context='VERTS')
            bm.to_mesh(n.data)
            hull=bmesh.new(); hull.from_mesh(n.data)
            bmesh.ops.convex_hull(hull,input=hull.verts[:])
            hm=bpy.data.meshes.new('UCX_'+n.name+'_01'); hull.to_mesh(hm); hull.free(); bm.free()
            u=bpy.data.objects.new('UCX_'+n.name+'_01',hm); u.matrix_world=mw; col_ucx.objects.link(u)
        old=bpy.data.objects.get('UCX_SM_Wing_%s_01'%side)
        if old: bpy.data.objects.remove(old,do_unlink=True)
        bpy.data.objects.remove(o,do_unlink=True)
