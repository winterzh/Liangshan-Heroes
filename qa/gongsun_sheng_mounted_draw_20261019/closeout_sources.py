from pathlib import Path
import ast,datetime,hashlib,json,subprocess
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
pres=[]
for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/name).read_text());assert all(sha(R/x['path'])==x['sha256'] for x in data);pres.append({'manifest':name,'files':len(data),'changed':[]})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(Q/'source_preservation.json',{'manifests':pres,'hud_unchanged':True,'runtime_changes':False})
inspection=json.loads((Q/'source_inspection.json').read_text());assert len(inspection['sources'])==8 and all(not v['touches_cell_edge'] for r in inspection['sources'] for v in r['views'].values())
state=json.loads((E/'queue_rig_v2/state.json').read_text());assert state['state']=='waiting_for_processes_and_lease_to_clear' and not state['native_started']
assert sha(Q/'rig_v2/run.py')==state['runner_sha256']
queue_pid=int(state['pid'])
raw=subprocess.check_output(['powershell.exe','-NoProfile','-Command',f'Get-CimInstance Win32_Process -Filter "ProcessId={queue_pid}" | Select-Object ProcessId,Name | ConvertTo-Json -Compress'],text=True,encoding='utf-8')
live=json.loads(raw);assert live['ProcessId']==queue_pid and live['Name'].lower()=='python.exe'
save(Q/'native_pending_at_source_sync.json',{'recorded_at':datetime.datetime.now().isoformat(),'queue_state_snapshot':state,'queue_process_observed_live':live,'actual_native_receipt_available':(E/'latest_rig_v2.json').exists(),'scope':'Historical source-sync observation only. Re-poll the same session/PID/state; this snapshot is not later liveness or native acceptance evidence.'})
def prepend(p,s):p.write_bytes(s.encode('utf-8')+p.read_bytes())
head='## 2026-10-19 公孙胜取剑/回鞘分层原稿\n\n'
body='内置imagegen新增八份1254四向原PNG，精确提示与来源见[本批来源](../qa/gongsun_sheng_mounted_draw_20261019/prompt_set.json)。整人clear_v1过渡稿让身体/鞘口漂移，upper_arm_v1多带袖口/肩甲状边缘，均不选；改为固定衣身torso_v1、闭合布袖upper_arm_v2、forearm_v1、hand_v1、sword_v1和空scabbard_v1六部件候选。衣身保留持缰手，分层用于固定衣身与鞘口后控制单剑/剑臂，不用每相位缩放整人掩盖漂移。八图直接目检、只读RGBA/边界/来源SHA检查通过，可见轮廓均未裁边，无本地修改PNG。\n\n本次收尾只同步已核对原稿、来源和已执行来源检查工具；本地十一阶段组装原型仍等共享Godot空闲，未运行/解析的原型脚本、准备绑定另留本地，实际执行及画面结论后继单独同步。原生未通过声明见native_pending_at_source_sync.json的历史时点，不能把队列登记、原稿边界或来源校验当动作通过；继续观察同一活队列，不重复启动。手/剑/鞘的实际握持、接缝、路径净空及完整连续动作仍待原生画面核对。\n\n129运行/16保护/81外来与HUD零变化，生产采用0。冠服、短须绦、单柄松纹古锭剑和黄花马仍依据第54回；分层及取剑时序为游戏美术补足，无新剧情/伤亡或自动批准其他章回技能。main/Steam未操作，全库人物、场景、战船、特效、UI、性能及其他未完动作继续。\n\n'
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,head+body)
prepend(R/'docs/DIRECTORY_INDEX.md',head+'- qa/gongsun_sheng_mounted_draw_20261019/native_originals/：八份内置原稿，六分层候选及两份不选原稿；无生产采用。\n- 同目录prompt_set.json、source_inspection.json、source_preservation.json：精确参数/输入来源、只读四格边界/RGBA与129/16/81保护后验。\n- native_pending_at_source_sync.json：本次原稿同步时单一等待队列的真实进程快照，不作为后续活跃或原生通过凭据。\n- 本地rig_v1/rig_v2与准备脚本仍在进行中，未完成实际验证，本次源码同步暂不纳入。\n\n')
attribute='qa/gongsun_sheng_mounted_draw_20261019/** -text whitespace=cr-at-eol,-blank-at-eof'
assert attribute not in (R/'.gitattributes').read_text()
with (R/'.gitattributes').open('a',encoding='utf-8',newline='\n') as f:f.write('\n# Exact articulated rider source originals and provenance.\n'+attribute+'\n')
names=['README.md','record_generated.py','inspect_sources.py','record_source_set.py','closeout_sources.py','prompt_set.json','source_inspection.json','source_preservation.json','native_pending_at_source_sync.json']
owned=[p.relative_to(R).as_posix() for p in Q.rglob('*') if p.is_file() and (p.parent.name=='native_originals' or (p.parent==Q and (p.name in names or p.name.startswith('tool_prompt_') or (p.name.startswith('source_') and p.name not in ['source_inspection.json','source_preservation.json']))))]
for name in ['record_generated.py','inspect_sources.py','record_source_set.py','closeout_sources.py']:ast.parse((Q/name).read_text(encoding='utf-8'))
save(E/'source_sync_whitelist.json',sorted(set(owned)))
print(json.dumps({'raw_sources':8,'source_files_for_sync':len(set(owned)),'queue_pid_observed_live':queue_pid,'prototype_godot_scripts_included':False}))
