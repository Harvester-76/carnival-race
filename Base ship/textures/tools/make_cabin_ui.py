# Клавиатуры пультов и голо-окна рубки: раскладка и заглушки текстур.
# Геометрия клавиатур (Blender, build_cabin_keyboards.py) берёт ТЕ ЖЕ числа: 16 колонок x 6 рядов, шаг 0.042 м, плата 0.69 x 0.276 м.
import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT=os.path.join(os.path.dirname(__file__),'..','interior')
os.makedirs(OUT,exist_ok=True)
W,H=2560,1024            # px; плата 0.69 (x) x 0.276 (y) м -> 3710 px/м
PW,PD=0.69,0.276
PX=W/PW; PITCH=0.042; KEY=0.034; TOP=0.028
COLS,ROWS=16,6
X0=(PW-COLS*PITCH)/2; Y0=(PD-ROWS*PITCH)/2
FONT='/System/Library/Fonts/Menlo.ttc'
# ряды сверху (дальний край, от человека) вниз; (текст, ширина в колонках), в сумме 16 колонок
def R(s): return [(t,1) for t in s.split()]
LAYOUT=[
 R('PWR SHD WPN NAV ENG COM SYNC LOCK AUTO MAN F1 F2 F3 F4 F5 F6'),
 R('ESC 1 2 3 4 5 6 7 8 9 0 - + DEL PGUP HOME'),
 R('TAB Q W E R T Y U I O P [ ] \\ PGDN END'),
 R('CAPS A S D F G H J K L ; \'')+[('ENT',2),('REW',1),('FWD',1)],
 [('SHF',2)]+R('Z X C V B N M , . / ^ REC PLAY MUTE'),
 R('ALT CTL FN')+[('SPACE',6)]+R('ARM SAFE < v > OK CNL'),
]
def cells():
    for r,row in enumerate(LAYOUT):
        c=0
        for t,span in row:
            yield r,c,span,t
            c+=span
def cap_rect(r,c,span):
    # прямоугольник верхней грани колпачка, px (x0,y0,x1,y1), y сверху
    cx=(X0+(c+span/2)*PITCH)*PX
    cy=(PD-(Y0+(ROWS-1-r+0.5)*PITCH))*PX
    w=(TOP+(span-1)*PITCH)*PX/2; h=TOP*PX/2
    return (cx-w,cy-h,cx+w,cy+h),(cx,cy)
def font(sz): return ImageFont.truetype(FONT,sz)
alb=Image.new('RGB',(W,H),(14,16,20)); em=Image.new('RGB',(W,H),(0,0,0))
da=ImageDraw.Draw(alb); de=ImageDraw.Draw(em)
for r,c,span,t in cells():
    (a,b,cc,d),(cx,cy)=cap_rect(r,c,span)
    # колпачок (вся плоскость колпачка) и тёмный зазор вокруг
    kc=(26,30,36) if t not in('PWR','ARM') else (60,24,24)
    da.rounded_rectangle((a-8,b-8,cc+8,d+8),12,fill=(20,23,28))
    da.rounded_rectangle((a,b,cc,d),14,fill=kc,outline=(44,50,58),width=3)
    sz=44 if len(t)<=2 else (34 if len(t)<=3 else 28)
    f=font(sz); tw=de.textlength(t,font=f)
    col=(120,230,255) if t not in('PWR','ARM','REC') else (255,110,90)
    de.text((cx-tw/2,cy-sz*0.55),t,font=f,fill=col)
    da.text((cx-tw/2,cy-sz*0.55),t,font=f,fill=(150,160,170))
em=em.filter(ImageFilter.GaussianBlur(0.8))
alb.save(os.path.join(OUT,'kb_albedo_2560x1024.png')); em.save(os.path.join(OUT,'kb_emission_2560x1024.png'))
# карта-подсказка для GPT: сетка колпачков
g=Image.new('RGB',(W,H),(0,0,0)); dg=ImageDraw.Draw(g)
for r,c,span,t in cells():
    (a,b,cc,d),_=cap_rect(r,c,span)
    dg.rectangle((a,b,cc,d),outline=(255,255,255),width=4)
    dg.text((a+8,b+6),t,font=font(26),fill=(255,220,0))
g.save(os.path.join(OUT,'kb_layout_guide_2560x1024.png'))
# голо-окна: атлас 2x2, ячейка 1024x640 (16:10)
CW,CH=1024,640
atlas=Image.new('RGBA',(CW*2,CH*2),(0,0,0,0))
def holo(kind):
    im=Image.new('RGBA',(CW,CH),(0,0,0,0)); d=ImageDraw.Draw(im)
    C=(80,220,255)
    def A(a): return C+(a,)
    d.rounded_rectangle((6,6,CW-6,CH-6),18,fill=(20,90,120,50),outline=A(230),width=4)
    d.rectangle((6,6,CW-6,64),fill=(40,160,200,90)); d.text((24,16),kind.upper(),font=font(34),fill=A(255))
    for i in range(0,CW,64): d.line((i,64,i,CH),fill=A(30))
    for j in range(64,CH,64): d.line((0,j,CW,j),fill=A(30))
    if kind=='navigation':
        cx,cy=CW//2,CH//2+30
        for rr in (60,120,180,240): d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),outline=A(150),width=2)
        d.line((cx,cy,cx+int(230*math.cos(.9)),cy-int(230*math.sin(.9))),fill=A(255),width=4)
        for k,(x,y) in enumerate([(-120,-60),(90,-140),(160,40),(-60,110),(30,-20)]): d.ellipse((cx+x-8,cy+y-8,cx+x+8,cy+y+8),fill=A(255))
    elif kind=='engines':
        for i in range(6):
            x=60+i*150; h=80+((i*97)%260)
            d.rectangle((x,CH-60-h,x+90,CH-60),fill=(60,200,255,110),outline=A(230),width=3)
            d.text((x+8,CH-50),f'E{i+1}',font=font(28),fill=A(255))
    elif kind=='systems':
        for i in range(7):
            y=100+i*70; d.text((30,y),f'SYS-{i+1:02d}',font=font(30),fill=A(255))
            d.rectangle((250,y+6,250+(i*83%600)+100,y+34),fill=(60,200,255,120),outline=A(230),width=2)
    else:
        pts=[(40+i*40,CH//2+int(110*math.sin(i*.7)+60*math.sin(i*1.9))) for i in range(24)]
        d.line(pts,fill=A(255),width=4)
        d.text((40,90),'COMM LINK 04',font=font(34),fill=A(255))
    return im.filter(ImageFilter.GaussianBlur(0.6))
for k,kind in enumerate(['navigation','engines','systems','comms']):
    atlas.paste(holo(kind),((k%2)*CW,(k//2)*CH))
atlas.save(os.path.join(OUT,'holo_atlas_2048x1280_placeholder.png'))
gh=Image.new('RGB',(CW*2,CH*2),(0,0,0)); dg=ImageDraw.Draw(gh)
for k,kind in enumerate(['NAVIGATION','ENGINES','SYSTEMS','COMMS']):
    x,y=(k%2)*CW,(k//2)*CH
    dg.rectangle((x+4,y+4,x+CW-4,y+CH-4),outline=(255,255,255),width=6)
    dg.text((x+30,y+24),f'{k+1}: {kind}',font=font(48),fill=(255,220,0))
gh.save(os.path.join(OUT,'holo_layout_guide_2048x1280.png'))
print('ok')
