from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'assembly_v1'
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_horse_rig_sources_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
receipt_path=Path(json.loads((E/'latest_assembly_v1.json').read_text())['receipt']);P=receipt_path.parent
receipt=json.loads(receipt_path.read_text());assert receipt['complete'] and receipt['lock_released']
report=json.loads((P/'report.json').read_text());assert report['passed'] and len(report['checks'])==54
assert not report['production_adopted'] and not report['actual_unit_tested'] and not report['visual_accepted']
assert all(not x['changed'] for x in receipt['preservation']) and not receipt['source_changes']
A=N/'actual';A.mkdir();index=[]
for p in sorted(P.rglob('*')):
    if not p.is_file() or '.godot' in p.relative_to(P).parts:continue
    rel=p.relative_to(P);dst=A/rel
    if dst.suffix=='.gd':dst=dst.with_suffix('.gd.txt')
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst);assert sha(p)==sha(dst)
    index.append({'original':str(p),'archive':dst.relative_to(A).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
save(A/'archive_index.json',index)
assessment={
 'scope':'First complete four-direction four-leg assembly preview, not a mounted Unit or natural-gait acceptance.',
 'native_checks':54,'directions':['se','sw','ne','nw'],'legs_per_direction':4,
 'directly_viewed':[{'file':f'assembled_phase_{i}.png','sha256':sha(A/f'assembled_phase_{i}.png')} for i in range(4)],
 'observed':['Four-direction clean and joint-overlay renders exist for all four cycle phases.','No comparable large triangle stretching or isolated cut-piece fragment seen in these four captured phases.'],
 'open_visual_items':['Hoof sole pitch/contact is not qualified: lower-leg rigid rotation also rotates the attached hoof; a fixed model foot point is not a flat sole or collision proof.','Knee/hock cap thickness and upper/lower color transitions require refinement, especially rear-view foreleg caps.','Body-last draw order can occlude near hind legs under the tail; near/far root perspective and source reuse remain unqualified.','Four phase screenshots and normal process rendering do not establish human continuous-motion, stop/restart, rider, rein, Unit, chapter, compiled package or performance acceptance.'],
 'visual_accepted':False,'production_adopted':False,'full_goal_complete':False,
 'next':'Refine sole/joint/root/tail registration, then verify continuous motion and stopping/restarting before mounted rider/rein and actual Unit integration.'}
save(N/'visual_assessment.json',assessment)
save(N/'preservation.json',{'source_manifest_checks':receipt['preservation'],'hud_sha256':sha(R/'scripts/hud.gd'),'runtime_changed':False})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
def prepend(p,s):p.write_bytes(s.encode('utf-8')+p.read_bytes())
header='## 2026-10-19 四方向完整四腿首轮组装预览\n\n'
body='专用马身与前后腿上下段已完成首轮四向组装，进入[assembly_v1](../qa/gongsun_sheng_horse_rig_sources_20261019/assembly_v1/README.md)。五份原PNG不改像素，通过固定关节点、统一骨长、刚性纹理变换分别渲染LF/RF/LH/RH；循环模型按LF+RH、RF+LH配对，增加移动地面点参照。隔离Godot原生54项通过、16次正常换相，四张四向画面全目检；这证明来源可导入/完整组装和脚本几何，不证明蹄底接触或自然步态。\n\n四相未见旧案的大片三角拉裂或孤立裁片；仍未接受视觉：下腿带蹄刚性转动会改变蹄底角度，关节粗细/色差、近远腿根与马尾遮挡仍待修。先处理这些部位及连续运动/停走，再接骑手、缰绳、抽剑回收和实际Unit/章回/包内/性能；不得跳过。五候选原稿旧清单的未组装标记保留原时点，首轮事实由本批独立收据记录，不回写旧报告。129运行/16保护/81外来与HUD零变化，本批生产采用0，main和Steam未操作；全库美术目标仍开放。原著依据仅第54回黄花马、冠服、短须绦和单剑身份，步态/鞍具是美术解释，无新剧情或伤亡。\n\n'
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,header+body)
prepend(R/'docs/DIRECTORY_INDEX.md',header+'- qa/gongsun_sheng_horse_rig_sources_20261019/assembly_v1/：独立四向四腿首轮组装，准备绑定、54项原生收据、四相全目检与未接受原因；actual保存原报告、日志、来源/驱动和截图，非生产资源。\n- 同层assembly_preview.gd.txt与prepare_assembly.py：固定关节、四独立腿、对角循环与移动数学参照；不含骑手、Unit、碰撞或采用。\n\n')
prepend(Q/'README.md',header+'首轮组装与原生执行已完成，见assembly_v1/README.md；原54项仅来源/渲染/几何通过，四相全目检后视觉仍未接受。蹄底姿态、关节粗细/色差、腿根和马尾遮挡待修，接着验证连续运动/停走，再接骑手和实际Unit。下方“尚未组装”及prompt_set.json是原稿冻结时点，不回写。原PNG未改、生产采用0。\n\n')
prepend(Q/'RIG_ASSEMBLY_NEXT.md',header+'已按下方路线完成第一版四向/四腿独立场景，54项与四相画面归assembly_v1；尚未达到视觉采用。下一步先修蹄底角度、关节粗细/色差、近远根/尾部遮挡并验连续运动/停止启动，之后再合成骑手、缰绳及实际Unit。下方为原稿阶段计划语境。\n\n')
for p in Q.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
print(json.dumps({'native_checks':54,'viewed_four_direction_frames':4,'adopted':False,'archived_files':len(index)}))
