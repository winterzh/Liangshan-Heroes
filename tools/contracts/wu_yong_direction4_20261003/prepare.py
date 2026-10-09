"""Native-byte Wu Yong source lineage and AtlasTexture metadata; no image editing."""
from pathlib import Path
import json, hashlib, shutil, re
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
ASSET="assets/characters/wu_yong_direction4_20261003"
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):
 p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
jobs=json.loads((HERE/"jobs.json").read_text(encoding="utf-8"))
jobs+=json.loads((HERE/"jobs_extra.json").read_text(encoding="utf-8"))
retained=json.loads((HERE/"generation.json").read_text(encoding="utf-8")) if (HERE/"generation.json").exists() else {}
hashes={j["key"]:j["sha256"] for j in retained.get("jobs",[])}
ref="assets/characters/hero_portraits_20260926/wu_yong.png"
lineage={"schema":"native_direction4_generation_lineage_v1","character":"wu_yong","original_reference":{"path":ref,"sha256":sha(ROOT/ref)},"historical_source":"https://zh.wikisource.org/zh-hans/水滸傳_(70回本)/第13回","identity_note":"Preserves existing project scholar robe and feather fan; the novel describes copper chains, not the fan as his historical weapon.","jobs":[]}
lineage["jobs"].append({"key":"old_body","repository_path":"assets/anim/wu_yong_idle.png","sha256":sha(ROOT/"assets/anim/wu_yong_idle.png"),"method":"existing_project_reference","prompt":"Existing scholar identity and body rendering reference.","references":["original"]})
manifest={"schema":"native_direction4_spriteframes_v1","character":"wu_yong","sources":{},"poses":{},"states":{"idle":["idle"],"walk":["walk_a","walk_b"],"attack":["windup","strike","idle"],"hurt":["hurt"],"death":["fall","terminal","terminal"]},"resources":[],"scope":"32 independently authored low-frame poses; existing ranged gameplay and project portrait retained."}
for job in jobs:
 key=job["key"];native=Path(re.search(r"as (C:\\.*?\.png) by default",job["result"]).group(1))
 target=HERE/"generated"/(key+".png") if key.endswith("_rejected") else ROOT/ASSET/(key+".png")
 target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists():shutil.copyfile(native,target)
 expected=sha(native) if native.is_file() else hashes.get(key)
 assert expected and sha(target)==expected,"native source changed"
 im=Image.open(target);assert im.mode=="RGBA"
 alpha=im.getchannel("A");fraction=alpha.histogram()[0]/(im.width*im.height);assert fraction>.35
 refs=["original","old_body"] if key=="idle" else (["windup"] if key=="windup_edit_rejected" else ["idle"])
 status="rejected_hand_or_facing" if key.endswith("_rejected") else ("accepted_fronts_rejected_rears" if key=="windup" else "accepted")
 lineage["jobs"].append({"key":key,"repository_path":target.relative_to(ROOT).as_posix(),"sha256":sha(target),"method":"built_in_imagegen","generation_id":native.stem,"prompt":job["prompt"],"references":refs,"native_size":list(im.size),"mode":im.mode,"status":status})
 if key.endswith("_rejected"):continue
 manifest["sources"][key]={"path":target.relative_to(ROOT).as_posix(),"sha256":sha(target),"job":key,"mode":"RGBA","native_size":list(im.size),"import_limit":1536,"imported_size":list(im.size),"full_atlas":True,"alpha_zero_fraction":fraction,"unused_regions":[]}
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
 for i,d in enumerate(["se","sw","ne","nw"]):
  if key=="windup" and i>1:continue
  if key.startswith("windup_") and d!=key[-2:]:continue
  single=key.startswith("windup_")
  x=0 if single else (i%2)*(im.width//2);y=0 if single else (i//2)*(im.height//2)
  w=im.width if single else im.width//2;h=im.height if single else im.height//2
  bbox=alpha.crop((x,y,x+w,y+h)).point(lambda a:255 if a>16 else 0).getbbox();assert bbox
  l,t,r,b=bbox;virtual=max(w,h);padl=(virtual-w)//2;padt=(virtual-h)//2
  pose="windup" if single else key
  desired={"idle":.78,"walk_a":.78,"walk_b":.78,"windup":.83 if single else .78,"strike":.78,"hurt":.78,"fall":.59,"terminal":.82}[pose]
  scale=virtual*desired/((r-l) if key=="terminal" else (b-t))
  pivot=[(l+r)/2,b-7]
  manifest["poses"][pose+"_"+d]={"source":key,"region_raw":[x,y,w,h],"region":[x,y,w,h],"margin":[padl,padt,virtual-w,virtual-h],"virtual_size_imported":virtual,"pivot":pivot,"draw_offset_px":[virtual*.5-(padl+pivot[0]),virtual*.82-(padt+pivot[1])],"draw_scale":round(scale,6)}
manifest["sources"]["windup"]["unused_regions"]=[{"region":[0,627,1254,627],"reason":"Rear poses swap fan hand; replaced by independently drawn windup_ne and windup_nw."}]
for d in ["se","sw","ne","nw"]:
 for state in manifest["states"]:manifest["resources"].append(f"assets/anim/wu_yong_{state}_{d}.tres")
write(ROOT/"assets/direction4/wu_yong_20261003.json",manifest)
write(HERE/"generation.json",lineage)
print(json.dumps({"sources":len(manifest["sources"]),"poses":len(manifest["poses"]),"native_bytes_preserved":True}))

