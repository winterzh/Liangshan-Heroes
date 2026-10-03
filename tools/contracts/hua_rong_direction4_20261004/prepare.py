"""Native Hua Rong lineage and AtlasTexture metadata. Copies bytes, never edits pixels."""
from pathlib import Path
import hashlib, json, re, shutil
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
ASSET = "assets/characters/hua_rong_direction4_20261004"
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, obj):
 p.parent.mkdir(parents=True, exist_ok=True)
 p.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+"\n", encoding="utf-8", newline="\n")
jobs = json.loads((HERE/"jobs.json").read_text(encoding="utf-8"))
previous = json.loads((HERE/"generation.json").read_text(encoding="utf-8")) if (HERE/"generation.json").exists() else {}
hashes = {j["key"]:j["sha256"] for j in previous.get("jobs", [])}
by_key = {j["key"]:j for j in jobs}
refs = set()
pending = [j["key"] for j in jobs if not j["key"].endswith("_rejected")]
while pending:
 key = pending.pop()
 for ref in by_key[key]["references"]:
  if ref not in refs:
   refs.add(ref)
   if ref in by_key: pending.append(ref)
original = "assets/characters/hero_portraits_aligned_20260926/hua_rong.png"
lineage = {"schema":"native_direction4_generation_lineage_v1","character":"hua_rong","original_reference":{"path":original,"sha256":sha(ROOT/original)},"identity_note":"Existing aligned silver armor, white robe, pale-blue trim, high ponytail and bow identity. Current ranged infantry gameplay retained.","jobs":[{"key":"old_body","repository_path":"assets/anim/hua_rong_idle.png","sha256":sha(ROOT/"assets/anim/hua_rong_idle.png"),"method":"existing_project_reference","prompt":"Existing game body rendering reference.","references":["original"]}]}
manifest = {"schema":"native_direction4_spriteframes_v1","character":"hua_rong","sources":{},"poses":{},"states":{"idle":["idle"],"walk":["walk_a","walk_b"],"attack":["windup","strike","idle"],"hurt":["hurt"],"death":["fall","terminal","terminal"]},"resources":[],"scope":"32 independent low-frame poses; exact existing ranged infantry and aligned portrait retained."}
bounds = []
for job in jobs:
 key = job["key"]
 native = Path(re.search(r"as (C:\\.*?\.png) by default",job["result"]).group(1))
 rejected = key.endswith("_rejected")
 retained = not rejected or key in refs
 target = HERE/"generated"/(key+".png") if rejected else ROOT/ASSET/(key+".png")
 expected = sha(native) if native.is_file() else hashes.get(key)
 if retained:
  target.parent.mkdir(parents=True,exist_ok=True)
  if not target.exists(): shutil.copyfile(native,target)
  assert expected and sha(target)==expected, key+" native changed"
 lineage["jobs"].append({"key":key,"repository_path":target.relative_to(ROOT).as_posix() if retained else "","sha256":expected,"method":"built_in_imagegen","generation_id":native.stem,"prompt":job["prompt"],"references":job["references"],"status":"rejected_unused" if rejected else "accepted"})
 if rejected: continue
 im = Image.open(target)
 assert im.mode=="RGBA"
 alpha = im.getchannel("A")
 fraction = alpha.histogram()[0]/(im.width*im.height)
 assert fraction>.35
 manifest["sources"][key] = {"path":target.relative_to(ROOT).as_posix(),"sha256":sha(target),"job":key,"mode":"RGBA","native_size":list(im.size),"import_limit":1536,"imported_size":list(im.size),"full_atlas":True,"alpha_zero_fraction":fraction,"unused_regions":[]}
 assert max(im.size)<=1536
 lineage["jobs"][-1].update(native_size=list(im.size),mode=im.mode)
 descriptor = Path(str(target)+".import")
 if not descriptor.exists():
  path = "res://"+target.relative_to(ROOT).as_posix()
  cache = "res://.godot/imported/"+target.name+"-"+hashlib.md5(path.encode()).hexdigest()+".ctex"
  template=(ROOT/"assets/characters/guan_zhanzi_direction4_20260915/ne_fall.png.import").read_text()
  template=re.sub(r'uid="[^"]*"\n',"",template)
  template=re.sub(r'res://\.godot/imported/[^"]+',cache,template)
  template=re.sub(r'source_file="[^"]*"','source_file="'+path+'"',template)
  template=re.sub(r'process/size_limit=\d+',"process/size_limit=1536",template)
  descriptor.write_text(template,encoding="utf-8",newline="\n")
 for i,d in enumerate(["se","sw","ne","nw"]):
  single = key.startswith(("windup_","strike_"))
  if single and d!=key[-2:]: continue
  pose=key.rsplit("_",1)[0] if single else key
  x=0 if single else (i%2)*(im.width//2)
  y=0 if single else (i//2)*(im.height//2)
  w=im.width if single else im.width//2
  h=im.height if single else im.height//2
  bbox=alpha.crop((x,y,x+w,y+h)).point(lambda a:255 if a>16 else 0).getbbox()
  assert bbox
  l,t,r,b=bbox
  clearance=min(l,t,w-r,h-b)
  assert clearance>=4, (key,d,"visible pixels touch edge",bbox)
  virtual=max(w,h);padl=(virtual-w)//2;padt=(virtual-h)//2
  desired={"idle":.78,"walk_a":.78,"walk_b":.78,"windup":.85 if d in ("se","sw") else .95,"strike":.85 if d in ("se","sw") else .95,"hurt":.78,"fall":.56,"terminal":.82}[pose]
  scale=virtual*desired/((r-l) if pose=="terminal" else (b-t))
  pivot=[(l+r)/2,b-7]
  manifest["poses"][pose+"_"+d]={"source":key,"region_raw":[x,y,w,h],"region":[x,y,w,h],"margin":[padl,padt,virtual-w,virtual-h],"virtual_size_imported":virtual,"pivot":pivot,"draw_offset_px":[virtual*.5-(padl+pivot[0]),virtual*.82-(padt+pivot[1])],"draw_scale":round(scale,6)}
  bounds.append({"pose":pose+"_"+d,"bbox":list(bbox),"clearance_px":clearance,"single_canvas":single,"passed":True})
for d in ["se","sw","ne","nw"]:
 for state in manifest["states"]: manifest["resources"].append(f"assets/anim/hua_rong_{state}_{d}.tres")
assert len(manifest["poses"])==32
write(ROOT/"assets/direction4/hua_rong_20261004.json",manifest)
write(HERE/"generation.json",lineage)
write(ROOT/"qa/hua_rong_direction4_20261004/bounds_audit.json",{"passed":True,"checks":bounds,"scope":"Read-only alpha margins; single canvases need no neighboring-cell separation. Anatomy/facing require visual review."})
print(json.dumps({"production_pngs":len(manifest["sources"]),"independent_poses":len(manifest["poses"]),"native_bytes_preserved":True}))
