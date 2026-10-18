from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'mounted_v1';E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_assembly_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
receipt_path=Path(json.loads((E/'latest_mounted_v1.json').read_text())['receipt']);P=receipt_path.parent;receipt=json.loads(receipt_path.read_text())
assert receipt['complete'] and receipt['lock_released'] and not receipt['source_changes'] and all(not x['changed'] for x in receipt['preservation'])
report=json.loads((P/'report.json').read_text());assert report['passed'] and len(report['checks'])==84 and len(report['screenshots'])==6
A=N/'actual';A.mkdir();index=[]
for p in sorted(P.rglob('*')):
    if not p.is_file() or '.godot' in p.relative_to(P).parts:continue
    dst=A/p.relative_to(P)
    if dst.suffix=='.gd':dst=dst.with_suffix('.gd.txt')
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst);assert sha(p)==sha(dst)
    index.append({'original':str(p),'archive':dst.relative_to(A).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
save(A/'archive_index.json',index)
viewed=[f'assembled_phase_{i}.png' for i in range(4)]+['assembled_hold.png','assembled_restart.png']
save(N/'visual_assessment.json',{'native_checks':84,'directly_viewed':[{'file':f,'sha256':sha(A/f)} for f in viewed],'scope':'Two fixed rider poses mounted onto complete moving four-leg horse in four directions, six native captured states.','observed':['Idle and pointed-sword rider/horse/reins composite renders in all reviewed frames.','No obvious rider jumping away from saddle or static reins detached from the moving body in these captured frames.','Single sheathed sword in idle and held sword/empty sheath in point remain visible; exact equipment identity follows prior chapter54 art basis.'],'decision':'Usable base for draw/re-sheath transition development. This is a key-frame mounted comparison, not a full sword trajectory or final animation acceptance.','limitations':['Waist and visible rein hand/bit anchors are manual, with initial 10 source-pixel uncertainty; anatomical seat, grip, hidden hands, far boot depth, sword clearance and physical contact are not proven.','Rider and reins share the body offset by construction; six screenshots do not prove human continuous-motion quality or no slipping during braking/acceleration.','Actual Unit/chapter/compiled PCK/performance/production adoption remain unrun.'],'full_draw_recovery_accepted':False,'production_adopted':False,'full_goal_complete':False})
queue=json.loads((E/'queue_mounted_v1/state.json').read_text());assert queue['state']=='terminal' and queue['exit_code']==0;save(N/'completed_queue.json',queue)
pres=[]
for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/name).read_text());assert all(sha(R/x['path'])==x['sha256'] for x in data);pres.append({'manifest':name,'files':len(data),'changed':[]})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(Q/'preservation.json',{'manifests':pres,'hud_unchanged':True,'runtime_changes':False})
def prepend(p,s):p.write_bytes(s.encode('utf-8')+p.read_bytes())
head='## 2026-10-19 公孙胜骑手/缰绳合成到完整坐骑\n\n'
body='在七层完整坐骑assembly_v4上首次接入持缰待机和举剑指敌两种原绘骑手姿势，见[合成入口](../qa/gongsun_sheng_mounted_assembly_20261019/README.md)。每方向骑手固定0.8、腰鞍目标固定一次，手和马口用人工源坐标重绑；骑手与双条原绘皮革缰绳跟随同一躯干起伏/停姿高度，无逐帧包围盒拟合或为旧缰绳移动整人。复用10张既有原PNG，无新增图片或本地改像素。\n\n隔离Godot原生84项通过（来源字节/RGBA导入与原骨架/停走模型），四相、停止、再启动六张四向/双姿势图全目检；未见明显人马脱离或固定缰绳掉队，可继续做取剑/出鞘/指敌/回鞘过渡。它仍是两个固定骑手姿势的合成比较，未执行完整动作衔接；手/马口/腰鞍初始人工误差10源像素，握持、藏手/远靴遮挡、剑刃净空、完整连续人眼运动和物理接触均未据此通过。下一步复用既有reach/draw_mid等原稿比较衔接，逐相核对持剑/空鞘身份，再补实际Unit/适用章回/编译包/性能，不能把举剑图算抽剑已完成。\n\n129运行/16保护/81外来及HUD零变化，本批生产采用0、无自有活跃原生队列。冠服、短须绦、单剑和黄花马仍依第54回；鞍具/配色/动作时序属美术解释，不引入剧情伤亡或自动批准其他章回/祭风技能。main/Steam未操作，全库人物、场景、战船、特效、UI、性能及其他未完动作继续。\n\n'
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,head+body)
prepend(R/'docs/DIRECTORY_INDEX.md',head+'- qa/gongsun_sheng_mounted_assembly_20261019/：完整坐骑上的骑手/原绘缰绳首轮四向合成，十张既有来源、固定注册、84项/六图，非生产资源。\n- mounted_v1/actual/：原日志/报告/PNG/脚本/导入描述按原字节归档；visual_assessment.json单列六图目检范围。\n- 同目录DRAW_TRANSITION_NEXT.md：取剑、出鞘、指敌、回鞘衔接的下一步，当前仅两个固定骑手姿势，完整动作未接受。\n\n')
attribute='qa/gongsun_sheng_mounted_assembly_20261019/** -text whitespace=cr-at-eol,-blank-at-eof'
assert attribute not in (R/'.gitattributes').read_text()
with (R/'.gitattributes').open('a',encoding='utf-8',newline='\n') as f:f.write('\n# Exact mounted comparison sources and native evidence.\n'+attribute+'\n')
for p in Q.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
print(json.dumps({'native_checks':84,'reviewed_four_direction_frames':6,'original_textures':10,'new_pngs':0,'production_adopted':False}))
