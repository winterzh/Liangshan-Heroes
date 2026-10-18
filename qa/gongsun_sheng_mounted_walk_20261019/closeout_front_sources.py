"""Archive exact native results and describe the unfinished full art scope."""
from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
source_receipt=Path(json.loads((E/'latest_native_se_v2.json').read_text())['receipt']);P=source_receipt.parent;receipt=json.loads(source_receipt.read_text());assert receipt['complete'] and receipt['native_checks']==45
dest=Q/'native_se_v2/actual';dest.mkdir();index=[]
for p in sorted(P.rglob('*')):
    if not p.is_file() or '.godot' in p.relative_to(P).parts:continue
    rel=p.relative_to(P);target=dest/rel
    if target.suffix=='.gd':target=target.with_suffix('.gd.txt')
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target);assert sha(p)==sha(target)
    index.append({'original':str(p),'archive':target.relative_to(dest).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
save(dest/'archive_index.json',index)
rows=[json.loads(p.read_text()) for p in sorted(Q.glob('source_*.json'))];assert len(rows)==12
selected_se={'horse_contact_a_se_v3','horse_passing_a_se_v4','horse_contact_b_se_v1','horse_passing_b_se_v1'}
selected_sw={'horse_contact_a_sw_v1','horse_contact_b_sw_v1'}
reasons={'horse_contact_a_v1':'Same-side support, not intended diagonal pair.','horse_contact_a_v2':'Same-side support retained.','horse_passing_a_se_v1':'Near fore extended instead of flexed incoming.','horse_passing_a_se_v2':'Near fore improved but far fore retained old forward support.','horse_passing_a_se_v3':'Missing far foreleg; only three distinct hooves.','horse_passing_a_sw_v1':'Foreleg pair is reversed relative to intended diagonal transition, while hind pair follows guide; not accepted as passing A.'}
for row in rows:
    assert sha(Q/row['file'])==row['sha256']
    row.update(production_adopted=False,full_gait_accepted=False)
    if row['key'] in selected_se:row.update(selection='SE_source_comparison_only',directions=['se'],native_reference='native_se_v2/actual/receipt.json')
    elif row['key'] in selected_sw:row.update(selection='SW_contact_source_only',directions=['sw'],native_reference=None)
    else:row.update(selection='rejected',directions=[],reason=reasons[row['key']])
save(Q/'prompt_set_v2.json',{'mode':'builtin_imagegen','raw_sources':12,'new_this_batch':7,'selected_source_views':6,'rejected':6,'originals':rows,'production_adopted':False,'full_goal_complete':False})
report=json.loads((P/'report.json').read_text());sequence=[x['phase'] for x in report['phase_transitions']]
save(Q/'native_se_v2/visual_assessment.json',{'receipt':'actual/receipt.json','checks':45,'directly_viewed':[{'file':f'se_phase_{i}.png','sha256':sha(dest/f'se_phase_{i}.png')} for i in range(4)],'observed':'Four horse poses show distinct supports/passing limbs; same rider and fixed horse/rider scale and translation remain visually stable in four native grids. Reins use original painted texture between provisional bit/hand anchors.','phase_sequence':sequence,'observed_transitions':len(sequence),'limitations':['SE only. SW contacts are new sources with no full cycle; SW passing A rejected. NE/NW not qualified.','Actual continuous movement, foot contact/sliding, rider bounce, exact rein/seat anatomy, Unit/chapter/compiled package and performance remain unaccepted.','Screenshots observe four discrete loop phases, not a human continuous-video playtest.'],'production_adopted':False,'full_goal_complete':False})
preservation=[]
for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/name).read_text());changed=[x['path'] for x in data if sha(R/x['path'])!=x['sha256']];assert not changed
    preservation.append({'manifest':name,'files':len(data),'changed':changed})
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(Q/'front_sources_preservation.json',{'manifests':preservation,'hud_unchanged':True,'production_changed':False})
heading='## 2026-10-19 公孙胜坐骑前向步态来源继续补齐\n\n'
body='本批内置imagegen新绘7份原PNG，当前步态来源累计12份：SE四阶段进入固定比例比较，SW只选两张相反接触姿势；其余6份支撑/缺腿/过渡问题退回，原图与准确提示见[最新来源清单](../qa/gongsun_sheng_mounted_walk_20261019/prompt_set_v2.json)。其中SW首张过渡的前腿相位画反，不当合格步态。后继须先修此稿并补SW passing B；两份SW关节引导图已有，NE/NW随后继续。\n\nSE引擎预览原默认导入使7张纹理RGBA不一致，失败报告/图原样保留；后继只换项目现有无边缘改写/无损含mipmap的导入描述，不改PNG或删断言，45项/4图通过并全部直接查看，实际process记录16次顺序换相。比较中马身/骑手均固定比例和位置，缰绳使用原绘制带材；这是单向独立素材预览，不是完整自然步态、骑手起伏、脚滑/接触、Unit/章回/PCK/性能或玩家游玩验收。\n\n原著仍只沿第54回黄花马、单剑、冠服与短须绦，小跑/鞍具/服色是游戏补足，不新增剧情伤亡。当前运行129/保护16/外来81及HUD零变动，新骑乘采用0；吴用上一批采用保持。继续全库人物、场景、战船、特效、UI、性能和未完动作，main/Steam未操作。\n\n'
def prepend(p,text):
    old=p.read_bytes();assert not old.startswith(text.encode());p.write_bytes(text.encode()+old)
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md','GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md']:prepend(R/'docs'/name,heading+body)
prepend(R/'docs/DIRECTORY_INDEX.md','## 2026-10-19 坐骑前向来源与原生比较\n\n- qa/gongsun_sheng_mounted_walk_20261019/prompt_set_v2.json：12原PNG，SE四阶段比较/SW两接触稿暂选，6退稿；最新准确提示与来源SHA。\n- 同目录native_se_v1/actual_failed/：默认透明边缘导入导致7个原始RGBA校验失败，原记录不改写。\n- 同目录native_se_v2/actual/：无损导入后45项、4图全目检、16次process相位切换；非实际Unit/完整步态。\n- 同目录sw_passing_a_pose_guide与sw_passing_b_pose_guide：仅QA矢量关节图，前者已生成退稿，后者尚未生成；不能当生产绘画。\n\n')
prepend(Q/'README.md','## 2026-10-19 本轮新增7原稿，单向四阶段进入原生比较\n\n当前以prompt_set_v2.json为准：12份内置原PNG，SE选contact_a_se_v3/passing_a_se_v4/contact_b_se_v1/passing_b_se_v1进入比较；SW只选contact_a_sw_v1/contact_b_sw_v1继续。共6份原稿退回，SE passing A经历错误前腿、缺腿后修正；SW passing A前腿相位仍反，下一步须返修，passing B仅已准备关节图、未生成。NE/NW仍未资格化。\n\nnative_se_v1/actual_failed保存首次默认导入的7项RGBA失败。native_se_v2显式采用项目已用的lossless/fix_alpha_border=false/mipmaps=true设置，PNG与驱动断言保持；导入/原生退出0，45项/4截图全部直接查看，process真实顺序换相16次。对照马与骑手不逐帧包围盒拟合，位置/比例固定，缰绳在运行时使用原绘制带材。只证明单向素材可导入/叠合并循环渲染；自然连续步态、脚滑/接触、骑手起伏、其他方向、实际Unit/章回/PCK与性能仍待做，采用0。129运行/16保护/81外来/HUD保持。下文5份/仅接触姿势为此前历史。\n\n')
for p in Q.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
print(json.dumps({'raw_originals':len(rows),'native_checks':45,'native_screenshots_viewed':4,'source_art_adopted':False,'archives':len(index)}))
