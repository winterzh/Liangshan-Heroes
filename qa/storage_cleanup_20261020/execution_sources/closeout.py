from pathlib import Path
import json,gzip,shutil,hashlib,sys
sys.stdout.reconfigure(encoding='utf-8')
R=Path('D:/AI项目/水浒/开发工程');Q=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261020');T=R/'qa/storage_cleanup_20261020'
assert not T.exists();T.mkdir()
v=json.loads((Q/'verification.json').read_text(encoding='utf-8'));a=json.loads((Q/'document_archive.json').read_text(encoding='utf-8'))
assert v['complete'] and not v['protected_changed']
for n in ['inventory.json','document_archive.json','plan.json.gz','protected_before.json.gz','verification.json']:shutil.copy2(Q/n,T/n)
with gzip.open(T/'deleted.jsonl.gz','wb') as f:f.write((Q/'deleted.jsonl').read_bytes())
(T/'execution_sources').mkdir()
for n in ['inventory.py','prepare.py','cleanup.ps1','compact_docs.py','verify.py','closeout.py']:shutil.copy2(Q/n,T/'execution_sources'/n)
rows='\n'.join(f"| [{x['path']}]({x['github_snapshot']}) | {x['lines']} | `{x['sha256']}` |" for x in a['files'])
readme=f'''# 2026-10-20 冗余整理与历史恢复

本轮完成两项整理：六份入口文档由 **16,405行缩至191行**；按逐文件清单移除 **1,458个重复导入缓存 / 835,962,369字节（约797 MiB）**。D盘清理前后空闲增加839,913,472字节（约801 MiB），同时有文档压缩和并行任务影响，不能把磁盘变化等同缓存逻辑字节。C盘无删除目标，其空闲变化不计清理成果。

## 保护与验证

- 六份旧文档先完整ZIP归档，所有成员解压读回与原始字节及SHA-256一致，再精简当前入口。完整验收条件、原著要求及未完成范围保留，专题文档/原图/原始证据不删除。
- 缓存仅限四个旧私有工程的 `project/.godot/imported`；本次按**文件内容**比较，识别出不同文件名但字节相同的副本。每个目标都有不参与删除的相同SHA保留文件；764个私有缓存继续保留。
- 删除前校验绝对路径、限定目录、无reparse祖先、单硬链接、大小/SHA和独占打开；检查Godot空闲，PowerShell逐文件 `Remove-Item -LiteralPath`，无递归目录删除。
- 主缓存、保留副本及原107个未跟踪文件共4,659个保护文件前后SHA一致；未跟踪清单不变。运行代码、生产资源、原著依据、原图/提示/父图、发布包、玩家存档与Git对象库不在删除清单。
- 未启动游戏、运行Godot功能验收或再次发布Steam。缓存与文档整理不改变任何候选的采用资格。已发布版本仍是Build26048429。

## 历史文档归档

本机ZIP：`{a['archive_path']}`；{a['archive_bytes']:,}字节。

SHA-256：`{a['archive_sha256']}`。

下表链接指向整理前的不可变Git提交 `{a['source_commit']}`；换机或仅在GitHub浏览时仍能阅读完整旧文档，不依赖本机ZIP。

| 原文件及完整历史入口 | 原行数 | 原字节SHA-256 |
| --- | --- | --- |
{rows}

恢复旧文档时，先把ZIP解压到新的空目录，核对 `document_archive.json` 中每个文件的SHA；只从中查阅或挑选需要的内容，不覆盖当前入口。也可从上表指定Git提交读取同一路径；原六份文档全部保留，不靠摘要重建历史。

## 缓存恢复

`plan.json.gz` 的每条目标包含原位置、大小、SHA与 `retained_copy`。需要恢复某个旧测试工程时，先确认目标缺失、保留文件SHA匹配，再复制到原位置，保留原文件名；不要覆盖现有差异文件。也可按该批固定Godot版本重新导入。保留副本是缓存，后续清理前须继续维护其映射，不能误删后再称可直接复制恢复。

## 收据

- `document_archive.json`：六份原文与新文档哈希、行数、ZIP及Git历史定位。
- `inventory.json`、`plan.json.gz`：限定缓存目录与逐文件删除/保留映射。
- `deleted.jsonl.gz`：实际删除流水；`protected_before.json.gz`：4,659个保护文件的前验哈希。
- `verification.json`：删除与文档归档后验、未跟踪清单、磁盘变化及本轮资格边界。
- `execution_sources/`：本轮实际脚本副本；工程外执行收据在 `D:/CodexEvidence/shuihu/storage_cleanup_20261020`。

ZIP与原始发布二进制不上传Git，仓库保留恢复索引、哈希与执行证据。当前文档在README、PROJECT_STATUS、DEVELOPMENT_PLAN、SOURCE_SETUP、WORKLOG和DIRECTORY_INDEX各自维护一个入口，后续不要再把同一段批次日志复制到所有文件。
'''
(T/'README.md').write_text(readme,encoding='utf-8',newline='\n')
ag=R/'AGENTS.md';old=ag.read_bytes()
header='''## 2026-10-20 入口文档精简与重复缓存整理

六份入口文档16,405行精简为191行；原全文先存入 `D:/AI项目/水浒/归档/水浒_入口文档历史_20261020.zip`，完整解压读回SHA一致，Git旧提交391f2cc6同样保留。当前说明只维护一次，各专题与历史证据用链接引用，避免重复堆积。完整范围/验收条件与原著要求未缩减。

旧私有导入缓存按内容SHA复核后删除1,458份相同副本（835,962,369字节），保留764份私有文件及逐文件恢复映射；4,659个保护文件前后SHA一致，107个未跟踪文件清单不变。主缓存、运行代码/资源、发布包、原图/来源、存档和Git对象库保持。详见[本批记录及恢复](qa/storage_cleanup_20261020/README.md)。复查旧测试工程前重新导入或核对SHA后复制保留副本；旧批次清理记录按当时语境阅读。

'''
assert not old.startswith(header.splitlines()[0].encode())
ag.write_bytes(header.replace('\n','\r\n').encode('utf-8')+old)
restore=Path(a['archive_path']).with_suffix('.恢复说明.md')
assert not restore.exists()
restore.write_text('# 水浒入口文档归档恢复\n\n'+readme.split('## 历史文档归档\n\n')[1].split('## 缓存恢复')[0]+'\n本次完整清理记录：D:/AI项目/水浒/开发工程/qa/storage_cleanup_20261020/README.md\n',encoding='utf-8')
print(json.dumps({'qa_files':len(list(T.rglob('*'))),'archive_readme':str(restore),'cache_mib':v['deleted_cache_logical_bytes']/2**20,'d_free_delta_mib':v['free_delta']['D']/2**20},ensure_ascii=False,indent=2))
