from pathlib import Path
import hashlib,json,re,subprocess
R=Path(__file__).resolve().parents[2];Q=R/'qa/storage_cleanup_20261027';O=Path(__file__).parent;BASE='5837d1bdc769f2847888a074f41b5c3d629c5529'
v=json.loads((Q/'verification.json').read_bytes());assert v['removed_files']==52176 and v['removed_bytes']==14949340024
records=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def edit(name,change):
 p=R/name;old=p.read_bytes();nl='\r\n' if b'\r\n' in old else '\n';text=old.decode().replace('\r\n','\n');git=subprocess.check_output(['git','show',BASE+':'+name],cwd=R)
 assert git==old.replace(b'\r\n',b'\n');new=change(text).strip()+'\n';data=new.replace('\n',nl).encode();p.write_bytes(data)
 records.append({'path':name,'before_bytes':len(old),'after_bytes':len(data),'before_sha256':sha(old),'after_sha256':sha(data),'original_git_commit':BASE,'original_git_blob_sha256':sha(git),'original_working_tree_newline':'CRLF' if nl=='\r\n' else 'LF','original_full_text_available_in_git':True})
stop='../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md'
def status(t):
 t=t.split('\n本次负例状态：',1)[0]
 lines=t.splitlines();i=next(i for i,x in enumerate(lines) if x.startswith('| GitHub |'));lines[i]='| GitHub | [winterzh/Liangshan-Heroes / stable](https://github.com/winterzh/Liangshan-Heroes/tree/codex/sync-20260905-stable)：停止全量测试及27个通过进程的记录已同步`5837d1bd`；本轮文档/缓存收尾另按白名单同步，以远端最新提交为准 |'
 t='\n'.join(lines)
 t=t.replace('52负例执行器162116_c86e8835已通过完整准入并进入原生执行，61尚未取得。','全量负例按用户要求停止，27个进程39383项通过；52／61整组未取得，后续按修改做针对性测试。')
 return t+'\n\n本轮旧缓存去重及入口文档归并见[清理与恢复](../qa/storage_cleanup_20261027/README.md)。'
edit('docs/PROJECT_STATUS.md',status)
def plan(t):
 t=t.split('\n本次负例状态：',1)[0]
 t=re.sub(r'## 本轮全量测试已按用户要求停止\n\n.*?\n\n','本轮全量测试已按用户要求停止；后续按实际修改做必要的针对性测试。已过27个进程及未完成范围见[项目总览](PROJECT_STATUS.md)。\n\n',t,count=1,flags=re.S)
 a='52负例首轮162116首Lu world超时，未生成报告；后继仅加耗时日志并经8GD加载通过，175238暂停态逐行让帧版完整重跑准入中，52尚未通过；完整61仍需52全部通过及原件核验。'
 assert a in t;t=t.replace(a,'全量负例按用户要求停止，已过27个进程39383项；其余取消/未运行，52／61未授。后续按修改选择必要测试，完整矩阵不作为当前代码和文档工作的阻塞条件。')
 return t
edit('docs/DEVELOPMENT_PLAN.md',plan)
source='''# 源码设置与换机（2026-10-27）

本机开发目录为 `D:/AI项目/水浒/开发工程`，打开其中 `project.godot`；桌面旧目录仅为历史兼容入口。当前进度见[项目总览](PROJECT_STATUS.md)，开发顺序及完整要求见[开发计划](DEVELOPMENT_PLAN.md)，逐批证据见[开发日志](WORKLOG.md)和[目录索引](DIRECTORY_INDEX.md)。

## 启动与导入

使用 Godot **4.6.3**。在仓库根目录运行 `Play.cmd`；编辑器用 `Play.cmd -Mode editor`，仅导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器先检查导入缓存。

本机引擎路径依次来自 `-GodotPath`、`GODOT_PATH`、被忽略的 `godot.local.txt` 和 PATH。机器路径、SDK凭据及签名配置不写进生产脚本。81份资源导入配置和26份候选工具/预览源码已补交，详见[入库记录](../qa/pending_source_sync_20261020/README.md)；`.import`设置随资源入库，`.godot`缓存不上传。

## 换机与 Git 同步

在自己的 checkout 开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

目标仓库为 `https://github.com/winterzh/Liangshan-Heroes.git`，开发分支为 `codex/sync-20260905-stable`。工作区干净且未分叉时才 `git pull --ff-only origin codex/sync-20260905-stable`；有本地修改或分叉先核对来源，不自动stash、reset或覆盖。

每轮按实际修改做验证，更新WORKLOG及涉及的文档；检查远端、白名单差异、大小及敏感内容后逐文件提交推送，回读远端SHA。玩家存档、Steam登录/缓存、Godot缓存、安装包及无关历史备份不上传。main合并和平台发布按AGENTS.md及当次授权执行。

## 验证与共享引擎

用户已取消全量52／61测试，后续按修改做必要的针对性检查；不自动恢复全量矩阵。现有27个进程39383项通过、取消及未运行范围见[原始收据](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md)。原版键鼠验收继续按用户选择暂不恢复。

调用Godot前检查已有进程和共享锁，等通道自然空闲并串行执行，不控制其他聊天的进程。使用与候选精确绑定的冻结、清单及自己的成功导入；默认命名来源检查只授静态结果。原失败存档和证据保留，复验使用逐字新副本，不把旧冻结的通过转授新源码。当前b22及大名府、持久化与各章节边界统一见[当前验证](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/VALIDATION.md)，具体执行命令留在相应QA目录。

## 旧快照和缓存恢复

本轮12个旧战役快照只去掉与最新b22缓存逐字相同的导入文件；复验前按[本轮映射与恢复器](../qa/storage_cleanup_20261027/README.md)补齐。最新b22缓存是恢复保留副本，后续清理不能直接删除。主缓存、各快照源码、独有缓存和原始QA/存档保留。

10月26日第二轮的三个旧快照按[既有映射](../qa/storage_cleanup_20261026_round2/README.md)恢复；上一轮54快照ZIP及9月7日7z已被用户删除，旧收据不代表当前仍有归档载荷。其他旧缓存按各批恢复说明补齐或用绑定Godot版本重新导入，不覆盖不同文件。

## 发布与历史

当前Steam Windows为Build26048429，冻结生产来源0083b47a；见[更新记录](STEAM_UPDATE_20261019.md)及[发布指南](STEAM_RELEASE_GUIDE.md)。公开战役续玩未开放，经典固定30波保存/继续保留。源码同步、发行程序验证、平台上线与人工验收各自记录。

整理前的完整设置和历史工具状态保留于[Git提交5837d1bd](https://github.com/winterzh/Liangshan-Heroes/blob/5837d1bdc769f2847888a074f41b5c3d629c5529/docs/SOURCE_SETUP.md)，原10月20日文档归档说明见[历史全文与恢复](../qa/storage_cleanup_20261020/README.md)。专题入口见[文档导航](README.md)、[QA导航](../qa/README.md)及[GitHub约定](GITHUB_REPOSITORY.md)。
'''
edit('docs/SOURCE_SETUP.md',lambda t:source)
def index(t):
 paragraphs=t.split('\n\n');paragraphs=[p for p in paragraphs if not p.startswith(('本次负例状态：','最新完整执行：','最新负例执行：'))]
 t='\n\n'.join(paragraphs)
 anchor='| 按批次记录完成事项 | [开发日志](WORKLOG.md) |';assert anchor in t
 return t.replace(anchor,anchor+'\n| 本轮重复缓存清理与恢复 | [清理收据与恢复器](../qa/storage_cleanup_20261027/README.md) |')
edit('docs/DIRECTORY_INDEX.md',index)
note='''## 2026-10-27 本轮收尾与冗余清理

按用户要求停止全量测试后收尾：27个进程39383项通过、1个取消、24个未执行，原件和资格边界保持。旧12个战役快照删除52176个与保留b22缓存完全相同的导入文件，14949340024字节（约13.92GiB）；168个独有/差异缓存保留。47391个已跟踪保护文件SHA及97543个非目标文件元数据前后不变。12个实际恢复样本SHA通过，主缓存、最新b22、源码/原图、QA/私有档案和Git对象保留；没有启动游戏或全量测试。

PROJECT_STATUS、DEVELOPMENT_PLAN、SOURCE_SETUP和目录索引归并重复/过期运行日志，完整旧文档由5837d1bd Git原字节及行尾说明保留，完整验收条件不缩减。本轮只做文件保护/恢复核对、文档链接和提交检查，按白名单同步stable。[清理与恢复](../qa/storage_cleanup_20261027/README.md)。

'''
edit('docs/WORKLOG.md',lambda t:t.replace('# 开发日志\n\n','# 开发日志\n\n'+note,1))
edit('AGENTS.md',lambda t:'## 2026-10-27 旧战役导入缓存去重\n\n12个旧快照的重复imported文件已按逐文件SHA移除，恢复映射和保留副本见[清理收据](qa/storage_cleanup_20261027/README.md)。最新b22 `20261027_075456_3e4a48ab/project/.godot/imported` 是本轮恢复保留副本，不可当无用缓存直接删除；旧快照复验前先恢复本轮缺失文件。源码、原始QA/档案与主缓存保留。\n\n'+t)
(Q/'document_cleanup.json').write_text(json.dumps({'schema':'shuihu_entry_document_cleanup_v1','reference_commit':BASE,'files':records,'complete_development_acceptance_table_retained':True},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'document_files':len(records),'before_bytes':sum(r['before_bytes'] for r in records),'after_bytes':sum(r['after_bytes'] for r in records),'changes':records},ensure_ascii=False))
