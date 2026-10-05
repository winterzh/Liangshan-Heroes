from pathlib import Path
import json
repo=Path('E:/ChatGPT/水浒');qa=repo/'qa/current_campaign_art_20261005'
clean=json.loads((qa/'cleanup.json').read_text(encoding='utf-8'))
assert clean['complete'] and clean['protected_sha_unchanged']
line=f"本批清理：仅本批旧私有缓存，删除{clean['removed_files']}个与最新保留缓存文件名/大小/SHA一致的imported文件，共{clean['removed_bytes']}字节（约{clean['removed_bytes']/1024**3:.2f} GiB）；{clean['protected_files']}个受保护文件前后SHA一致。原图、资源、源码、日志、失败截图、档案及最新缓存保留，旧私有工程复查须重新导入；其他批次与主缓存未动。\n\n"
for p in [repo/'docs'/name for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md','CURRENT_CAMPAIGN_ART_20261005.md']]+[qa/'README.md']:
    data=p.read_bytes();marker='本轮只按白名单提交推送codex/sync-20260905-stable；'.encode('utf-8')
    assert marker in data and line.encode('utf-8') not in data;p.write_bytes(data.replace(marker,line.encode('utf-8')+marker,1))
print(json.dumps({'complete':True,'cleanup_files':clean['removed_files'],'cleanup_bytes':clean['removed_bytes']}))
