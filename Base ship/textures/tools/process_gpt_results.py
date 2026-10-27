# Обработка файлов GPT из interior/gpt_raw/results/: двери (разрезать склейку), окна пилотов, большой экран, климат-экран.
import os, numpy as np
from PIL import Image
D=os.path.join(os.path.dirname(__file__),'..','interior'); R=os.path.join(D,'gpt_raw','results')
# --- двери: две двери на белом фоне
im=Image.open(os.path.join(R,'doors_texture.png')).convert('RGB'); a=np.asarray(im).astype(int)
mask=(a.min(axis=2)<235)
cols=mask.sum(axis=0)>20; xs=np.where(cols)[0]
gaps=np.where(np.diff(xs)>30)[0]; split=xs[gaps[0]]+1 if len(gaps) else a.shape[1]//2
def bbox(x0,x1):
    m=mask[:,x0:x1]; ys=np.where(m.sum(axis=1)>10)[0]; xx=np.where(m.sum(axis=0)>10)[0]
    return x0+xx[0],ys[0],x0+xx[-1]+1,ys[-1]+1
bl=bbox(0,split); br=bbox(split,a.shape[1])
print('left',bl,'right',br)
im.crop(bl).resize((1040,1920),Image.LANCZOS).save(os.path.join(D,'door_cabin_albedo.png'))
im.crop(br).resize((1088,1664),Image.LANCZOS).save(os.path.join(D,'door_engine_albedo.png'))
# --- большой экран и климат-экран
Image.open(os.path.join(R,'screen_big.jpeg')).convert('RGB').resize((1920,1080),Image.LANCZOS).save(os.path.join(D,'screen_big.png'))
Image.open(os.path.join(R,'screen_climat.jpeg')).convert('RGB').resize((1024,640),Image.LANCZOS).save(os.path.join(D,'screen_climate.png'))
# --- окна пилотов: 4 ячейки 1024x640 из панелей атласа (прозрачность по яркости)
src=Image.open(os.path.join(R,'hologram_atlas.jpeg')).convert('RGB')
crops={0:(8,25,403,300),     # TARGET ORBITS  -> перед левым креслом
       1:(805,25,1195,285),  # ENGINE CHECKS  -> пилот слева
       2:(407,25,797,420),   # FLIGHT PANEL   -> пилот справа
       3:(805,285,1195,475)} # PRESSURE PANEL -> перед правым креслом
CW,CH=1024,640
atlas=Image.new('RGBA',(CW*2,CH*2),(0,0,0,0))
for k,box in crops.items():
    c=src.crop(box); w,h=c.size; s=min(CW/w,CH/h)
    nw,nh=int(w*s),int(h*s); c=c.resize((nw,nh),Image.LANCZOS)
    arr=np.asarray(c,np.float32)/255; m=arr.max(axis=2)
    al=np.clip((m-0.06)/0.30,0,1)
    cell=np.zeros((CH,CW,4),np.float32); y0=(CH-nh)//2; x0=(CW-nw)//2
    cell[y0:y0+nh,x0:x0+nw,:3]=arr; cell[y0:y0+nh,x0:x0+nw,3]=np.maximum(al,0.35)   # панели остаются слегка заметными
    atlas.paste(Image.fromarray((cell*255).astype(np.uint8)),((k%2)*CW,(k//2)*CH))
atlas.save(os.path.join(D,'holo_atlas_2048x1280.png'))
print('ok')
# --- цилиндрическая голограмма 2560x1024: четыре вертикальные панели (колонки интерфейса) по окружности, прозрачность по яркости
CWc,CHc=640,1024
cols_src=[(8,25,403,650),(407,25,797,650),(805,25,1195,650),(8,25,403,650)]   # левая, центральная, правая, левая ещё раз
col=Image.new('RGBA',(CWc*4,CHc),(0,0,0,0))
for k,box in enumerate(cols_src):
    c=src.crop(box); w,h=c.size; s=min((CWc-40)/w,(CHc-40)/h)
    nw,nh=int(w*s),int(h*s); c=c.resize((nw,nh),Image.LANCZOS)
    arr=np.asarray(c,np.float32)/255; m=arr.max(axis=2); al=np.clip((m-0.06)/0.30,0,1)*0.95
    cell=np.zeros((CHc,CWc,4),np.float32); y0=(CHc-nh)//2; x0=(CWc-nw)//2
    cell[y0:y0+nh,x0:x0+nw,:3]=arr; cell[y0:y0+nh,x0:x0+nw,3]=np.maximum(al,0.12)
    col.paste(Image.fromarray((cell*255).astype(np.uint8)),(k*CWc,0))
col.save(os.path.join(D,'holo_column.png')); print('column ok')
