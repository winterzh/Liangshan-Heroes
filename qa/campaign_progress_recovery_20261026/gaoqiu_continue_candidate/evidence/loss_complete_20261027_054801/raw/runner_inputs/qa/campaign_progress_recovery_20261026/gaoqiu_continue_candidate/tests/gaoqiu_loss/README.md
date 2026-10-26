# 高俅自然失败三进程工具

本文件记录工具准备时状态：仅 Python AST、帮助入口、轻量来源核对与静态审查；未编译或运行本工具。后续原生结果以独立运行收据和项目验证记录为准，不把既有连环马、造船或候选导入结果转授本路线。

## 三进程合同

1. `save_before_loss`：全新隔离档，真实可见菜单选择第五章、原剧情按钮开战。记录原宋江/忠义堂实体及三组既有岸军；实际 Escape → SaveAndExit，生产 `continue_saved` 退出。保存主槽 gen1 与本地活动 LC gen1、原 token/上下文/源/引擎身份；不构造训练队列或更改游戏状态。
2. `resume_loss`：实际菜单 Continue 恢复同槽同 token，在暂停时以生产 Codec 精确比较宋江、堂、资源、人口、全部友军身份、波次、阶段与时钟。正常 Resume 后通过原命令卡切宋江为被动，以实际地图寻路选既有第一组岸军旁可达点，发普通 minimap move。原宋江实际移动/掉血，并由生产 `.died` 信号记录真实敌方 killer；原忠义堂必须仍活。240 秒未自然达成即失败，敌波/补兵正常运行。
3. `reject_terminal`：独立进程正常 startup，只读回同 token LC gen1→gen2→gen3、原槽 SHA、CFG、奖励及 uncredited proof；实际可见 Continue 返回 `LOCAL_RUN_TERMINAL`，保持菜单并正常关闭错误层，不能重建 Battle 或重放结算。

失败结算严格使用 LC v3 / Intent v2 / ACK v2 / Level5 contract3。完整保存 `gao_lure`、`gao_fire`、`gao_land`、`gao_capture` 实际 done/missed/pending 分类；失败时 pending 合法，不捏造全目标完成。ACK 必须 `CAMPAIGN_PROGRESS_NOT_REQUIRED`、`persisted=false`、空 CFG SHA；CFG 原字节或不存在状态、records/unlocked、Steam-disabled 奖励状态均不新增。20 帧后结算、metrics 和 HUD 不重复。捕获高俅是可选演义目标，本片不授胜利资格。

## 运行

宿主在候选根目录 `run_gaoqiu_loss.py`。无参数默认只查本工具及已固定准备来源，不遍历完整工程、不创建 profile、不取引擎锁。带 `--base-run` 而无 `--run` 才做完整只读准入；只在显式 `--run` 时取得共享锁并执行一次完整准入。

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_loss.py --help
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_loss.py
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/run_gaoqiu_loss.py --run --base-run .godot/campaign_progress_recovery_20261026/20261027_050851_9bd328cf --timeout 420 --wait-lane 60
```

`--timeout` 是各进程宿主期限，不改生产时钟/事务预算。实际执行复用 `integration_768/prepare_gaoqiu.py.prepared_state(new_run)`，要求该新 Gao 工程自己的完整生成身份、23 脚本和固定 helper、来源 pins、引擎及成功导入。此入口不使用旧祖先的 project，也不把轻量检查当执行准入。示例 941c 来源的造船结果不授本失败路线通过资格。

新 profile 仅创建一次，三个原 Popen PID/nonce 独立，报告与前驱 SHA、外部四 worker 和所有来源前后绑定。宿主只在自身锁、全部尝试子进程已终态及引擎通道空闲时释放锁；失败保留收据与原日志。bootstrap 检查四 worker SHA，`can_instantiate` 失败立即退出，计时前等待非 physics 帧。

## 范围与来源

- `sources.json` 固定本批 host/README/四 GD，逐文件记录从旧 LHM loss、Gao training 宿主以及 Gao 准备器派生/依赖的原 SHA；本片没有修改它们。
- 仅私有 Flow 按钮的程序触发与源工程实际损伤/存档/终局合同；不授公开入口、OS 真人键鼠、Steam SDK/实际账号奖励、导出 EXE、完整高俅胜利资格。
- 无 HP/位置/资源/人口/进度/敌波/种子注入，无直接 lose/win、直调 Session 安装、强制倍率或暂停赋值。stance、选择、移动及按钮均为原操作入口。世界只读观察不保证此首轮路线必能在 240 秒内败亡；超时必须保留原失败，不能降低目标。
