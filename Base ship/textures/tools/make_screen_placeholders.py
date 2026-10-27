# Заглушки: большой экран кают-компании, климат-экран, цилиндрическая голограмма. Финалы рисует GPT (см. gpt_prompts/03_*.md).
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT=os.path.join(os.path.dirname(__file__),'..','interior')
FONT='/System/Library/Fonts/Menlo.ttc'
def f(s): return ImageFont.truetype(FONT,s)
# большой экран: туманность (из фона рендера) 1920x1080
bg=Image.open(os.path.join(OUT,'..','..','..','..','..','..','tmp','x')) if False else None
src='/private/tmp/claude-501/-Users-ivanconnectivity-work-3D-models-Spaceships-for-game/d633934b-a8a3-4f90-b8c9-86b0379876eb/scratchpad/bg_space.png'
if os.path.exists(src): Image.open(src).convert('RGB').resize((1920,1080),Image.LANCZOS).save(os.path.join(OUT,'screen_big_placeholder_1920x1080.png'))
else: Image.new('RGB',(1920,1080),(6,10,24)).save(os.path.join(OUT,'screen_big_placeholder_1920x1080.png'))
# климат-экран 1024x640
W,H=1024,640; im=Image.new('RGB',(W,H),(6,22,30)); d=ImageDraw.Draw(im); C=(90,225,255)
d.rectangle((0,0,W-1,60),fill=(12,60,78)); d.text((20,12),'CLIMATE',font=f(34),fill=C)
d.text((W-250,12),'AUTO  22.4C',font=f(30),fill=(255,200,90))
for i,(lab,val) in enumerate([('TEMP','22.4 C'),('HUM','45 %'),('O2','20.9 %'),('CO2','0.04 %'),('PRES','101 kPa')]):
    y=100+i*84; d.text((24,y),lab,font=f(30),fill=C); d.text((200,y),val,font=f(36),fill=(255,255,255))
    d.rectangle((420,y+8,980,y+36),outline=C,width=2); d.rectangle((424,y+12,424+int((300+i*70)*0.9),y+32),fill=(40,170,210))
im.save(os.path.join(OUT,'screen_climate_placeholder_1024x640.png'))
# цилиндрическая голограмма 2048x1024 (u вокруг цилиндра, бесшовно по горизонтали)
W,H=2560,1024; hg=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(hg); A=lambda a:(90,225,255,a)
for y in range(0,H,16): d.line((0,y,W,y),fill=A(40 if y%64 else 110),width=2)
for x in range(0,W,160): d.line((x,0,x,H),fill=A(60),width=3)
random.seed(3)
for i in range(16):
    x=i*160+20; h=random.randint(120,700)
    d.rectangle((x,H-60-h,x+88,H-60),fill=A(120),outline=A(230),width=3)
    d.text((x+6,H-50),f'{i:02d}',font=f(28),fill=A(255))
for k in range(4):
    cx=k*640+320; cy=300
    for r in (60,110,160): d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=A(200),width=3)
    d.line((cx,cy,cx+int(150*math.cos(k)),cy+int(150*math.sin(k))),fill=A(255),width=4)
d.rectangle((0,0,W,10),fill=A(255)); d.rectangle((0,H-10,W,H),fill=A(255))
hg.save(os.path.join(OUT,'holo_column_placeholder_2560x1024.png'))
# карты-подсказки
g=Image.new('RGB',(1920,1080),(0,0,0)); dg=ImageDraw.Draw(g); dg.rectangle((4,4,1915,1075),outline=(255,255,255),width=8); dg.text((30,30),'BIG SCREEN 16:9  1920x1080',font=f(44),fill=(255,220,0)); g.save(os.path.join(OUT,'screen_big_layout_guide_1920x1080.png'))
g=Image.new('RGB',(1024,640),(0,0,0)); dg=ImageDraw.Draw(g); dg.rectangle((4,4,1019,635),outline=(255,255,255),width=6); dg.rectangle((4,4,1019,64),outline=(255,220,0),width=4); dg.text((20,10),'TITLE BAR',font=f(30),fill=(255,220,0)); dg.text((20,100),'5 rows: label | value | bar',font=f(30),fill=(255,220,0)); g.save(os.path.join(OUT,'screen_climate_layout_guide_1024x640.png'))
g=Image.new('RGB',(2560,1024),(0,0,0)); dg=ImageDraw.Draw(g)
for i in range(5): x=i*640; dg.line((x,0,x,1024),fill=(255,255,255),width=4); 
for i in range(4): dg.text((i*640+20,20),f'quarter {i+1} (wraps around the cylinder)',font=f(30),fill=(255,220,0))
dg.rectangle((0,0,2559,1023),outline=(255,255,255),width=8); g.save(os.path.join(OUT,'holo_column_layout_guide_2560x1024.png'))
print('ok')
