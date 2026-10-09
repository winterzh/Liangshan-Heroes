"""Update the current handoff without rewriting earlier executed QA evidence."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
DOCS=['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cp=BASE/'rejected_skill_import_cleanup_applied_v17.json';c=json.loads(cp.read_text(encoding='utf-8'))
    assert c['complete'] and c['apply_requested'] and c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    assert c['deleted_files']==len(c['matches']) and c['deleted_bytes']==c['matched_bytes']
    summary={k:c[k] for k in ['scope','keeper_receipt','keeper_receipt_sha256','targets','protected_files','matched_bytes','apply_requested','complete','deleted_files','deleted_bytes','producer_sha256','protected_hash_drift','keeper_match_hash_drift','elapsed_seconds']}
    summary.update(full_inventory=str(cp),full_inventory_sha256=sha(cp),different_or_missing_keeper_count=len(c['different_or_missing_kept']),restore='Reimport only the named rejected v16/v16a/v16b private projects before rechecking. Sources, original images, executed producers, logs, screenshots, profiles and saves retained. Current v17 successful cache and all other caches untouched.')
    p=QA/'rejected_skill_import_cleanup_v17.json';assert not p.exists();p.write_bytes((json.dumps(summary,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    body=f'''<!-- guard-readability-v17-current -->
## 2026-10-07 人物特性、技能画面复核与林冲枪架遮挡修正

人物标准按原著区别：武松、林冲普通待机/行走抬头挺胸、成人比例端正；时迁保留机敏警觉。攻击、受击、倒地自然弯曲，不统一成僵硬军姿。已登记36默认资源；715项80图普通战斗/倒地、441项70图连续运动采样的历史资格保留。

技能v16终态329项48图失败（夹具错误要求武松章敌方英雄）；v16a终态733项112图失败（武松E击杀后复用死目标）；v16b761项112图/28实际效果机械通过，但林冲W后R的白色中心枪架遮住上半身，画面判退。三批真实失败/判退收据、固定producer和原生证据保留。v17只改Battle.LinGuardFx._draw外围位置/线段/透明度，生命计时、技能效果、反击、数值及PNG未改。

当前正式源码原样复制、无私有运行时补丁，正常时钟1.0：7主动技能×4向，真实中/后期计时与后期1280×720、1440×960、1920×1080窗口，761项、112图、28实际效果通过，5034来源零漂移。直接复核19张当前原生视口，包括林冲枪架四向及选定中/后期尺寸；上身、头部和血条可辨，外围提示仍可见。证据ordinary_guard_readability_qualified_v17.json、ordinary_guard_readability_visual_review_v17.json及review_v17_frames。武松召唤虎近距离身体/名字/血条重叠仍开放，不能称全部UI无遮挡。合法level6/rank1、接触摆位、冻结非参与者、关雾/镜头和到达相位后冻结截图是明确夹具；不等于无间断演出、自然升级/通关、性能或真机证明。

只删除指定v16/v16a/v16b判退工程imported中与保留v17成功批同名、大小、SHA256一致的{c['deleted_files']}文件、{c['deleted_bytes']:,}字节（约{c['deleted_bytes']/1024**3:.2f}GiB）；{c['protected_files']}受保护文件及保留匹配缓存零漂移。不同缓存保留；旧工程复查先重导入，收据rejected_skill_import_cleanup_v17.json。此前6批4.824GiB未删。

新增只读八关声明审计campaign_restore_gap_inventory_v18.json：level5三败高太尉、level8智取大名府缺少已安装恢复profile/factory；高太尉结局按钮仍为匿名回调，需要具名可恢复的任务按钮及对应对象/船体/运输/生产绑定。下一阶段补齐实际恢复并验独立进程保存、继续、再保存、自然结局/奖励一次和既有关卡回归。当前公开继续仍classic30；声明齐全不算功能通过。拥挤编队UI、完整连续演出、同版九玩法/发行程序、约10分钟尾帧及Android2.0.1真机等全项目项仍开放。

本轮源码、审核证据、清理记录和七份交接文档尚待白名单提交推送；上一独立远端回读897c0ad763ac22d9c953ae8dfdc805e2ba0bdc17。未合main或发布平台。
<!-- /guard-readability-v17-current -->

'''
    for name in DOCS:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- guard-readability-v17-current -->' not in old
        old,n=re.subn(r'<!-- skill-clearance-v16a-pending -->.*?<!-- /skill-clearance-v16a-pending -->\s*','',old,count=1,flags=re.S);assert n==1
        if name=='DEVELOPMENT_AUDIT_20261006.md':
            rows=old.splitlines()
            for i,line in enumerate(rows):
                if line.startswith('| 原著人物特性、成人比例与动作身份 |'):
                    rows[i]='| 原著人物特性、成人比例与动作身份 | 36默认资源；715项80图普通战斗/倒地、441项70图运动采样；当前761项112图技能中后期/28效果通过，19当前视口直接复核，林冲外围枪架修正 | 拥挤虎/人物/血条、无间断完整演出、全库/七人终态、多尺寸流程仍开放；相位截图不等于全流程 |'
                elif line.startswith('| GitHub增量同步 |'):
                    rows[i]='| GitHub增量同步 | 上一独立回读897c0ad7；当前v17生产画面修正、761项112图/19视口证据及失败/清理记录待本轮白名单同步 | 不合main、不发布平台；全目标继续 |'
            old='\n'.join(rows)+'\n'
        extra=''
        if name=='SOURCE_SETUP.md':extra='当前v17已完成，勿重复启动。复验入口run_ordinary_guard_readability_v17.py --from-production <v16b完成收据> --work-root <工程外QA父目录> --run；它仅接受已记录的battle.gd绘制差异，复制后零私有运行时补丁。被清失败批先重新导入。\n\n'
        p.write_bytes((body+extra+old).encode('utf-8'))
    print(json.dumps({'docs':7,'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'full_goal_qualified':False}))
if __name__=='__main__':main()
