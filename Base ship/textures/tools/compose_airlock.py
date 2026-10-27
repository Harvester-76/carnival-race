# Атлас шлюзов UV_Airlock 2048x2048. Диски (внешние люки): A - большой (кормовой грузовой, 9 м), B - люк кают-компании (4,4 м).
# Без аргументов: рисует заглушки. С файлами GPT (interior/airlock_disc_cargo.png, airlock_disc_hatch.png, квадрат, диск вписан до краёв)
# вклеивает их в атлас по кругам. Круги в UV измерены по модели (r_внутр - плоский диск, r_внеш - кольцо-фланец).
import os, math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
D=os.path.join(os.path.dirname(__file__),'..','interior'); W=2048
DISCS={'A':dict(center=(0.7529,0.2186),r_out=0.210,r_in=0.170,file='airlock_disc_cargo.png',kind='cargo',rot=90),   # rot: градусы против часовой, по ориентации UV на корпусе
       'B':dict(center=(0.2688,0.2697),r_out=0.203,r_in=0.158,file='airlock_disc_hatch.png',kind='hatch',rot=180)}
def px(u,v): return u*W,(1-v)*W
def placeholder_disc(size,kind,r_ratio):
    S=size; im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im); c=S/2
    d.ellipse((0,0,S,S),fill=(58,66,76,255))
    ri=S/2*r_ratio
    # кольцо: полосы опасности
    n=48
    for i in range(n):
        a0=i*360/n; col=(225,185,40,255) if i%2==0 else (28,28,30,255)
        d.pieslice((S*0.0,S*0.0,S,S),a0,a0+360/n,fill=col)
    d.ellipse((c-ri*1.0-S*0.0,c-ri,c+ri,c+ri),fill=(74,84,96,255))
    d.ellipse((c-ri*0.97,c-ri*0.97,c+ri*0.97,c+ri*0.97),outline=(40,46,54,255),width=max(3,S//120))
    segs=12 if kind=='cargo' else 8
    for i in range(segs):
        a=i*2*math.pi/segs; d.line((c+ri*0.2*math.cos(a),c+ri*0.2*math.sin(a),c+ri*0.95*math.cos(a),c+ri*0.95*math.sin(a)),fill=(36,42,50,255),width=max(3,S//160))
    for rr in (0.2,0.55,0.8):
        d.ellipse((c-ri*rr,c-ri*rr,c+ri*rr,c+ri*rr),outline=(36,42,50,255),width=max(3,S//160))
    d.ellipse((c-ri*0.12,c-ri*0.12,c+ri*0.12,c+ri*0.12),fill=(150,156,164,255),outline=(30,34,40,255),width=max(3,S//120))
    # прямоугольный проход (дверь) и индикаторы
    dw,dh=ri*0.62,ri*1.0
    d.rounded_rectangle((c-dw/2,c-dh/2+ri*0.05,c+dw/2,c+dh/2+ri*0.05),ri*0.04,outline=(20,24,28,255),width=max(4,S//90))
    d.ellipse((c-ri*0.55,c-ri*0.05,c-ri*0.47,c+ri*0.03),fill=(200,60,50,255)); d.ellipse((c-ri*0.55,c+ri*0.10,c-ri*0.47,c+ri*0.18),fill=(60,190,90,255))
    mask=Image.new('L',(S,S),0); ImageDraw.Draw(mask).ellipse((0,0,S,S),fill=255); im.putalpha(mask)
    return im
def main():
    atlas=Image.new('RGBA',(W,W),(84,90,98,255)); d=ImageDraw.Draw(atlas)
    d.rectangle((0,0,W,int(W*0.16)),fill=(120,126,134,255))             # полоса болтов/мелких деталей (v > 0.84)
    for key,s in DISCS.items():
        S=int(2*s['r_out']*W); f=os.path.join(D,s['file'])
        if os.path.exists(f): disc=Image.open(f).convert('RGBA').resize((S,S),Image.LANCZOS)
        else: disc=placeholder_disc(S,s['kind'],s['r_in']/s['r_out'])
        disc=disc.rotate(s.get('rot',0))
        x,y=px(*s['center']); atlas.alpha_composite(disc,(int(x-S/2),int(y-S/2)))
    atlas.convert('RGB').save(os.path.join(D,'airlock_atlas_2048.png'))
    # карта-подсказка для GPT (каждый диск отдельно)
    for key,s in DISCS.items():
        G=1536; g=Image.new('RGB',(G,G),(0,0,0)); dg=ImageDraw.Draw(g); c=G/2
        dg.ellipse((2,2,G-2,G-2),outline=(255,255,255),width=6)
        r=G/2*s['r_in']/s['r_out']; dg.ellipse((c-r,c-r,c+r,c+r),outline=(255,220,0),width=6)
        dg.text((c-300,40),f"outer ring zone (100% - {int(100*s['r_in']/s['r_out'])}% radius)",fill=(255,255,255))
        dg.text((c-250,c-10),f"inner hatch disc ({int(100*s['r_in']/s['r_out'])}% radius)",fill=(255,220,0))
        g.save(os.path.join(D,f"airlock_disc_{s['kind']}_guide_1536.png"))
    print('ok')
main()
# --- внутренняя дверь шлюза кают-компании (лист 3,96 x 2,98 м = 4:3), заглушка и карта-подсказка
def inner_door():
    Wd,Hd=1536,1152; im=Image.new('RGB',(Wd,Hd),(78,86,96)); d=ImageDraw.Draw(im)
    d.rectangle((16,16,Wd-17,Hd-17),outline=(40,46,54),width=14)
    d.rounded_rectangle((Wd*0.30,Hd*0.12,Wd*0.70,Hd*0.50),30,fill=(110,150,180),outline=(30,34,40),width=16)      # окно
    d.ellipse((Wd*0.80,Hd*0.40,Wd*0.92,Hd*0.40+Wd*0.12),fill=(150,156,164),outline=(30,34,40),width=10)            # колесо/ручка
    d.rounded_rectangle((Wd*0.06,Hd*0.12,Wd*0.16,Hd*0.34),14,fill=(36,40,46)); d.ellipse((Wd*0.085,Hd*0.15,Wd*0.135,Hd*0.15+Wd*0.05),fill=(200,60,50)); d.ellipse((Wd*0.085,Hd*0.24,Wd*0.135,Hd*0.24+Wd*0.05),fill=(60,190,90))
    n=24
    for i in range(n):
        x0=Wd*0.04+i*(Wd*0.92/n); d.polygon([(x0,Hd*0.94),(x0+Wd*0.92/n*0.5,Hd*0.94),(x0+Wd*0.92/n*0.5+30,Hd*0.86),(x0+30,Hd*0.86)],fill=(225,185,40) if i%2==0 else (28,28,30))
    im.save(os.path.join(D,'airlock_inner_door_placeholder_1536x1152.png'))
    g=Image.new('RGB',(Wd,Hd),(0,0,0)); dg=ImageDraw.Draw(g); dg.rectangle((4,4,Wd-5,Hd-5),outline=(255,255,255),width=8)
    for nm,(x0,y0,x1,y1) in {'WINDOW':(0.30,0.12,0.70,0.50),'WHEEL HANDLE':(0.80,0.40,0.92,0.52),'STATUS LIGHTS':(0.06,0.12,0.16,0.34),'HAZARD STRIP':(0.04,0.86,0.96,0.94)}.items():
        dg.rectangle((x0*Wd,y0*Hd,x1*Wd,y1*Hd),outline=(255,220,0),width=6); dg.text((x0*Wd+10,y0*Hd+10),nm,fill=(255,220,0))
    dg.text((20,Hd//2),'inner airlock door leaf 3.96 x 2.98 m (1536x1152)',fill=(120,220,255)); g.save(os.path.join(D,'airlock_inner_door_layout_guide_1536x1152.png'))
inner_door()
