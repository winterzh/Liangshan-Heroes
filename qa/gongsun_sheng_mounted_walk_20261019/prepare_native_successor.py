"""Retain the first failure and prepare a successor with explicit lossless imports."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019')
prior_path=Path(json.loads((E/'latest_native_se_v1.json').read_text())['receipt']);prior=prior_path.parent
report=json.loads((prior/'report.json').read_text());assert len(report['failures'])==7 and all(x.startswith('native original RGBA ') for x in report['failures'])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
dest=Q/'native_se_v1/actual_failed';dest.mkdir();index=[]
for p in sorted(prior.rglob('*')):
    if not p.is_file() or '.godot' in p.relative_to(prior).parts:continue
    rel=p.relative_to(prior);target=dest/rel
    if target.suffix=='.gd':target=target.with_suffix('.gd.txt')
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);assert sha(p)==sha(target)
    index.append({'original':str(p),'archive':target.relative_to(dest).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
(dest/'archive_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
N=Q/'native_se_v2';N.mkdir()
shutil.copyfile(Q/'native_se_v1/preview.gd.txt',N/'preview.gd.txt')
run=(Q/'native_se_v1/run.py').read_text().replace('native_se_v1','native_se_v2')
(N/'run.py').write_text(run,encoding='utf-8',newline='\n')
prepare=(Q/'native_se_v1/prepare.py').read_text().replace('prepared_se_v1','prepared_se_v2')
needle='rows=[{'
assert prepare.count(needle)==1
extra='''# Match established project art imports: retain every original RGBA byte.
template=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018/prepared_v3/images/horse_no_reins_v2.png.import')
raw=template.read_text();assert 'process/fix_alpha_border=false' in raw and 'mipmaps/generate=true' in raw
old_ctex='horse_no_reins_v2.png-a4aceb1e8de5a112998a347bcd6d430f.ctex'
for key in sources:
    resource='res://images/'+key+'.png'
    ctex=key+'.png-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    desc=raw.replace(old_ctex,ctex).replace('res://images/horse_no_reins_v2.png',resource)
    (E/'images'/(key+'.png.import')).write_text(desc,encoding='utf-8',newline='\\n')
'''
prepare=prepare.replace(needle,extra+needle)
(N/'prepare.py').write_text(prepare,encoding='utf-8',newline='\n')
(N/'first_attempt_diagnosis.json').write_text(json.dumps({'prior_receipt':str(prior_path),'prior_receipt_sha256':sha(prior_path),'failed_checks':report['failures'],'observation':'All 7 original PNG byte checks pass, all 7 native RGBA checks fail; default descriptors enable fix_alpha_border, unlike project prior exact-RGBA descriptors. Successor explicitly disables border processing, keeps lossless format and enables project mipmaps.','same_painted_png_bytes':True,'checks_removed':False,'driver_unchanged_sha256':sha(N/'preview.gd.txt'),'old_project_and_receipt_unchanged':True,'new_native_executed':False},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'archived_failed_files':len(index),'successor':str(N)}))
