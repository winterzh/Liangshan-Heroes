"""Record exact owned failed/cancelled cache cleanup and current scoped Unit acceptance."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cp=BASE/'failed_unit_graph_import_cleanup_applied_v19.json';c=json.loads(cp.read_text(encoding='utf-8'))
    assert c['complete'] and c['apply_requested'] and c['deleted_files']==len(c['matches']) and c['deleted_bytes']==c['matched_bytes']
    assert c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    result={k:c[k] for k in ['scope','keeper_receipt','keeper_receipt_sha256','targets','protected_files','matched_bytes','apply_requested','complete','deleted_files','deleted_bytes','producer_sha256','protected_hash_drift','keeper_match_hash_drift','elapsed_seconds']}
    result.update(full_inventory=str(cp),full_inventory_sha256=sha(cp),different_or_missing_keeper_count=len(c['different_or_missing_kept']),restore='Reimport only the named cancelled v19 and failed v19b/v19c private projects before rechecking. Original Unit/source images, native snapshot payloads, executed producers, failed reports/logs/receipts and profiles/saves retained. Current v19d keeper, prior success/main/other tasks/platform caches untouched.')
    p=QA/'failed_unit_graph_import_cleanup_v19.json';assert not p.exists();p.write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    review=json.loads((QA/'campaign_units_review_v19d.json').read_text(encoding='utf-8'));assert review['passed'] and not review['full_world_qualified']
    old='未新增清理或平台发布。'
    new=f'只清指定取消v19/失败v19b/v19c工程imported中与保留v19d成功批同名、大小、SHA256一致的{c["deleted_files"]}文件、{c["deleted_bytes"]:,}字节（约{c["deleted_bytes"]/1024**3:.2f}GiB），{c["protected_files"]}受保护文件及保留匹配缓存零漂移。不同缓存保留；收据failed_unit_graph_import_cleanup_v19.json，旧工程复查先重导入。未新增平台发布。'
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8');a=s.index('<!-- campaign-units-v19d-current -->');b=s.index('<!-- /campaign-units-v19d-current -->',a)
        current=s[a:b];assert current.count(old)==1;s=s[:a]+current.replace(old,new)+s[b:]
        if name=='DEVELOPMENT_AUDIT_20261006.md':
            rows=s.splitlines()
            for i,line in enumerate(rows):
                if line.startswith('| 战役落盘、退出、独立进程继续、再次保存、胜败与奖励不重发 |'):
                    rows[i]=f'| 战役落盘、退出、独立进程继续、再次保存、胜败与奖励不重发 | 公开仍经典30；既有七人跨进程410项及两关Level/Mission76项保留。本轮两关真实Unit图7态、{review["checks"]}项/5038来源零漂移，完整Unit/Level payload精确重捕获；登船/乔装/救人/援军死亡与矿点新引用通过 | 禁用detached owner/map和Node旗标为明确夹具；仍需实际地图/场景/灯光/FX/时钟/完整Mission/root/core及独立进程保存/继续/再保存、自然结局/奖励一次和既有章回归；未开放战役玩家入口 |'
                elif line.startswith('| 审核、修错、有限冗余清理 |'):
                    rows[i]=f'| 审核、修错、有限冗余清理 | 当前两关真实Unit图{review["checks"]}项复验通过，StringName/引用/槽位问题修正，实际失败来源保留。本轮指定v19/v19b/v19c重复imported {c["deleted_files"]}文件、{c["deleted_bytes"]:,}字节清除，保护/保留缓存零漂移，历史清理收据保留 | 只删除指定一致文件，旧工程重导入。6批4.824GiB未删；完整审核继续 |'
                elif line.startswith('| GitHub增量同步 |'):
                    rows[i]='| GitHub增量同步 | 上一远端e1d546d0；当前四文件Unit图接入、原字节属性、七态证据/失败/清理及后续地图缺口审计待本轮白名单同步 | 不合main、不发布平台；全目标继续 |'
            s='\n'.join(rows)+'\n'
        p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'protected_files':c['protected_files'],'docs':7}))
if __name__=='__main__':main()
