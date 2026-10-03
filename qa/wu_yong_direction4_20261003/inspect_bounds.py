from pathlib import Path
import json
from PIL import Image
repo=Path(__file__).resolve().parents[2]
m=json.loads((repo/"assets/direction4/wu_yong_20261003.json").read_text(encoding="utf-8"))
rows=[]
for key,p in m["poses"].items():
 im=Image.open(repo/m["sources"][p["source"]]["path"])
 x,y,w,h=p["region_raw"]
 a=im.getchannel("A").crop((x,y,x+w,y+h)).point(lambda v:255 if v>16 else 0)
 l,t,r,b=a.getbbox()
 rows.append({"pose":key,"bounds":[l,t,r,b],"cell":[w,h],"minimum_empty_margin":min(l,t,w-r,h-b),"passed":min(l,t,w-r,h-b)>0})
out={"passed":all(r["passed"] for r in rows),"poses":rows,"scope":"Read-only proof that alpha>16 foreground does not touch any cell boundary; anatomy reviewed in native engine renders."}
(Path(__file__).parent/"bounds_audit.json").write_text(json.dumps(out,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"passed":out["passed"],"minimum_margin":min(r["minimum_empty_margin"] for r in rows),"failed":[r for r in rows if not r["passed"]]}))
