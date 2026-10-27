"""Preserve terminal Daming evidence; business payloads and executables stay local."""
from pathlib import Path
import hashlib,json,os,subprocess,importlib.util
import sys
sys.dont_write_bytecode=True

R=Path(__file__).resolve().parents[2]
S=R/'.godot/daming_projectile_flow_20261027/20261027_125326_b7c20f07'
Q=R/'qa/campaign_progress_recovery_20261026'
COMMIT='9939346d1fa9704f1406a959d03dff9723eff57c'
def xp(path): return Path('\\\\?\\'+str(Path(path).absolute()))
def raw(path): return xp(path).read_bytes()
def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(raw(path))
def write(path,data): xp(path.parent).mkdir(parents=True,exist_ok=True);xp(path).write_bytes(data)
def save(path,data):write(path,(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode())
helper=R/'.godot/persistence19_protocol_20261027/archive_protocol.py'
spec=importlib.util.spec_from_file_location('daming_inner_archive_core',helper)
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
receipt=read(S/'receipt.json')
assert receipt['child_process_terminal'] and receipt['lock_released'] and receipt['lock_ownership_confirmed'] and receipt['engine_lane_idle'] and receipt['final_identity_passed'] and not receipt['cleanup_errors']
assert receipt['complete'] is False and receipt['source_flow_chain_passed'] is False and len(receipt['reports'])==1
assert receipt['reports'][0]['checks']==307 and receipt['reports'][0]['failures']==['first actual safety callback completed fight remains healthy']
complete=receipt['complete'];D=Q/'daming_continue_candidate/evidence'/('flow_inner_complete_20261027_125326' if complete else 'flow_flank_failure_20261027_125326')
xp(D).mkdir(parents=True,exist_ok=False)
entries=[];objects={};pins=[];excluded=[];refs={}; reference_manifests={}
def add(path,role,target=None):
    b=raw(path);digest=sha(b);assert path.suffix.lower() in {'.py','.gd','.json','.md','.log','.cs','.txt'} and b'\0' not in b
    b.decode('utf-8-sig')
    if digest not in objects:
        rel=target or 'raw/objects/'+digest+'/'+path.name;write(D/rel,b);assert raw(D/rel)==b
        entries.append({'path':rel,'bytes':len(b),'sha256':digest,'kind':'original_bytes','source':str(path),'role':role})
        objects[digest]={'kind':'this_archive_original','archive_path':rel,'sha256':digest,'bytes':len(b)}
    return objects[digest]
gaobase=Q/'projectile_filter_candidate/evidence/terminal_core_success_20261027_091102'
loadbase=Q/'projectile_filter_candidate/evidence/tools_load_seed_failure_20261027_094230'
def register(base,path,digest,size):
    b=raw(path);assert sha(b)==digest and len(b)==size
    manifest=base/'manifest.json';msha=sha(raw(manifest));reference_manifests[str(manifest.relative_to(R)).replace('\\','/')]=msha
    refs[digest]={'kind':'prior_committed_archive','archive_path':str(path.relative_to(R)).replace('\\','/'),'bytes':size,'sha256':digest,'git_commit':COMMIT,'manifest_path':str(manifest.relative_to(R)).replace('\\','/'),'manifest_sha256':msha}
gm=read(gaobase/'source_map.json')
for item in gm['unique_objects']:
    kind=item['kind']
    if kind=='exact_git_blob':refs[item['sha256']]=item;continue
    path=(gaobase if kind=='this_archive_original' else R)/item['archive_path']
    base=gaobase if kind=='this_archive_original' else (R/item['manifest_path']).parent if kind=='prior_committed_archive' else (R/item['source_map']).parent
    register(base,path,item['sha256'],item['bytes'])
for item in read(loadbase/'source_map.json')['mappings']:register(loadbase,loadbase/item['archive_path'],item['sha256'],item['bytes'])
add(S/'receipt.json','original_host_receipt','raw/receipt.json')
add(Path(__file__),'archive_builder','archive_builder.py')
reports=[]
for row in receipt['reports']:
    path=Path(row['path']);assert path.is_relative_to(S);d=read(path)
    assert sha(raw(path))==row['sha256'] and len(d['checks'])==row['checks'] and d['passed']==row['passed']
    reports.append({'role':row['first_role'],'mode':row['mode'],'pid':d['pid'],'checks':len(d['checks']),'passed':d['passed'],'failures':d['failures'],'exit_reason':d.get('exit_reason'),'report_sha256':row['sha256']})
    add(path,'actual_report','raw/'+str(path.relative_to(S)).replace('\\','/'))
for step in receipt['steps']:
    path=S/step['first_role']/step['mode']/(step['mode']+'.log');assert sha(raw(path))==step['log_sha256']
    add(path,'actual_log','raw/'+str(path.relative_to(S)).replace('\\','/'))
fixture_metadata={}
for role,data in receipt['roles'].items():
    ref=data.get('closed_a_fixture')
    if ref:
        path=Path(ref['path']);assert path==S/'closed_a'/role/'descriptor.json';assert sha(raw(path))==ref['sha256']
        descriptor=read(path);assert descriptor['complete']
        fixture_metadata[role]=descriptor
        add(path,'closed_a_descriptor_only','raw/closed_a/'+role+'/descriptor.json')
for name,digest in receipt['pinned_files'].items():
    path=Path(name)
    if path.suffix.lower()=='.exe':
        excluded.append({'source':name,'sha256':digest,'kind':'native_hash_only','read_or_copied':False});continue
    parts=path.relative_to(S).parts if path.is_relative_to(S) else ()
    if len(parts)>=4 and parts[0]=='closed_a' and parts[2]=='slot_scope':
        role=parts[1];row=fixture_metadata[role]['frozen_inventory']['files']['/'.join(parts[3:])]
        assert row['sha256']==digest
        excluded.append({'source':name,'sha256':digest,'bytes':row['bytes'],'kind':'business_payload_hash_only','read_or_copied':False,'metadata_source':str(S/'closed_a'/role/'descriptor.json')});continue
    assert path.is_relative_to(R),name
    source=path if path.is_relative_to(S) else S/'runner_inputs'/path.relative_to(R)
    b=raw(source);assert sha(b)==digest
    resolution=objects.get(digest) or refs.get(digest)
    if resolution is None:resolution=add(source,'actual_frozen_named_input')
    objects[digest]=resolution
    pins.append({'source':name,'frozen_input':str(source),'bytes':len(b),'sha256':digest,'resolution_object_sha256':digest})
assert len(pins)+len(excluded)==len(receipt['pinned_files'])
if complete:
    assert len(reports)==8 and len({x['pid'] for x in reports})==8 and all(x['passed'] and not x['failures'] for x in reports)
    assert receipt['eight_stages_passed'] and receipt['source_flow_chain_passed']
# Verify every referenced object against its exact fixed Git blob, not merely
# the matching working-tree archive. No physical profile/EXE read is allowed.
reference_items=[v for v in objects.values() if v['kind']!='this_archive_original']
specs=[v['git_commit']+':'+v.get('git_path',v.get('archive_path','')) for v in reference_items]
for item,blob in zip(reference_items,a.git_blobs(specs)):
    assert a.sha(blob['data'])==item['sha256'] and len(blob['data'])==item['bytes']
    if 'git_blob' in item:assert item['git_blob']==blob['git_blob']
    item['git_blob']=blob['git_blob']
for name,digest in reference_manifests.items():
    blob=a.git_blobs([COMMIT+':'+name])[0];assert a.sha(blob['data'])==digest
failure_report=read(Path(receipt['reports'][0]['path']))
failed=next(row for row in failure_report['checks'] if not row['passed'])
state=failed['detail'];assert state['phase']==3 and state['actors']['shi']['hp']==0 and state['actors']['shi']['dying']
assert state['actors']['lu']['hp']==360 and state['actors']['lu']['outcome']==''
assert not state['events'].get('daming_lu_safe') and not state['events'].get('daming_shi_safe')
assert len(state['selected_escort_alive'])==8 and all(x['hp']>0 for x in state['selected_escort_alive'])
assert failure_report['save_exit_observed'] is False and failure_report['checkpoint']=={}
summary={'schema':'daming_current_flow_archive_summary_v1','original_run':str(S),'complete':complete,'source_flow_chain_passed':receipt['source_flow_chain_passed'],'actual_reports':reports,'actual_checks':sum(x['checks'] for x in reports),'actual_passed_checks':sum(sum(y['passed'] for y in read(Path(x['path']))['checks']) for x in receipt['reports']),'steps':[{k:v for k,v in x.items() if k!='command'} for x in receipt['steps']],'closed_a_roles':list(fixture_metadata),'receipt_pin_count':len(receipt['pinned_files']),'native_or_business_payload_read_or_copied':False,'original_19_faults_qualified':False,'full_61_qualified':False,'public_continue_qualified':False,'native_sdk_qualified':False,'human_acceptance':False,'error':receipt.get('error')}
summary['failure_boundary']={'first_role':'lu','selected_first_id':'28','dead_other_id':'29','before_first_exit_tick':'22524','failed_tick':state['logical_tick'],'no_first_safe':True,'no_save':True,'original_100_and_140_checks_passed':True,'actual_killer_not_recorded':True}
summary['lateral_escape_succeeded']=True
summary['movement_evidence']={k:{name:value for name,value in next(x[k] for x in failure_report['route_observations'] if k in x).items() if name!='state'} for k in ('first_exit_flank_result','first_exit_crossing_result')}
assert summary['movement_evidence']['first_exit_flank_result']['reached'] is True
assert summary['movement_evidence']['first_exit_crossing_result']['first']['state']==1
mapping={'schema':'daming_current_flow_source_map_v1','receipt_pin_count':len(receipt['pinned_files']),'pin_paths':pins,'excluded_payloads':excluded,'unique_objects':list(objects.values()),'reference_manifests':reference_manifests,'whole_source_hash_performed':False}
save(D/'summary.json',summary);save(D/'source_map.json',mapping)
text=f'''# 大名府双角色真实 Flow：2026-10-27 12:53:26

本包保留实际批次的原始宿主收据、报告、日志与冻结命名输入。complete={str(complete).lower()}；实际{len(reports)}个报告、{summary['actual_checks']}项检查，终态和各案结果见summary.json，原始失败不会改写为通过。

本批使用b22完整冻结及自己的首次冷导入，只执行普通救援、护送和原存档／继续入口。本轮内圈三护卫实际达到每伤员100px并通过清障后原140px保护条件；随后卢俊义实际普通侧向移动成功，出口指令也安装独立ST_MOVE／home／非空path；原safe回调尚未完成时石秀实际阵亡，未任一safe／未保存。运动记录保留真实path和状态，不将map_open的整段可通行诊断误作终点本身封格。原观察未记录killer，不指定杀伤来源或移动阻塞原因。实际source_private屏幕外GL结果不等于公开入口、桌面键鼠、SDK、发行版或全游戏验收。52负例、完整61阶段和原19类故障仍分别验证。

source_map映射全部命名pins；实际文本输入逐项从本次冻结runner_inputs或run内原件读SHA，复用既有已提交归档／精确Git blob的原字节。closed_a仅复制descriptor元数据，物理slot_scope业务文件及EXE只保留宿主pin与元数据SHA，未读取或复制；不复制profile、缓存或完整项目。完整来源后验和进程/锁终态以原宿主收据为准，归档未重算整项目。原始报告保留其完整QA观察与typed快照，不作事实回填。
'''
write(D/'README.md',text.encode())
for name in ('summary.json','source_map.json','README.md'):
    b=raw(D/name);entries.append({'path':name,'bytes':len(b),'sha256':sha(b),'kind':'derived_metadata'})
save(D/'manifest.json',{'schema':'daming_current_flow_archive_manifest_v1','original_run':str(S),'entries':entries})
actual=[]
for folder,dirs,names in os.walk(xp(D),onerror=lambda e:(_ for _ in ()).throw(e)):
    actual.extend(Path(folder,n).relative_to(xp(D)).as_posix() for n in names)
assert set(actual)=={x['path'] for x in entries}|{'manifest.json'}
for row in entries:assert len(raw(D/row['path']))==row['bytes'] and sha(raw(D/row['path']))==row['sha256']
print(json.dumps({'archive':str(D),'files':len(actual),'bytes':sum(len(raw(D/n)) for n in actual),'manifest_sha256':sha(raw(D/'manifest.json')),'actual_checks':summary['actual_checks'],'complete':complete},ensure_ascii=False))
