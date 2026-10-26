# 高俅正常造船：活动期三进程续玩工具

本文记录工具准备时状态：**未编译、未运行 Godot、未获得高俅自然路线资格**。全部文件是独立外部 QA；原 LHM、生产脚本、旧候选、冻结和已定稿 integration 四文件保持原样。后续执行必须绑定新 Gao 全量冻结及其独立成功 import，旧 768 或连环马的通过结果不能替代。

| 进程 | 正常路径与证据 |
| --- | --- |
| `save_queue` | 新 profile 的真实菜单剧情页，按高俅标题定位并滚动到可见的“出征”按钮，原对话及开战按钮；选一个现有工匠，在关卡 `YARD_SITE` 通过 `arm_build` / `_try_place_building` 正常建船坞，实扣 100 金、100 木，工匠正常走到并完成 30 秒施工。然后对这个船坞仅提交一次 `queue_train(liangshan_warship)`，实扣 90 金、65 木、预留 3 人口，28 秒原计时运行至少 5 秒后，实际 Esc / SaveAndExit 将未完成队列写同槽 gen1；由生产 AppLifecycle 以 `continue_saved` 退出。 |
| `resume_complete_save` | 独立进程实际菜单 Continue，恢复同一 token、槽 SHA、造船坞 entity ID、岸边 berth、生产定义、队列和剩余时间、资源人口及物理 tick。正常暂停菜单继续，跨进程累计 28 秒（至多两物理帧取整）只完成一艘船，真实船出生在原固定泊位的本地水域候选；再自然运行 29 秒，无第二次下单、重复船或重复人口。实际 SaveAndExit / ConfirmSave 保存原槽 gen2，由生产再次退出。 |
| `verify_completed` | 第三进程实际菜单 Continue，核对已完成的唯一同一艘船、空队列、3 人口以及同一活动期生命周期，随后测试正常退出。只授活动期持久性，不做终局或奖励结算。 |

Gao 的已安装目标合同是 contract3；LC 使用公共 `local_campaign_continue_lifecycle_v3`：`begin()` 为已验证 Gao context 写实际 gen1 active，终局才进入 gen2/gen3。因此工具读取实际 lifecycle document/revision/token/hash，检查首次保存取得的 gen1 active 在后两进程及再保存后逐字一致，`intent` 和 `progress_receipt` 仍为空；槽代数独立为 1→2。它同时核 Campaign 的 CFG 存在性/原 SHA、records/unlocked/owner 没有新增。这里没有 ACK 或奖励资格。

真实生产队列没有原生 job UUID；报告身份由原 producer entity ID、queue index/key、order tick 组成。跨进程 checkpoint/training 采用生产 Codec，保留整数类型、Vector2/Vector2i 和浮点位，不用原始 JSON 字典代替精确状态比较。可见按钮 `.pressed.emit()` 和 viewport Esc 验证真实 UI 回调链，不表示桌面鼠标或人工验收。继续入口只在严格隔离 profile 中使用现有私有 Flow 门槛，`STEAM_DISABLED=1`，`CAMPAIGN_QA` 为空。

工匠、船只、金木、人口、队列计时、HP、位置、完成标志和波次都不赋值。普通用户设置固定为 1x / 60Hz、auto-micro 0；不停止敌军或跳过正常施工。首波仍按原生约 140 秒出发，施工或出口发生阻塞时按实际战况和有界等待失败，不调低断言或冻结敌波。A 的施工等待上限 120 秒，B 完成等待 50 秒、防重等待 65 秒；宿主每进程默认 360 秒，超时保留失败。

```powershell
# 轻量来源/计划检查：不读全工程、不创建 profile、不占锁、不启动引擎。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_training.py

# 新 freeze/import 完成后，根线程另做全来源只读准入（会全量哈希）。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_training.py --base-run <新Gao冻结目录>

# 仅根线程在独占通道时授权实际运行。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_training.py --base-run <新Gao冻结目录> --run --timeout 360 --wait-lane 1800
```

绑定直接调用 `integration_768/prepare_gaoqiu.py::prepared_state`，要求自身生成身份、完整 23 脚本＋native helper 来源/构建/实际字节及自身成功 import，返回的新 run/project/generation 才用于执行。外部三 GD 和宿主/README 以 `sources.json` 绑定；bootstrap 先检查全部 worker SHA，离开 physics frame，`can_instantiate()` 失败即退出。宿主仅 `--run` 使用共享锁，冻结全部准备来源与 workers，三进程复用一个新短 profile，分别记录原 Popen PID、独立 nonce、前序报告 SHA 和正常原生退出；终态再核全源/生成/引擎/全部 pins。仅在原子进程都终态、无活 Godot 且仍持有自己的锁时释放。

复用的是 LHM `base.gd` 的菜单滚动、可见按钮、Flow 保存/继续及精确 Codec 算法，`terminal.gd` 的报告退出形式、`bootstrap.gd` 与宿主的绑定模式；另按真实 Gao 源新增正常施工/水域出生检查。`sources.json` 保留原件 SHA。完整高俅胜利、失败、终局拒旧槽、四演义目标、credited/SDK 和原版键鼠仍是后续工作。
