import json,gzip,shutil,hashlib,subprocess
from pathlib import Path
E=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261019');R=Path('D:/AI项目/水浒/开发工程');Q=R/'qa/storage_cleanup_20261019'
p=json.load(gzip.open(E/'plan.json.gz','rt',encoding='utf-8'));v=json.loads((E/'verification.json').read_text(encoding='utf-8'));assert not v['protected_changed'] and not v['targets_remaining']
assert not Q.exists();Q.mkdir()
for name in ['plan.json.gz','protected_before.json.gz','inventory.json','verification.json']:
 shutil.copyfile(E/name,Q/name)
with gzip.open(Q/'deleted.jsonl.gz','wb') as f:f.write((E/'deleted.jsonl').read_bytes())
S=Q/'execution_sources';S.mkdir()
for name in ['inventory.py','prepare.py','cleanup.ps1','verify.py','closeout.py']:
 shutil.copyfile(E/name,S/name)
imports=[x for x in p['targets'] if x['kind']=='identical_import_cache'];browser=[x for x in p['targets'] if x['kind']!='identical_import_cache'];gib=v['logical_bytes']/2**30;delta=v['free_delta']['D']/2**30
body=f'''# 2026-10-19 冗余缓存清理

本轮仅清理可重建缓存。实际删除 {v['deleted_files']} 个文件、逻辑字节 {v['logical_bytes']:,}（{gib:.3f} GiB）；D盘实测空闲变化 +{delta:.3f} GiB（并行任务可影响磁盘空闲，不能与逻辑字节等同）。C盘空闲变化 {v['free_delta']['C']:,} 字节，本轮没有C盘删除目标。

## 实际范围

- 四个已退出的水浒私有测试工程：晁盖完整包、刘唐推车、施恩HUD、吴用步态；只移除与保留主缓存文件名/大小/SHA-256完全相同的 {len(imports)} 个导入缓存，{sum(x['bytes'] for x in imports):,} 字节。
- {len(p['retained_unique_private_cache'])} 个不匹配的私有导入缓存留在原处。主 `.godot/imported`、Steam候选/集成QA/性能缓存未清理。
- 工程外水浒测试浏览器的白名单 Cache / Code Cache / GPUCache / ShaderCache / GrShaderCache / DawnCache：{len(browser)} 个可重建缓存文件，{sum(x['bytes'] for x in browser):,} 字节。只处理包含profile组件的私有路径；Storage、Service Worker、CacheStorage、Shared Dictionary和账号用户状态未列入。

## 验证与保护

删除前逐文件检查绝对路径与限定根、reparse祖先、单硬链接、文件哈希和独占打开；进程复查未发现水浒测试引擎或其私有浏览器运行。PowerShell按字面路径逐文件删除，未执行递归目录删除。

{v['protected_files']} 个受保护文件前后SHA-256完全一致，包括Git已跟踪/未跟踪文件、主导入缓存、有差异的私有缓存和工程外非profile原始证据。人物原稿/精确提示/父图、原著依据、测试日志/视频、生产资源、107个未提交文件、发布包、Git对象库和外来测试进程保持。保护清单不涵盖所有被忽略的构建副本；本轮目标清单没有这些非缓存文件。清理执行脚本自身不计保护集。

未运行游戏或Godot验收；缓存清理不构成功能/美术验收，也未操作main/Steam。未验证的自然动作与美术候选状态不因本轮改变。

## 清单与恢复

- `plan.json.gz`：每个删除目标的路径、大小、SHA、类型及导入缓存保留副本；独有缓存清单和清理前磁盘空闲。
- `deleted.jsonl.gz`：实际逐文件删除流水；`verification.json`：删除后保护与磁盘结果。
- `protected_before.json.gz`：保护集完整哈希；`inventory.json`：限定两个根目录的只读盘点。
- `execution_sources/`：实际执行脚本副本；工程外原收据保留在 `D:/CodexEvidence/shuihu/storage_cleanup_20261019`。

未打包删除内容：导入缓存已有逐文件哈希一致的主缓存副本，浏览器缓存可重建；没有删除历史源码或原始证据。复查四个旧私有工程前应先用对应Godot版本重新导入；必要时可按plan的retained_copy复制单个相同文件到原位置（先核对目标缺失和保留副本SHA，不覆盖现有文件）。测试浏览器缓存在重新打开时自动生成。
'''
(Q/'README.md').write_text(body,encoding='utf-8')
head=f'''## 2026-10-19 冗余缓存清理

按逐文件白名单移除旧私有测试工程的相同导入缓存及已退出测试浏览器缓存，共{v['deleted_files']}文件/{gib:.3f}GiB逻辑数据；{len(p['retained_unique_private_cache'])}个有差异的私有缓存保留。{v['protected_files']}个保护文件前后SHA一致，主缓存、Steam批次、人物原稿/原著依据/原始证据和未提交文件保留。详见[清理收据](../qa/storage_cleanup_20261019/README.md)。旧私有工程复查前重新导入；未运行游戏或发布。

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','DIRECTORY_INDEX.md']:
 f=R/'docs'/name;f.write_bytes(head.encode('utf-8')+f.read_bytes())
f=R/'AGENTS.md';f.write_bytes(head.replace('../qa/','qa/').encode('utf-8')+f.read_bytes())
f=R/'.gitattributes';old=f.read_bytes();f.write_bytes(old+(b'\n' if not old.endswith(b'\n') else b'')+b'qa/storage_cleanup_20261019/** -text whitespace=cr-at-eol,-blank-at-eof\n')
paths=['.gitattributes','AGENTS.md','docs/WORKLOG.md','docs/SOURCE_SETUP.md','docs/DIRECTORY_INDEX.md']+[x.relative_to(R).as_posix() for x in Q.rglob('*') if x.is_file()]
(E/'sync_paths.txt').write_text('\n'.join(paths)+'\n',encoding='utf-8');print(json.dumps({'paths':len(paths),'logical_GiB':gib,'D_free_delta_GiB':delta},ensure_ascii=False))
