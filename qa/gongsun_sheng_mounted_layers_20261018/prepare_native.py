"""Freeze the three-layer native preview; no production resources or scripts changed."""
from pathlib import Path
import hashlib,json,re,shutil
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018');P=E/'prepared'
assert not P.exists();(P/'images').mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
data=json.loads((Q/'layer_bindings_v2.json').read_text());template=(R/'assets/characters/liu_tang_pushcart_20261017/cart_only.png.import').read_text()
for row in data['textures'].values():
    src=R/row['canonical_source'];assert sha(src)==row['sha256'];dst=P/row['file'];shutil.copyfile(src,dst);assert sha(dst)==row['sha256']
    resource='res://'+row['file'];cache='res://.godot/imported/'+dst.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    descriptor=template.replace('res://assets/characters/liu_tang_pushcart_20261017/cart_only.png',resource);descriptor=re.sub(r'res://\.godot/imported/[^"\n]+\.ctex',cache,descriptor)
    descriptor='\n'.join(line for line in descriptor.splitlines() if not line.startswith('uid='))+'\n';Path(str(dst)+'.import').write_text(descriptor,encoding='utf-8')
shutil.copyfile(Q/'layer_bindings_v2.json',P/'inputs.json');shutil.copyfile(Q/'native_preview.gd.txt',P/'preview.gd')
(P/'project.godot').write_text('[application]\nconfig/name="Gongsun fixed mount layers QA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n',encoding='utf-8')
frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
binding={'prepared':True,'native_executed':False,'project':str(P),'frozen':frozen,'scope':data['scope'],'textures':len(data['textures']),'expected_captures':4,'must_wait_for_existing_wu_queue_terminal':True}
for out in [E/'prepared_binding.json',Q/'native_prepared_binding.json']:
    with out.open('x',encoding='utf-8') as f:f.write(json.dumps(binding,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'prepared':str(P),'files':len(frozen),'textures':len(data['textures']),'states':len(data['states']),'native_executed':False}))
