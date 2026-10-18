"""A skinning experiment over original painted pixels; no bitmap writes."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'native_sw_rig_v1';N.mkdir()
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019/prepared_sw_rig_v1')
prior=json.loads((Q/'native_sw_v1/prepared_binding.json').read_text());P=Path(prior['project']);E.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in prior['files']:
    src=P/row['path'];assert sha(src)==row['sha256'];dst=E/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
data=prior['inputs'];data['scope']='SW diagnostic skinning experiment only. Fixed columns show original source poses; LIVE column applies two-bone near-fore correction to passing A. All horse PNG bytes/UVs and other source regions preserved. Not actual Unit, complete gait/anatomy/ground-contact/performance acceptance.'
data['rig']={'texture':'horse_passing_a_sw_v3','shoulder':[877,401],'knee':[900,490],'hoof':[935,588],'target':[948,548],'spacing':10,'mask':[[860,408],[902,408],[913,445],[935,480],[957,523],[974,563],[970,604],[906,610],[891,572],[889,530],[875,485],[860,440]]}
(E/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(Q/'native_sw_v1/preview.gd.txt').read_text()
driver=driver.replace('\troot.add_child(stage)','\tvar rig: Dictionary=stage.prepare_rig()\n\tcheck(float(rig.upper_length_error)<.001 and float(rig.lower_length_error)<.001,"two bone segment lengths retained")\n\tcheck(float(rig.hoof_target_error)<.001,"manual hoof anchor reaches target")\n\tcheck(int(rig.outside_mask_changed_vertices)==0 and int(rig.moved_vertices)>0,"local mesh correction leaves all outside vertices unchanged")\n\troot.add_child(stage)',1)
driver=driver.replace('"texture_references":refs,','"texture_references":refs,"rig_diagnostics":stage.rig_info,',1)
needle='\t\tvar rr: Array=data.textures[key].selected_region;'
assert driver.count(needle)==1
driver=driver.replace(needle,'\t\tif use_rig and key==String(data.rig.texture):draw_mesh(rig_mesh,textures[key]);return\n'+needle,1)
driver=driver.replace('\t\t\tvar selected: int=','\t\t\tuse_rig=i==4\n\t\t\tvar selected: int=',1)
driver=driver.replace('"LIVE PROCESS / "','"LIVE + LEG RIG / "').replace('"FIXED PHASE / "','"RAW SOURCE / "')
driver=driver.replace('SW source comparison only. Horse/rider PNG bytes unchanged; runtime rein uses original painted leather material.','SW skinning diagnostic. Only LIVE passing A uses the leg mesh. Original painted PNG/UV data are retained.')
driver+='\n'+(Q/'rig_sw_stage.gd.txt').read_text()
(N/'preview.gd.txt').write_text(driver,encoding='utf-8',newline='\n');(E/'preview.gd').write_text(driver,encoding='utf-8',newline='\n')
run=(Q/'native_sw_v1/run.py').read_text().replace('native_sw_v1','native_sw_rig_v1');(N/'run.py').write_text(run,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(E).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(E.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(E),'files':files,'inputs':data,'native_executed':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'prepared':True,'source_png_unchanged':True,'rig':data['rig']}))
