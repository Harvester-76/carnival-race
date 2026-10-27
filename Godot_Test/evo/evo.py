#!/usr/bin/env python3
"""Эволюция параметров ботов. Запуск: python3 evo/evo.py [поколений] [параллельно]
Каждый прогон: godot --headless -- evo track=N secs=S genes=файл tuning=снимок out=результат (10 ботов с разными генами, игрока нет).
Приспособленность особи = среднее по трассам: пройденный путь, км − 0,6·удары − 6·возвраты на трассу − 0,3·потерянные детали.
Состояние сохраняется после каждого поколения (evo/state.json), лучшее в evo/best.json и bot_genes_latest.json (в игру копируется как ../bot_genes.json после вашего ОК)."""
import json, os, random, subprocess, sys, shutil, time, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__)); PROJ = os.path.dirname(HERE)
GODOT = "/opt/homebrew/bin/godot"
R = {"v_max": [800.0, 2400.0], "lat_acc": [60.0, 320.0], "a_cap": [150.0, 900.0], "look_k": [1.0, 4.0], "look_min": [500.0, 1800.0], "a_gain": [0.6, 2.5], "align_lo": [0.4, 0.9], "att_gain": [0.8, 2.5], "alt_pref": [0.0, 1.0], "alt_free": [0.0, 1.0], "clear_m": [100.0, 500.0], "lane": [-700.0, 700.0], "apex": [0.0, 1.0], "sep_w": [0.0, 2.0]}
DEF = {"v_max": 1400.0, "lat_acc": 130.0, "a_cap": 350.0, "look_k": 2.5, "look_min": 900.0, "a_gain": 1.2, "align_lo": 0.7, "att_gain": 1.2, "alt_pref": 0.5, "alt_free": 0.0, "clear_m": 220.0, "lane": 0.0, "apex": 0.3, "sep_w": 1.0}
POP = 20; SECS = 150; TRACKS_PER_GEN = 3; TRACK_POOL = [t for t in range(1, 41) if t not in (14, 28)]; VALID = [101, 102, 103]
TMP = os.path.join(HERE, "tmp"); os.makedirs(TMP, exist_ok=True)
SNAP = os.path.join(TMP, "tuning_snapshot.json")
shutil.copy(os.path.join(PROJ, "tuning.json"), SNAP)         # обучение идёт на снимке настроек двигателей, правки в игре его не меняют

def clamp(k, x): return min(max(x, R[k][0]), R[k][1])
def rand_ind(spread=0.35):
    return {k: clamp(k, DEF[k] + random.gauss(0, spread) * (R[k][1] - R[k][0])) for k in R}
def mutate(g, sigma=0.10, p=0.35):
    return {k: (clamp(k, v + random.gauss(0, sigma) * (R[k][1] - R[k][0])) if random.random() < p else v) for k, v in g.items()}
def cross(a, b):
    return {k: (a[k] if random.random() < 0.5 else b[k]) for k in a}

def run_group(tag, track, genes):
    gp = os.path.join(TMP, tag + "_g.json"); op = os.path.join(TMP, tag + "_r.json")
    json.dump(genes, open(gp, "w"))
    if os.path.exists(op): os.remove(op)
    subprocess.run(["nice", "-n", "10", GODOT, "--headless", "--path", PROJ, "--", "evo", "track=%d" % track, "secs=%d" % SECS, "genes=" + gp, "tuning=" + SNAP, "out=" + op],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try: return json.load(open(op))
    except Exception: return None

def score(r):
    g = lambda k: r.get(k) or 0.0
    return g("prog") / 1000.0 - 0.6 * g("hits") - 6.0 * g("resp") - 0.3 * g("lost")

def evaluate(pop, tracks, par, tagp):
    """возвращает по особи список очков по трассам и сырые итоги"""
    jobs = []
    for ti, tr in enumerate(tracks):
        idx = list(range(len(pop))); random.shuffle(idx)
        for gi in range(0, len(idx), 10):
            grp = idx[gi:gi + 10]
            while len(grp) < 10: grp.append(random.randrange(len(pop)))     # добор, если особей не кратно 10
            jobs.append((tr, grp, "%s_%d_%d" % (tagp, ti, gi)))
    sc = [[] for _ in pop]; raw = [[] for _ in pop]
    with cf.ThreadPoolExecutor(par) as ex:
        futs = {ex.submit(run_group, tag, tr, [pop[i] for i in grp]): (tr, grp) for tr, grp, tag in jobs}
        for f in cf.as_completed(futs):
            tr, grp = futs[f]; res = f.result()
            if not res: continue
            for pos, i in enumerate(grp):
                if len(sc[i]) < len(tracks): sc[i].append(score(res[pos])); raw[i].append(res[pos])
    return sc, raw

def main():
    gens = int(sys.argv[1]) if len(sys.argv) > 1 else 40; par = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    st_path = os.path.join(HERE, "state.json")
    if os.path.exists(st_path):
        st = json.load(open(st_path)); pop = st["pop"]; g0 = st["gen"]; hist = st["hist"]
    else:
        pop = [dict(DEF)] + [rand_ind() for _ in range(POP - 1)]; g0 = 0; hist = []
    for gen in range(g0, gens):
        t0 = time.time()
        tracks = random.sample(TRACK_POOL, TRACKS_PER_GEN)
        sc, raw = evaluate(pop, tracks, par, "g%d" % gen)
        fit = [sum(s) / len(s) if s else -99 for s in sc]
        order = sorted(range(len(pop)), key=lambda i: -fit[i])
        best = pop[order[0]]
        rec = {"gen": gen, "tracks": tracks, "best_fit": fit[order[0]], "mean_fit": sum(fit) / len(fit), "min_fit": fit[order[-1]], "best": best, "sec": round(time.time() - t0)}
        hist.append(rec)
        print("gen %d tracks %s best %.1f mean %.1f (%d с)" % (gen, tracks, rec["best_fit"], rec["mean_fit"], rec["sec"]), flush=True)
        elite = [pop[i] for i in order[:4]]
        json.dump([pop[i] for i in order[:10]], open(os.path.join(HERE, "bot_genes_latest.json"), "w"), indent=1)   # лучшие 10
        json.dump({"gen": gen, "best": best, "fit": fit[order[0]]}, open(os.path.join(HERE, "best.json"), "w"), indent=1)
        newpop = list(elite)
        while len(newpop) < POP:
            a = pop[min(random.sample(range(POP), 3), key=lambda i: order.index(i))]; b = pop[min(random.sample(range(POP), 3), key=lambda i: order.index(i))]
            newpop.append(mutate(cross(a, b)))
        pop = newpop
        if gen % 5 == 4:                                     # проверка на трассах, которых не было в обучении
            vs, _ = evaluate(elite[:1] * 10, VALID[:1], par, "v%d" % gen)
            rec["valid"] = sum(vs[0]) / max(1, len(vs[0])) if vs and vs[0] else None
            print("   проверка на новой трассе: %s" % rec["valid"], flush=True)
        json.dump({"pop": pop, "gen": gen + 1, "hist": hist}, open(st_path, "w"))
if __name__ == "__main__": main()
