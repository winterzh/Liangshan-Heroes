from pathlib import Path
import subprocess,hashlib,json,ast,re,sys,collections,base64
sys.stdout.reconfigure(encoding='utf-8')
R=Path('D:/AI项目/水浒/开发工程');E=Path('D:/CodexEvidence/shuihu/pending_source_sync_20261020')
def g(*a):return subprocess.check_output(['git',*a],cwd=R).decode('utf-8')
files=[s for s in g('ls-files','--others','--exclude-standard','-z').split('\0') if s]
assert len(files)==107
tracked=set(s for s in g('ls-files','-z').split('\0') if s)
rows=[];py=[];imports=[];jsons=[];sources=[];uids=collections.defaultdict(list)
for n in files:
 p=R/n;b=p.read_bytes();t=b.decode('utf-8-sig')
 assert len(b)<5_000_000 and not p.is_symlink() and p.stat().st_nlink==1,n
 assert not re.search(r'gh[pousr]_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}',t),n
 row={'path':n,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'scope':'resource_import_settings' if n.endswith('.import') else 'qa_candidate_source_not_adopted'}
 if n.endswith('.import'):
  source=n[:-7];assert source in tracked and (R/source).is_file(),n
  source_file=re.search(r'^source_file="res://(.+)"$',t,re.M).group(1)
  assert source_file==source,n
  uid=re.search(r'^uid="([^"]+)"$',t,re.M).group(1);uids[uid].append(n)
  imports.append({'path':n,'tracked_source':source,'uid':uid})
 if n.endswith('.py'):ast.parse(t,filename=n);py.append(n)
 if n.endswith('.json'):json.loads(t);jsons.append(n)
 rows.append(row)
for n in tracked:
 if n.startswith('assets/') and n.endswith('.import'):
  t=(R/n).read_text(encoding='utf-8-sig');m=re.search(r'^uid="([^"]+)"$',t,re.M)
  if m and m.group(1) in uids:uids[m.group(1)].append(n)
collisions={uid:n for uid,n in uids.items() if len(n)>1}
assert not collisions,collisions
for ver in ['rig_v1','rig_v2','rig_v3']:
 n=f'qa/gongsun_sheng_mounted_draw_20261019/{ver}/prepared_binding.json';v=json.loads((R/n).read_text(encoding='utf-8'))
 assert v['native_executed'] is False
 for x in v['inputs']['textures'].values():
  src=R/x['canonical_source'];assert src.is_file() and hashlib.sha256(src.read_bytes()).hexdigest()==x['sha256'],str(src)
  sources.append({'binding':n,'canonical_source':x['canonical_source'],'sha256':x['sha256']})
q=R/'qa/yang_lin_continuous_leg_preview_20261019';fixture=json.loads((q/'fixture.json').read_text(encoding='utf-8'))
assert fixture['production_adopted'] is False and fixture['native_accepted'] is False
for x in fixture['sources']:
 assert hashlib.sha256((R/x['file']).read_bytes()).hexdigest()==x['sha256']
 sources.append({'binding':'qa/yang_lin_continuous_leg_preview_20261019/fixture.json','canonical_source':x['file'],'sha256':x['sha256']})
js=subprocess.run(['C:/Program Files/nodejs/node.exe','--check',str(q/'viewer.js')],capture_output=True,text=True)
assert js.returncode==0,js.stderr
html=(q/'viewer.html').read_text(encoding='utf-8');template=(q/'viewer.template.html').read_text(encoding='utf-8');viewer=(q/'viewer.js').read_text(encoding='utf-8')
embedded={**fixture,'sources':[{**x,'image':'data:image/png;base64,'+base64.b64encode((R/x['file']).read_bytes()).decode('ascii')} for x in fixture['sources']]}
expected=template.replace('__FIXTURE__',json.dumps(embedded,ensure_ascii=False,separators=(',',':'))).replace('__VIEWER_SCRIPT__',viewer)
html_matches=html==expected
assert html_matches,'Embedded candidate differs from recorded fixture/source/template'
report={'source_head':g('rev-parse','HEAD').strip(),'original_pending_files':len(files),'original_pending_bytes':sum(x['bytes'] for x in rows),'import_settings':len(imports),'qa_candidate_files':len(files)-len(imports),'python_ast_parse_count':len(py),'json_parse_count':len(jsons),'javascript_syntax_check':True,'import_sources_tracked_and_present':True,'uid_collision_count':len(collisions),'canonical_texture_bindings_checked':len(sources),'embedded_html_exact_source_fixture_match':html_matches,'native_tests_run':False,'visual_acceptance_granted':False,'production_adopted':False,'steam_actions':False,'files':rows,'source_bindings':sources}
(E/'intake_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['files','source_bindings']},ensure_ascii=False,indent=2))
