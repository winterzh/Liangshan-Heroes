from pathlib import Path
import hashlib,zipfile,json,subprocess,datetime,sys
sys.stdout.reconfigure(encoding='utf-8')
R=Path('D:/AI项目/水浒/开发工程');Q=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261020')
names=['README.md','docs/PROJECT_STATUS.md','docs/DEVELOPMENT_PLAN.md','docs/WORKLOG.md','docs/SOURCE_SETUP.md','docs/DIRECTORY_INDEX.md']
head=subprocess.check_output(['git','-C',str(R),'rev-parse','HEAD']).decode().strip()
assert head=='391f2cc686703d7c38780c5a116d33ba2376d906'
assert not subprocess.check_output(['git','-C',str(R),'status','--porcelain','--untracked-files=no']).strip()
original={name:(R/name).read_bytes() for name in names}
archive=Path('D:/AI项目/水浒/归档/水浒_入口文档历史_20261020.zip')
assert not archive.exists()
archive.parent.mkdir(parents=True,exist_ok=True)
rows=[{'path':n,'bytes':len(b),'lines':len(b.splitlines()),'sha256':hashlib.sha256(b).hexdigest(),'github_snapshot':f'https://github.com/winterzh/Liangshan-Heroes/blob/{head}/{n}'} for n,b in original.items()]
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for name,data in original.items():z.writestr(name,data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert set(z.namelist())==set(names)
    for x in rows:
        unpacked=z.read(x['path'])
        assert unpacked==original[x['path']] and hashlib.sha256(unpacked).hexdigest()==x['sha256']
manifest={'archived_at':datetime.datetime.now().astimezone().isoformat(),'source_commit':head,'archive_path':str(archive),'archive_bytes':archive.stat().st_size,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'full_decompression_verified':True,'files':rows,'before_lines':sum(x['lines'] for x in rows)}
(Q/'document_archive.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
link='[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)'
def write(name,text):
    assert (R/name).read_bytes()==original[name],f'Concurrent change: {name}'
    (R/name).write_text(text.rstrip()+'\n',encoding='utf-8',newline='\n')
readme=original['README.md'].decode('utf-8').split('## 历史开发记录')[0]
readme+='''## 开发与历史记录

打开 `project.godot` 或运行 `Play.cmd`；Godot版本与本机路径设置见[源码设置](docs/SOURCE_SETUP.md)。

旧批次全文已归档并保留Git历史，见[归档与恢复说明](qa/storage_cleanup_20261020/README.md)。当前首页只展示最新入口，逐批证据仍在 `docs/` 和 `qa/`。
'''
write('README.md',readme)
status=original['docs/PROJECT_STATUS.md'].decode('utf-8').split('\n---\n')[0]
status+='\n\n## 历史与恢复\n\n旧批次总览已完整归档，'+link+'；历史版本结论不覆盖本页当前状态。\n'
write('docs/PROJECT_STATUS.md',status)
oldplan=original['docs/DEVELOPMENT_PLAN.md'].decode('utf-8')
plan=oldplan.split('## 历史计划与阶段证据')[0]
gates=oldplan[oldplan.index('## 后续执行顺序'):oldplan.index('## 下一批入口与本轮同步范围')]
plan+='## 完整验收条件\n\n以下保留原计划的完整批次与门槛；前述当前顺序优先，表内历史基础通过不授予全库或全游戏资格。\n\n'+gates.replace('## 后续执行顺序\n','')
plan+='\n## 历史计划\n\n旧阶段计划、失败与候选入口见'+link+'及各自QA目录。旧PID、后台队列和旧源码准入不作为当前运行状态；没有缩减完整范围。\n'
write('docs/DEVELOPMENT_PLAN.md',plan)
work='''# 开发日志

## 2026-10-20 冗余整理

六份入口文档原共16,405行，已先完整ZIP归档、逐文件解压读回并核对SHA-256，再将当前入口与历史记录分开。首页、总览、计划、源码设置和目录索引只保留各自职责；原批次日志、原图、依据与QA没有永久删除。缓存清理仅限有相同SHA保留副本的旧私有导入缓存，实际数量、保护后验与磁盘变化以[本批收据](../qa/storage_cleanup_20261020/README.md)为准。

## 2026-10-20 GitHub首页与主线收尾

48042d84补齐旧stable合并历史，ffa625de补齐交接，391f2cc6纠正首页README与总览/计划。main和stable内容一致，工作区为main；107个未跟踪文件保持本地，未混入生产或文档提交。当前提交以Git历史与远端回读为准。

## 2026-10-20 Steam人物与场景更新发布

Windows default Build26048429 / Manifest697009053566575953；[四语公告](https://steamcommunity.com/games/5088120/announcements/detail/669505296465397048)已公开。生产来源0083b47a，原生219、包内1169、身份各10和EXE十一场景通过；服务器、全新下载、客户端文件与库内启动分别核实。首个失败批保留，QA断言修正未改变生产人物数据。[更新文档](STEAM_UPDATE_20261019.md)、[发布收据](../qa/steam_release_20261019/README.md)。完整续玩、全流程真人与长期性能仍未完成。

## 当前开发与历史

剩余范围和次序见[项目总览](PROJECT_STATUS.md)、[开发计划](DEVELOPMENT_PLAN.md)，人物与剧情先核对百二十回本。逐批人物/场景/工具文档仍保留，不把候选生成或技术检查当玩家功能完成。

'''+link+'。归档含本次整理前全部4,850行日志，可按Git快照或本地ZIP查询和恢复。以后仅在本文件新增实际完成的批次摘要，运行命令放源码设置，证据细节放对应QA。\n'
write('docs/WORKLOG.md',work)
setup='''# 源码设置与换机（2026-10-20）

## 当前入口

本机开发目录：`D:/AI项目/水浒/开发工程`；打开其中 `project.godot`。桌面旧目录为历史兼容入口。本次收尾工作区是main，跟踪origin/main；main/stable已合并，实际SHA以Git回读为准。[当前版本](PROJECT_STATUS.md)、[开发计划](DEVELOPMENT_PLAN.md)。

## 启动与导入

需要Godot **4.6.3**。仓库根目录运行 `Play.cmd`；进入编辑器用 `Play.cmd -Mode editor`，仅准备导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器会先检查导入缓存。

本机引擎路径依次来自 `-GodotPath` 参数、`GODOT_PATH` 环境变量、被Git忽略的 `godot.local.txt`，最后查PATH。不要将机器绝对路径、SDK凭据或签名配置写入生产脚本。Steam发布程序与源码启动分开，不能用编辑器启动代替发行包验收。

## 换机与Git同步

在自己的Git checkout开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

核对目标分支和远端后，仅在无未完成修改且可快进时 `git pull --ff-only`。若有分叉或共享修改，先检查来源，不自动stash、reset或覆盖。既定开发同步分支为 `codex/sync-20260905-stable`；本次主线合并有用户明确授权，未来合并和平台发布仍按AGENTS.md与当次授权。

每轮验证后同步更新本文件、WORKLOG及本批文档；按逐文件白名单提交，不用全盘git add、强推或改写历史。推送后读回远端SHA。禁止上传Steam登录/缓存、玩家存档、Godot缓存、安装包、密钥和无关历史备份。

## 验证与共享引擎

依据具体修改选择对应 `qa/` 及实现文档的当前入口。旧harness/producer只证明其绑定的冻结源码，不因为文件仍在就能用于新版本。先检查已有执行器/共享锁及实际进程，等自然空闲，串行使用Godot；不重复启动或控制其他聊天的进程。新执行器按相应审查要求接入，失败原证据保留。

旧私有测试工程的重复缓存已有清理记录；复验前按对应Godot版本重新导入，或按保留副本与SHA映射恢复缺失文件，不能覆盖仍存在的差异缓存。主缓存、源码/原图、发布包、存档和Git对象不在本轮删除范围。

## 发布与历史

当前Steam Build26048429，冻结生产来源0083b47a；[发布指南](STEAM_RELEASE_GUIDE.md)、[本批更新文档](STEAM_UPDATE_20261019.md)。源码同步、上传、default上线、四语公告、客户端下载/启动与真人接受分别记录。完整战役续玩未开放，经典固定30波保存/继续保留。

'''+link+'包含本次整理前全部设置/旧工具说明。临时批次命令留在对应QA，避免再次把历史状态堆入当前启动入口。\n'
write('docs/SOURCE_SETUP.md',setup)
index='''# 项目目录索引（2026-10-20）

## 当前文档入口

| 用途 | 文件 |
| --- | --- |
| 仓库首页 | [README](../README.md) |
| 版本、交付范围与剩余工作 | [项目总览](PROJECT_STATUS.md) |
| 后续顺序与完整验收条件 | [开发计划](DEVELOPMENT_PLAN.md) |
| 启动、换机、共享引擎与源码同步 | [源码设置](SOURCE_SETUP.md) |
| 按批次记录完成事项 | [开发日志](WORKLOG.md) |
| 本次Steam更新 | [更新文档](STEAM_UPDATE_20261019.md) |
| Steam交付步骤 | [发布指南](STEAM_RELEASE_GUIDE.md) |
| 美术缺口与来源 | [全量美术台账](ART_COMPLETION_20260926.md)及各人物/场景实现说明 |
| 入口文档历史与本次清理 | [QA及恢复说明](../qa/storage_cleanup_20261020/README.md) |

## 运行与资源目录

| 位置 | 用途 |
| --- | --- |
| `project.godot`、`Play.cmd` | Godot工程及本机启动器 |
| `scripts/`、`scenes/`、`assets/` | 运行代码、场景、正式资源及必要来源链 |
| `native/`、`vendor/` | 原生接口、第三方依赖与许可 |
| `tools/` | 构建、检查及受控执行工具 |
| `docs/` | 当前入口及人物/场景/玩法等专题说明 |
| `qa/` | 实际检查、失败记录、候选和来源证据；存在文件不代表已采用 |
| `marketing/` | 平台说明与宣传材料 |
| `.godot/`、`build/`、`scratchpad/` | 本地缓存/产物/临时资料，不据此同步全部文件 |
| `D:/AI项目/水浒/历史资料`、`归档` | 历史材料和可恢复归档 |

## 本批索引与新增规则

`qa/storage_cleanup_20261020/`记录六份入口文档归档、哈希、重复缓存映射、实际删除流水和保护后验。10月19日旧缓存清理见[原记录](../qa/storage_cleanup_20261019/README.md)，本次Steam交付见[发布QA](../qa/steam_release_20261019/README.md)。

每类信息只维护一个当前入口，其他文档用链接引用；旧批次PID、命令和状态留对应QA，不再六处复制同一段过程日志。新增实现与QA目录后更新本索引，保留原图/提示/父图/原著依据/失败记录。候选与生产、源码同步与平台交付分别说明。

'''+link+'含整理前完整3,509行索引；旧来源清单绝对路径不批量改写。\n'
write('docs/DIRECTORY_INDEX.md',index)
manifest['after_lines']=sum(len((R/n).read_bytes().splitlines()) for n in names)
manifest['after_files']=[{'path':n,'bytes':(R/n).stat().st_size,'lines':len((R/n).read_bytes().splitlines()),'sha256':hashlib.sha256((R/n).read_bytes()).hexdigest()} for n in names]
(Q/'document_archive.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:manifest[k] for k in ['archive_path','archive_bytes','archive_sha256','before_lines','after_lines']},ensure_ascii=False,indent=2))
