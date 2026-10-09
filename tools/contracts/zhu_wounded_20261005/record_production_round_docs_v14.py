"""Record final scoped production qualification and verified cache cleanup."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT.parent/'qa-ordinary-posture-20261006'
QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))

def main():
    cp=BASE/'failed_v10_import_cleanup_applied_v14.json';c=read(cp)
    assert c['complete'] and c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    assert c['deleted_files']==len(c['matches']) and c['deleted_bytes']==c['matched_bytes']
    r=read(QA/'ordinary_production_qualified_v14.json')
    assert r['complete'] and r['private_runtime_patches']==0
    summary={k:c[k] for k in ['scope','keeper_receipt','keeper_receipt_sha256','targets','protected_files','matched_bytes','apply_requested','complete','deleted_files','deleted_bytes','producer_sha256','protected_hash_drift','keeper_match_hash_drift','elapsed_seconds']}
    summary.update(full_inventory=str(cp),full_inventory_sha256=sha(cp),different_or_missing_keeper_count=len(c['different_or_missing_kept']),
        restore='Only exact duplicate imported files removed. Reimport the named failed project in Godot before rechecking. Its source, import descriptors, receipts, logs, screenshots, private profile and saves remain.')
    sp=QA/'failed_death_import_cleanup_v14.json';assert not sp.exists()
    sp.write_bytes((json.dumps(summary,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    body=f'''<!-- ordinary-production-v14-qualified -->
## 2026-10-07 当前正式源码：人物特征动作、受击与倒地复验通过

武松、林冲待机和行走保留端正站姿；时迁等人物保留各自原著特性。ArtDB普通默认取图已登记武松四向death、林冲四向death/hurt；林冲仅西南采用新朝左站立受击和倒地，其他三向为原资源逐字节别名。当前36个默认资源及6份来源清单见ordinary_character_default_routes_v14.json。生产代码本轮只修改ArtDB两行查表，Unit、人物数值、技能、存档、任务回调未改；显式剧情变体继续采用原路由。作者候选清单的历史资格字段不改写。

正式生产脚本原样复制，无私有运行时补丁，正常时钟1.0：近战/非致命反击369项、48图；真实致命战斗/四阶段倒地/影子保留与释放/Unit释放346项、32图，合计715项、80图通过。4904来源、105既有和25新输入零漂移。12张关键原生视口直接复核并原字节保存，林冲SW朝向、成人比例与长枪完整，武松四向落地保持双刀与身体身份。证据ordinary_production_qualified_v14.json及ordinary_production_visual_review_v14.json。接触摆位、非参与者冻结、关雾、镜头和相位仍为明确夹具，不能据此关闭连续步态、血条间距、多尺寸UI、自然通关或性能资格。

只删除指定失败批ordinary_death_pilot_v10_5101dfd0的imported中与保留v14成功批同名、大小、SHA256一致的{c['deleted_files']}个文件、{c['deleted_bytes']:,}字节（约{c['deleted_bytes']/1024**2:.1f}MiB）；{c['protected_files']}个受保护文件及保留匹配缓存零漂移。源码、原图、失败画面、日志、存档、成功批、主缓存、其他工程和平台包保留。旧失败工程复查前须重新导入。范围、完整清单位置与恢复方式见failed_death_import_cleanup_v14.json。先前6批4.824GiB只读清单仍未删除。

本轮已本地修改并验证，尚待本轮白名单提交、推送和独立远端SHA回读；当前此前远端为7ebfe4e3。GitHub源码同步不等于Steam发布。完整目标继续依DEVELOPMENT_AUDIT_20261006.md：连续动作与多尺寸UI、八关动态/生产/船体、战役独立进程保存与自然结局/奖励一次、同版九玩法/发行程序、正常时钟约10分钟尾帧/切换清理和Android真机资格。
<!-- /ordinary-production-v14-qualified -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- ordinary-production-v14-qualified -->' not in old
        if name=='DEVELOPMENT_AUDIT_20261006.md':
            lines=old.splitlines()
            for i,line in enumerate(lines):
                if line.startswith('| 原著人物特性、成人比例与动作身份 |'):
                    lines[i]='| 原著人物特性、成人比例与动作身份 | 当前默认36资源；正式原样生产近战/受击369项48图、倒地/影子346项32图，715项80图通过，12关键视口直接复核，4904+105+25输入零漂移；见v14收据和当前路由登记 | 连续足底/衣装/武器、施法血条间距、多尺寸UI、七人终态及全库人物/头像/特效仍开放 |'
                elif line.startswith('| 审核、修错、有限冗余清理 |'):
                    lines[i]=f'| 审核、修错、有限冗余清理 | 本轮覆盖状态审核通过。指定v10失败批{c["deleted_files"]}个重复imported文件、{c["deleted_bytes"]:,}字节已删除；受保护文件和保留匹配缓存零漂移。先前两批7436文件清理保留原收据 | 仅关闭指定批缓存；先前6批4.824GiB未删。完整目标审核持续开放，旧失败工程须重新导入 |'
            old='\n'.join(lines)+'\n'
        p.write_bytes((body+'以下为历史检查点，状态以本节及最新同步收据为准。\n\n'+old).encode('utf-8'))
    print(json.dumps({'docs_updated':7,'checks':715,'captures':80,'default_resources':36,'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'full_goal_qualified':False}))

if __name__=='__main__':main()
