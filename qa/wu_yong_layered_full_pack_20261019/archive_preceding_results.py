"""Retain exact raw prior native evidence; exclude caches and private profiles."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def archive(src,dest):
    rows=[];dest.mkdir(parents=True,exist_ok=False)
    for p in sorted(src.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(src)
        if any(x in ['.godot','profile','profiles','identity_profile','visual_profile'] for x in rel.parts):continue
        if p.suffix not in ['.png','.json','.log','.gd']:continue
        target=dest/rel
        if target.suffix=='.gd':target=target.with_suffix('.gd.txt')
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);assert sha(p)==sha(target)
        rows.append({'original':str(p),'archive':target.relative_to(dest).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
    (dest/'archive_index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    return rows
u=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit_v2/actual_native/20261019_001140_9eb6f327')
g=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018/native_resources/20261019_001442_0b5be04d')
ur=archive(u,R/'qa/wu_yong_push_gait_20261018/actual_unit_v2')
gr=archive(g,R/'qa/gongsun_sheng_mounted_layers_20261018/actual_native_v3')
print(json.dumps({'wu_files':len(ur),'gongsun_files':len(gr)}))
