import cv2, numpy as np, os, sys
D = '/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/textures/'
B = D + 'bake/'
MN = np.array([-26, -46, -8], np.float32); RG = np.array([52, 92, 22], np.float32)
S = int(sys.argv[1]) if len(sys.argv) > 1 else 4096

def load(k):
    a = cv2.imread(B + f'hull_{k}_4k.png', cv2.IMREAD_UNCHANGED)[..., ::-1].astype(np.float32) / 65535
    if S != a.shape[0]: a = cv2.resize(a, (S, S), interpolation=cv2.INTER_AREA)
    return a
pos = load('pos'); nrm = load('nrm')
cover = (pos.max(2) > 0)
cover = cv2.erode(cover.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) | cover
P = pos * RG + MN                       # world position (m)
N = nrm * 2 - 1
x, y, z = P[..., 0], P[..., 1], P[..., 2]
nx, ny, nz = N[..., 0], N[..., 1], N[..., 2]
ax = np.abs(x)
ao = load('ao')[..., 0] if os.path.exists(B + 'hull_ao_4k.png') else np.ones((S, S), np.float32)
ed = load('edge')[..., 0] if os.path.exists(B + 'hull_edge_4k.png') else np.ones((S, S), np.float32)
edge = np.clip((1 - ed) * 6, 0, 1)      # 1 at rounded edges

def sstep(a, b, v): t = np.clip((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def hash3(i, j, k, seed):
    h = (i * 374761393 + j * 668265263 + k * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535

def vnoise(px, py, pz, seed=0):
    xi, yi, zi = np.floor(px).astype(np.int64), np.floor(py).astype(np.int64), np.floor(pz).astype(np.int64)
    fx, fy, fz = px - xi, py - yi, pz - zi
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    r = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fz if dz else 1 - fz)
                r = r + w * hash3(xi + dx, yi + dy, zi + dz, seed)
    return r

def fbm(sx, sy, sz, oct=4, seed=0):
    r = 0; a = .5; tot = 0
    for o in range(oct):
        f = 2 ** o
        r = r + a * vnoise(x * sx * f, y * sy * f, z * sz * f, seed + o); tot += a; a *= .5
    return (r / tot).astype(np.float32)

# ---------- paint layout (world coords, nose = +Y) ----------
top = sstep(.35, .6, nz); side = sstep(.55, .8, np.abs(nx)); belly = sstep(.35, .6, -nz)
rear = sstep(.5, .8, -ny); front = sstep(.5, .8, ny)
def band(v, a, b, soft=.04): return sstep(a - soft, a + soft, v) * (1 - sstep(b - soft, b + soft, v))

black = np.zeros((S, S), np.float32)
jit = (fbm(1.3, 1.3, 1.3, 3, 5) - .5)          # ragged paint edges
jit2 = (fbm(4, 4, 4, 2, 6) - .5)
T = np.zeros((S, S), np.float32); WID = np.ones((S, S), np.float32); ALONG = np.zeros((S, S), np.float32)
def acc(m, tl, w, al):
    global T, WID, ALONG
    k = m > .5
    T = np.where(k, tl, T); WID = np.where(k, w, WID); ALONG = np.where(k, al, ALONG)
def tri(v, v0, thin, gap, thick, along):
    """thin | thick | thin stripe set starting at v0, records local coords for the wear pattern."""
    t = v - v0
    r = np.zeros((S, S), np.float32)
    for st, w in ((0, thin), (thin + gap, thick), (thin + gap + thick + gap, thin)):
        m = band(t, st, st + w, .02)
        acc(m, (t - st) / w, w, along)
        r = np.maximum(r, m)
    return r
# 1. top: thin-thick-thin on each side of the centreline
topb = np.maximum(top, sstep(-.3, -.1, nz) * sstep(-1.2, -.7, z))   # include groove walls near the nose
black = np.maximum(black, topb * tri(ax, 1.1, .3, .3, 1.3, y + (x > 0) * 7.3) * band(y, -41, 27))
# 2. sides above the portholes: thin-thick-thin stacked in height
black = np.maximum(black, side * tri(z, 1.5, .3, .3, 1.1, y + (x > 0) * 5.1) * band(y, -42, 27))
# 3. thin band under the portholes
m3 = side * band(z, -0.9, -0.55) * band(y, 3, 17)
acc(m3, (z + .9) / .35, .35, y); black = np.maximum(black, m3)
# 4. wings: thin stripes running ALONG the span
wing = sstep(.3, .5, nz) * sstep(7.2, 7.6, ax)
dtrail = (y - (-36 - .58 * (ax - 10))) * .865      # straight distance from the trailing edge
black = np.maximum(black, wing * tri(dtrail, 3.0, .4, .4, 1.4, .865 * ax - .5 * y + 3) * band(ax, 8.5, 24, .1))
# 5. frame around the cockpit glass
d = np.sqrt((ax - 3.6) ** 2 + ((y - 31.5) / 1.3) ** 2 + ((z + 1.0) / 1.0) ** 2)
mf = band(d, 2.3, 4.2, .25) * (1 - belly) * front
acc(mf, (d - 2.3) / 1.9, 1.3, np.arctan2(z + 1.0, (y - 31.5) / 1.3) * 2.5 + ax)
black = np.maximum(black, mf)
# 6. rear panel behind the engines: dark
acc(rear, np.clip((x + 13) / 26, 0, 1), 1.3, z * 1.0 + 3)
black = np.maximum(black, rear * .85)
black *= cover
# groove walls on the nose have other normals and cut the stripes into segments: bridge those narrow gaps
black = cv2.morphologyEx(black, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))) * cover

# panel grid -> per-panel tint and seam lines
def grid_cell(u, v, cu, cv):
    fu, fv = u / cu, v / cv
    row = np.floor(fv); fu = fu + (row % 2) * .5
    iu = np.floor(fu); cu_f = fu - iu; cv_f = fv - row
    h = hash3(iu.astype(np.int64), row.astype(np.int64), np.zeros_like(iu, dtype=np.int64), 7)
    seam = np.minimum(np.minimum(cu_f, 1 - cu_f) * cu, np.minimum(cv_f, 1 - cv_f) * cv)
    return h, seam
ux = np.abs(nx) > .6; uz = np.abs(nz) > .6
u = np.where(ux, y, x); v = np.where(ux, z, np.where(uz, y, z))
h, seam = grid_cell(u, v, 3.6, 1.8)
seamline = seam * 0
tint = h * 0

# ---------- wear ----------
dirt = np.clip((1 - ao) * 1.3, 0, 1)
big = fbm(.35, .35, .35, 4, 11)
mid = fbm(1.6, 1.6, 1.6, 4, 23)
fine = fbm(7, 7, 7, 3, 37)
chipmask = (sstep(.80, .85, fine) * .55 + sstep(.5, .62, mid) * sstep(.25, .5, edge) * 1.1) * (.5 + big)
chipmask = np.clip(chipmask, 0, 1) * cover * (1 - np.clip(black * 1.2, 0, 1))   # no chips on stripe paint: the pattern supplies its own wear
scratch = sstep(.84, .9, 1 - np.abs(fbm(5, 5, 5, 2, 51) - .5) * 2) * (1 - belly * 0) * .6
streak_n = fbm(2.2, 2.2, .22, 4, 61)
streak = sstep(.5, .78, streak_n) * (side + front * .5 + top * .3)
rust_n = fbm(.9, .9, .9, 5, 71)
zone_worn = np.clip(belly * 1.0 + rear * .9, 0, 1)
rust = sstep(.56, .72, rust_n * .8 + fine * .3) * zone_worn * (.6 + .4 * dirt)
rustspot = sstep(.74, .8, mid) * (.25 + top * .0) * (1 - zone_worn)  # small rust specks everywhere

white = np.array([.90, .90, .88], np.float32)
blk = np.array([.095, .095, .105], np.float32)
metal = np.array([.34, .34, .36], np.float32)
primer = np.array([.45, .45, .47], np.float32)
rustc = np.array([.30, .15, .08], np.float32)
steel = np.array([.30, .30, .31], np.float32)
soot = np.array([.07, .065, .06], np.float32)

WP = cv2.imread(D + 'stripe_wear_pattern.png', 0).astype(np.float32) / 255
WP = WP[:, 306:489]                                    # stripe columns only (white = worn through)
texel = 92.0 / S * (4096 / 4096) * (4096 / S) * (S / 4096) if False else .03 * 4096 / S   # metres per texel
rows = int(WP.shape[0] * .24 * 4096 / S)
def prep(width_m):
    cols = max(int(width_m / texel), 4)
    return cv2.resize(WP, (cols, rows), interpolation=cv2.INTER_AREA)
def sample(R, mask_w):
    h, w = R.shape
    mx = (np.clip(T, 0, 1) * (w - 1)).astype(np.float32)
    my = (ALONG / texel).astype(np.float32)
    my = np.abs(((my % (2 * h)) + 2 * h) % (2 * h) - h).clip(0, h - 1)
    return cv2.remap(R, mx, my, cv2.INTER_LINEAR)
worn = np.where(WID > .8, sample(prep(1.3), 1), sample(prep(.35), 1))
peel = sstep(.45, .6, worn) * (black > .5)
black = black * (1 - peel)
blk3 = black[..., None]
col = white[None, None] * (1 + tint[..., None]) * (1 - blk3) + blk * blk3
# worn belly/rear base: darker metallic paint instead of clean white
col = col * (1 - zone_worn[..., None] * .7) + (steel * (.45 + .6 * big[..., None])) * (zone_worn[..., None] * .7)
col = col * (1 - seamline[..., None] * .6)
# streaks of dirt
col = col * (1 - streak[..., None] * .22 * np.array([.8, .9, 1.0], np.float32))
# dirt in crevices
col = col * (1 - dirt[..., None] * .45)
col = col * (1 + (big[..., None] - .5) * .14) * (1 + (mid[..., None] - .5) * .07)
# chips: expose primer on black, bare metal on white
chipcol = metal * blk3 * 0 + (primer * blk3 + metal * (1 - blk3))
col = col * (1 - chipmask[..., None] * .85) + chipcol * chipmask[..., None] * .85

# rust
col = col * (1 - rust[..., None] * .8) + rustc * (.7 + .6 * fine[..., None]) * rust[..., None] * .8
col = col * (1 - rustspot[..., None]) + rustc * rustspot[..., None]
# exhaust soot behind the engines
soot_m = rear * sstep(.4, .7, fbm(.5, .5, .5, 3, 91))
col = col * (1 - soot_m[..., None] * .5) + soot * soot_m[..., None] * .5
col = np.clip(col, 0, 1)

# roughness / metallic
rough = .52 - black * .12 + chipmask * -.15 + rust * .35 + zone_worn * .1 + streak * .06 + dirt * .1 + (fine - .5) * .08
rough = np.clip(rough, .15, 1)
metallic = np.clip(chipmask * .9 + zone_worn * .4 * (1 - rust) + rust * .1, 0, 1)

def out(name, a, srgb):
    a = np.clip(a, 0, 1)
    if srgb: a = np.where(a <= .0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - .055)
    # bleed outward so mip/bilinear sampling has no black halo at island edges
    m = cover.astype(np.uint8)
    img = (a * 255 + .5).astype(np.uint8)
    if img.ndim == 2: img = img[..., None]
    for _ in range(0):
        pass
    cv2.imwrite(D + name, (img[..., ::-1] if img.shape[2] == 3 else img[..., 0]))

out(f'hull_albedo_{S}.png', col, True)
out(f'hull_roughness_{S}.png', rough, False)
out(f'hull_metallic_{S}.png', metallic, False)
print('done', S, 'black coverage', float(black[cover].mean()), 'worn', float(zone_worn[cover].mean()))
