from pathlib import Path
import ast,hashlib,json,re,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
N=Q/'assembly_v1';N.mkdir()
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_horse_rig_sources_20261019')
P=E/'prepared_assembly_v1';P.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
inspection=json.loads((Q/'source_inspection_v1.json').read_text())
by_file={x['file']:x for x in inspection['sources']}
chosen={'body':'body_v1','fore_upper':'fore_upper_v2','fore_lower':'fore_lower_v1','hind_upper':'hind_upper_v2','hind_lower':'hind_lower_v2'}
template=(R/'qa/gongsun_sheng_mounted_walk_20261019/native_sw_v1/actual/images/horse_no_reins_v2.png.import').read_text()
textures={}
for key,name in chosen.items():
    src=Q/'native_originals'/f'{name}.png';row=by_file[src.relative_to(Q).as_posix()];assert sha(src)==row['sha256']
    rel=f'images/{key}.png';dst=P/rel;dst.parent.mkdir(exist_ok=True);shutil.copyfile(src,dst)
    descriptor=template.replace('horse_no_reins_v2.png',key+'.png')
    descriptor=re.sub(r'uid="[^"]+"\n','',descriptor)
    (P/(rel+'.import')).write_text(descriptor,encoding='utf-8',newline='\n')
    textures[key]={'file':rel,'canonical_source':src.relative_to(R).as_posix(),'sha256':row['sha256'],'rgba8_sha256':row['rgba8_sha256']}
anchors={
 'fore_upper':[[[290,140],[435,555]],[[335,140],[220,555]],[[305,140],[360,545]],[[340,140],[320,545]]],
 'fore_lower':[[[365,125],[350,570]],[[275,125],[300,570]],[[350,115],[340,550]],[[275,115],[290,560]]],
 'hind_upper':[[[325,165],[312,495]],[[305,165],[350,495]],[[315,150],[325,480]],[[330,150],[325,480]]],
 'hind_lower':[[[390,125],[360,570]],[[270,125],[300,570]],[[365,120],[340,550]],[[285,120],[315,550]]],
}
views=[{'direction':d,'near_side':side,'fore_root':f,'hind_root':h,'floor_y':floor} for d,side,f,h,floor in [
 ('se','R',[435,402],[185,405],620),('sw','L',[204,402],[483,405],620),
 ('ne','R',[465,330],[188,320],550),('nw','L',[165,330],[447,320],550)]]
data={'scope':'Four-direction complete horse layer assembly diagnostic. Manual fixed anchors, independent LF/RF/LH/RH, diagonal phase model, moving mathematical ground reference. Not rider, physical contact, actual Unit, chapter, compiled PCK, performance or adoption acceptance. Reuse each directional leg painting for near and far legs is an unqualified art interpretation.','textures':textures,'anchors':anchors,'views':views,'source_basis':'qa/gongsun_sheng_mounted_topology_20261018/source_basis.json','bbox_fitting_per_phase':False,'native_qualified':False,'production_adopted':False}
save(P/'inputs.json',data)
driver=(Q/'assembly_preview.gd.txt').read_bytes();(P/'preview.gd').write_bytes(driver);(N/'preview.gd.txt').write_bytes(driver)
(P/'project.godot').write_text('[application]\nconfig/name="Gongsun dedicated horse layer assembly diagnostic"\n[display]\nwindow/size/viewport_width=2560\nwindow/size/viewport_height=1440\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
old=(R/'qa/gongsun_sheng_mounted_walk_20261019/native_sw_rig_v2/run.py').read_text()
runner=old.replace('gongsun_sheng_mounted_walk_20261019','gongsun_sheng_horse_rig_sources_20261019').replace('native_sw_rig_v2','assembly_v1')
(N/'run.py').write_text(runner,encoding='utf-8',newline='\n');ast.parse(runner)
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
save(N/'prepared_binding.json',{'project':str(P),'files':files,'inputs':data,'native_executed':False})
print(json.dumps({'prepared_files':len(files),'directions':4,'legs_per_view':4,'production_adopted':False}))
