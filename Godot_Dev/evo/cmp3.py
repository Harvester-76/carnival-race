import json, concurrent.futures as cf, importlib.util
sp=importlib.util.spec_from_file_location("evo","evo.py"); evo=importlib.util.module_from_spec(sp); sp.loader.exec_module(evo)
g=json.load(open("bot_genes_latest.json"))[:10]
for x in g: x["lift_brake"]=0.0
tracks=[9,21,34,4,11,30]; res={}
with cf.ThreadPoolExecutor(4) as ex:
    fs={ex.submit(evo.run_group,"cmp_dv_%d"%t,t,g):t for t in tracks}
    for f in cf.as_completed(fs): res[fs[f]]=f.result()
R=[r for t in tracks for r in (res[t] or [])]; k=max(len(R),1)
o=json.load(open("cmp_result4.json"))
o["dive"]=dict(n=len(R),score_old_formula=sum((r.get("prog") or 0)/1000-0.6*(r.get("hits") or 0)-6*(r.get("resp") or 0)-0.3*(r.get("lost") or 0)-0.4*(r.get("above") or 0) for r in R)/k,score_new_formula=sum(map(evo.score,R))/k,prog_km=sum((r.get("prog") or 0)/1000 for r in R)/k,above_s=sum((r.get("above") or 0) for r in R)/k,hits=sum((r.get("hits") or 0) for r in R)/k,resp=sum((r.get("resp") or 0) for r in R)/k,out=sum((r.get("out") or 0) for r in R)/k)
json.dump(o,open("cmp_result5.json","w"),indent=1)
