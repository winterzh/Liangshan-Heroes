from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_horse_rig_sources_20261019')
N=Q/'assembly_v4';N.mkdir();P=E/'prepared_assembly_v4';P.mkdir()
old=json.loads((Q/'assembly_v3/prepared_binding.json').read_text());source=Path(old['project']);data=old['inputs']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in old['files']:
    src=source/row['path'];assert sha(src)==row['sha256'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
lookup={Path(x['file']).stem:x for x in json.loads((Q/'source_inspection_v3.json').read_text())['sources']}
template=(source/'images/body.png.import').read_text()
for key,name in [('body','body_no_tail_v1'),('tail','tail_v1')]:
    row=lookup[name];src=Q/row['file'];assert sha(src)==row['sha256'];rel=f'images/{key}.png';shutil.copyfile(src,P/rel)
    if key=='tail':(P/(rel+'.import')).write_text(template.replace('body.png','tail.png'),encoding='utf-8',newline='\n')
    data['textures'][key]={'file':rel,'canonical_source':src.relative_to(Q.parents[1]).as_posix(),'sha256':row['sha256'],'rgba8_sha256':row['rgba8_sha256']}
for view in data['views']:view.pop('near_hind_front_start_y')
data['neutral_body_rise']=16.0
data['scope']='Four-direction complete horse assembly: independent painted body/tail/shin/hoof, tail drawn behind articulated legs and root-cover body; model slowdown/hold/restart with a raised neutral body pose. Selected sole-line anchors are level in stance, not proof of full painted sole contact, physical collision, non-sliding brake/acceleration, human continuous gait, mounted Unit, chapter, package or performance acceptance.'
(P/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(source/'preview.gd').read_text();needle='2.0*cos(t/cycle*TAU*2.0)*speed';assert driver.count(needle)==2
driver=driver.replace(needle,needle+'-float(data.neutral_body_rise)*(1.0-speed)')
oldblock='''\t\tfor i in [1,3,0,2]:paint_leg(d,poses[i])
\t\tvar source:=Rect2(cell(d),Vector2(627,627));var bob: float=2.0*cos(t/cycle*TAU*2.0)*speed-float(data.neutral_body_rise)*(1.0-speed)
\t\tdraw_texture_rect_region(textures.body,Rect2(Vector2(0,bob),Vector2(627,627)),source)
\t\tpaint_leg(d,poses[2],float(data.views[d].near_hind_front_start_y))'''
newblock='''\t\tvar source:=Rect2(cell(d),Vector2(627,627));var bob: float=2.0*cos(t/cycle*TAU*2.0)*speed-float(data.neutral_body_rise)*(1.0-speed)
\t\tdraw_texture_rect_region(textures.tail,Rect2(Vector2(0,bob),Vector2(627,627)),source)
\t\tfor i in [1,3,0,2]:paint_leg(d,poses[i])
\t\tdraw_texture_rect_region(textures.body,Rect2(Vector2(0,bob),Vector2(627,627)),source)'''
assert driver.count(oldblock)==1;driver=driver.replace(oldblock,newblock)
driver=driver.replace(',clip_y: float=-10000.0','').replace(',clip_y)',')')
driver='\n'.join(line for line in driver.split('\n') if 'if clip_y>' not in line)
assert 'clip_y' not in driver
driver=driver.replace(' / separate hoof / ',' / separate tail + hoof / ')
driver=driver.replace('Separate shin and hoof layers. Fixed manual sole line stays level during stance; normal slowdown / hold / restart.','Independent tail, shin and hoof layers. Raised neutral body pose; normal slowdown / hold / restart.')
for p in [P/'preview.gd',N/'preview.gd.txt']:p.write_text(driver,encoding='utf-8',newline='\n')
runner=(Q/'assembly_v3/run.py').read_text().replace('assembly_v3','assembly_v4');ast.parse(runner);(N/'run.py').write_text(runner,encoding='utf-8',newline='\n')
queue=(Q/'assembly_v3/wait_then_run.py').read_text().replace('assembly_v3','assembly_v4');ast.parse(queue);(N/'wait_then_run.py').write_text(queue,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(P),'files':files,'inputs':data,'native_executed':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'prepared_files':len(files),'painted_textures':len(data['textures']),'runtime_piece_clipping':False}))
