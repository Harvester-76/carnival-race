# Бесшовные тайлы интерьера 2 x 2 м: стены, пол, потолок для рубки/кают-компании (bridge), коридора (corr) и кают (room).
# Для каждого тайла: *_albedo.png, *_normal.png (OpenGL, зелёный вверх), *_rough.png.
# Заглушки считаются здесь процедурно. Когда GPT пришлёт настоящий albedo, положить его как tiles/<имя>_albedo.png
# и запустить:  python3 make_interior_tiles.py --from-albedo   (нормаль и шероховатость будут выведены из albedo).
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
OUT=os.path.join(os.path.dirname(__file__),'..','interior','tiles'); os.makedirs(OUT,exist_ok=True)
N=1024; TILE_M=2.0; PXM=N/TILE_M
rng=np.random.default_rng(11)

def pnoise(power=2.0,seed=0,scale=1.0):
    r=np.random.default_rng(seed); w=r.standard_normal((N,N))
    f=np.fft.fft2(w); fy=np.fft.fftfreq(N)[:,None]; fx=np.fft.fftfreq(N)[None,:]
    k=np.sqrt(fx**2+fy**2); k[0,0]=1; f=f/(k**(power/2)); f[0,0]=0
    n=np.real(np.fft.ifft2(f)); n=(n-n.min())/(n.max()-n.min()); return n
def grid_mask(cells,seam_px,offset=0,stagger=False):
    """1 внутри панели, 0 на шве. cells - число панелей по оси."""
    y,x=np.mgrid[0:N,0:N]
    cx=N/cells
    if stagger:
        row=(y//cx).astype(int); xs=(x+(row%2)*cx/2)%N
    else: xs=x
    dx=np.minimum(xs%cx,cx-(xs%cx)); dy=np.minimum(y%cx,cx-(y%cx))
    seam=np.minimum(dx,dy)
    return np.clip(seam/seam_px,0,1)
def rivets(cells,r_px,inset):
    h=np.zeros((N,N)); y,x=np.mgrid[0:N,0:N]; cx=N/cells
    for i in range(cells):
        for j in range(cells):
            for ox,oy in ((inset,inset),(cx-inset,inset),(inset,cx-inset),(cx-inset,cx-inset)):
                px,py=i*cx+ox,j*cx+oy
                d=np.sqrt(((x-px+N/2)%N-N/2)**2+((y-py+N/2)%N-N/2)**2)
                h=np.maximum(h,np.clip(1-d/r_px,0,1)**0.5)
    return h
def scratches(n,seed,length=140):
    im=Image.new('L',(N,N),0); d=ImageDraw.Draw(im); r=random.Random(seed)
    for _ in range(n):
        x,y=r.uniform(0,N),r.uniform(0,N); a=r.uniform(0,math.tau); L=r.uniform(20,length)
        for ox in (-N,0,N):
            for oy in (-N,0,N): d.line((x+ox,y+oy,x+ox+L*math.cos(a),y+oy+L*math.sin(a)),fill=r.randint(60,200),width=1)
    return np.asarray(im.filter(ImageFilter.GaussianBlur(0.6)),np.float32)/255
def diamond(cell):
    im=Image.new('L',(N*2,N*2),0); d=ImageDraw.Draw(im); c2=cell*2
    for i in range(N//cell):
        for j in range(N//cell):
            cx,cy=(i+0.5)*c2,(j+0.5)*c2; ang=math.pi/4 if (i+j)%2==0 else -math.pi/4
            L,W=c2*0.42,c2*0.11
            pts=[(cx+L*math.cos(ang)*s1-W*math.sin(ang)*s2,cy+L*math.sin(ang)*s1+W*math.cos(ang)*s2) for s1,s2 in((-1,-1),(1,-1),(1,1),(-1,1))]
            d.polygon(pts,fill=255)
    return np.asarray(im.resize((N,N),Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0)),np.float32)/255
def planks(width_px,seed):
    r=np.random.default_rng(seed); y,x=np.mgrid[0:N,0:N]
    row=(y//width_px).astype(int); n_rows=N//width_px
    shift=r.uniform(0,N,n_rows)[row]; xs=(x+shift)%N
    plank_len=N//2; pid=(xs//plank_len).astype(int)
    tone=r.uniform(0.85,1.15,(n_rows,4))[row%n_rows,pid%4]
    seam=np.minimum(np.minimum(y%width_px,width_px-(y%width_px)),np.minimum(xs%plank_len,plank_len-(xs%plank_len)))
    return tone,np.clip(seam/3.0,0,1)

def save(name,alb,height,rough):
    a=np.clip(alb,0,1); Image.fromarray((a*255).astype(np.uint8)).save(os.path.join(OUT,name+'_albedo.png'))
    nm_from_height(name,height); Image.fromarray((np.clip(rough,0,1)*255).astype(np.uint8)).save(os.path.join(OUT,name+'_rough.png'))
def nm_from_height(name,h,strength=3.0):
    h=h.astype(np.float32); dx=(np.roll(h,-1,1)-np.roll(h,1,1))*strength*8; dy=(np.roll(h,-1,0)-np.roll(h,1,0))*strength*8
    n=np.dstack([-dx,dy,np.ones_like(h)]); n/=np.linalg.norm(n,axis=2,keepdims=True)
    Image.fromarray(((n*0.5+0.5)*255).astype(np.uint8)).save(os.path.join(OUT,name+'_normal.png'))
def tint(base,var,n): return np.dstack([base[i]+var*(n-0.5) for i in range(3)])

def wall(name,base,cells,seam,paint_var=0.05,rivet=True,stagger=False):
    n=pnoise(2.2,1); g=pnoise(0.6,2); m=grid_mask(cells,seam,stagger=stagger)
    alb=tint(base,paint_var*2,n)*(0.9+0.1*g[...,None])
    pan=np.random.default_rng(5).uniform(0.94,1.06,(cells,cells))
    ids=(np.mgrid[0:N,0:N][0]//(N//cells)).astype(int)%cells; jds=(np.mgrid[0:N,0:N][1]//(N//cells)).astype(int)%cells
    alb=alb*pan[ids,jds][...,None]
    alb*= (0.55+0.45*m)[...,None]                              # затемнение швов
    sc=scratches(40,3); alb=alb*(1-0.10*sc[...,None])+0.05*sc[...,None]
    h=0.5*m+0.04*n+(0.2*rivets(cells,7,26) if rivet else 0)-0.1*sc
    rough=0.55+0.25*(1-m)+0.15*n
    save(name,alb,h,rough)
def floor_plate(name,base,cells,diamond_cell=None):
    n=pnoise(2.2,4); m=grid_mask(cells,5); g=pnoise(0.6,6)
    alb=tint(base,0.05,n)*(0.85+0.15*g[...,None])*(0.6+0.4*m)[...,None]
    h=0.5*m+0.03*n
    if diamond_cell:
        d=diamond(diamond_cell); h=h+0.25*d; alb=alb*(1+0.12*d[...,None])
    sc=scratches(60,7); alb=alb*(1-0.12*sc[...,None])+0.06*sc[...,None]
    rough=0.45+0.3*(1-m)+0.2*n
    save(name,alb,h,rough)
def ceiling(name,base,cells,perf=False):
    n=pnoise(2.2,8); m=grid_mask(cells,4); alb=tint(base,0.04,n)*(0.7+0.3*m)[...,None]
    h=0.5*m+0.02*n
    if perf:
        y,x=np.mgrid[0:N,0:N]; p=((x%32-16)**2+(y%32-16)**2<22)&(m>0.99); alb=alb*(1-0.5*p[...,None]); h=h-0.15*p
    save(name,alb,h,0.6+0.2*(1-m))
def wood(name,base):
    tone,seam=planks(64,9); n=pnoise(2.4,10)
    gr=np.asarray(Image.fromarray((np.random.default_rng(12).random((N//32,N))*255).astype(np.uint8)).resize((N,N),Image.BICUBIC),np.float32)/255
    alb=np.dstack([base[i]*tone*(0.85+0.3*gr)*(0.5+0.5*seam) for i in range(3)])
    h=0.4*seam+0.05*gr; save(name,alb,h,0.5+0.15*n)

def build():
    # рубка и кают-компания
    wall('wall_bridge',(0.62,0.61,0.58),2,6,rivet=True)
    floor_plate('floor_bridge',(0.11,0.12,0.14),4)
    ceiling('ceiling_bridge',(0.80,0.80,0.82),2,perf=False)
    # коридор (синевато-серый, как сейчас)
    wall('wall_corr',(0.25,0.30,0.36),2,6,rivet=True,stagger=False)
    floor_plate('floor_corr',(0.16,0.17,0.19),4,diamond_cell=32)
    ceiling('ceiling_corr',(0.20,0.23,0.27),4,perf=True)
    # каюты (светлые, тёплые)
    wall('wall_room',(0.74,0.72,0.67),2,4,paint_var=0.04,rivet=False)
    wood('floor_room',(0.34,0.23,0.14))
    ceiling('ceiling_room',(0.86,0.86,0.86),2)
def from_albedo():
    for f in os.listdir(OUT):
        if f.endswith('_albedo.png'):
            name=f[:-11]; a=np.asarray(Image.open(os.path.join(OUT,f)).convert('RGB').resize((N,N),Image.LANCZOS),np.float32)/255
            lum=a.mean(axis=2); lum=np.roll(lum,0)
            low=np.asarray(Image.fromarray((lum*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24)),np.float32)/255
            h=np.clip(0.5+(lum-low)*2.0,0,1); nm_from_height(name,h,2.0)
            Image.fromarray((np.clip(0.75-0.4*h+0.15*lum,0,1)*255).astype(np.uint8)).save(os.path.join(OUT,name+'_rough.png'))
            print('pbr from albedo:',name)
if __name__=='__main__':
    if '--from-albedo' in sys.argv: from_albedo()
    else: build(); print('ok')
