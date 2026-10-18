"""Supersede an unexecuted preparation with distinct texture cache paths."""
from pathlib import Path
import hashlib,json,re,shutil
Q=Path(__file__).resolve().parent
old=Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2_20261018')
E=Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2b_20261018')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not E.exists() and not (old/'native_resources').exists()
binding=json.loads((old/'prepared_binding.json').read_text());P=E/'prepared'
for row in binding['frozen']:
    src=Path(binding['project'])/row['path'];assert sha(src)==row['sha256']
    dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
for path in (P/'images').glob('*.png.import'):
    name=path.name.removesuffix('.import');resource='res://images/'+name
    cache='res://.godot/imported/'+name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    content=path.read_text();content=re.sub(r'res://\.godot/imported/[^"\n]+\.ctex',cache,content)
    path.write_text(content,encoding='utf-8')
targets=[re.search(r'^path="([^"]+)"',p.read_text(),re.M).group(1) for p in (P/'images').glob('*.import')]
assert len(targets)==len(set(targets))==3
binding['project']=str(P);binding['frozen']=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
binding['supersedes_unexecuted_preparation']=str(old/'prepared_binding.json')
save(E/'prepared_binding.json',binding);save(Q/'idle_repair_v2b_binding.json',binding)
save(Q/'idle_repair_v2_static_rejection.json',{'native_executed':False,'reason':'All three copied import descriptors pointed at the same cache path; rejected statically before running Godot. Original preparation retained unchanged.','superseded':str(old),'successor':str(E),'distinct_successor_cache_paths':targets})
print(json.dumps({'prepared':str(P),'unique_texture_imports':len(targets)}))
