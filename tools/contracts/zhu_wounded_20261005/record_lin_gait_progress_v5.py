"""Archive completed Lin gait evidence; keep full production/gameplay gates open."""
from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];QA=ROOT/'qa/zhu_wounded_20261005'
run=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_gait_motion_lin_chong_v5_c90ea218'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
r=read(run/'receipt.json');v=r['result']
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==r['candidate_input_drift']==0
assert v['engine_time_scale']==1.0 and len(v['checks'])==96 and all(c['passed'] for c in v['checks'])
assert len(v['samples'])==len(r['captures'])==80
for row in r['inputs']+r['candidate_inputs']:assert sha(ROOT/row['path'])==row['sha256']==sha(run/'project'/row['path'])
for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']==sha(run/'harness'/Path(row['path']).name)
dest=QA/'ordinary_lin_chong_gait_motion_comparison_v5.json';assert not dest.exists();shutil.copyfile(run/'receipt.json',dest)
directory=QA/'lin_chong_gait_review_frames_v5';assert not directory.exists();directory.mkdir()
reviewed=[5,6,8,11,13,15,35,59,75];captures=[]
for n in reviewed:
 src=run/'project'/v['samples'][n]['capture'];assert sha(src)==r['captures'][n]['sha256'];dst=directory/src.name
 shutil.copyfile(src,dst);assert sha(src)==sha(dst);captures.append({'sample':n,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
write(QA/'ordinary_lin_chong_gait_motion_review_v5.json',{
 'scope':'Direct original viewport frame review of detached actual Unit/Defs movement at1x/4x; no continuous playback or original Battle/combat/UI/save/platform qualification.',
 'checks':96,'captures':80,'baseline_inputs':len(r['inputs']),'candidate_inputs':42,'input_drift':0,'candidate_input_drift':0,
 'engine_time_scale':1.0,'four_heading_four_phase_coverage':v['seen'],'directly_viewed_frames':captures,
 'runtime_receipt':dest.relative_to(ROOT).as_posix(),'runtime_receipt_sha256':sha(dest),
 'observations':['Upright mature Lin identity and low spear carry remain visible in idle and walking.',
  'Four independently authored contact/passing phases in each front/back direction appeared under inherited normal movement.',
  'Boot-only pivot windows exclude the spear and improve body/ground marker alignment in viewed idle/start/stop/reverse frames.',
  'Armor panel/tassel/spear length/grip continuity, foot slip, health-bar spacing and full-game actions remain open.'],
 'detached_motion_component_qualified':True,'continuous_gait_qualified':False,'production_qualified':False})
block='''<!-- lin-full-gait-v5-current -->
## 2026-10-07 林冲四向待机/四步相行走候选完成独立对照

按沉稳挺拔的教头体态处理，健康上背、自然抬头挺胸、成年比例；保留蓝衣金边甲与长枪低持。17原生来源形成四向idle及每向walk_a/passing_a/walk_b/passing_b，共20姿态/8资源。脚点按独立靴子区域编排，避开伸入下部的长枪与红缨；原v4待机资源不修改。内置imagegen原生生成/编辑，数学参考和已验证武松步相仅作腿姿/镜头参考，不继承武松脸、服装或双刀。所有精确请求、父图和换脚/背景失败原图保留，不本地裁切/缩放/镜像/重绘，不以idle充walk。

17来源原生尺寸导入与374项来源/透明/资源检查通过。真实Unit/正常Defs英雄与四技能、正常时钟1.0的独立起停/反向对照96项、80截图通过，4904旧输入及42候选输入零漂移，四向四步相全部实际出现。直接查看原生1×/4×视口帧5/6/8/11/13/15/35/59/75，体态与主要身高/脚点衔接改善。仍需连续足底/衣装/枪缨/枪长/握法、血条间距、战斗/终态和原Battle/生产取图/UI/存档资格；普通生产路由未替换，production_qualified=false。

清单：assets/direction4/ordinary_lin_chong_20261006_gait_v5.json；来源链：tools/contracts/zhu_wounded_20261005/generation_lin_chong_gait_v5.json；实际对照与审核：qa/zhu_wounded_20261005/ordinary_lin_chong_gait_motion_comparison_v5.json及ordinary_lin_chong_gait_motion_review_v5.json。此前只到idle/SE候选的段落是历史阶段；旧producer与收据不改写。

下一步同时核验武松/林冲的连续与完整动作、原关卡/生产UI路由，再推进完整DEVELOPMENT_AUDIT_20261006.md。八关动态、自然结局/奖励一次、九模式、性能及Android资格仍开放。本轮未清理、打包或发布平台。
<!-- /lin-full-gait-v5-current -->

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md']:
 p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- lin-full-gait-v5-current -->' not in old
 extra=''
 if name=='SOURCE_SETUP.md':extra='林冲新对照入口：python -X utf8 -B qa/zhu_wounded_20261005/harness/ordinary_lin_gait_motion_comparison_v5.py --key lin_chong --from-receipt <已完成原Battle evidence/receipt.json> --work-root <包含已核验texture_bootstrap_lin_chong_gait_v5_run.json的工程外QA目录> --run。无--run预检。自然等待共享Godot，不改变生产入口或角色数值。\n\n'
 p.write_bytes((block+extra+old).encode('utf-8'))
p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';lines=p.read_text(encoding='utf-8').splitlines();found=0
for i,line in enumerate(lines):
 if line.startswith('| 原著人物特性、成人比例与动作身份 |'):
  lines[i]='| 原著人物特性、成人比例与动作身份 | 七人135原生来源/140姿态，原Battle946项/16截图/4904输入零漂移。武松、林冲各17来源/20姿态/8资源、306/374来源检查与各96项/80截图实际Unit起停反向通过，四向四步相覆盖，4904旧+42候选输入零漂移；林冲正常时钟1.0及靴子独立脚点已记录 | 两人连续衣装/足底/武器、完整战斗/终态/血条/原Battle生产UI资格待完成；普通生产路由尚未替换。七人完整终态、全库人物/旧头像/特效/多尺寸UI仍未闭合 |';found+=1
assert found==1;p.write_bytes(('\n'.join(lines)+'\n').encode('utf-8'))
p=ROOT.parent/'qa-rescued-seven-current-20261006/continuation_state.json';state=read(p)
state.update(runner_session_id=None,state='Lin complete17source20pose8resource candidate passed17native/374source checks and real Unit96checks80captures,4904+42inputs zero drift, normalclock1.0. All own jobs terminal. Nine viewed original viewport frames archived. Both ordinary candidates remain production/continuous/combat/originalBattle unqualified.',committed=False,pushed=False,next='Review and whitelist sync Lin candidate round, then qualify both ordinary characters continuous/full actions/original Battle and UI, and continue full development audit. No cleanup or platform publish done.')
p.write_bytes((json.dumps(state,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'checks':96,'captures':80,'review_frames':len(reviewed),'documents':7,'production_qualified':False}))
