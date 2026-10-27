# Левое крыло: часть граней смотрит наизнанку относительно правого (зеркала). Переворачиваем их по правому крылу.
# Вызывается из export_godot.py (в самом .blend не сохраняется, пока вы не попросите).
import bpy, bmesh
from mathutils import Vector
from mathutils.kdtree import KDTree
def fix_wing_l():
    L=bpy.data.objects['SM_Wing_L']; R=bpy.data.objects['SM_Wing_R']
    fr=[(R.matrix_world@p.center,(R.matrix_world.to_3x3()@p.normal).normalized()) for p in R.data.polygons]
    kd=KDTree(len(fr))
    for i,(c,n) in enumerate(fr): kd.insert(c,i)
    kd.balance()
    bad=[]
    for p in L.data.polygons:
        c=L.matrix_world@p.center; n=(L.matrix_world.to_3x3()@p.normal).normalized()
        co,i,d=kd.find(Vector((-c.x,c.y,c.z)))
        if d<0.02 and fr[i][1].dot(Vector((-n.x,n.y,n.z)))<0.0: bad.append(p.index)
    bm=bmesh.new(); bm.from_mesh(L.data); bm.faces.ensure_lookup_table()
    import os
    if not os.environ.get('NOFLIP'): bmesh.ops.reverse_faces(bm,faces=[bm.faces[i] for i in bad])
    bm.to_mesh(L.data); bm.free(); L.data.update()
    # UV левого крыла = UV правого (зеркально совпадающие углы граней), иначе на верхней грани нет полос корпусной текстуры
    ul=L.data.uv_layers['UVMap'].data; ur=R.data.uv_layers['UVMap'].data
    vkd=KDTree(len(R.data.vertices))
    for v in R.data.vertices: vkd.insert(R.matrix_world@v.co,v.index)
    vkd.balance()
    fk=KDTree(len(R.data.polygons))
    for p in R.data.polygons: fk.insert(R.matrix_world@p.center,p.index)
    fk.balance(); nuv=0
    for p in L.data.polygons:
        c=L.matrix_world@p.center; co,fi,d=fk.find(Vector((-c.x,c.y,c.z)))
        if d>0.02: continue
        q=R.data.polygons[fi]
        if len(q.loop_indices)!=len(p.loop_indices): continue
        for lk in p.loop_indices:
            w=L.matrix_world@L.data.vertices[L.data.loops[lk].vertex_index].co
            best=min(q.loop_indices,key=lambda rk:(R.matrix_world@R.data.vertices[R.data.loops[rk].vertex_index].co-Vector((-w.x,w.y,w.z))).length)
            ul[lk].uv=ur[best].uv; nuv+=1
    print('WING_L uv copied',nuv)
    print('WING_L flipped',len(bad),'of',len(L.data.polygons)); return len(bad)
if __name__=='__main__': fix_wing_l()
