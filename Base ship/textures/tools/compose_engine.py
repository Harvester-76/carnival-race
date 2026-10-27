import cv2, numpy as np, os, sys
D = '/Users/ivanconnectivity/work/3D models/Spaceships for game/Base ship/textures/'
B = D + 'bake/'
MN = np.array([-26, -46, -8], np.float32); RG = np.array([52, 92, 22], np.float32)
S = int(sys.argv[1]) if len(sys.argv) > 1 else 4096

def load(k):
    a = cv2.imread(B + f'eng_{k}_4k.png', cv2.IMREAD_UNCHANGED)[..., ::-1].astype(np.float32) / 65535
    if S != a.shape[0]: a = cv2.resize(a, (S, S), interpolation=cv2.INTER_AREA)
    return a
pos = load('pos'); nrm = load('nrm')
cover = pos.max(2) > 0
P = pos * RG + MN; N = nrm * 2 - 1
x, y, z = P[..., 0], P[..., 1], P[..., 2]
ao = load('ao')[..., 0] if os.path.exists(B + 'eng_ao_4k.png') else np.ones((S, S), np.float32)
ed = load('edge')[..., 0] if os.path.exists(B + 'eng_edge_4k.png') else np.ones((S, S), np.float32)
edge = np.clip((1 - ed) * 7, 0, 1)
dirt = np.clip((1 - ao) * 1.4, 0, 1)

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
def fbm(sx, sy, sz, oct=3, seed=0):
    r = 0; a = .5; tot = 0
    for o in range(oct):
        f = 2 ** o
        r = r + a * vnoise(x * sx * f, y * sy * f, z * sz * f, seed + o); tot += a; a *= .5
    return (r / tot).astype(np.float32)

big = fbm(.8, .8, .8, 3, 3)
mid = fbm(6, 6, 6, 3, 13)
fine = fbm(45, 45, 45, 2, 23)
speck = sstep(.86, .9, fbm(90, 90, 90, 1, 33))

gun = np.array([.095, .100, .115], np.float32)          # ~ sRGB 88,90,98
col = gun[None, None] * (.88 + .24 * mid[..., None]) * (1 + (fine[..., None] - .5) * .18)
col = col * (1 - dirt[..., None] * .55)
# bare, brighter metal on worn edges
metal_edge = np.array([.32, .33, .36], np.float32)
we = np.clip(edge * (.5 + big * 1.0), 0, 1)
col = col * (1 - we[..., None] * .7) + metal_edge * we[..., None] * .7
# light heat tint (blue-bronze) near edges and in recesses
heat = np.clip(edge * .6 + dirt * .25, 0, 1) * sstep(.45, .75, big)
tint = np.array([.20, .15, .28], np.float32)
col = col * (1 - heat[..., None] * .35) + tint * heat[..., None] * .35
# tiny scratches / bright specks
col = col + speck[..., None] * .10
col = np.clip(col, 0, 1)

rough = .36 + (fine - .5) * .16 + dirt * .22 - we * .12 + (mid - .5) * .08
rough = np.clip(rough, .15, .9)
metallic = np.clip(.92 - dirt * .18 + we * .08, 0, 1)

def out(name, a, srgb):
    a = np.clip(a, 0, 1)
    if srgb: a = np.where(a <= .0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - .055)
    img = (a * 255 + .5).astype(np.uint8)
    cv2.imwrite(D + name, img[..., ::-1] if img.ndim == 3 else img)
out(f'engine_albedo_{S}.png', col, True)
out(f'engine_roughness_{S}.png', rough, False)
out(f'engine_metallic_{S}.png', metallic, False)
print('done', S, float(cover.mean()))
