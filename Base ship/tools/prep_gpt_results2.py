# Обработка второй пачки GPT (Downloads/GPT Results 2, копия в textures/interior/gpt_raw/results2):
# диски шлюзов (грузовой A, кают-компании B), паркет и потолок кают, тайлы грузового отсека (клёпаная стена, рифлёный пол).
# Фото-тайлы не бесшовные, поэтому делаем зеркальную раскладку 2x2 (стыки совпадают по построению).
import os, glob, numpy as np
from PIL import Image, ImageDraw
T=os.path.join(os.path.dirname(__file__),'..','textures','interior'); R=os.path.join(T,'gpt_raw','results2'); TL=os.path.join(T,'tiles')
def find(prefix): return glob.glob(os.path.join(R,prefix+'*'))[0]
def circle_disc(im,size=1536):
    a=np.asarray(im.convert('RGB')).max(axis=2); ys,xs=np.where(a>18); x0,x1,y0,y1=xs.min(),xs.max(),ys.min(),ys.max()
    s=max(x1-x0,y1-y0)+1; cx=(x0+x1)/2; cy=(y0+y1)/2
    c=im.convert('RGB').crop((int(cx-s/2),int(cy-s/2),int(cx-s/2)+s,int(cy-s/2)+s)).resize((size,size),Image.LANCZOS).convert('RGBA')
    m=Image.new('L',(size,size),0); ImageDraw.Draw(m).ellipse((0,0,size-1,size-1),fill=255); c.putalpha(m); return c
def mirror2(im):
    w,h=im.size; o=Image.new(im.mode,(2*w,2*h)); o.paste(im,(0,0)); o.paste(im.transpose(Image.FLIP_LEFT_RIGHT),(w,0))
    o.paste(im.transpose(Image.FLIP_TOP_BOTTOM),(0,h)); o.paste(im.transpose(Image.ROTATE_180),(w,h)); return o
def normal_from(im,k=2.0):
    g=np.asarray(im.convert('L'),np.float32)/255; dx=np.roll(g,-1,1)-np.roll(g,1,1); dy=np.roll(g,-1,0)-np.roll(g,1,0)
    n=np.dstack([-dx*k,dy*k,np.ones_like(g)*0.5]); n/=np.linalg.norm(n,axis=2,keepdims=True)
    return Image.fromarray(((n*0.5+0.5)*255).astype(np.uint8))
def rough_from(im,lo=0.45,hi=0.75):
    g=np.asarray(im.convert('L'),np.float32)/255; r=lo+(1-g)*(hi-lo); return Image.fromarray((r*255).astype(np.uint8))
# --- диски
circle_disc(Image.open(find('adecea95-3e52-4a98-b9fa-69765fd00682.png'))).save(os.path.join(T,'airlock_disc_cargo.png'))
sheet=Image.open(find('57d2fcd5')).convert('RGB'); a=np.asarray(sheet).max(axis=2); cols=np.where((a>18).any(axis=0))[0]
gaps=np.where(np.diff(cols)>20)[0]; left=cols[0],cols[gaps[0]]            # первый объект листа = круглый люк
circle_disc(sheet.crop((left[0],0,left[1]+1,sheet.size[1]))).save(os.path.join(T,'airlock_disc_hatch.png'))
# --- каюты: паркет и потолок (2x2 зеркало, 1024)
for key,name in (('bN3J4z','floor_room'),('fly4cl','ceiling_room')):
    im=Image.open(find(key)).convert('RGB'); im=im.crop((0,0,min(im.size),min(im.size))); m=mirror2(im).resize((1024,1024),Image.LANCZOS)
    m.save(os.path.join(TL,name+'_albedo.png')); rough_from(m,0.35 if name=='floor_room' else 0.4,0.6).save(os.path.join(TL,name+'_rough.png')); normal_from(m,1.0 if name=='floor_room' else 0.4).save(os.path.join(TL,name+'_normal.png'))
# --- грузовой отсек: клёпаная стена и рифлёный пол (2048)
w=Image.open(find('ZHMQ4e')).convert('RGB'); wm=mirror2(w); wm.save(os.path.join(TL,'wall_cargo_albedo.png'))
rough_from(wm,0.4,0.7).save(os.path.join(TL,'wall_cargo_rough.png')); normal_from(wm,1.2).save(os.path.join(TL,'wall_cargo_normal.png'))
f=Image.open(find('jC1ttA')).convert('RGB'); f=f.crop((0,0,860,860)); fm=mirror2(f).resize((2048,2048),Image.LANCZOS); fm.save(os.path.join(TL,'floor_cargo_albedo.png'))
rough_from(fm,0.45,0.8).save(os.path.join(TL,'floor_cargo_rough.png')); normal_from(fm,3.0).save(os.path.join(TL,'floor_cargo_normal.png'))
print('ok')
