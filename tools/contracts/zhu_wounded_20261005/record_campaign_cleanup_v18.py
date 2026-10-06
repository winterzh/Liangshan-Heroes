"""Record exact failed-cache removals and keep the full campaign audit open."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cp=BASE/'failed_campaign_import_cleanup_applied_v18.json';c=json.loads(cp.read_text(encoding='utf-8'))
    assert c['complete'] and c['apply_requested'] and c['deleted_files']==len(c['matches']) and c['deleted_bytes']==c['matched_bytes']
    assert c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    result={k:c[k] for k in ['scope','keeper_receipt','keeper_receipt_sha256','targets','protected_files','matched_bytes','apply_requested','complete','deleted_files','deleted_bytes','producer_sha256','protected_hash_drift','keeper_match_hash_drift','elapsed_seconds']}
    result.update(full_inventory=str(cp),full_inventory_sha256=sha(cp),different_or_missing_keeper_count=len(c['different_or_missing_kept']),restore='Reimport only named failed v18/v18a private projects before rechecking. Original/source images, executed producers, failed logs/receipts, profiles/saves and current v18b successful cache retained. Other batches/main/other tasks/platform packages untouched.')
    p=QA/'failed_campaign_import_cleanup_v18.json';assert not p.exists();p.write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    old='未新增平台发布；冗余只在成功后另核指定失败批与保留缓存的逐文件一致性。'
    new=f'只清指定失败v18/v18a工程imported中与保留v18b成功批同名、大小、SHA256一致的{c["deleted_files"]}文件、{c["deleted_bytes"]:,}字节（约{c["deleted_bytes"]/1024**3:.2f}GiB）；{c["protected_files"]}受保护文件及保留匹配缓存零漂移，不同缓存保留。收据failed_campaign_import_cleanup_v18.json，旧工程复查先重导入。未新增平台发布。'
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8');assert s.count(old)==1;s=s.replace(old,new)
        if name=='DEVELOPMENT_AUDIT_20261006.md':
            rows=s.splitlines()
            for i,line in enumerate(rows):
                if line.startswith('| 战役落盘、退出、独立进程继续、再次保存、胜败与奖励不重发 |'):
                    rows[i]='| 战役落盘、退出、独立进程继续、再次保存、胜败与奖励不重发 | 公开仍限经典30波；既有七人独立进程410项保留。本轮5/8固定profile/惰性工厂及具名Gao按钮已接入，真实原章Level/Mission组件重建76项、5036输入零漂移通过 | ID空壳/只读原地图是组件夹具，不证明Unit/船体/运输/生产/完整world；继续实际独立进程保存/继续/再保存、自然结局/奖励一次及既有章回归。未开放公开战役入口 |'
                elif line.startswith('| 审核、修错、有限冗余清理 |'):
                    rows[i]=f'| 审核、修错、有限冗余清理 | 当前76项组件复验通过；修正Gao工厂环境前提，失败执行来源保留。本轮v18/v18a重复imported {c["deleted_files"]}文件、{c["deleted_bytes"]:,}字节清除，保护/保留匹配缓存零漂移；v7/v14/v15/v17清理保留原收据 | 只删除指定一致文件，旧工程复查先重导入。6批4.824GiB未删；完整审核继续 |'
                elif line.startswith('| GitHub增量同步 |'):
                    rows[i]='| GitHub增量同步 | 上一远端d561d78c；当前四文件组件接入、76项证据、失败/清理记录及七份交接待本轮白名单同步 | 不合main、不发布平台；全目标继续 |'
            s='\n'.join(rows)+'\n'
        p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'protected_files':c['protected_files'],'docs':7}))
if __name__=='__main__':main()
