"""Retain scoped original-chapter proof, native candidate evidence and current handoff."""
from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT.parent/'qa-ordinary-posture-20261006'
QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
run=Path(read(BASE/'ordinary_chapter_actions_v6b_run.json')['run']);receipt=read(run/'receipt.json')
assert receipt['complete'] and receipt['lock_released'] and not receipt['source_changes'] and not receipt['private_source_changes']
assert receipt['private_patch_verified'] and receipt['candidate_input_drift']==0
assert receipt['result']['passed'] and receipt['result']['checks']==255 and len(receipt['result']['screenshots'])==32 and receipt['result']['engine_time_scale']==1.0
shutil.copy2(run/'receipt.json',QA/'ordinary_chapter_actions_v6b.json')
boot=Path(read(BASE/'texture_bootstrap_wu_song_actions_v6_run.json')['run']);texture=read(boot/'receipt.json')
assert texture['complete'] and texture['lock_released'] and len(texture['dimensions']['checks'])==7
shutil.copy2(boot/'receipt.json',QA/'wu_song_actions_texture_v6.json')
viewed=['lin_chong_nw_idle','lin_chong_nw_attack','lin_chong_se_hurt','lin_chong_nw_walk','wu_song_ne_idle','wu_song_ne_attack','wu_song_sw_hurt','wu_song_ne_walk']
frames=QA/'ordinary_chapter_actions_review_frames_v6';frames.mkdir(exist_ok=True)
images=[]
for name in viewed:
 src=run/'evidence'/(name+'.png');dest=frames/src.name
 shutil.copy2(src,dest);assert sha(src)==sha(dest)
 images.append({'name':name,'path':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest),'native_bytes_unchanged':True})
failures=[]
for folder in ['ordinary_chapter_actions_v6_5600c55f','ordinary_chapter_actions_v6a_5ea8ab6d']:
 failed=BASE/folder;r=read(failed/'receipt.json');assert not r['complete'] and r['lock_released']
 row={'run':str(failed),'receipt_sha256':sha(failed/'receipt.json'),'failure':r['failure'],'harnesses':r['harnesses'],'steps':r['steps']}
 if (failed/'evidence/report.json').exists():
  row['report']=read(failed/'evidence/report.json');row['report_sha256']=sha(failed/'evidence/report.json')
 failures.append(row)
write(QA/'ordinary_chapter_actions_failed_parents_v6.json',{'failures':failures,'scope':'Failed originals and exact frozen producers retained. v6 parse type error; v6a four incorrect assumptions about missing Wu hurt plus slow-render timer movement sampling. v6b uses explicit bool, existing no-hurt fallback and observed physical movement. No production fixes or stat injections.'})
write(QA/'ordinary_chapter_actions_review_v6.json',{'mechanical_checks':255,'captures':32,'baseline_inputs':4904,'candidate_inputs':86,
 'root_input_drift':0,'private_input_drift_except_declared_artdb_patch':0,'normal_clock':1.0,'reviewed':images,
 'findings':['New ordinary idle/walk stays upright in the sampled actual chapter contexts; standard portraits, selected unit panel and skill identities remain.',
 'Original Lin has four authored directional attack/hurt resources; complete continuous spear/body alignment remains unqualified.',
 'Actual Wu attacks in all four logical directions use the same legacy side-view strip with directional=false: rear-facing idle transitions to a side-view attack. Actual Wu has no authored hurt and normally retains the current body under programmatic recoil.',
 'Seven native imagegen outputs retained, selected five supply sixteen new Wu action candidates; native1254RGBA import checks passed. Three-phase attack and hurt sampling/resources are not authored or run yet. Incorrect SW heading and NW cross-cell boot source variants retained.'],
 'scope':receipt['scope'],'production_qualified':False,'continuous_gait_qualified':False,'new_action_runtime_qualified':False})
note='''<!-- ordinary-actions-v6-current -->
## 2026-10-07 原关卡动作诊断与武松战斗候选

人物按原著特性分别处理：武松魁梧剽悍、林冲沉稳挺拔，普通待机保持健康上背与成人比例；时迁保留轻巧机警。攻击/受击允许合理转胯、屈膝、倾身，不统一成僵硬军姿。

原祝家庄林冲/大名府武松的正常指令、真实近战/反击、恢复行走与原HUD诊断255项、32截图通过，正常时钟1.0；4904原输入及86候选输入零漂移。只有私有ArtDB普通idle/walk查询替换，生产源码四脚本未修改。接触摆位、冻结非参与者、关雾/镜头及命中物理帧冻结是明确夹具；这不是默认接入、技能/死亡、连续步态、自然通关、保存、性能或平台资格。v6类型错误及v6a受击/计时夹具错误原批完整保留。当前证据：qa/zhu_wounded_20261005/ordinary_chapter_actions_v6b.json及ordinary_chapter_actions_review_v6.json。

实际发现武松四向攻击仍取同一旧侧面帧带，后视出手会跳回侧面；无独立hurt图时沿用身体加程序化退缩。新增imagegen原生战斗候选保留7张1254RGBA来源，5张选用来源组成四向蓄势/斩击/收势/受击16姿态，7张实际原生尺寸导入通过。西南首版两帧错向、西南第二版hurt错向、西北首版脚跨格均保留；西南hurt改为独立原生图。清单assets/direction4/ordinary_wu_song_20261007_actions_v6.json，精确请求/父图链tools/contracts/zhu_wounded_20261005/generation_wu_song_actions_v6.json。未本地裁切/缩放/镜像/重绘。

下一步为新战斗图独立编排脚点/头部身高与SpriteFrames，实跑动作与待机/行走衔接；核验双刀握法、后视支撑腿，林冲连续枪长/枪缨与体型。新战斗资源尚未编排，resources=0；普通两人默认路由、完整动作/连续资格仍开放。全项目仍按DEVELOPMENT_AUDIT_20261006.md执行。本轮未清理、打包或发布平台。
<!-- /ordinary-actions-v6-current -->

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','CHARACTER_POSTURE_20261006.md','DIRECTORY_INDEX.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md']:
 p=ROOT/'docs'/name;raw=p.read_bytes();assert b'<!-- ordinary-actions-v6-current -->' not in raw
 p.write_bytes(note.encode('utf-8')+raw)
p=ROOT/'docs/SOURCE_SETUP.md'
entry='''\n当前原关卡诊断入口：python -X utf8 -B qa/zhu_wounded_20261005/harness/ordinary_chapter_actions_v6b.py --from-receipt <已完成原Battle evidence/receipt.json> --work-root <包含Wu/Lin已核验native texture bootstrap收据的工程外QA目录> --run。无--run只读预检。自然等待共享Godot，使用独立私有profile。该入口只诊断旧战斗图与新idle/walk，不加载本轮新战斗候选。\n'''
p.write_bytes(p.read_bytes()+entry.encode('utf-8'))
audit=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';text=audit.read_text(encoding='utf-8')
old='| 两人连续衣装/足底/武器、完整战斗/终态/血条/原Battle生产UI资格待完成；'
new='| 新增原Battle动作诊断255项/32截图/4904+86输入零漂移，私有普通idle/walk查询替换，正常近战/反击与原HUD已观察。武松旧攻击侧面跳变已确认，新增7原生来源/16选用姿态候选及原生导入；新动作脚点/资源/运行未完成。两人连续衣装/足底/武器、技能/终态/完整生产UI资格待完成；'
assert old in text;text=text.replace(old,new,1);audit.write_bytes(text.encode('utf-8'))
print(json.dumps({'completed_original_diagnostic':255,'native_import_checks':7,'retained_review_frames':len(images),'new_action_runtime_qualified':False,'production_qualified':False}))
