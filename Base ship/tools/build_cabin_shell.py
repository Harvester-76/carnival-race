# Cabin shell (floor, walls, ceiling) + glass trim (sill/jamb), rear wall has an opening for the corridor.
import bpy, bmesh, mathutils, numpy as np
for n in ('SM_Cabin_Shell','SM_Cabin_Trim'):
    ob=bpy.data.objects.get(n)
    if ob: m=ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(m)
o=bpy.data.objects['SM_Spaceship']; arm=bpy.data.objects['SK_Spaceship']
mw=o.matrix_world; inv=mw.inverted(); me0=o.data
CORR_HW=1.4; CORR_TOP=0.70; CEIL=0.84; LOUNGE_RISE=0.20; STEP_Y=26.0
def ray(orig,d,skip=(1,7,8),maxn=6):
    p=mathutils.Vector(orig); dv=mathutils.Vector(d).normalized()
    for _ in range(maxn):
        ok,loc,nrm,idx=o.ray_cast(inv@p,(inv.to_3x3()@dv).normalized())
        if not ok: return None
        w=mw@loc
        if me0.polygons[idx].material_index in skip: p=w+dv*0.02; continue
        return w
    return None
zf=-2.31
def fl(y): return zf+LOUNGE_RISE if y<=STEP_Y+0.001 else zf
ys=[18+0.5*i for i in range(14)]+[24.6,25.0,25.5,26.0,26.02,26.5,26.9]+[27.5+0.5*i for i in range(11)]+[33.0]
def inner_w(y):
    zs=np.linspace(zf+0.3,1.0,8); ws=[]
    for z in zs:
        s=4.0 if y<29 else 2.0
        for sg in (-1,1):
            r=ray((sg*s,y,z),(sg,0,0))
            if r: ws.append(abs(r.x))
    return min(ws) if ws else None
W=[inner_w(y) for y in ys]
for i,w in enumerate(W):
    if w is None: W[i]=W[i-1]
W=[w-0.34 for w in W]
GP=np.array([(24.81,6.84,-0.70),(29.37,6.09,-1.72),(32.91,5.28,-2.72)])
def glass_edge(y): return (float(np.interp(y,GP[:,0],GP[:,1])), float(np.interp(y,GP[:,0],GP[:,2])))
def wall_top(y):
    if y<=24.5: return CEIL
    return max(glass_edge(y)[1]-0.03 if y<=32.91 else -9, zf+0.3)
bm=bmesh.new(); rows=[]
for y,w in zip(ys,W):
    wt=wall_top(y); has=y<=26.9
    rows.append(dict(y=y,w=w,LB=bm.verts.new((-w,y,fl(y))),RB=bm.verts.new((w,y,fl(y))),RT=bm.verts.new((w,y,wt)),LT=bm.verts.new((-w,y,wt)),
        RC=bm.verts.new((w,y,CEIL)) if has else None,LC=bm.verts.new((-w,y,CEIL)) if has else None))
def quad(a,b,c,d,mat): bm.faces.new((a,b,c,d)).material_index=mat
for A,B in zip(rows[:-1],rows[1:]):
    quad(A['LB'],A['RB'],B['RB'],B['LB'],0)
    quad(A['RB'],A['RT'],B['RT'],B['RB'],1); quad(A['LT'],A['LB'],B['LB'],B['LT'],1)
    if A['RC'] is not None and B['RC'] is not None: quad(A['RC'],A['LC'],B['LC'],B['RC'],2)
r0=rows[0]; r1=rows[-1]; w0=r0['w']; y0=r0['y']; h=CORR_HW
V=lambda x,z: bm.verts.new((x,y0,z))
zr=fl(y0)
# rear wall with an opening for the corridor
quad(r0['LB'],V(-h,zr),V(-h,CEIL),r0['LC'],1)
quad(V(h,zr),r0['RB'],r0['RC'],V(h,CEIL),1)
quad(V(-h,CORR_TOP),V(h,CORR_TOP),V(h,CEIL),V(-h,CEIL),1)
quad(r1['LB'],r1['RB'],r1['RT'],r1['LT'],1)
bm.normal_update(); cen=mathutils.Vector((0,26,-1))
for f in bm.faces:
    if (f.calc_center_median()-cen).dot(f.normal)>0: f.normal_flip()
mesh=bpy.data.meshes.new('SM_Cabin_Shell'); bm.to_mesh(mesh); bm.free()
ob=bpy.data.objects.new('SM_Cabin_Shell',mesh); bpy.data.collections['COL_Interior'].objects.link(ob)
for n in ('MAT_Cabin_Floor','MAT_Cabin_Wall','MAT_Cabin_Ceiling'): mesh.materials.append(bpy.data.materials[n])
mod=ob.modifiers.new('Solid','SOLIDIFY'); mod.thickness=0.22; mod.offset=-1
bpy.context.view_layer.objects.active=ob; bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
bpy.ops.object.modifier_apply(modifier='Solid')
ob.parent=arm; ob.matrix_parent_inverse=arm.matrix_world.inverted()
bm=bmesh.new()
def q(a,b,c,d):
    f=bm.faces.new([bm.verts.new(p) for p in (a,b,c,d)]); f.material_index=0
pairs=list(zip(ys,W))
for sg in (1,-1):
    for (ya,wa),(yb,wb) in zip(pairs[14:],pairs[15:]):
        if ya<24.59 or yb>33.05: continue
        xg0,zg0=glass_edge(min(ya,32.91)); xg1,zg1=glass_edge(min(yb,32.91)); xg0+=0.03; xg1+=0.03; z0=zg0; z1=zg1
        ta=wall_top(ya); tb=wall_top(yb)               # inner edge at the wall top, outer edge at the glass bottom edge
        q((sg*wa,ya,ta),(sg*xg0,ya,min(z0,ta)),(sg*xg1,yb,min(z1,tb)),(sg*wb,yb,tb))
        q((sg*xg0,ya,min(z0,ta)),(sg*xg0,ya,min(z0,ta)-0.4),(sg*xg1,yb,min(z1,tb)-0.4),(sg*xg1,yb,min(z1,tb)))
        q((sg*xg0,ya,min(z0,ta)-0.4),(sg*wa,ya,ta-0.4),(sg*wb,yb,tb-0.4),(sg*xg1,yb,min(z1,tb)-0.4))
    wI=W[13]
    q((sg*6.6,24.46,1.05),(sg*6.84,24.81,-0.70),(sg*wI,24.6,-0.73),(sg*wI,24.5,CEIL))
# corner wedge between the sill ramp end (y=33), the front plate side and the glass corner: closes the triangular pocket
for sg in (1,-1):
    wq=W[-1]
    q((sg*4.60,33.0,-2.0),(sg*wq,33.0,wall_top(33.0)),(sg*(glass_edge(32.91)[0]+0.03),33.0,glass_edge(32.91)[1]),(sg*4.74,33.91,-2.33))
bm.normal_update()
for f in bm.faces:
    if f.normal.z<0 and abs(f.normal.z)>0.3 and f.calc_center_median().y>32.9: f.normal_flip()
bm.normal_update(); cen=mathutils.Vector((0,28,-1.5))
for f in bm.faces:
    if (f.calc_center_median()-cen).dot(f.normal)<0: f.normal_flip()
tm=bpy.data.meshes.new('SM_Cabin_Trim'); bm.to_mesh(tm); bm.free()
tr=bpy.data.objects.new('SM_Cabin_Trim',tm); bpy.data.collections['COL_Interior'].objects.link(tr); tm.materials.append(bpy.data.materials['MAT_Cabin_Wall'])
tr.parent=arm; tr.matrix_parent_inverse=arm.matrix_world.inverted()
print('shell',len(mesh.polygons),'trim',len(tm.polygons))

# ceiling extension y 26.9..28.8 following the underside of the roof strip (closes the exposed hull skin above the top glass edge)
ce=bpy.data.objects.get('SM_Cabin_CeilExt')
if ce: m=ce.data; bpy.data.objects.remove(ce); bpy.data.meshes.remove(m)
bm=bmesh.new(); ystn=[26.9+0.3*i for i in range(7)]   # 26.9 .. 28.7
ystn.append(28.9)
def wfun(y): return float(np.interp(y,ys,W))
def zce(y): return 0.84-(y-26.9)*(0.84-0.36)/2.0
GT=np.array([(24.46,6.6),(26.88,6.07),(29.37,5.67)])
def xgt(y): return float(np.interp(y,GT[:,0],GT[:,1]))-0.08-0.30*max(0.0,(y-27.0)/1.9)
# the extension only lies under the opaque roof strip: its far edge follows the boundary of the top glass (V shape), so nothing shows through the glass
def y_lim(x):
    x=abs(x)
    return (28.74-(x/3.15)*0.39 if x<=3.15 else 28.35-(x-3.15)*0.503)-0.05
xw=xgt(26.9); xs=np.linspace(-xw,xw,int(2*xw/0.4)+1)
def pv(x,y): return bm.verts.new((x,y,zce(y)))
for xa,xb in zip(xs[:-1],xs[1:]):
    ya,yb=y_lim(xa),y_lim(xb)
    bm.faces.new((pv(xa,26.9),pv(xb,26.9),pv(xb,yb),pv(xa,ya))).material_index=0
# side skirts of the flat ceiling (y 24.5..26.9): from the wall edge to the glass top edge
sk=[24.5,25.0,25.5,26.0,26.5,26.9]
for sg in (1,-1):
    pts=[(bm.verts.new((sg*wfun(y)-sg*0.02,y,CEIL)),bm.verts.new((sg*xgt(y),y,CEIL))) for y in sk]
    for (a0,a1),(b0,b1) in zip(pts[:-1],pts[1:]): bm.faces.new((a0,a1,b1,b0)).material_index=0
bm.normal_update()
for f in bm.faces:
    if f.normal.z>0: f.normal_flip()
me2=bpy.data.meshes.new('SM_Cabin_CeilExt'); bm.to_mesh(me2); bm.free(); me2.materials.append(bpy.data.materials['MAT_Cabin_Ceiling'])
ce=bpy.data.objects.new('SM_Cabin_CeilExt',me2); bpy.data.collections['COL_Interior'].objects.link(ce)
md=ce.modifiers.new('Solid','SOLIDIFY'); md.thickness=0.08; md.offset=-1
bpy.context.view_layer.objects.active=ce; bpy.ops.object.select_all(action='DESELECT'); ce.select_set(True); bpy.ops.object.modifier_apply(modifier='Solid')
ce.parent=arm; ce.matrix_parent_inverse=arm.matrix_world.inverted()
print('ceil ext',len(me2.polygons))
