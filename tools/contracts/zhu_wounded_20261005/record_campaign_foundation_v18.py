"""Record the verified component boundary and remaining full-world integration work."""
from pathlib import Path
import hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    locator=json.loads((BASE/'campaign_foundation_v18b_run.json').read_text(encoding='utf-8'));run=Path(locator['run']);rp=run/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and r['private_runtime_patches']==r['root_input_drift']==r['private_input_drift']==0
    assert r['result']['passed'] and r['result']['checks']>=65 and r['component_qualified'] and not r['full_world_qualified']
    assert len(r['source_files'])==5036 and len(r['result']['runtime'])==3
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    p=QA/'campaign_foundation_qualified_v18b.json';assert not p.exists();shutil.copy2(rp,p)
    log=run/'skills.log';p=QA/'campaign_foundation_verified_log_v18b.txt';assert not p.exists();shutil.copy2(log,p)
    text=log.read_text(encoding='utf-8');assert '[rts] FAIL' not in text and 'SCRIPT ERROR:' not in text
    for label in ['level5 initial restored Level recaptures byte-equivalent payload','level5 end_button restored Level recaptures byte-equivalent payload','level8 initial restored Level recaptures byte-equivalent payload','level5 end_button callback belongs to rebuilt Mission with fixed gao_end id','original fixed Mission callback reaches authored basic ending']:
        assert '[rts] PASS '+label in text,label
    checks={
      'installed_profiles_and_inert_factories':True,'actual_original_level5_level8_launch':True,
      'all_declared_level_fields_reconstructed':True,'mission_ui_and_event_ledgers_reconstructed_without_replay':True,
      'gao_named_button_new_mission_callback_ownership':True,'original_button_reaches_authored_ending_under_explicit_stage_fixture':True,
      'unit_state_graph_restore':False,'boats_transport_production_restore':False,'map_scenery_visual_core_restore':False,
      'independent_process_save_continue_resave':False,'natural_ending_and_reward_once':False,'public_campaign_entry':False}
    review={'passed':True,'receipt_sha256':sha(rp),'log_sha256':sha(log),'checks':r['result']['checks'],'source_inputs':5036,'private_runtime_patches':0,'root_input_drift':0,'private_input_drift':0,
        'requirements':checks,'scope':r['scope'],'full_goal_qualified':False,'platform_released':False,
        'review':'Production delta reviewed: two exact installed selectors/flag maps; inert factories preserve normal definition override order; Gao Mission-owned fixed id replaces the anonymous source-world closure, existing _finish preconditions/ending unchanged. Corrected erroneous Level4-derived environment requirement. No native art/value/save schema or public Continue gate changed.',
        'next':['Implement explicit level5/level8 Unit contracts and graph membership/reference schemas; preserve Gao naval/embarked/capture state and Daming captive/disguise/worker mine object identity.',
            'Implement actual native Liangshan versus Daming map/scenery/lighting/passages and visual partition/world core binding; delay Gao Level binding until Mission-owned end_button is recreated.',
            'Complete real paid production/transport/ship/stage save, exit, independent-process continue and resave; natural endings/reward once and existing chapters/modes regression before public campaign entry.'],
        'inherited_report_note':'Base harness report retains its generic character-fixture scope text. This receipt/review defines actual Level/Mission component scope; no character render or full save qualification claimed.'}
    p=QA/'campaign_foundation_review_v18b.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    body=f'''<!-- campaign-foundation-v18b-current -->
## 2026-10-07 第5/8关恢复组件接入与高太尉具名收兵按钮

已补齐已安装level5/level8固定profile、旗标和惰性runtime/Level工厂。高太尉收兵按钮改为Mission.add_level_button("gao_end")及具名activate_mission_button，保留原_finish的战斗阶段、威胁清空、忠义堂/宋江存活条件和原结局；重建不携带旧世界闭包。Gao使用原梁山环境，修正误套其他关卡CampaignEnvironment.enabled条件，未改环境配置或地图。

真实原两关启动后，关卡全部声明字段和任务/表现组件捕获并重建：{r['result']['checks']}项通过、5036输入零漂移，无私有运行时补丁。覆盖高太尉初态/收兵按钮态和大名府初态；重建后Level再次捕获payload一致，事件账本不重放，按钮归属新Mission；内容不匹配/丢失按钮拒绝。原高太尉按钮在明确敌方伤害/0.5秒关卡调度夹具下抵达原基础结局。证据campaign_foundation_qualified_v18b.json、campaign_foundation_verified_log_v18b.txt及campaign_foundation_review_v18b.json。

组件验收使用脱离场景树的ID绑定Unit空壳和只读原地图几何，**不证明Unit/船体/运输/生产/完整世界读档**。两次失败producer/收据保留：v18在autoload初始化前preload导致Localize编译失败；v18a发现Gao环境前提错误、测试HUD类型错误和零delta策略节拍问题；另建v18a/v18b修正。旧level4/official-profile测试的“level5未安装”断言是历史范围，不能当现行九profile验收入口；未改写旧执行工具。

下一阶段完成level5/8专属Unit契约、图成员与对象引用（刘唐登船/押俘、乔装/俘虏/工人矿点），原梁山/大名府场景与灯光/通道、表现分区和world core；高太尉需等Mission按钮重建后再绑定Level。随后实际保存、退出、独立进程继续/再保存、自然结局/奖励一次和既有关卡回归。公开战役继续仍关闭，公开保存仍classic30；九玩法/发行程序、长帧/切换清理、真机及人物拥挤/完整演出等全目标未关闭。

本轮代码与组件证据/交接文档尚待白名单提交推送，上一远端d561d78c。未新增平台发布；冗余只在成功后另核指定失败批与保留缓存的逐文件一致性。
<!-- /campaign-foundation-v18b-current -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- campaign-foundation-v18b-current -->' not in old
        extra=''
        if name=='SOURCE_SETUP.md':extra='当前组件复验入口run_campaign_foundation_v18b.py --from-production <v17完成收据> --work-root <工程外QA父目录> --run；使用固定安装脚本、自然等待共享引擎及四环境路径私有profile。已成功批勿重复启动；完整world恢复另待专属集成入口。\n\n'
        p.write_bytes((body+extra+old).encode('utf-8'))
    print(json.dumps({'component_checks':r['result']['checks'],'inputs':5036,'docs':7,'full_world_qualified':False}))
if __name__=='__main__':main()
