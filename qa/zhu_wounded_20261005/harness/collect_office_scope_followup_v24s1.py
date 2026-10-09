from pathlib import Path
import json, hashlib, datetime
ROOT=Path('E:/ChatGPT/水浒'); Q=ROOT/'qa/zhu_wounded_20261005'
RUN=Path('E:/ChatGPT/qa-world-restore-20261007/daming_admit_v24s_2a817e70')
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def row(p):return {'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)}
files=[]
def cp(p,rel):
    d=ROOT/rel;d.parent.mkdir(parents=True,exist_ok=True)
    with d.open('xb') as f:f.write(p.read_bytes())
    files.append(row(d));return d
main=read(RUN/'receipt.json')
assert main['complete'] and main['json_boundary_regression_requested'] is True
assert main['json_boundary_report']['checks']==533 and len(main['json_boundary_report']['cases'])==11
manifest=read(RUN/'isolated_slot_and_lifecycle_manifest.json')
for item in manifest:
    p=Path(item['path']);assert p.is_relative_to(RUN/'profile') and sha(p)==item['sha256'] and p.stat().st_size==item['bytes']
j=next(r for r in manifest if '/local_runs/' in r['path'].replace('\\','/'))
jpath=Path(j['path']); journal=read(jpath);jp=json.loads(journal['payload']);raw=journal['payload'].encode('utf-8')
assert set(journal)=={'app','magic','owner','payload','payload_bytes','payload_sha256','previous_sha256','revision','version'}
assert journal['magic']=='LH_LOCAL_CONTINUE_LIFECYCLE' and journal['app']=='5088120' and journal['owner']=='1'
assert len(raw)==int(journal['payload_bytes']) and hashlib.sha256(raw).hexdigest()==journal['payload_sha256']
assert journal['previous_sha256']=='0'*64 and int(journal['revision'])==1
assert jp['schema']=='local_continue_lifecycle_v1' and jp['state']=='active' and jp['generation']==1 and jp['victory'] is False
assert jp['context']=={'mode':'defense','level_id':'','waves':30}
assert sorted(p.name for p in jpath.parent.iterdir())==['record_0000000001.json']
slotdir=None
bindings=[]
for n in [1,2]:
    r=next(r for r in manifest if '/local_runs/' not in r['path'].replace('\\','/') and Path(r['path']).name==f'record_{n:010d}.json')
    p=Path(r['path']);slotdir=p.parent;env=read(p);payload=json.loads(env['payload'])
    assert p.read_bytes()==(RUN/'retained_slots'/f'generation_{n}.json').read_bytes()
    assert payload['binding']=={'kind':'uncredited','token':jp['token'],'receipt_sha256':sha(jpath)}
    assert payload['context']=={'mode':'campaign','level_id':'level8','waves':0}
    bindings.append(payload['binding'])
assert sorted(p.name for p in slotdir.iterdir())==['record_0000000001.json','record_0000000002.json']
assert not list((RUN/'profile').rglob('writing/owner.json'))
cp(jpath,'qa/zhu_wounded_20261005/daming_admit_active_local_journal_v24s1.json')
public_audit=Path('E:/ChatGPT/native_ownership_json_v24q_proposal/INDEPENDENT_READONLY_PUBLIC_IDENTITY_V24S.json')
assert sha(public_audit)=='5ee693102e84b4aded2e8547ce4e991862b31fd9954b3cb04d2f662a512babeb'
cp(public_audit,'qa/zhu_wounded_20261005/independent_readonly_public_identity_v24s1.json')
P=Path('E:/ChatGPT/daming_safe_retreat_v25_proposal')
pins={'daming_safe_retreat_component_negative_v25.gd':'ccb4abd78fe1277c2475f53ace9ff4c5c133e1e8ca4ebb59fa6ac30c65ab134a',
      'daming_safe_retreat_component_negative_v25.tscn':'46adcee78872917b6518dc186ba1a055ff3bf00694835b723e51447282ba22fc',
      'COMPONENT_NEGATIVE_INTERFACE_V25.json':'8ce5e3379c9a6502682cb8a3c6fb38261e708888492a0126c8677f7ad4d4e160',
      'COMPONENT_STATIC_V25.json':'1b529da1ab2d2899fc54d6225b67cd09aff879d8833e7b0378ba067e90a13212',
      'COMPONENT_README_V25.md':'aa79538dc672db6816588d185490c316810d4e0037fa862ce6eebbe9ef2c0436'}
for name,digest in pins.items():
    assert sha(P/name)==digest
    cp(P/name,'qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25/'+name)
notice='''## 2026-10-08 同步范围补充：冻结工程与本地完整目录分别记录

三进程通过范围为原冻结输入raw5041/distinct5037及明确补齐依赖、元数据后的隔离runtime5102。四个公开修复文件与该批精确同SHA；不能将这份资格解释为当前本地完整目录的运行资格。独立只读清单发现本地整树5042文件与隔离工程有24个额外草稿素材、84个依赖/元数据缺项及4个UID差异；草稿未混入本轮提交。公司使用既有bootstrap/重新导入后重新建立完整身份与私有profile，不能沿用家里content_version。完整差异见qa/zhu_wounded_20261005/independent_readonly_public_identity_v24s1.json。

额外核对实际active local journal头、原文件SHA、token、世代1/2 binding及存档副本相等，没有writing锁。原LocalLifecycle固定context为defense/空章/30，与本次Slot的campaign/level8/0不同；这是当前API的实际行为，只证明原声明的本地生命周期与binding，不证明逐战役context或奖励语义。原数据保留，未修改ledger。原生profile目录保留作为证据；释放的是进程及写锁。

独立Unit/Contract/Pair组件负例已准备181用例×2路线，尚未解析/运行；不把362计划行计为通过。单人撤离producer、五组实际live cast负例、自然结局/持久战役进度等仍待完成。完整计划继续按办公室交接推进。

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','DEVELOPMENT_AUDIT_20261007.md']:
    p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8')
    assert s.startswith('## 2026-10-08 凌晨：大名府办理半程三进程磁盘续玩通过')
    p.write_bytes((notice+s).encode());files.append(row(p))
for name in ['HANDOFF_20261007_OFFICE.md','NATIVE_OWNERSHIP_JSON_REPAIR_20261007.md','DAMING_SAFE_RETREAT_DESIGN_20261008.md']:
    p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8')
    pos=s.index('\n\n')+2;s=s[:pos]+notice+s[pos:]
    s=s.replace('本轮提交以远端 stable 最新 SHA 及同步收据为准。最终提交以远端分支及同步收据为准。','本轮提交以远端 stable 最新 SHA 及同步收据为准。')
    p.write_bytes(s.encode());files.append(row(p))
audit={'schema':'office_admission_scope_and_journal_audit_v24s1','created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
       'actual_json_boundary_requested':True,'json_boundary_checks':533,'owned_slot_checks':76,
       'private_frozen_runtime_files':5102,'public_complete_tree_native_qualified':False,'qualified_public_source_paths':4,
       'journal_raw_sha256':sha(jpath),'journal_context':jp['context'],'slot_context':{'mode':'campaign','level_id':'level8','waves':0},
       'journal_matches_original_API_default':True,'journal_context_equals_slot':False,
       'binding_receipt_SHA_and_token_exact_in_both_generations':True,'retained_slots_match_actual_bytes':True,
       'actual_slot_head_revision':2,'actual_journal_head_revision':1,'writing_lock_present':False,
       'native_or_source_changed':False,'component_native_qualified':False,'files':files}
with (Q/'office_admission_scope_and_journal_audit_v24s1.json').open('x',encoding='utf-8') as f:
    json.dump(audit,f,ensure_ascii=False,indent=2);f.write('\n')
print(json.dumps({'files':len(files)+1,'journal_verified':True,'public_whole_tree_qualified':False,'component_planned_rows':362}))
