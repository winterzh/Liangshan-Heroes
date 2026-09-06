# 9 月 7 日早上 7 点交接

本次为用户预定的一次性收尾：同步已验证源码、尝试 Steam 更新，并为公司电脑保留可继续工作的检查点。

## 源码检查点

- 仓库：<https://github.com/winterzh/Liangshan-Heroes>。
- 分支：`codex/sync-20260905-stable`。
- 收尾运行代码：`56adcacb78356fb9ecc33bc62eb0db252cb35ea6`。本机开始时干净、仅落后远端 4 个提交，fetch 后确认没有分叉，已按约定 pull --ff-only；远端回读一致。
- 收尾另接入已独立验证的第15个迷雾恢复组件，及未晋级源码草稿的受控归档；它们不在56adcac冻结候选内。还修复了Windows非UTF-8默认编码下构建结束时未能识别自身锁的问题，改为按写入时的UTF-8读取锁标识。最终提交号以Git历史及任务回复为准。
- “Find syncable 水浒 tasks”及其所有子任务已确认停止新开发、引擎和推送。202文件白名单已逐项验收，精确接收196个新增文件，其余公共文档和Git属性按增量合并；879条源码映射独立回读无缺失。两份归档与待办见[续玩交接](RUN_RESUME_HANDOFF_20260907.md)。

## Steam 实际状态

早上通过已登录 Steamworks 新打开的 builds 页面回读，App `5088120` 的 `default` 仍是 **Build `25154403`**，Windows Depot `5088121`、Manifest `596698599141519420`。这次没有生成新 Build ID，也没有切换 default；原更新及公告见 [已上线记录](STEAM_UPDATE_20260907.md)。

30 项成就的中英文均已保存，图标仍空缺，页面明确提示有未发布配置。正常首项图标文件选择返回 `fileChooser.setFiles failed / Not allowed`。上传页也明确提示 Depot 配置须先发布。没有通过别的端点或脚本绕过文件访问限制，也没有把草稿当作线上功能。

恢复条件：在 Edge 的 `edge://extensions` 中打开 ChatGPT 扩展详情，开启“允许访问文件 URL”，或由用户在正常文件窗口手动选择所需文件。首项待选图标为 `assets/ui/achievements/ach_clear_level_1.png`；60 图标映射及后续发布顺序见 [Steam 后台接续](STEAM_BACKEND_SETUP_20260907.md)。这属于上传工具的访问条件，不是再次等待 Steam 发布授权。

工坊测试组、第二可用测试账号及真实双账号联调仍缺；本轮没有扩展工坊可见性。正式更新授权已有，但需要先补齐配置及验证，不能将尚未联调的成就/工坊直接记为验收完成。

## 验证与本地候选

本轮验证结果与精确源码/包指纹见 [早间 QA](../qa/morning_handoff_20260907/README.md)。新测试使用独立项目、私有用户目录和共同 Godot 锁，禁用真实 Steam 初始化，不修改玩家进度。历史 `df7ed18` 测试包和夜间 R2 候选保持各自原始收据；不能把它们当成当前 checkout 的新导出。

早间初始builder在包65项、发行EXE启动、source身份10项已通过后，因收尾任务提前接入Fog新文件触发源码变化保护，PCK身份子进程未启动，原builder完整结果保持false。后续对同一未改变EXE使用独立probe补测，原始失败与补测分开归档；不重写失败收据或放宽保护。中文路径下的锁清理也以真实cp936/非UTF-8模式复现并修复，测试未修改活动引擎锁。

完成独立补测后：176项native、65项包检查/发行EXE启动、source和PCK身份各10项均通过，进程已退出、玩家文件不变、锁已释放。ZIP为219,887,525字节，SHA-256 `cb2608362f4456a14253a6a6d960eddfc30cc2b4442ed8fcfa84e15532baa227`；本机路径为`.godot/steam_candidates/20260907_070844_beba3054/independent_recovery/LiangshanHeroes_Steam_candidate.zip`。此包只对应56adcac，未含后接收的Fog；GitHub另保留Fog的独立正式验证。新包没有上传Steam。

## 公司电脑接续

1. 在已经配置好的 Git checkout 中先运行 `git status --short --branch`，确认远端为上述仓库、分支为 stable，并核对本地改动。只有工作区干净且无分叉时才运行 `git pull --ff-only origin codex/sync-20260905-stable`；有修改时先保留并核对来源，不自动 stash/reset/覆盖。
2. Godot 工程在 checkout 根目录，直接打开 `project.godot`；使用 Godot **4.6.3**。机器路径写入被忽略的 `godot.local.txt` 或 `GODOT_PATH`，然后运行 `Play.cmd`。源码普通启动不要求安装 Steam 原生依赖；Steam 候选流程见 `tools/setup_steam_dependency.py` 和 [源码说明](SOURCE_SETUP.md)。
3. 若办公室打开的是历史共享非 Git 外层工作区，继续使用已确认的独立 checkout 与逐文件白名单同步，包含外层交接文档；不要在非 Git 目录直接 pull，也不要套一层嵌套克隆覆盖旧工作。
4. 先读 [当前进度](PROJECT_STATUS.md)、本页和 [RNG 接入 QA](../qa/run_gameplay_rng_integration_20260907/README.md)。当前有 15 个局部恢复组件，完整 RunSession、保存退出/继续本局、全部效果视觉、退出重启整局对照仍未完成；正式性能及真人试玩门槛仍开放。
5. 先确认家里开发任务已停在检查点，再在公司开始修改同一批文件。PR #1 已关闭；继续推 stable，不自行合并 main 或创建 GitHub Release。

本次安排在报告实际阻塞后停止；后续上传操作待恢复正常文件访问和必要测试条件后继续。
