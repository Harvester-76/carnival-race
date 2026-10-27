import json, os, sys, concurrent.futures as cf
sys.argv=[sys.argv[0]]
import importlib.util
sp=importlib.util.spec_from_file_location("evo","evo.py"); evo=importlib.util.module_from_spec(sp); sp.loader.exec_module(evo)
old=json.load(open("../../Godot_Test/bot_genes.json"))[:10]; new=json.load(open("bot_genes_latest.json"))[:10]
tracks=[9,21,34,4,11,30]
jobs=[(n,g,t) for t in tracks for n,g in (("old",old),("new",new))]
res={}
with cf.ThreadPoolExecutor(4) as ex:
    fs={ex.submit(evo.run_group,"cmp_%s_%d"%(n,t),t,g):(n,t) for n,g,t in jobs}
    for f in cf.as_completed(fs): res[fs[f]]=f.result()
out={}
for n in ("old","new"):
    rows=[evo.score(r) for t in tracks for r in (res[(n,t)] or [])]
    ab=[(r.get("above") or 0) for t in tracks for r in (res[(n,t)] or [])]
    pr=[(r.get("prog") or 0)/1000 for t in tracks for r in (res[(n,t)] or [])]
    hi=[(r.get("hits") or 0) for t in tracks for r in (res[(n,t)] or [])]
    k=max(len(rows),1)
    out[n]=dict(n=len(rows),score=sum(rows)/k,prog_km=sum(pr)/k,above_s=sum(ab)/k,hits=sum(hi)/k)
    out[n]["per_track"]=[sum(evo.score(r) for r in res[(n,t)])/10 if res[(n,t)] else None for t in tracks]
json.dump(out,open("cmp_result.json","w"),indent=1)
