from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019');A=Q/'browser_review';A.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
summary=[]
for name in ['browser_rig_v2','browser_rig_v3','browser_rig_v3_detail']:
    S=E/name;D=A/name;D.mkdir();rows=[]
    for p in sorted(S.rglob('*')):
        if not p.is_file() or any(x.startswith('profile_') for x in p.relative_to(S).parts):continue
        dst=D/p.relative_to(S);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst);assert sha(p)==sha(dst)
        rows.append({'original':str(p),'archive':dst.relative_to(D).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
    save(D/'archive_index.json',rows)
    receipt=json.loads((S/'receipt.json').read_text());assert len(receipt['steps'])==3
    summary.append({'case':name,'directly_viewed':[{'file':step['label']+'.png','sha256':step['png_sha256']} for step in receipt['steps']]})
for f in ['idle.png','clear.png','point.png']:assert sha(E/'browser_rig_v3'/f)==sha(E/'browser_rig_v3_replay'/f)
shutil.copyfile(E/'browser_rig_v3_replay/receipt.json',A/'standalone_replay_receipt.json')
save(A/'visual_assessment.json',{'reviewed_browser_frames':9,'cases':summary,'observed':['v2 rear idle sleeve folds across the back; rear pointed sword close to horse ears.','v3 moves rear idle hand forward, uses a quadratic grasp/release approach and raises rear pointed sword by 20 source units.','v3 idle/clear/point and approach/sweep/release frames all directly viewed; no gross body rescaling or extra sword introduced in those frames.'],'scope':'Own isolated browser, static horse, no reins, selected static poses only. The clear.svg timestamp 2.4 may display segment name partial_out because of floating boundary rounding, while its interpolation reaches the clear endpoint; raw files kept unchanged.','limitations':['Not Godot parsing/import/native render, moving horse/reins, continuous human motion, physical grip or full swept clearance.','Joint/cuff appearance, anatomical arm path, hidden hand, actual Unit/chapter/package/performance and adoption remain open.'],'standalone_public_model_replay_images_exactly_match':True,'native_executed':False,'production_adopted':False,'full_goal_complete':False})
pres=[]
for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/name).read_text());assert all(sha(R/x['path'])==x['sha256'] for x in data);pres.append({'manifest':name,'files':len(data),'changed':[]})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(A/'preservation.json',{'manifests':pres,'hud_unchanged':True,'runtime_changes':False})
def prepend(p,s):p.write_bytes(s.encode('utf-8')+p.read_bytes())
head='## 2026-10-19 分层剑臂浏览器组装与后视姿势调整\n\n'
body='对既有八份原稿作静态浏览器组装，未新增或修改原PNG。v2暴露后视待机上臂折到背部、指敌剑刃靠近马耳；新v3移动后视待机手、采用二次曲线接近/离开剑柄，后视指敌剑位上提20源像素。九张四向图（v2三图，v3三关键图加三中间图）全部直接目检；静态衣身未随相位缩放、未新增第二把剑。新浏览器独立模型可仅凭已同步canonical_source重放，三张重放PNG与首次v3图SHA完全一致，见[browser_review](../qa/gongsun_sheng_mounted_draw_20261019/browser_review/visual_assessment.json)。\n\n本批验证范围只有隔离浏览器的静态马匹/选定姿势，不含缰绳，不是Godot解析/导入/原生、连续动作、物理握持或全路径净空通过。袖口/关节、臂部解剖、藏手及游戏Unit/章回/编译包/性能仍未完成。原生v2等待队列保留原输入与同一进程；确认旧占用控制进程退出但外来共享占用声明残留，已提出备份移走的确认请求，未改动该声明。v3仅冻结本地后继候选，未另起并行原生队列。未解析Godot原型继续留本地，本次仅同步已执行浏览器工具、独立数据模型和精确图像/来源证据。\n\n129运行/16保护/81外来及HUD零变化，生产采用0，原著第54回冠服、短须绦、单剑和黄花马身份不变，分层/时序为美术补足；不增加剧情伤亡或批准其他章回技能。main/Steam未操作，全库人物、场景、战船、特效、UI、性能及未完动作继续。\n\n'
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,head+body)
prepend(R/'docs/DIRECTORY_INDEX.md',head+'- qa/gongsun_sheng_mounted_draw_20261019/browser_models/：v2/v3静态来源模型，只有数据、无Godot驱动；供已执行浏览器重放工具使用。\n- 同目录render_browser_rig.py：隔离浏览器静态来源组装，--model可只依赖已同步canonical_source重放；不是原生执行器。\n- browser_review/：九张目检图及原SVG/PNG/日志/图层精确归档，独立模型重放回执、视觉范围与保护后验；无浏览器profile缓存。\n- rig_v1/v2/v3及Godot准备脚本仍本地待验，不纳入本批同步；当前仅原v2一条原生等待队列。\n\n')
prepend(Q/'README.md',head+'浏览器九张四向静态图已直接查看，后视待机手与指敌高度经调整；见browser_review/visual_assessment.json。可用render_browser_rig.py --model browser_models/rig_v3.json <工程外新输出目录>重放三张静态图（使用当前仓库canonical_source；从工程根目录调用时传完整项目内model路径）。本批三张重放图与首次v3字节SHA相同。它不画缰绳、不运行马步/完整动作，也不算Godot通过。原生仍由同一v2等待队列观察共享占用声明，后继v3只准备未启动；相关Godot脚本仍未同步。下方原稿收尾描述保留旧时点。\n\n')
for p in [Q/'render_browser_rig.py',Path(__file__)]:ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
owned=[p.relative_to(R).as_posix() for p in A.rglob('*') if p.is_file()]+[p.relative_to(R).as_posix() for p in (Q/'browser_models').glob('*.json')]+[(Q/'render_browser_rig.py').relative_to(R).as_posix(),Path(__file__).relative_to(R).as_posix()]
save(E/'browser_sync_whitelist.json',sorted(owned))
print(json.dumps({'browser_reviewed_frames':9,'standalone_replay_exact':True,'new_png_art':0,'native_executed':False,'files_for_sync':len(owned)}))
