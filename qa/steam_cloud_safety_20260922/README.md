# Steam Cloud / Rich Presence 安全修复 QA

基点 `3c47d21693e91d70d0521fd47f30b30b603ae979`，目标分支 `codex/sync-20260905-stable`。本批仅源码修复与文档同步，不构建安装包、不合并 main、不发布 Steam、GitHub Release 或更新服务器。

## 最终结果

Godot **4.6.1 macOS ARM64**，冻结批 `/tmp/lsh-cloud-safety-final-20260922-r2`：真实导入通过，**740/740** 检查通过；3331 份受测来源在副本和工作区均零漂移。无 SCRIPT ERROR / ERROR / WARNING。完整来源、每组退出码和检查数在 [source-receipt.json](source-receipt.json)。

归档日志按原样保留，包括三处测试标签末尾空格；源码和文档的 `git diff --check` 通过，未为消除日志空白告警改写原始运行证据。

导入时 Godot 自动探测本机 ADB，日志有 `tcp:5037 Connection refused` 提示；未连接 Android 设备，不影响本轮 macOS 脚本回归，也不据此声称安卓验证通过。

| 回归组 | 检查数 |
|---|---:|
| F1～F8 输入、旧 F2 迁移与 HUD 键帽 | 93 |
| RTS 基础操作 | 47 |
| 经营规则 | 66 |
| 英雄与物品 | 64 |
| HUD 内部快照 | 38 |
| 输入操作 | 122 |
| 战斗操作 | 95 |
| 战役操作 | 32 |
| 实际 SteamCloud / 设置 / 存档脚本 | 104 |
| 实际 Presence / Battle / 波次事件脚本 | 79 |

## 修复与覆盖

- 两个新 Autoload 的 `ready` 命名冲突；实际生产脚本导入，不再以 Python 重写逻辑代替。
- GodotSteam 4.22.1 `fileRead` 指定真实字节数，校验 `ret` 字节数与 `buf`；短读、错误类型、禁用 Cloud、坏 payload 都拒绝覆盖；仅同步 `fileWrite`，无返回 void 的异步假成功。
- 账号绑定、分账号镜像、旧共享镜像与旧 Steam 迁移归属。A→B、空/已有 B 云档、失去原生账号、无归属残留镜像均测试。
- 真实文件故障注入：在私有 profile 的 `settings.cfg.tmp` 创建空目录，模拟账号切换中途写盘失败；不会把 A 进度上传为 B，新实例也拒绝未完成的 `pending_owner` 过渡。两方副本保留，移除故障不自动绕过归属检查。
- 首次读失败重读、读失败期间本地设置保留、同步写失败退避、失败期间云端进度提高、失败期间云端偏好改变、断连后的最新进度/设置/语言合并。读取前及失败后不盲写覆盖。
- 下载设置即时应用音频、语言、按键通知，并经过 F1～F8 与旧 F2 冲突链迁移；错误类型/超限设置不会部分改动运行状态。
- 真实 Campaign._save/_load、Settings.save、语言保存通过 `/root/SteamCloud` 路径通知被测实例，保存期间的重入保护经过验证；未知 campaign 段保留。
- 演义印采用不同目标集的真实 GDScript 测试，不跨局拼接目标。
- 八关四语标题、玩法独立分类、真实两次据守波次递增、暂停/恢复、语言变化、原生接口失败后重试、账号失效清理，以及普通非 Steam 启动不调用 SDK。
- 云设置晚到时，速度仅在未暂停的部署/战斗阶段更新，不改变剧情、结算或暂停状态。
- 四语 Steam `#Status` 输入文件检查；这不是后台已上传或公开的证据。

## 隔离

白名单复制源码与 QA 脚本至工程外新目录，UUID 命名的新 profile，存在则拒绝复用。没有复制 Steam DLL，没有真实 Steam 单例，`STEAM_DISABLED=1`，不改 HOME。测试会修改自己的小型配置夹具，既有玩家 profile 不在操作范围。

常规测试保持 `CAMPAIGN_QA=1`；只有在校验私有路径、无原生 Steam 后，同步保存探针临时将其置为 `0`，调用保存后立即还原，不跨帧、不 await、不调用网络。Steam 禁用始终保留；文件落点和还原状态都断言。生产代码没有新增 QA 全局写入旁路。

## 诊断批与失败记录

- 原 `3c47d216`：实际导入因两个 `ready` 变量重名失败；历史 Python 11 项通过不能证明原生代码有效。
- 专项 r1：Presence 79 通过；Cloud 测试脚本局部变量类型推断失败，修复夹具后重跑。
- 专项 r2：揭示首次失败拉取期间的设置丢失、错误账号字段类型比较异常；另有一个测试错误期待归属中断自动恢复，改为断言设计规定的持久停止。原始诊断日志节选保存在 `diagnostic-r2-cloud.log`。
- 专项 r3、r4：检查通过，但分别遇到后续来源变化；不能充当最终冻结验收。
- 完整 r1：738 项通过，但新增“失败上传后再次下载较新设置”的修复/用例导致来源漂移，整体收据判为 false；保留为诊断，不用于本批通过声明。
- **完整 r2**：新增回归包含在内，740 项通过，双侧来源漂移为空，作为本批唯一最终冻结依据。

## 文案与边界

恢复原 12 条 Steam 状态的源分片，再增加 2 条明确的“已提交 Steam / 本机状态停止同步”文案；4517 条目录的格式校验零错误。除这 2 条新增文案外，重建前后既有翻译内容逐项相同。通用扫描仍报告 38 条：8 条既有游戏缺译、30 条 Steam 独立四语表内的文本被当作源文案扫描；本批未用批量排除隐藏它们。

本批没有 Windows 原生 SDK、真实两个 Steam 账号、跨设备或离线 Steam 客户端验收；没有更新真实后台 `#Status` 配置。`fileWrite` 返回成功仅代表 Steam 客户端接受缓存写入，不证明服务器已经同步。

没有新增完整 60 波性能测试、原生手机截图或实际续玩恢复链验收。此次不改触屏布局几何；既有 173 状态图形测试的历史结果不能算作本批重跑。

故障中的本地归属恢复边界见 [实现文档](../../docs/STEAM_CLOUD_PRESENCE_20260921.md)。

## 远端并行变化

最终 fetch 时，`origin/codex/sync-20260905-stable` 仍为 `3c47d216`，`origin/main` 已从 `c1f0bcfc` 独立前进到 `80f4aeb4`。只读复核确认 main 的 Cloud 仍含旧版接口/编译问题；`hud.gd → SteamService.set_presence()` 是另一条状态写入链，且 main 的 `project.godot` 缺少 SteamPresence Autoload。本批没有合并该变化，740 项结果对应 stable 修复来源，不代表 main 或未来合并结果通过。

未来合并须保留本批 Cloud 安全修复，统一好友状态入口、保留 Autoload，并重新验证；即使 Git 文本合并不冲突，也不能让两套逻辑同时写入状态。

## 复现

```sh
python3 -B tools/run_rts_refinement_qa.py --godot /path/to/Godot --out /absolute/new/outside-checkout
python3 -B tools/run_steam_cloud_presence_qa.py --godot /path/to/Godot --out /another/new/outside-checkout
```

源码及脚本以最终 source-receipt 的 SHA 为准。提交/远端同步结果以本轮 Git 收尾回读为准，不将源码同步等同正式发布。
