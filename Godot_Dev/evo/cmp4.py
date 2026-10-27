import json, os, subprocess, sys, concurrent.futures as cf, importlib.util
sp=importlib.util.spec_from_file_location("evo","evo.py"); evo=importlib.util.module_from_spec(sp); sp.loader.exec_module(evo)
GEN=sys.argv[1] if len(sys.argv)>1 else "genes_run4_final.json"; EXTRA=sys.argv[2:]   # доп. аргументы игры, напр. flip
g=json.load(open(GEN))[:10]
for x in g: x["lift_brake"]=0.0
def run(tag,track):
    gp=os.path.join(evo.TMP,tag+"_g.json"); op=os.path.join(evo.TMP,tag+"_r.json"); json.dump(g,open(gp,"w"))
    if os.path.exists(op): os.remove(op)
    subprocess.run(["nice","-n","10",evo.GODOT,"--headless","--path",evo.PROJ,"--","evo",*EXTRA,"track=%d"%track,"len=%d"%evo.LEN_KM,"secs=%d"%evo.SECS,"genes="+gp,"tuning="+evo.SNAP,"out="+op],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try: return json.load(open(op))
    except Exception: return None
tracks=[9,21,34,4,11,30]; res={}
with cf.ThreadPoolExecutor(4) as ex:
    fs={ex.submit(run,"cmp4_%s_%d"%("_".join(EXTRA) or "base",t),t):t for t in tracks}
    for f in cf.as_completed(fs): res[fs[f]]=f.result()
R=[r for t in tracks for r in (res[t] or [])]; k=max(len(R),1)
f_=lambda key:sum((r.get(key) or 0) for r in R)/k
print(EXTRA or "base",dict(n=len(R),prog_km=round(sum((r.get("prog") or 0)/1000 for r in R)/k,1),out=round(f_("out"),2),hits=round(f_("hits"),2),resp=round(f_("resp"),2)))
