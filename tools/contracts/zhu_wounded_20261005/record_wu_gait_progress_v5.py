"""Preserve the completed Wu gait diagnostic and update the full development audit."""
from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];QA=ROOT/'qa/zhu_wounded_20261005'
run=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_gait_motion_wu_song_v5_a2865ea3'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
r=read(run/'receipt.json');assert r['complete'] and r['lock_released'] and r['input_sha_drift']==r['candidate_input_drift']==0
assert len(r['result']['checks'])==96 and all(c['passed'] for c in r['result']['checks'])
assert len(r['captures'])==len(r['result']['samples'])==80 and len(r['candidate_inputs'])==42
for row in r['inputs']+r['candidate_inputs']:assert sha(ROOT/row['path'])==row['sha256']==sha(run/'project'/row['path'])
for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']==sha(run/'harness'/Path(row['path']).name)
dest=QA/'ordinary_wu_song_gait_motion_comparison_v5.json';assert not dest.exists();shutil.copyfile(run/'receipt.json',dest)
selected=[5,6,7,9,10,15,35,59,75]
directory=QA/'wu_song_gait_review_frames_v5';assert not directory.exists();directory.mkdir()
captures=[]
for n in selected:
    src=run/'project'/r['result']['samples'][n]['capture']; assert sha(src)==r['captures'][n]['sha256']
    dst=directory/src.name;shutil.copyfile(src,dst);assert sha(dst)==sha(src)
    captures.append({'sample':n,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
write(QA/'ordinary_wu_song_gait_motion_review_v5.json',{
    'scope':'Direct original viewport frame inspection of a detached real Unit/Defs movement diagnostic at1x/4x; not continuous playback, original Battle/combat/UI/save or platform qualification.',
    'mechanical_checks':96,'captures':80,'baseline_inputs':len(r['inputs']),'candidate_inputs':42,
    'input_drift':0,'candidate_input_drift':0,'four_heading_four_phase_coverage':r['result']['seen'],
    'directly_viewed_frames':captures,'runtime_receipt':dest.relative_to(ROOT).as_posix(),'runtime_receipt_sha256':sha(dest),
    'observations':[
        'New idle and walking maintain an upright mature body and low twin-dao carry; old deep-crouch ordinary walking is no longer used by the candidate adapter.',
        'Back-facing NE/NW are separately authored and stay back-facing when starting, reversing and stopping instead of borrowing old frontal walk images.',
        'All four contact/passing phases per heading were actually rendered with inherited movement and normal ordinary hero/skills definitions.',
        'At1x/4x the principal body height and foot-origin placement remain comparable between candidate idle and walk in viewed frames.',
        'Detailed bead arrangement, cloth/hair ripple, blade length, foot slip and health-bar spacing still need continuous/full-game action review.'
    ],'detached_motion_component_qualified':True,'continuous_gait_qualified':False,'production_qualified':False})
block='''<!-- wu-full-gait-v5-current -->
## 2026-10-06 武松四向待机/四步相行走候选完成独立对照

按武松魁梧剽悍、健康上背与抬头挺胸的普通体态处理；保留行者衣装、念珠、绑腿与双刀低持，步行允许自然重心转移。原生17来源构成四向idle及每向walk_a/passing_a/walk_b/passing_b，共20姿态/8资源。全部经内置imagegen原生生成/编辑，精确请求、父图、数学腿部producer及三张错误换脚/朝向原图保留；不本地裁切/缩放/镜像/重绘，不以idle充walk。

17张原生尺寸导入、306项来源/透明/取样检查通过。独立实际Unit/正常Defs英雄与四技能起停/反向对照96项、80截图通过，4904旧输入及42候选输入零漂移，四向四步相全部实际出现。直接查看原生视口帧5/6/7/9/10/15/35/59/75的1×/4×：普通行走保持挺拔，背面朝向和主要身高/脚点与idle衔接改善。此为脱离Battle的动作组件证据；未连续播放审查衣装/足底滑动，仍需攻击/受击/终态、血条间距、原关卡/生产取图/UI/存档资格。普通武松生产路由未替换，production_qualified=false。林冲目前仍为idle与SE两步相候选，下一步补同等完整动作。

清单：assets/direction4/ordinary_wu_song_20261006_gait_v5.json；来源链：tools/contracts/zhu_wounded_20261005/generation_wu_song_gait_v5.json；实际对照与审核：qa/zhu_wounded_20261005/ordinary_wu_song_gait_motion_comparison_v5.json及ordinary_wu_song_gait_motion_review_v5.json。旧producer与旧收据不改写。

全目标仍按DEVELOPMENT_AUDIT_20261006.md推进；八关动态阶段、自然胜败/奖励一次、九模式、性能/Android资格尚未关闭。本轮没有清理、打包或平台发布。以下历史状态按对应日期/范围理解。
<!-- /wu-full-gait-v5-current -->

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md']:
    p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- wu-full-gait-v5-current -->' not in old
    extra=''
    if name=='SOURCE_SETUP.md':extra='新动作对照入口：python -X utf8 -B qa/zhu_wounded_20261005/harness/ordinary_gait_motion_comparison_v5.py --key wu_song --from-receipt <已完成原Battle evidence/receipt.json> --work-root <包含已核验texture_bootstrap_wu_song_gait_v5_run.json的工程外QA目录> --run。无--run为预检。自然等待共享引擎；不会启动生产入口或改变角色数值。\n\n'
    p.write_bytes((block+extra+old).encode('utf-8'))
p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';lines=p.read_text(encoding='utf-8').splitlines();found=0
for i,line in enumerate(lines):
    if line.startswith('| 原著人物特性、成人比例与动作身份 |'):
        lines[i]='| 原著人物特性、成人比例与动作身份 | 七人135原生来源/140姿态，原Battle946项/16截图/4904输入零漂移。普通武松新17来源/20姿态/8资源、306来源检查与96项/80截图独立实际Unit起停/反向通过，四向四步相全部覆盖，4904旧+42候选输入零漂移；林冲仍为idle/SE接触步相候选 | 武松连续衣装/足底、战斗/终态/血条/原Battle生产UI资格及林冲完整四向动作待完成；普通生产取图尚未替换。七人完整终态、全库人物/旧头像/特效/多尺寸UI仍未闭合 |';found+=1
assert found==1;p.write_bytes(('\n'.join(lines)+'\n').encode('utf-8'))
statefile=ROOT.parent/'qa-rescued-seven-current-20261006/continuation_state.json';s=read(statefile)
s.update(runner_session_id=None,state='Wu ordinary full gait candidate:17sources20poses8resources imported/source306 and real Unit96checks80captures with4904+42inputs zero drift completed. All own jobs terminal. Nine viewed original viewport frames archived byte-identically. Production/continuous/combat/originalBattle remain unqualified.',next='Whitelist review/commit/push the verified Wu candidate round, then finish Lin complete gait and qualify original gameplay/combat/UI plus continuous detailed gait. Keep full development audit open; no cleanup done.',committed=False,pushed=False)
statefile.write_bytes((json.dumps(s,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'checks':96,'captures':80,'reviewed_original_frames':len(captures),'documents':7,'production_qualified':False}))
