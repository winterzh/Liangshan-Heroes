"""Save a completed skill stage without qualifying the still-running whole pilot."""
from pathlib import Path
import hashlib, json, shutil

ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_final_actions_v8a_f9097739'

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    prior_path=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_chapter_combat_production_v7_ca2acb46/receipt.json'
    prior=read(prior_path)
    assert prior['complete'] and prior['covered_default_routes_verified']
    for row in prior['source_files']+prior['candidate_inputs']:
        assert sha(ROOT/row['path'])==row['sha256']
        if row['path']!='scripts/art_db.gd': assert sha(RUN/'project'/row['path'])==row['sha256']
    art=ROOT/'scripts/art_db.gd'
    needle='"attack": "character_traits_v7_wu_song_combat", "hurt": "character_traits_v7_wu_song_combat"'
    assert art.read_text(encoding='utf-8').count(needle)==1
    expected=art.read_text(encoding='utf-8').replace(needle,needle+', "death": "character_traits_v8_wu_song_death"').encode('utf-8')
    assert (RUN/'project/scripts/art_db.gd').read_bytes()==expected
    report_path=RUN/'skills_0/report.json';report=read(report_path)
    assert report['passed'] and report['checks']==61 and report['engine_time_scale']==1.0 and len(report['screenshots'])==8
    copies=[];target_dir=QA/'ordinary_lin_skill0_checkpoint_v8a_frames';target_dir.mkdir(exist_ok=False)
    viewed={'lin_chong_0_'+d+'_cast' for d in ['se','sw','ne','nw']}|{'lin_chong_0_se_effect'}
    for row in report['screenshots']:
        source=Path(row['path']);assert sha(source)==row['sha256']
        target=target_dir/source.name;shutil.copy2(source,target);assert sha(target)==row['sha256']
        copies.append({'path':target.relative_to(ROOT).as_posix(),'sha256':sha(target),'directly_viewed':row['name'] in viewed})
    out=QA/'ordinary_lin_skill0_checkpoint_v8a.json';assert not out.exists()
    data={'completed_stage':'skills_0','run':str(RUN),'stage_report_sha256':sha(report_path),'result':report,
          'saved_native_viewports':copies,'root_source_inputs':len(prior['source_files']),
          'existing_candidate_inputs':len(prior['candidate_inputs']),'root_input_drift':0,
          'private_input_drift_except_declared_death_lookup':0,
          'private_patch':'Wu ordinary death lookup only; production ArtDB unchanged.',
          'visual_review':'Five directly viewed original viewports show actor/map after fog fixture fix, matching front/back headings, original HUD and post-cast upright idle. Other three captures saved; continuous blending/full skill effects not qualified.',
          'whole_pilot_complete':False,'wu_death_runtime_qualified':False,'production_qualified':False,
          'scope':'Original Lin Chong in registered Zhu chapter, four-direction first skill via legal restored-level6/rank1 fixture and real player commands. Nonparticipants frozen/contact/zoom/fog-off/phase freezes. Not natural leveling, full chapter, final death qualification, performance or release.'}
    out.write_bytes((json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    paragraph='''<!-- wu-death-candidate-v8-current -->
## 2026-10-07 武松倒地候选与技能检查进度

人物体态继续按原著身份分别处理：武松魁梧剽悍、林冲沉稳挺拔，普通站立与行走保持健康成人比例；时迁保留轻巧机警。攻击、受击和倒地允许合理发力、屈膝与身体弯曲。衣甲细节属于本项目的美术解释。

武松新增内置imagegen原生倒地来源9张，全部保存原字节与精确请求/父图链。选4张新来源及同人物既有西北受击来源，组成12姿态/4向资源；致命受击、倒下、静止、静止四槽，末槽是终态停留。错误朝向、缺刀、跨格的原图保留，相应错误格不采用；AtlasTexture仅用元数据取样，倒地保持固定成人解剖尺度。5个实际原生来源导入与来源/SHA核验通过，仍为候选，未登记生产默认death。

首轮v8技能画面因旧雾纹理覆盖人物判退，执行脚本、失败收据及两张实际黑屏证据保留。v8a夹具显式隐藏旧雾层并核验人物可见，未为此修改游戏源码。原祝家庄林冲第一技能四向61检查/8原生视口完成，正常时钟1.0；4904来源与105既有输入在本检查点零漂移。直接查看5张，人物/地图、前后视角和原HUD可见，施法后恢复挺拔idle；其余三张保存，连续衔接及完整技能特效不据此判为完成。合法level6/rank1恢复、接触摆位、非参与者冻结、关雾/镜头/相位冻结均为明确夹具，不是自然升级或通关。

完整两人技能及原level1真实致命伤/四向倒地仍在同一v8a私有批继续；共享引擎繁忙时自然等待，不操作其他任务。证据见qa/zhu_wounded_20261005/wu_death_native_review_v8.json、ordinary_final_actions_rejected_v8.json、ordinary_lin_skill0_checkpoint_v8a.json；请求与来源链见tools/contracts/zhu_wounded_20261005/generation_wu_song_death_v8.json。生产脚本和v7已合格默认范围保持本轮输入零漂移。本轮不将候选同步写成默认接入、完整审查、性能或平台发布；全项目未完成项继续按DEVELOPMENT_AUDIT_20261006.md执行。
<!-- /wu-death-candidate-v8-current -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md']:
        p=ROOT/'docs'/name;text=p.read_text(encoding='utf-8');assert '<!-- wu-death-candidate-v8-current -->' not in text
        extra=''
        if name=='SOURCE_SETUP.md':
            extra='v8a复查入口：python -X utf8 -B qa/zhu_wounded_20261005/harness/run_ordinary_final_actions_v8a.py --from-receipt <已合格v7生产receipt.json> --work-root <含倒地原生导入收据的工程外QA目录> --run。当前批已在运行，复查前须核对外部continuation_state.json及共享锁，不能重复启动。无--run只预检。\n\n'
        p.write_bytes((paragraph+extra+text).encode('utf-8'))
    p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';text=p.read_text(encoding='utf-8')
    p.write_bytes(('2026-10-07增量检查点：武松倒地5来源/12姿态/4资源已完成原生导入及来源核验，生产默认未接入；原林冲第一技能四向61项/8图完成，合法level6恢复夹具。v8旧雾层黑屏已判退保留，v8a完整技能/死亡仍在运行并自然等待共享引擎。来源检查点4904+105输入零漂移。本增量不关闭下表连续动作、完整技能/死亡或全项目未完成项。证据见ordinary_lin_skill0_checkpoint_v8a.json及wu_death_native_review_v8.json。\n\n'+text).encode('utf-8'))
    print(json.dumps({'completed_stage_checks':61,'captures':8,'directly_viewed':5,'root_input_drift':0,'production_scripts_changed':False,'whole_pilot_complete':False}))

if __name__=='__main__': main()
