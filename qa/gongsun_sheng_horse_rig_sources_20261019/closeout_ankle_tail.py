from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_horse_rig_sources_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def archive(kind,viewed,decision):
    receipt_path=Path(json.loads((E/f'latest_{kind}.json').read_text())['receipt']);P=receipt_path.parent
    receipt=json.loads(receipt_path.read_text());assert receipt['complete'] and receipt['lock_released'] and not receipt['source_changes']
    assert all(not x['changed'] for x in receipt['preservation'])
    A=Q/kind/'actual';A.mkdir();rows=[]
    for p in sorted(P.rglob('*')):
        if not p.is_file() or '.godot' in p.relative_to(P).parts:continue
        dst=A/p.relative_to(P)
        if dst.suffix=='.gd':dst=dst.with_suffix('.gd.txt')
        dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst);assert sha(p)==sha(dst)
        rows.append({'original':str(p),'archive':dst.relative_to(A).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
    save(A/'archive_index.json',rows)
    report=json.loads((P/'report.json').read_text());assert report['passed'] and len(report['screenshots'])==6
    assessment={'native_checks':len(report['checks']),'decision':decision,'directly_viewed':[{'file':f,'sha256':sha(A/f)} for f in viewed],'full_continuous_gait_accepted':False,'actual_unit_tested':False,'production_adopted':False,'full_goal_complete':False}
    save(Q/kind/'visual_assessment.json',assessment)
    state=json.loads((E/f'queue_{kind}/state.json').read_text());assert state['state']=='terminal' and state['exit_code']==0
    save(Q/kind/'completed_queue.json',state)
    return assessment
v3=archive('assembly_v3',['assembled_phase_0.png','assembled_phase_1.png','assembled_hold.png','assembled_restart.png'],'Rejected for next-stage use: rectangular near-hind redraw exposes a hard upper cut edge over the tail; hold forelegs remain overly bent. Sole-layer/source model checks pass only. Other two phase images not directly reviewed.')
v4=archive('assembly_v4',[f'assembled_phase_{i}.png' for i in range(4)]+['assembled_hold.png','assembled_restart.png'],'Usable component base for mounted comparison: independent painted tail removes the v3 rectangular cutoff in all six reviewed four-direction frames; selected sole anchors can stay level, neutral forelegs extend more. No comparable large tearing/fragments seen. Joint proportions/root perspective and human continuous motion still require mounted-context review. This is not a production, physical-contact, no-slip braking/acceleration, actual Unit, chapter, package or performance acceptance.')
selected={'body_no_tail_v1','tail_v1','fore_upper_v2','fore_shin_v2','hind_upper_v2','hind_shin_v1','hoof_v1'}
rows=[]
for p in sorted(Q.glob('source_*.json')):
    row=json.loads(p.read_text())
    if 'key' not in row or 'file' not in row:continue
    assert sha(Q/row['file'])==row['sha256'];row.update(selection='assembly_v4_component_base' if row['key'] in selected else 'historical_not_current',production_adopted=False);rows.append(row)
assert len(rows)==14
save(Q/'prompt_set_v3.json',{'mode':'builtin_imagegen','raw_sources':14,'new_this_batch':6,'selected_component_base':sorted(selected),'originals':rows,'candidate':'assembly_v4','full_goal_complete':False,'production_adopted':False})
pres=[]
for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/name).read_text());assert all(sha(R/x['path'])==x['sha256'] for x in data);pres.append({'manifest':name,'files':len(data),'changed':[]})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(Q/'assembly_v4/preservation.json',{'manifests':pres,'hud_unchanged':True,'runtime_changes':False})
def prepend(p,s):p.write_bytes(s.encode('utf-8')+p.read_bytes())
head='## 2026-10-19 坐骑独立蹄/尾图层与停走预览\n\n'
body='内置imagegen新增6张原PNG，专用目录累计14张；新前/后小腿、独立蹄、无尾马身和独立尾组成七层比较基线，原图及精确提示见[prompt_set_v3.json](../qa/gongsun_sheng_horse_rig_sources_20261019/prompt_set_v3.json)。前小腿v1后视关节仍偏金，v2改为棕色；旧原稿、准备绑定和原检查不回写。所有PNG按原字节复制，无本地画图修改。\n\nassembly_v2因共享引擎繁忙未进入原生；新v3对齐躯干/腿根起伏，68项通过但近后腿矩形重绘露切边、停姿前腿过弯，4/6图目检即拒绝。新v4改用独立原绘尾层在腿后绘制，去掉裁片分支，停姿躯干上提16源像素。原生72项、四相/停止/再启动六张四向图全目检，可作为骑手合成比较基线；未见旧切边/大片拉裂。蹄底仅人工两点参照线水平，不能称完整轮廓接触或物理碰撞；减速/启动脚底不滑、连续自然步态及关节比例/根部透视仍未最终接受。下一步在此完整坐骑上固定一次腰鞍配准，骑手随同躯干，重绑手/马口缰绳，再验抽剑回收和实际Unit/章回/编译包/性能，不继续用整图切腿补签。\n\n本批生产采用0、129运行/16保护/81外来与HUD零变化，两队列均终止且已让出自有引擎。原著仍只据第54回冠服、短须绦、单剑及黄花马，配色/鞍具/关节时序是美术解释，无新剧情伤亡。main/Steam未操作，全库人物、场景、战船、特效、UI、性能和其他未完动作仍开放。\n\n'
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,head+body)
prepend(R/'docs/DIRECTORY_INDEX.md',head+'- qa/gongsun_sheng_horse_rig_sources_20261019/prompt_set_v3.json：累计14原PNG、本轮新增6，当前七层组装比较基线。\n- assembly_v2/：准备后因引擎繁忙未原生；冻结输入保留。\n- assembly_v3/：68项/六图，直接目检四图后因矩形切边和停姿拒绝；actual保留原报告/日志/六图。\n- assembly_v4/：72项/六图全目检，独立原绘尾层及独立蹄、停走预览，可继续合成骑手，非生产采用；actual与visual_assessment.json分别保留机器原结果和人眼范围。\n\n')
prepend(Q/'README.md',head+'最新prompt_set_v3.json累计14份原PNG，当前七层基线见assembly_v4/README.md。本轮新增6份，使用内置imagegen并保存全部精确参数/来源；无像素后处理。v3虽68项通过但切边/停姿拒绝，v4改独立尾层和中立躯干高度，72项与六图全目检后可进入骑手合成比较。蹄底仅选定两点参照、完整自然步态/Unit/性能/采用尚未完成，下方旧阶段状态保留时点语境。\n\n')
prepend(Q/'RIG_ASSEMBLY_NEXT.md',head+'下一步使用assembly_v4七层完整坐骑及固定关节，合成mounted_layers_20261018的骑手/缰绳。腰到鞍一次固定配准、与躯干相同起伏及停姿高度；重新标注手与马口，不用移动整个人去迁就旧缰绳。先比较站立/循环/停走及近远靴遮挡，再接抽剑回收和实际Unit。v4仅六张关键画面与来源/几何合格，连续自然步态、完整蹄底/碰撞、刹车启动不滑与游戏内采用仍开放。下方旧路线/旧不合格阶段留作历史。\n\n')
for p in Q.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
print(json.dumps({'source_pngs':14,'new_pngs':6,'v3_checks':v3['native_checks'],'v4_checks':v4['native_checks'],'v4_reviewed_frames':len(v4['directly_viewed']),'production_adopted':False}))
