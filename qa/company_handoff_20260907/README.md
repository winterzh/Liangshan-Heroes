# 公司电脑接续验证：2026-09-07

公司独立 checkout 从 `513ee336` 安全快进 79 个提交到 `e7318c525bec1f04e588e28fbcb6cedf9efaea4b`，再补齐本页列出的 Godot 元数据。Godot 4.6.3 的资源导入、普通主菜单以及由主菜单进入标准 30 波驻守均已实际运行；驻守已经过旁白并进入 `Phase.FIGHT`，玩法 RNG 无故障。正式整局恢复、30 波全程、性能和真人试玩门槛未改变。

## 网络与代码保全

初始工作区干净，origin 和 stable 分支正确。普通 fetch 在数据包传输中报 `curl 56`、`early EOF`；仅更换 TLS 实现和 HTTP/协议选项仍失败。先以 `--filter=blob:none` 获取提交和树，再按 Git 原生 promisor 流程分批补齐当前树对象。约 38 MiB 的商店视频从同一提交的 GitHub raw 地址取得，39,460,768 字节，Git blob OID 精确匹配 `1d2332ad59e4f5f4306b5fa32e9e13e40af1a80e` 后才写入对象库。没有关闭证书校验或修改系统网络配置。

所有当前树文件对象缺失数降至 0 后，确认 ahead/behind 为 0/79，执行 `git pull --ff-only origin codex/sync-20260905-stable`，再回读远端 SHA 一致。历史 blob 仍可由 Git 按需获取，当前工程文件完整可离线读取。旧共享工程的 492 个指定代码/文本与原公司基线比较，仅四份交接文档有机器路径替换；没有公司独有的未同步代码。

## 首次导入元数据

- 1,142 个已跟踪 `.import` 只发生 CRLF/LF 差异，固定生产资源、文档资源和图标导入描述为 LF；没有改变其内容、压缩参数或资源路径。
- 60 个成就 `.import` 仅补上 Godot 自动生成的 `[remap]/uid`。
- 101 个新增 `.gd.uid` 随源码提交：scripts 28、tools 73；均对应已有脚本，UID 合法且没有碰撞。
- 261 个 QA 图片 `.import` 和 9 个 QA `.gd.uid` 仅是本次扫描生成物，全部对应已跟踪源文件；4,662 个仓库文本/日志/manifest 未引用它们。只在 Git 忽略规则中排除自动 sidecar，原 PNG、日志和来源 manifest 保留。以后若生产或 QA 来源清单明确依赖具体 sidecar，须显式纳入版本控制。

没有改动玩法脚本、场景或源图。全部首次生成物已在本机 `.godot/company_handoff/20260907_100023/generated_metadata/` 保留，归档清单也保留在同轮目录。

## 验证与失败边界

| 原始运行 | 实际结果 |
| --- | --- |
| `20260907_100023` | 导入、主菜单 headless、主菜单 Vulkan 均 exit 0，错误行为空、玩家不变；整体 `complete=false`，因为首次导入生成元数据，触发工作区变化检查。 |
| `20260907_100811` | 四项进程均 exit 0；隔离 APPDATA 路径过长，驻守阶段出现三条 shader cache 建目录错误，整体仍为 false。 |
| `20260907_100923` | 缩短私有用户目录后四项均 exit 0，错误行为空，源码/真实玩家不变；`complete=true`。驻守截图仍处于旁白，只计入口初始化。 |
| `20260907_101051` | 通过实际“30 关”按钮与“继续”按钮进入可操作驻守，`phase=2`、`ready=true`、`paused=false`、`rng_fault=""`；exit 0，错误行为空，源码/真实玩家不变。 |

原始日志和 receipt 位于 [runs/](runs/)，两个失败没有改写成通过。最终画面为 [主菜单](menu.png) 与 [驻守场景](defense.png)，1280×720、Vulkan Forward+；本次全部测试进程已退出，共用锁已按自身标识释放。截图上的瞬时 FPS 不作为性能结果。

[verification.json](verification.json) 记录本轮汇总，[runtime_manifest.json](runtime_manifest.json) 固定实际受测运行输入。原始 receipt 的 `source_head` 是基线 e7318c5，受测候选额外包含本页元数据修复，不能把 receipt 误读为仅测试未修改的 e7318c5。

## 公司使用与复验

工程根目录直接打开 `project.godot`，运行 `Play.cmd`；Godot 路径只放忽略的 `godot.local.txt` 或 `GODOT_PATH`。首次导入可运行 `Play.cmd -Mode import`。源码普通启动不需要安装 Steam 原生依赖。

自动检查使用共同 `.godot/redraw_rejection_source.lock`，引擎串行运行，设置新的短路径私有 APPDATA、LOCALAPPDATA、TEMP、TMP，以及 `STEAM_DISABLED=1`、`CAMPAIGN_QA=1`。不要使用真实玩家目录或删除其他任务的锁。主菜单的 headless 入口为 `tools/run_local.ps1 -GodotArgs @('--headless','--quit-after','180')`。图形 driver 以 `.gd.txt` 保存在对应 runs 中，复制到新的忽略目录恢复 `.gd` 后，通过同一启动器的 `--script` 参数运行；截图路径由 `COMPANY_CAPTURE_OUTPUT` 提供。不要直接运行归档文本或沿用历史用户目录。
