from pathlib import Path
import json,hashlib
repo=Path('E:/ChatGPT/水浒');qa=repo/'qa/zhu_captives_bound_20261005'
clean=json.loads((qa/'cleanup.json').read_text(encoding='utf-8'))
assert clean['complete'] and clean['protected_sha_unchanged']
line=f"本批清理：只删除本批旧私有工程中{clean['removed_files']}个与最新缓存文件名/大小/SHA完全一致的imported文件，共{clean['removed_bytes']}字节（约{clean['removed_bytes']/1024**3:.2f} GiB）；{clean['protected_files']}个受保护文件前后SHA一致。原图、源码、资源、日志、失败截图、存档/私有档及最新缓存保留；旧私有工程复查须重新导入。未触及其他批次和主工程缓存。\n\n"
for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md','ZHU_CAPTIVES_BOUND_20261005.md']:
    p=repo/'docs'/name;s=p.read_bytes();marker='本轮只按白名单提交推送codex/sync-20260905-stable；'.encode('utf-8')
    assert s.count(marker)>=1 and line.encode('utf-8') not in s
    p.write_bytes(s.replace(marker,line.encode('utf-8')+marker,1))
p=qa/'README.md';s=p.read_text(encoding='utf-8');s=s.replace('本轮只按白名单',line+'本轮只按白名单',1);p.write_text(s,encoding='utf-8')
print(json.dumps({'complete':True,'cleanup_gib':round(clean['removed_bytes']/1024**3,2)}))
