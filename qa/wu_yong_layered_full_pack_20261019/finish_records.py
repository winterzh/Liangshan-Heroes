"""Write current handoff and verify evidence, without touching game art pixels."""
from pathlib import Path
import ast,hashlib,json
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
W=R/'qa/gongsun_sheng_mounted_walk_20261019'
rows=[json.loads(p.read_text()) for p in sorted(W.glob('source_*.json'))]
assert len(rows)==5
for row in rows:
    assert sha(W/row['file'])==row['sha256']
    if row['key'] in ['horse_contact_a_se_v3','horse_contact_b_se_v1']:
        row.update(selection='SE_only_next_comparison',directions=['se'],full_gait_accepted=False)
    else:row.update(selection='rejected',directions=[],reason='Same-side support topology' if row['key'].startswith('horse_contact_a') else 'Near fore is extended rather than the requested flexed forward passing leg; diagonal transition not accepted')
save(W/'prompt_set.json',{'mode':'builtin_imagegen','originals':rows,'raw_sources':5,'selected_SE_contact_sources':2,'rejected':3,'production_adopted':False,'full_goal_complete':False})
viewed=[f'viewport_{n}_{d}.png' for n in [960,1280,1920] for d in ['se','sw','ne','nw']]
viewed += [f'{state}_{d}{suffix}.png' for state,suffix in [('actual_walk','_2'),('actual_hurt',''),('actual_recovered','')] for d in ['se','sw','ne','nw']]
viewed.append('unloaded_original_body.png');assert len(viewed)==25
save(Q/'package_visual_assessment.json',{'raw_screenshots':45,'directly_viewed':[{'path':'actual_package/visual/'+p,'sha256':sha(Q/'actual_package/visual'/p)} for p in viewed],'observed':'Own Wu actor and one cart visible at three resolutions; selected actual moving, armed hurt, restored pushing and unload samples match source-stage behavior.','limits':'25 of 45 direct views; still captures do not qualify continuous gait, hidden hand contact, wheel spin, full chapter, HUD layout or performance. 960 inherited roster/task overlap and 1920 outer-map black region retained.','full_goal_complete':False})
preservation=[]
for rel in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    data=json.loads((R/rel).read_text());changed=[x['path'] for x in data if sha(R/x['path'])!=x['sha256']];assert not changed
    preservation.append({'manifest':rel,'files':len(data),'changed':changed})
hud=R/'scripts/hud.gd';assert sha(hud)=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(Q/'closeout_preservation.json',{'manifests':preservation,'hud_sha256':sha(hud),'old_106_manifest_is_historical':True})
head='## 2026-10-19 吴用分层推车已采用，公孙胜继续返修\n\n'
body='吴用同一已验证私有源已完成完整PCK导出：编译身份6项、实际Unit美术/所属/三尺寸174项、45原图（25张直接查看），官方release正常启动480帧退出0；前序源码实景144项/33图全部查看。仅将已测试的unit/campaign_art两文件接入Root，保留晁盖/阮小七所属隔离、原肖像/数值及受击/卸货朴刀；[收据和范围](../qa/wu_yong_layered_full_pack_20261019/README.md)。新运行保护基线129文件，旧106保留历史；16保护/81外来/HUD不变。资源创建时false字段不回写，采用看新production_adoption.json。\n\n公孙胜固定马身/骑手/缰绳的原生资源预览59项/4图通过且全部查看，仍未实际Unit/完整抽剑回收或生产采用。新增黄花马5份内置imagegen原稿，2份只选SE对角接触姿势继续比较，3份支撑/过渡问题退回；原图/精确提示在[步态候选](../qa/gongsun_sheng_mounted_walk_20261019/README.md)，无本地改像素。\n\n两组均按适用原著章回，动作和颜色补足不冒称原文事实，不新增剧情伤亡。吴用关卡既有三目标/肩挑文本及七车十一担还需后续统一；连续自然步态、其余人物/车轮、骑乘、场景、战船、特效、UI、性能、人眼游玩继续。当前没有活跃吴用等待器；已验证本批未操作main或Steam。\n\n'
def prepend(relative,text):
    p=R/relative;old=p.read_bytes();assert not old.startswith(text.encode('utf-8'));p.write_bytes(text.encode('utf-8')+old)
for name in ['WORKLOG.md','SOURCE_SETUP.md','ART_FULL_20260915.md']:prepend('docs/'+name,head+body)
prepend('docs/DIRECTORY_INDEX.md','## 2026-10-19 当前接续入口\n\n- qa/wu_yong_layered_full_pack_20261019/：完整PCK6+174项、45图/25目检、正常release480帧、精确两文件采用、当前129运行基线。\n- qa/wu_yong_push_gait_20261018/actual_unit_v2/：后继实景144项/33图，33张直接查看；原失败保留。\n- qa/gongsun_sheng_mounted_layers_20261018/actual_native_v3/：原生资源59项/四向网格全目检，未Unit/动作采用。\n- qa/gongsun_sheng_mounted_walk_20261019/：5份内置原PNG/精确提示与QA关节图，SE两接触稿暂选，三退稿；未全步态采用。\n\n下方“准备/等待/106不变”等保留原批历史，当前以本节及对应新收据为准。\n\n')
prepend('docs/WU_YONG_PUSHCART_20261017.md',head+body.split('公孙胜固定')[0]+'本批未改任务/目标文本与七车十一担逻辑，不把局部美术采用当完整原著符合；旧合图完整PCK记录保持旧范围。\n\n')
prepend('docs/GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md','## 2026-10-19 原生分层预览完成，骑乘动作未采用\n\n同一native_v3候选已导入并完成59项/四向3×3网格截图，四图直接查看；actual_native_v3/原始日志/报告/SHA归档，马身共用/固定骑手比例/皮革纹理缰绳按预期显示。不是实际Unit、完整出鞘回收或连续动作资格。另新增黄花马5份内置原PNG，只有SE相反对角两接触姿势进入下一轮比较，三份同侧支撑/过渡退稿保留；准确提示和原字节见mounted_walk_20261019/prompt_set.json。小跑是游戏解释，不是原文指定。仍只适用第54回身份，未生产接入。当前运行保护基线已随后因吴用采用更新至129文件，下方106/未执行是历史状态。\n\n')
prepend('qa/wu_yong_push_gait_20261018/README.md','## 2026-10-19 后继实景及包内已通过，当前采用看新收据\n\nactual_unit_v2/原生144项/33原图全部直接查看；同一源完整PCK6身份+174美术/45图（25直接查看）及release480帧退出0后，精确两脚本接入Root。当前采用/129保护基线见相邻wu_yong_layered_full_pack_20261019/，下文false/排队等保留历史创作语境。旧失败不改写，仍不代表连续自然步态、完整酒计/存读档或全库美术完成。\n\n')
prepend('qa/gongsun_sheng_mounted_layers_20261018/README.md','## 2026-10-19 实际原生预览59项通过\n\n吴用后继结束后已运行同一v3准备：import/native均退出0，59项/4原始截图，四向各九格全部直接查看；原日志/报告/脚本/输入及SHA见actual_native_v3/，原全图alpha1诊断仍保持。仅原生资源渲染通过；实际Unit、完整抽剑回收/骑乘连续性与生产采用仍未通过。下方尚未执行/等待与106不变属于当时历史，随后吴用采用后的当前基线为129。\n\n')
attrs=R/'.gitattributes'
with attrs.open('a',encoding='utf-8',newline='\n') as f:f.write('\n# Preserve new horse originals and exact native/package acceptance evidence.\nqa/gongsun_sheng_mounted_walk_20261019/** -text whitespace=cr-at-eol,-blank-at-eof\nqa/wu_yong_layered_full_pack_20261019/** -text whitespace=cr-at-eol,-blank-at-eof\n')
for directory in [Q,W]:
    for p in directory.glob('*.py'):ast.parse(p.read_text(),filename=str(p))
print(json.dumps({'handoff_updated':True,'source_images':len(rows),'current_baseline':129,'package_viewed':len(viewed)}))
