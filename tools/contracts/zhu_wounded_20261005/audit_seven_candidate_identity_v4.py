"""Cross-check seven current candidate manifests and own-key runtime receipts."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for key,cn,manifest,source,unit in (
    ('shi_qian','时迁','walk_footclear_declared','walk_sources_footclear_declared','unit_motion_footclear'),
    ('shi_xiu','石秀','walk_footclear','walk_sources_footclear','unit_motion_identity_footclear'),
    ('qin_ming','秦明','walk_passing','walk_sources_passing','unit_motion_passing'),
    ('yang_lin','杨林','walk_passing','walk_sources_passing','unit_motion_passing'),
    ('huang_xin','黄信','walk_passing','walk_sources_passing','unit_motion_passing'),
    ('wang_ying','王英','walk_passing','walk_sources_passing','unit_motion_passing'),
    ('deng_fei','邓飞','walk_passing','walk_sources_passing','unit_motion_passing')):
    mp=ROOT/f'assets/direction4/zhu_wounded_{key}_20261006_{manifest}_v4.json';m=read(mp)
    sp=QA/f'{key}_{source}_v4.json';s=read(sp)
    up=QA/f'{key}_{unit}_v4.json';u=read(up)
    assert m['schema']=='native_direction4_spriteframes_v1' and m['revision']=='character_traits_v4'
    assert m['production_qualified'] is False and len(m['poses'])==20 and len(m['resources'])==8
    if 'candidate_only' in m:assert m['candidate_only'] is True
    assert m['states']=={'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']}
    assert s['passed'] and s['authored_poses']==20 and s['production_pngs']==len(m['sources'])
    assert u['complete'] and u['lock_released'] and u['input_sha_drift']==0 and u['identity_key']==key and not u['production_qualified']
    assert u['result']['passed'] and len(u['result']['checks'])==52 and all(c['passed'] for c in u['result']['checks'])
    assert len(u['result']['samples'])==len(u['captures'])==80
    inputs={v['path']:v['sha256'] for v in u['inputs']}
    for v in m['sources'].values():
        assert sha(ROOT/v['path'])==v['sha256']==inputs[v['path']]
        assert sha(ROOT/(v['path']+'.import'))==inputs[v['path']+'.import']
    for resource in m['resources']:assert sha(ROOT/resource)==inputs[resource]
    for sample in u['result']['samples']:
        assert len(sample['units'])==8
        for v in sample['units']:
            assert v['key']==key and v['hp']==v['max_hp']==110 and v['base_speed']==82 and v['atk']==0 and not v['hero'] and v['noncombat'] and v['slots']==0
            assert v['real_frames'] and v['directional']
    for d in ('se','sw','ne','nw'):
        assert f'idle_{d}_0' in u['result']['seen']
        for i in range(4):assert f'walk_{d}_{i}' in u['result']['seen']
    rows.append({'key':key,'name':cn,'manifest':mp.relative_to(ROOT).as_posix(),'manifest_sha256':sha(mp),
        'source_receipt':sp.relative_to(ROOT).as_posix(),'source_receipt_sha256':sha(sp),'source_checks':len(s['checks']),
        'native_sources':len(m['sources']),'poses':20,'resources':8,'unit_receipt':up.relative_to(ROOT).as_posix(),
        'unit_receipt_sha256':sha(up),'unit_checks':52,'unit_captures':80,'unit_input_drift':0,
        'identity_samples':640,'hp':110,'speed':82,'attack':0,'hero':False,'noncombat':True,'slots':0,
        'qualification_marker':'candidate_only=true and production_qualified=false' if 'candidate_only' in m else 'legacy explicit production_qualified=false; no candidate_only field'})
out={'scope':'Selected candidate source/resource SHA and own-key detached Unit identity coherence only; not original Battle/campaign/production/UI or continuous gait acceptance',
     'characters':rows,'native_sources':sum(r['native_sources'] for r in rows),'authored_poses':140,'identity_samples':4480,
     'passed':True,'production_qualified':False,'remaining':['Continuous foot/cloth review','Original rescue/return/terminal/production/UI','Save compatibility and cross-process reward once','Full eight chapters/nine modes/performance/Android qualification']}
p=QA/'rescued_seven_candidate_identity_audit_v4.json';assert not p.exists();p.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
table=['# 获救七人候选证据矩阵','',
    '本表核对当前选用资源与自身key的脱离Battle实际Unit夹具。全部仍为候选，不能代表原关卡、连续动作、生产/UI、续玩或平台完成。',
    '', '| 人物 | 原生源/姿态 | 来源检查 | Unit检查/截图 | 身份逐帧/输入漂移 |', '| --- | --- | --- | --- | --- |']
for r in rows:table.append(f"| {r['name']} | {r['native_sources']}/20 | {r['source_checks']} | 52/80 | 640/0 |")
table.extend(['','每人HP110、速度82、攻击0、非英雄、非战斗、技能槽0；选用PNG、导入描述与8份资源逐一匹配实际Unit冻结输入。时迁declared清单仅补弃用区域声明，与实际运行资源等价的证据仍保留。石秀旧44项收据不改写，本次新增独立52项身份补验。',
    '', '详细路径、当前SHA与逐项范围见qa/zhu_wounded_20261005/rescued_seven_candidate_identity_audit_v4.json。各角色失败原图、请求、生成/缓存守卫失败均保留。',
    '', '下一步连续足点/衣装审核、原解救/撤回/终态、生产查询一致性、任务UI及跨进程保存奖励一次性；生产/存档接入次序见RESCUED_ART_INTEGRATION_20261006.md。完整八关、九模式、约10分钟性能/尾帧和Android真机/平台目标仍开放。'])
(ROOT/'docs/RESCUED_ART_CANDIDATE_MATRIX_20261006.md').write_text('\n'.join(table)+'\n',encoding='utf-8')
print(json.dumps({'characters':7,'native_sources':out['native_sources'],'poses':140,'identity_samples':4480,'passed':True,'production_qualified':False}))
