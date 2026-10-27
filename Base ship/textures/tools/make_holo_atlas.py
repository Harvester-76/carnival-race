# Собирает атлас голо-окон 2048x1280 (4 ячейки 1024x640) из картинок GPT в interior/gpt_raw/.
# Тёмный фон превращается в прозрачность (альфа по яркости), названия с чужими брендами замазываются.
import os, numpy as np
from PIL import Image
D=os.path.join(os.path.dirname(__file__),'..','interior'); R=os.path.join(D,'gpt_raw')
CW,CH=1024,640
# ячейка атласа -> (файл, прямоугольники для замазывания в долях 0..1: x0,y0,x1,y1)
CELLS={0:('holo_raw_1.jpeg',[]),
       1:('holo_raw_3.jpeg',[(0,0,0.27,0.07),(0.82,0.01,1,0.07)]),
       2:('holo_raw_2.jpeg',[(0.03,0.04,0.25,0.15)]),
       3:('holo_raw_4.jpeg',[])}
atlas=Image.new('RGBA',(CW*2,CH*2),(0,0,0,0))
for k,(fn,masks) in CELLS.items():
    im=Image.open(os.path.join(R,fn)).convert('RGB')
    w,h=im.size; tw=int(h*CW/CH)                      # обрезка до 16:10 по бокам
    x0=(w-tw)//2; 
    a=np.asarray(im,np.float32)/255
    for (mx0,my0,mx1,my1) in masks:
        a[int(my0*h):int(my1*h),int(mx0*w):int(mx1*w)]=0
    im=Image.fromarray((a*255).astype(np.uint8)).crop((x0,0,x0+tw,h)).resize((CW,CH),Image.LANCZOS)
    a=np.asarray(im,np.float32)/255
    m=a.max(axis=2)
    al=np.clip((m-0.12)/0.45,0,1)**0.8
    rgba=np.dstack([a,al]); 
    atlas.paste(Image.fromarray((rgba*255).astype(np.uint8),'RGBA'),((k%2)*CW,(k//2)*CH))
atlas.save(os.path.join(D,'holo_atlas_2048x1280.png')); print('ok')
