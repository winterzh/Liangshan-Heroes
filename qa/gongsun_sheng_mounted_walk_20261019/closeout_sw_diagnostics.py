from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];K=R/'qa/gongsun_sheng_horse_rig_sources_20261019'
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    if p.exists():
        assert json.loads(p.read_text(encoding='utf-8'))==d, f'Existing evidence differs: {p}'
        return
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def archive(kind,viewed,decision):
    receipt_path=Path(json.loads((E/f'latest_{kind}.json').read_text())['receipt']);P=receipt_path.parent;receipt=json.loads(receipt_path.read_text());assert receipt['complete']
    D=Q/kind/'actual';D.mkdir(exist_ok=True);index=[]
    for p in sorted(P.rglob('*')):
        if not p.is_file() or '.godot' in p.relative_to(P).parts:continue
        rel=p.relative_to(P);dst=D/rel
        if dst.suffix=='.gd':dst=dst.with_suffix('.gd.txt')
        dst.parent.mkdir(parents=True,exist_ok=True)
        if not dst.exists():shutil.copyfile(p,dst)
        assert sha(p)==sha(dst)
        index.append({'original':str(p),'archive':dst.relative_to(D).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
    save(D/'archive_index.json',index)
    report=json.loads((P/'report.json').read_text());sequence=[x['phase'] for x in report['phase_transitions']]
    assert len(sequence)>=16 and all(sequence[i]==(sequence[i-1]+1)%4 for i in range(1,len(sequence)))
    save(Q/kind/'visual_assessment.json',{'native_checks':len(report['checks']),'raw_screenshots':4,'directly_viewed':[{'file':f'se_phase_{i}.png','sha256':sha(D/f'se_phase_{i}.png')} for i in viewed],'actual_direction':'sw','filename_prefix_is_historical':True,'phase_sequence':sequence,'visual_decision':decision,'render_or_math_pass_is_not_visual_acceptance':True,'full_goal_complete':False,'production_adopted':False})
    return {'case':kind,'native_checks':len(report['checks']),'viewed':len(viewed),'decision':decision}
cases=[archive('native_sw_v1',[0,1,2,3],'Unaccepted: near fore hoof remains low in passing A; anatomy/limb-root depth/clearance/trajectory not qualified.'),archive('native_sw_rig_v1',[1],'Rejected: two-bone endpoint/lengths pass, but whole-texture skinning tears/distorts knee region. Outside-mask vertex check is not a pixel-position or visual proof.'),archive('native_sw_rig_v2',[1],'Rejected: rigid source pieces and exact body-area partition pass, but joint seam and extraneous painted fragment remain visible. Not an anatomy/continuity/performance pass.')]
for kind,marker in [('native_sw_v1','queue_sw_v1'),('native_sw_rig_v1','queue_sw_rig_v1')]:
    state=json.loads((E/marker/'state.json').read_text());assert state['state']=='terminal'
    save(Q/kind/'completed_queue.json',state)
old=json.loads((Q/'prompt_set_v2.json').read_text());rows=[json.loads(p.read_text()) for p in sorted(Q.glob('source_*.json'))];assert len(rows)==17
previous={x['key']:x for x in old['originals']}
for row in rows:
    assert sha(Q/row['file'])==row['sha256']
    if row['key'] in previous:
        row.update({k:previous[row['key']][k] for k in ['selection','directions']})
    else:
        row.update(selection='diagnostic_source_only' if row['key'] in ['horse_passing_a_sw_v3','horse_passing_b_sw_v1'] else 'not_selected',directions=['sw'])
    row.update(production_adopted=False,full_gait_accepted=False)
save(Q/'prompt_set_v3.json',{'mode':'builtin_imagegen','raw_sources':17,'new_this_batch':5,'originals':rows,'diagnostics':cases,'production_adopted':False,'full_goal_complete':False})
kit=[];selected={'body_v1','fore_upper_v2','fore_lower_v1','hind_upper_v2','hind_lower_v2'}
for p in sorted(K.glob('source_*.json')):
    if p.name=='source_inspection_v1.json':continue
    row=json.loads(p.read_text());assert sha(K/row['file'])==row['sha256'];row.update(selection='unassembled_candidate' if row['key'] in selected else 'superseded_wrong_segment',production_adopted=False,native_qualified=False);kit.append(row)
assert len(kit)==8
inspection=json.loads((K/'source_inspection_v1.json').read_text());assert all(not v['visible_touches_cell_edge'] for x in inspection['sources'] for v in x['views'].values())
save(K/'prompt_set.json',{'mode':'builtin_imagegen','raw_sources':8,'candidate_parts':sorted(selected),'originals':kit,'assembled':False,'native_qualified':False,'production_adopted':False,'full_goal_complete':False})
pres=[]
for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/name).read_text());changed=[x['path'] for x in data if sha(R/x['path'])!=x['sha256']];assert not changed;pres.append({'manifest':name,'files':len(data),'changed':changed})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(K/'preservation.json',{'manifests':pres,'hud_unchanged':True,'runtime_changes':False})
def prepend(p,s):
    old=p.read_bytes();head=s.encode('utf-8')
    if not old.startswith(head):p.write_bytes(head+old)
head='## 2026-10-19 坐骑西南向诊断与专用肢段原稿\n\n'
body='本轮内置imagegen新绘13份原PNG：旧步态目录新增5份（累计17），[新专用图层](../qa/gongsun_sheng_horse_rig_sources_20261019/README.md)8份、五份组装候选/三份错误分段修订。马身、前后腿上下段各有四向图；只读边界检查无可见裁边，但体量/关节点/遮挡未注册、尚未组装或原生资格化。原图、精确提示与来源SHA全部保留，不用本地绘画改PNG。\n\n西南四姿势原生45项/四图全目检，换相正常但近前蹄过低，未接受自然步态。整图蒙皮48项虽骨长/蹄点通过仍有膝部拉扯；刚性裁片49项虽分区/刚性检查通过仍有接缝/碎片，两案仅直接查看关键相位1即视觉拒绝。新图层不替这些旧结果补签。后继按RIG_ASSEMBLY_NEXT.md先组装完整四腿/四向、地面参照与连续换步，再验骑手/缰绳、实际Unit/适用章回/包内/性能，不能把组件PNG或数学通过当功能。\n\n当前129运行/16保护/81外来及HUD零变化，吴用上一批采用保持；本批生产接入0、无活跃本任务引擎/队列，main/Steam未操作。原著仍仅第54回身份、冠服、短须绦、单剑和黄花马；关节/配色/时序为美术解释，无新增剧情伤亡。全库人物、场景、战船、特效、UI、性能、抽剑回收及全部未完动作继续。\n\n'
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,head+body)
prepend(R/'docs/DIRECTORY_INDEX.md','## 2026-10-19 专用马身与肢段组装入口\n\n- qa/gongsun_sheng_horse_rig_sources_20261019/：8内置原PNG、五候选、精确提示/来源、只读边界，尚未组装/原生/采用。\n- 同目录RIG_ASSEMBLY_NEXT.md：完整四腿/四向、固定关节标定、地面参照、骑手/尾部遮挡及下一步实际验证范围。\n- qa/gongsun_sheng_mounted_walk_20261019/prompt_set_v3.json：17原PNG；新增5份和西南45/48/49项的原生诊断分别留档；后两案均视觉拒绝。\n- 同目录native_sw_v1/actual、native_sw_rig_v1/actual、native_sw_rig_v2/actual：原日志/报告/PNG/驱动/导入描述精确归档；文件名se_phase为复制驱动历史前缀，实际方向SW。\n\n')
prepend(Q/'README.md','## 2026-10-19 西南诊断尚未解决自然步态，转专用图层\n\n最新prompt_set_v3.json累计17份原PNG，本轮新增5份；SW passing A v2仍未按前腿角色修正，v3进入诊断但蹄过低，v4未明显改善，单视角v1又移动马身，均不算抬蹄已修好。passing B v1仅为诊断候选。西南原生45项/4图全目检；整图蒙皮48项关键相位可见拉扯、整图裁片49项关键相位可见接缝/碎片，两案均视觉拒绝，其他3图未逐张查看。不能从报告passed推出自然步态或功能通过。原冻结项目和原字节证据均留存actual/。\n\n后继来源转到相邻gongsun_sheng_horse_rig_sources_20261019：已绘马身/前后腿上下段五候选，先做完整四腿与四向组装，不能再用整图裁片或单点数学补签。旧预览/失败的范围不回写，129/16/81与HUD保持、生产接入0。\n\n')
attribute='qa/gongsun_sheng_horse_rig_sources_20261019/** -text whitespace=cr-at-eol,-blank-at-eof'
if attribute not in (R/'.gitattributes').read_text(encoding='utf-8'):
    with (R/'.gitattributes').open('a',encoding='utf-8',newline='\n') as f:f.write('\n# Exact purpose-built horse body/limb originals and source provenance.\n'+attribute+'\n')
for folder in [Q,K]:
    for p in folder.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
print(json.dumps({'new_painted_pngs':13,'walk_sources':len(rows),'kit_sources':len(kit),'native_cases':cases,'adopted':False}))
