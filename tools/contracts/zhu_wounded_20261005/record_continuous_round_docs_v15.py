"""Record scoped continuous sampling, capture repairs and exact duplicate cleanup."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    cp=BASE/'rejected_continuous_cache_cleanup_applied_v15.json';c=read(cp)
    assert c['complete'] and c['apply_requested'] and c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    assert c['deleted_files']==len(c['matches']) and c['deleted_bytes']==c['matched_bytes']
    r=read(QA/'ordinary_continuous_gait_qualified_v15b.json');v=read(QA/'ordinary_continuous_gait_visual_review_v15b.json')
    assert r['complete'] and v['passed'] and v['receipt_sha256']==sha(QA/'ordinary_continuous_gait_qualified_v15b.json')
    summary={k:c[k] for k in ['scope','keeper_receipt','keeper_receipt_sha256','targets','protected_files','matched_bytes','apply_requested','complete','deleted_files','deleted_bytes','producer_sha256','protected_hash_drift','keeper_match_hash_drift','elapsed_seconds']}
    summary.update(full_inventory=str(cp),full_inventory_sha256=sha(cp),different_or_missing_keeper_count=len(c['different_or_missing_kept']),
        restore='Reimport the named rejected v15/v15a private projects in Godot before rechecking. Only imported exact duplicates removed; source, import descriptors, native images, receipts, reports, logs, screenshots, private profiles and saves remain. Retained v14 and v15b successful caches unchanged.')
    p=QA/'rejected_continuous_import_cleanup_v15.json';assert not p.exists();p.write_bytes((json.dumps(summary,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    body=f'''<!-- continuous-gait-v15b-current -->
## 2026-10-07 普通武松、林冲连续运动采样与三种桌面窗口复核

原祝家庄林冲/大名府武松保持人物物理与正常时钟1.0，各四向实际指令行走，每案8张原生运动采样并遍及全部4步相，位置实际推进；标准头像和人物数值保留。v15b生产脚本原样、无私有补丁，441项/70图通过，5034输入零漂移。直接复核当前14视口（每人每向1运动样本、3种待机窗口）；另保存已直接复核的v15a每人每向前4样本共32图，当前与前批的全部来源输入和逐案4姿态集合一致。证据ordinary_continuous_gait_qualified_v15b.json、ordinary_continuous_gait_visual_review_v15b.json。1280×720、1440×960、1920×1080中资源栏、头像、技能及底栏可见，人物头部、衣装/盔甲和武器保持身份。

审核保留两次真实判退：v15首个新方向采到四次投票转向前的旧姿态，301项中12项失败；v15a机械301项/70图通过但手动镜头跳转后的氛围矩形明暗边界判退。v15b只在采样时等待实际方向，并调用既有_refresh_run_capture_presentation刷新派生几何，逐图验证滤镜原点和完整视口尺寸；不改生产脚本、PNG、动作资源或模拟值。旧producer、失败图/日志/收据不改写。当前资格为正常运动采样和所述桌面视口复核，不是无间断录像或逐像素脚底接触证明；完整攻击/施法连续演出、技能中后期血条间距、多尺寸完整流程和Android真机仍开放。

只清指定判退v15/v15a工程imported中与保留v15b成功批同名、大小、SHA256一致的{c['deleted_files']}文件、{c['deleted_bytes']:,}字节（约{c['deleted_bytes']/1024**3:.2f}GiB）；{c['protected_files']}受保护文件和保留匹配缓存零漂移。源码、原生图片、失败证据、私有profile/存档、主缓存、其他任务、成功v14/v15b缓存及平台包保留，旧工程复查先重导入；清单/恢复见rejected_continuous_import_cleanup_v15.json。此前6批4.824GiB清单仍未删除。

本轮验收工具、相关证据/文档尚待本轮白名单提交推送；上一远端为99ed9d85。下一项ordinary_skill_clearance_v16.gd/run_ordinary_skill_clearance_v16.py核验7个主动技能、4向、中/后期实际计时姿态，后期再核对3种窗口，共计划112图；合法level6/rank1与到达相位后冻结截图均为明确夹具，结果依新完成收据，准备或启动不算通过。被动林冲E无抬手，沿用已有被动命中证据。全项目其他审计门槛仍按DEVELOPMENT_AUDIT_20261006.md推进，未合main或发布平台。
<!-- /continuous-gait-v15b-current -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- continuous-gait-v15b-current -->' not in old
        old,n=re.subn(r'<!-- continuous-gait-v15a-waiting -->.*?<!-- /continuous-gait-v15a-waiting -->\s*','',old,count=1,flags=re.S);assert n==1
        if name=='DEVELOPMENT_AUDIT_20261006.md':
            lines=old.splitlines()
            for i,line in enumerate(lines):
                if line.startswith('| 原著人物特性、成人比例与动作身份 |'):
                    lines[i]='| 原著人物特性、成人比例与动作身份 | 默认36资源；正式715项80图通过。新增正常物理连续运动采样441项70图、5034输入零漂移；14当前视口与32同来源前批运动样本直接复核，三种桌面窗口主要HUD可见 | 采样不等于无间断视频/逐像素脚底接触；完整攻击/施法连续、技能中后期血条、多尺寸流程、七人终态与全库人物/头像/特效仍开放 |'
                elif line.startswith('| 审核、修错、有限冗余清理 |'):
                    lines[i]=f'| 审核、修错、有限冗余清理 | 当前v15b采样及主要桌面HUD复核通过；判退v15/v15a重复imported {c["deleted_files"]}文件、{c["deleted_bytes"]:,}字节已清，受保护/保留缓存零漂移。先前v7/v14清理保留原收据 | 只关闭指定重复文件，旧工程复查先重导入；6批4.824GiB未删。完整审核继续，失败来源/报告不删除 |'
            old='\n'.join(lines)+'\n'
        extra=''
        if name=='SOURCE_SETUP.md':extra='连续复验固定producer：python -X utf8 -B qa/zhu_wounded_20261005/harness/run_ordinary_continuous_gait_v15b.py --from-production <v14完成收据> --work-root <工程外QA父目录> --run；v15b已完成，不重复启动。技能中/后期入口run_ordinary_skill_clearance_v16.py参数同前，先查工程外continuation_state.json/运行定位文件再恢复已有进程；本机Godot仍由忽略配置提供。\n\n'
        p.write_bytes((body+extra+old).encode('utf-8'))
    print(json.dumps({'docs_updated':7,'checks':441,'captures':70,'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'full_goal_qualified':False}))
if __name__=='__main__':main()
