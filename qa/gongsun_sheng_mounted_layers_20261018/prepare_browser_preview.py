"""Copy unmodified PNGs for a local runtime canvas preview, never export edited art."""
from pathlib import Path
import hashlib,json,shutil
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018/browser')
assert not E.exists();(E/'images').mkdir(parents=True)
sources={'horse.png':Q/'native_originals/horse_idle_v1.png','rider_recoil.png':Q/'native_originals/rider_drawn_recoil_v1.png','rider_recover.png':Q/'native_originals/rider_drawn_recover_v1.png','original_recoil.png':R/'qa/gongsun_sheng_mounted_hurt_sources_20261018/native_originals/drawn_recoil_v1.png','original_recover.png':R/'qa/gongsun_sheng_mounted_hurt_sources_20261018/native_originals/drawn_recover_v1.png'}
rows=[]
for name,src in sources.items():
    dst=E/'images'/name;shutil.copyfile(src,dst);assert src.read_bytes()==dst.read_bytes();rows.append({'original':str(src),'file':'images/'+name,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()})
shutil.copyfile(Q/'layer_preview.html',E/'index.html')
with (Q/'browser_inputs.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'scope':'Browser canvas composition only; no Godot/Unit acceptance, no PNG pixel edits.','project':str(E),'files':rows},ensure_ascii=False,indent=2)+'\n')
print(E)
