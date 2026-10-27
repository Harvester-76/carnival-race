# Мини-библиотека скруглённых деталей для мебели (bmesh). Подключать exec(open(...).read()).
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

SHARP=math.radians(38)

class Furn:
    """Копит геометрию в один bmesh; каждая деталь строится во временном bmesh (скругление) и добавляется целиком."""
    def __init__(s,mesh,slot_names):
        s.me=mesh; s.bm=bmesh.new(); s.names=slot_names; s.tri=0
    def mi(s,name):
        if name not in s.names: s.names.append(name)
        return s.names.index(name)
    def _add(s,t,m,smooth=True):
        for f in t.faces: f.material_index=s.mi(m); f.smooth=smooth
        if smooth:
            for e in t.edges:
                if len(e.link_faces)==2 and e.calc_face_angle(0)>SHARP: e.smooth=False
        tm=bpy.data.meshes.new('_t')
        for _ in range(len(s.names)): tm.materials.append(None)   # иначе Blender обнуляет индексы материалов
        t.to_mesh(tm); t.free()
        s.bm.from_mesh(tm); bpy.data.meshes.remove(tm)
    def rbox(s,c,size,r=0.03,rot=(0,0,0),m='Steel',seg=3,smooth=True):
        t=bmesh.new(); bmesh.ops.create_cube(t,size=1.0)
        for v in t.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
        r=min(r,min(size)*0.48)
        if r>0.002: bmesh.ops.bevel(t,geom=list(t.edges),offset=r,offset_type='OFFSET',segments=seg,profile=0.5,affect='EDGES')
        M=Matrix.Translation(c)@Euler(rot,'XYZ').to_matrix().to_4x4()
        bmesh.ops.transform(t,matrix=M,verts=t.verts); s._add(t,m,smooth)
    def cyl(s,c,r,h,m='Steel',r2=None,seg=20,rot=(0,0,0),bev=0.0):
        t=bmesh.new(); bmesh.ops.create_cone(t,cap_ends=True,cap_tris=False,segments=seg,radius1=r,radius2=(r if r2 is None else r2),depth=h)
        if bev>0.002:
            es=[e for e in t.edges if len(e.link_faces)==2 and all(abs(v.co.z)>h/2-1e-4 for v in e.verts)]
            bmesh.ops.bevel(t,geom=es,offset=min(bev,r*0.9,h*0.45),offset_type='OFFSET',segments=2,profile=0.5,affect='EDGES')
        M=Matrix.Translation(c)@Euler(rot,'XYZ').to_matrix().to_4x4()
        bmesh.ops.transform(t,matrix=M,verts=t.verts); s._add(t,m)
    def sph(s,c,r,m='Steel',sc=(1,1,1),seg=14):
        t=bmesh.new(); bmesh.ops.create_uvsphere(t,u_segments=seg,v_segments=max(6,seg//2),radius=r)
        for v in t.verts: v.co=Vector((v.co.x*sc[0],v.co.y*sc[1],v.co.z*sc[2]))
        bmesh.ops.transform(t,matrix=Matrix.Translation(c),verts=t.verts); s._add(t,m)
    def write(s):
        s.me.materials.clear()
        for n in s.names:
            s.me.materials.append(bpy.data.materials.get(n))
        s.bm.to_mesh(s.me); s.me.update(); s.bm.free()
        return s.names

def get_mat(name,color,rough=0.5,metal=0.0,emit=None,st=0.0):
    m=bpy.data.materials.get(name)
    if m: return m
    m=bpy.data.materials.new(name); m.use_nodes=True
    b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=color; b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
    if emit is not None: b.inputs['Emission Color'].default_value=emit; b.inputs['Emission Strength'].default_value=st
    return m
