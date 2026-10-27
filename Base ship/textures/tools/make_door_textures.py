# Заглушки текстур дверей и карты-подсказки для GPT. Лицевая сторона двери: каюты 1,30 x 2,40 м, машинное отделение 1,70 x 2,60 м.
import os
from PIL import Image, ImageDraw, ImageFont
OUT=os.path.join(os.path.dirname(__file__),'..','interior'); os.makedirs(OUT,exist_ok=True)
FONT='/System/Library/Fonts/Menlo.ttc'
def f(s): return ImageFont.truetype(FONT,s)
# размеры (px) и зоны в метрах от левого верхнего угла листа, как его видит человек в коридоре
SPECS={
 'cabin':dict(size=(1040,1920),m=(1.30,2.40),
   zones=[('WINDOW',0.40,0.35,0.50,0.50),('HANDLE',0.10,1.20,0.20,0.40),('NUMBER PLATE',0.45,0.95,0.40,0.15),('STATUS PANEL',0.10,0.35,0.20,0.40),('KICK STRIP (hazard)',0.0,2.10,1.30,0.30)]),
 'engine':dict(size=(1088,1664),m=(1.70,2.60),
   zones=[('WINDOW',0.55,0.40,0.60,0.45),('HANDLE',0.12,1.25,0.25,0.45),('WARNING PLATE',0.55,1.05,0.60,0.20),('STATUS PANEL',0.12,0.40,0.25,0.40),('KICK STRIP (hazard)',0.0,2.30,1.70,0.30)]),
}
for name,s in SPECS.items():
    W,H=s['size']; mw,mh=s['m']; px=W/mw
    # заглушка
    im=Image.new('RGB',(W,H),(74,84,96)); d=ImageDraw.Draw(im)
    d.rectangle((20,20,W-20,H-20),outline=(52,60,70),width=10)
    for zn,x,y,w,h in s['zones']:
        a=(x*px,y*px,(x+w)*px,(y+h)*px)
        if zn=='WINDOW': d.rounded_rectangle(a,20,fill=(120,160,190),outline=(40,46,54),width=12)
        elif zn=='HANDLE': d.rounded_rectangle(a,30,fill=(40,44,50),outline=(110,116,124),width=6)
        elif zn.startswith('KICK'):
            n=int((a[2]-a[0])/70)
            for i in range(n):
                d.polygon([(a[0]+i*70,a[3]),(a[0]+i*70+35,a[3]),(a[0]+i*70+70,a[1]),(a[0]+i*70+35,a[1])],fill=(230,190,40) if i%2==0 else (30,30,30))
        elif zn=='STATUS PANEL': d.rounded_rectangle(a,12,fill=(36,40,46),outline=(100,106,114),width=4); d.ellipse((a[0]+20,a[1]+20,a[0]+60,a[1]+60),fill=(200,60,50))
        else: d.rounded_rectangle(a,10,fill=(200,204,208),outline=(60,64,70),width=4)
    im.save(os.path.join(OUT,f'door_{name}_albedo_placeholder.png'))
    # карта-подсказка для GPT
    g=Image.new('RGB',(W,H),(0,0,0)); dg=ImageDraw.Draw(g)
    dg.rectangle((4,4,W-5,H-5),outline=(255,255,255),width=8)
    for zn,x,y,w,h in s['zones']:
        a=(x*px,y*px,(x+w)*px,(y+h)*px)
        dg.rectangle(a,outline=(255,220,0),width=6); dg.text((a[0]+10,a[1]+10),zn,font=f(30),fill=(255,220,0))
    dg.text((20,H//2),f'door {mw:.2f} x {mh:.2f} m  ({W}x{H})',font=f(34),fill=(120,220,255))
    g.save(os.path.join(OUT,f'door_{name}_layout_guide_{W}x{H}.png'))
print('ok')
