# Красивые рендеры (Cycles). Запуск: blender -b spaceship_3.blend -P tools/render_beauty.py -- views.json WIDTH SAMPLES OUTDIR [имя_кадра ...]
# Фон: картинка из textures/backgrounds ложится на кадр «как есть» (Window-координаты, режим cover) только для лучей камеры; освещение берёт цвета той же картинки (equirect).
# mode 'int' (изнутри): корпус скрыт, остаётся только стекло (односторонняя тонировка MAT_Glass) - всё видно сквозь окна.
import bpy, sys, os, json, bmesh
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]; views=json.load(open(args[0])); W=int(args[1]); SMP=int(args[2]); OUT=args[3]; only=set(args[4:])
BG=os.path.join(os.path.dirname(bpy.data.filepath),'textures','backgrounds')
sc=bpy.context.scene; H=int(W*9/16)
sc.render.engine='CYCLES'; cy=sc.cycles; cy.samples=SMP; cy.use_denoising=True; cy.device='GPU'; cy.max_bounces=8; cy.transparent_max_bounces=24
try:
    pr=bpy.context.preferences.addons['cycles'].preferences; pr.compute_device_type='METAL'; pr.get_devices()
    for d in pr.devices: d.use=True
except Exception as e: print(e)
sc.render.resolution_x=W; sc.render.resolution_y=H; sc.render.resolution_percentage=100; sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Medium High Contrast'
for o in list(bpy.data.objects):
    if o.type=='CAMERA': bpy.data.objects.remove(o)
hull=bpy.data.objects.get('SM_Spaceship')                      # монолитный корпус (spaceship_3)
body=bpy.data.objects.get('SM_Hull_Body')                      # разделённый корпус (spaceship_4): корпус + детали в COL_Parts
parts_col=bpy.data.collections.get('COL_Parts'); part_objs=list(parts_col.objects) if parts_col else []
hull_like=[o for o in ([hull] if hull else [])+([body] if body else [])+part_objs if o.type=='MESH' and not o.name.startswith('SM_Glass_')]
glass_parts=[o for o in part_objs if o.name.startswith('SM_Glass_')]
file_lights=[o for o in bpy.data.objects if o.type=='LIGHT']
# только стекло корпуса
gl=None
def make_glass():
    me=hull.data.copy(); bm=bmesh.new(); bm.from_mesh(me)
    gi=[i for i,s in enumerate(hull.material_slots) if s.material and s.material.name=='MAT_Glass'][0]
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=gi],context='FACES'); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new('GlassOnly',me); sc.collection.objects.link(o); o.matrix_world=hull.matrix_world.copy(); return o
glass=make_glass() if hull else None
if glass: glass.hide_render=True
cam=bpy.data.objects.new('C',bpy.data.cameras.new('C')); sc.collection.objects.link(cam); sc.camera=cam
def world(bgfile,ox,oy,strength,env):
    w=bpy.data.worlds.new('W'); w.use_nodes=True; nt=w.node_tree; N=nt.nodes; L=nt.links; N.clear()
    out=N.new('ShaderNodeOutputWorld'); mix=N.new('ShaderNodeMixShader'); lp=N.new('ShaderNodeLightPath')
    img=bpy.data.images.load(os.path.join(BG,bgfile),check_existing=True)
    ar=img.size[0]/img.size[1]; rr=W/H
    su,sv=(rr/ar,1.0) if ar>rr else (1.0,ar/rr)
    tc=N.new('ShaderNodeTexCoord'); mp=N.new('ShaderNodeMapping'); mp.vector_type='POINT'
    mp.inputs['Scale'].default_value=(su,sv,1); mp.inputs['Location'].default_value=((1-su)*ox,(1-sv)*oy,0)
    t1=N.new('ShaderNodeTexImage'); t1.image=img; t1.extension='EXTEND'; t1.interpolation='Cubic'
    L.new(tc.outputs['Window'],mp.inputs['Vector']); L.new(mp.outputs[0],t1.inputs['Vector'])
    b1=N.new('ShaderNodeBackground'); b1.inputs['Strength'].default_value=strength; L.new(t1.outputs['Color'],b1.inputs['Color'])
    t2=N.new('ShaderNodeTexEnvironment'); t2.image=img; b2=N.new('ShaderNodeBackground'); b2.inputs['Strength'].default_value=env; L.new(t2.outputs['Color'],b2.inputs['Color'])
    L.new(lp.outputs['Is Camera Ray'],mix.inputs['Fac']); L.new(b2.outputs[0],mix.inputs[1]); L.new(b1.outputs[0],mix.inputs[2]); L.new(mix.outputs[0],out.inputs[0]); return w
def lamp(kind,loc,e,size=2.0,col=(1,0.95,0.88)):
    d=bpy.data.lights.new('L',kind); d.energy=e; d.color=col
    if kind=='AREA': d.size=size
    o=bpy.data.objects.new('L',d); sc.collection.objects.link(o); o.location=loc; return o
for v in views:
    if only and v['name'] not in only: continue
    loc,tgt=Vector(v['loc']),Vector(v['tgt']); ext=v.get('mode','ext')=='ext'
    for o in hull_like+glass_parts: o.hide_render=(not ext) if o in hull_like else False
    if glass: glass.hide_render=ext
    for o in bpy.data.objects:
        if o.type=='MESH': o.hide_render=o.hide_render or any(o.name.startswith(h) for h in v.get('hide',[]))
    for o in file_lights: o.hide_render=not (ext and v.get('hull_lights',True))
    b=v.get('bg',{}); sc.world=world(b.get('file','bg_nebula_purple.jpg'),b.get('ox',0.5),b.get('oy',0.5),b.get('strength',1.0),b.get('env',0.6))
    cam.location=loc; cam.data.lens=v['lens']; cam.data.sensor_width=36
    q=(tgt-loc).to_track_quat('-Z','Y'); cam.rotation_euler=q.to_euler()
    if v.get('roll'): cam.rotation_euler.rotate_axis('Z',v['roll'])
    ls=[]
    if ext:
        s=lamp('SUN',(0,0,100),v.get('sun',3.0),col=v.get('suncol',(1,0.93,0.82))); s.rotation_euler=tuple(v.get('sunrot',(0.9,0.3,-0.9))); s.data.angle=0.02; ls.append(s)
    else:
        a=lamp('AREA',loc+Vector((0,0,0.6)),v.get('fill',500)); a.rotation_euler=(tgt-a.location).to_track_quat('-Z','Y').to_euler(); ls.append(a)
        c=lamp('AREA',tgt+Vector((0,0,0.8))+(loc-tgt).normalized()*1.5,v.get('fill',500)*0.6,2.0,(0.8,0.9,1)); c.rotation_euler=(tgt-c.location).to_track_quat('-Z','Y').to_euler(); ls.append(c)
    sc.render.filepath=os.path.join(OUT,v['name']+'.png'); bpy.ops.render.render(write_still=True)
    for l in ls: bpy.data.objects.remove(l)
