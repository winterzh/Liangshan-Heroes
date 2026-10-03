"""Build Huyan's native-byte lineage and authored AtlasTexture metadata.
No image is written or changed. Pillow is used only for alpha inspection.
"""
from pathlib import Path
import json, hashlib, shutil, re
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
ASSET="assets/characters/hu_yanzhuo_direction4_20261003"
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):
 p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
jobs=json.loads((HERE/"jobs.json").read_text(encoding="utf-8"))
retained=json.loads((HERE/"generation.json").read_text(encoding="utf-8")) if (HERE/"generation.json").exists() else {}
retained_hashes={j["key"]:j["sha256"] for j in retained.get("jobs",[])}
lineage={"schema":"native_direction4_generation_lineage_v1","character":"hu_yanzhuo",
 "original_reference":{"path":"assets/characters/hero_portraits_aligned_20260926/hu_yanzhuo.png"},
 "historical_source":"https://ctext.org/wiki.pl?chapter=810331&if=en","jobs":[]}
lineage["original_reference"]["sha256"]=sha(ROOT/lineage["original_reference"]["path"])
lineage["jobs"].append({"key":"old_body","repository_path":"assets/anim/hu_yanzhuo_idle.png","sha256":sha(ROOT/"assets/anim/hu_yanzhuo_idle.png"),"method":"existing_project_reference","prompt":"Old mounted body rendering style only; mace/costume not retained.","references":["original"]})
manifest={"schema":"native_direction4_spriteframes_v1","character":"hu_yanzhuo","sources":{},"poses":{},
 "states":{"idle":["idle"],"walk":["walk_a","walk_b"],"attack":["windup","strike","idle"],"hurt":["hurt"],"death":["fall","terminal","terminal"]},
 "resources":[],"scope":"32 distinct low-frame poses, true RGBA, independently authored views; full smooth animation and balance not claimed."}
for job in jobs:
 key=job["key"]
 native=Path(re.search(r"as (C:\\.*?\.png) by default",job["result"]).group(1))
 target=HERE/"generated/walk_rejected.png" if key=="walk" else ROOT/ASSET/(key+".png")
 target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists(): shutil.copyfile(native,target)
 expected=sha(native) if native.is_file() else retained_hashes.get(key)
 if expected is None or sha(target)!=expected: raise ValueError("Native image changed or portable lineage missing")
 im=Image.open(target); assert im.mode=="RGBA"
 alpha=im.getchannel("A"); fraction=alpha.histogram()[0]/(im.width*im.height)
 assert fraction>.35
 lineage["jobs"].append({"key":key,"repository_path":target.relative_to(ROOT).as_posix(),"sha256":sha(target),
 "method":"built_in_imagegen","generation_id":native.stem,"prompt":job["prompt"],
 "references":["original","old_body"] if key=="idle" else ["idle"],
 "native_size":list(im.size),"mode":im.mode,"status":"rejected_sampling_overlap" if key=="walk" else ("accepted_except_rejected_regions" if key=="attack" else "accepted")})
 if key in ("portrait","walk"): continue
 manifest["sources"][key]={"path":target.relative_to(ROOT).as_posix(),"sha256":sha(target),"job":key,"mode":"RGBA","native_size":list(im.size),"import_limit":1536,"imported_size":list(im.size),"full_atlas":True,"alpha_zero_fraction":fraction,"unused_regions":[]}
 # Engine assigns UID on the first isolated import; copy that descriptor back before final freeze.
 descriptor=Path(str(target)+".import")
 if not descriptor.exists():
  path="res://"+target.relative_to(ROOT).as_posix()
  cache="res://.godot/imported/"+target.name+"-"+hashlib.md5(path.encode()).hexdigest()+".ctex"
  template=(ROOT/"assets/characters/guan_zhanzi_direction4_20260915/ne_fall.png.import").read_text()
  template=re.sub(r'uid="[^"]*"\n',"",template)
  template=re.sub(r'res://\.godot/imported/[^"]+',cache,template)
  template=re.sub(r'source_file="[^"]*"','source_file="'+path+'"',template)
  template=re.sub(r'process/size_limit=\d+',"process/size_limit=1536",template)
  descriptor.write_text(template,encoding="utf-8",newline="\n")
dirs=["se","sw","ne","nw"]
cells={}
for key in manifest["sources"]:
 w,h=manifest["sources"][key]["native_size"]
 cols,rows=(1,1) if key=="ne_strike" else ((2,2) if key in ("idle","hurt","walk_a","walk_b","windup") else (2,4))
 cells[key]=[[int(c*w/cols),int(r*h/rows),int((c+1)*w/cols)-int(c*w/cols),int((r+1)*h/rows)-int(r*h/rows)] for r in range(rows) for c in range(cols)]
cells["walk_b"][1]=[627,0,627,648];cells["walk_b"][3]=[627,648,627,606]
cells["windup"]=[[0,0,627,628],[627,0,627,645],[0,628,627,626],[627,645,627,609]]
cells["attack"][1]=[512,0,512,430]
cells["attack"][3]=[512,430,512,380]
cells["attack"][7]=[512,1190,512,346]
cells["death"]=[[30,67,444,341],[502,140,513,252],[25,421,462,325],[499,486,511,267],[40,782,419,341],[482,843,529,261],[58,1143,418,318],[500,1211,508,252]]
def add(pose,d,key,cell):
 region=cells[key][cell]; x,y,w,h=region
 im=Image.open(ROOT/manifest["sources"][key]["path"])
 alpha=im.getchannel("A").crop((x,y,x+w,y+h))
 bbox=alpha.point(lambda a:255 if a>16 else 0).getbbox()
 assert bbox
 l,t,r,b=bbox
 virtual=max(w,h); padl=(virtual-w)//2; padt=(virtual-h)//2
 # Preserve standing body height; raised rods extend above head and terminal horse is lower.
 desired={"idle":.78,"walk_a":.78,"walk_b":.78,"windup":.96,"strike":.80,"hurt":.83,"fall":.61,"terminal":.43}[pose]
 scale=virtual*desired/(b-t)
 pivot=[(l+r)/2,b-7]
 margin=[padl,padt,virtual-w,virtual-h]
 manifest["poses"][pose+"_"+d]={"source":key,"region_raw":region,"region":region,"margin":margin,
 "virtual_size_imported":virtual,"pivot":pivot,"draw_offset_px":[virtual*.5-(padl+pivot[0]),virtual*.82-(padt+pivot[1])],"draw_scale":round(scale,6)}
for i,d in enumerate(dirs):
 add("idle",d,"idle",i);add("hurt",d,"hurt",i)
 add("walk_a",d,"walk_a",i);add("walk_b",d,"walk_b",i)
 add("windup",d,"windup",i)
 add("strike",d,"ne_strike",0) if d=="ne" else add("strike",d,"attack",i*2+1)
 add("fall",d,"death",i*2)
 terminal_cell={"se":3,"sw":1,"ne":5,"nw":7}[d]
 add("terminal",d,"death",terminal_cell)
 for state in manifest["states"]: manifest["resources"].append(f"assets/anim/hu_yanzhuo_{state}_{d}.tres")
manifest["sources"]["attack"]["unused_regions"]=[{"region":[0,0,512,1536],"reason":"Four windups touch adjacent poses; replaced by independent windup.png."},{"region":[512,810,512,380],"reason":"NE strike faced NW; independently regenerated as ne_strike.png."}]
boxes=cells["death"]
xs=sorted({0,1024}|{r[0] for r in boxes}|{r[0]+r[2] for r in boxes})
ys=sorted({0,1536}|{r[1] for r in boxes}|{r[1]+r[3] for r in boxes})
for xa,xb in zip(xs,xs[1:]):
 for ya,yb in zip(ys,ys[1:]):
  if not any(r[0]<=xa and xb<=r[0]+r[2] and r[1]<=ya and yb<=r[1]+r[3] for r in boxes):
   manifest["sources"]["death"]["unused_regions"].append({"region":[xa,ya,xb-xa,yb-ya],"reason":"Unused atlas margin or detached transparent-edge fragment; no sprite sampled."})
write(ROOT/"assets/direction4/hu_yanzhuo_20261003.json",manifest)
write(HERE/"generation.json",lineage)
print(json.dumps({"sources":len(manifest["sources"]),"poses":len(manifest["poses"]),"portrait":"true native alpha","native_bytes_preserved":True}))

