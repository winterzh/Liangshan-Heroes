# 经典固定 30 波：公共 ContinueFlow 回归切片

2026-10-26。本目录只有外部 QA 驱动，**尚未运行或通过**。不修改候选的 20 个生产脚本、manifest、工程启动场景或真实玩家目录。宿主应复用已冻结、导入成功的 handoff 候选，串行持有项目共享引擎锁后运行。

可执行宿主为 `run_classic.py`，复用本批训练/黄泥冈执行器的 `run_batch`、identity、shared lock、private environment 和 process_step。默认实际执行全部六阶段，`--timeout 1800 --wait-lane 1800`；没有隐含的诊断/缩短模式。只查看帮助不会加载执行 helper、创建 profile 或启动引擎：

```powershell
python -B qa/campaign_progress_recovery_20261026/handoff_candidate/tests/classic/run_classic.py --help
python -B qa/campaign_progress_recovery_20261026/handoff_candidate/tests/classic/run_classic.py --base-run .godot/campaign_progress_recovery_20261026/<已导入的20文件批次>
```

宿主拒绝 14 文件旧候选和未完成准备的批次；在 `.godot/campaign_progress_classic_20261026/<新批次>/` 留下失败或成功 receipt，私有 profile 位于同盘 `CodexQA/campclassic/`。四个 `.gd` 原字节冻结；before/after 同时核对根工程、候选 manifest/20源码、实际工程生成身份、引擎、helper、worker 和阶段证据。报告必须属于实际 Popen 的 PID/独有 nonce/顺序时间区间，Windows 即使复用 PID 也不会把两次运行混为一个进程。

## 复用来源与范围

| 新文件 | 原有可靠流程 | 原文件 SHA-256 |
| --- | --- | --- |
| `driver.gd` | `tools/classic30_continue_acceptance.gd`，按当前 startup/identity 契约适配 | `34f3bd375824b8cffac920016e8141a50f7b81c3487ecafe4fca8fb8c0530379` |
| `policy.gd` | `tools/classic30_player_commands.gd`，原字节复制 | `51bc7583e8c3ecf4a36d6cfd5339a6fab0bdee9515bf568a4b2b1c52a1588297` |
| `inflight.gd` | `tools/classic30_inflight_observer.gd`，原字节复制 | `0549d6f2eca39aa9ed1aaf4b24eb07ae635c67cd307effbd178ceefe6a8c177c` |

历史 `qa/classic30_continue_20260909/20260924_125334_7d11f343/` 证明这些普通命令曾完成 30 波；它不证明本候选通过。不要直接运行旧 Python runner：它会重新冻结主工程并设置 `CAMPAIGN_QA=1`。

新驱动通过实际菜单“驻守战”→“30 关 · 经典（推荐）”，按原介绍按钮开局，使用生产选择、下令、付费建造/训练、技能学习/施法接口。Esc 通过 `Viewport.push_input` 打开暂停；其余按钮使用可见且启用的 Button.pressed，属于自动自然模拟，不是 OS 键鼠/原版 EXE 人工验收。没有设置资源、血量、单位位置、波次、计时器、终局标志或直接调用 `_end`。

新增核对：实际启动恢复完成；当前 Provider 的源码/引擎身份；固定 `user://continue/v1`；每次槽代际递增而 binding/token 不变；生产无损 Codec 的暂停观测；classic 原生命周期 **gen1 active→gen2 terminal**；终局等待真实 Flow 和 HUD；两个新进程拒绝旧槽时槽、生命周期清单、CFG、进度记录及禁用 SDK 奖励状态均不变。没有套用 campaign gen3，也不扩大公开战役入口。

## 六个严格顺序阶段

| `CC_MODE` / control.case | 触发和预期 report.outcome |
| --- | --- |
| `new_economy` | 新鲜 profile，无槽；正常经营 ≥8 秒，确有建造/训练/采集，保存退出；`saved_and_exiting` |
| `resume_combat` | 独立进程恢复暂停世界；真实敌人及在途动作存在，再存；`saved_and_exiting` |
| `resume_transition` | 独立进程恢复；真实换波且未到 30 波，再存；`saved_and_exiting` |
| `resume_victory` | 第三次独立恢复，自然完成 30 波及 778 敌，厅存活；`natural_victory` |
| `terminal_reject_1` | 新进程点击继续，明确终局拒绝、留在菜单、无持久变化；`terminal_refused` |
| `terminal_reject_2` | 再一个新进程重复同一拒绝；`terminal_refused` |

所有阶段共用同一私有 profile、batch nonce、候选与原始槽。每个阶段必须正常退出后才启动下一个，不能复制/重写槽来代替跨进程恢复。前 3 阶段由生产 AppLifecycle 的 `continue_saved` 路径退出。宿主必须同时检查退出码、最终 outcome、passed 和每项 check；保存流程退出 0 本身不表示 QA 通过。

全流程保留 1.0 倍速、60 Hz、固定波次/正常倍率；历史耗时约 1025 模拟秒。建议每进程墙钟上限 1800 秒，control.max_sim_seconds 为 1800；不能为赶时间改游戏时钟。定期 progress.json 只作状态显示，不能替代最终报告。

## 环境与宿主调用契约

宿主先复制本目录四个 `.gd` 到新的外部 worker 目录并逐文件 SHA 冻结。不得复制进候选 `scripts/` 或改变候选身份。`CC_BINDINGS` 指向 UTF-8 JSON 字典，恰好三个键 `driver.gd`、`policy.gd`、`inflight.gd`，值为相应小写 SHA-256；`bootstrap.gd` 由宿主另行前后 pin。README 不是运行依赖。

| 变量 | 要求 |
| --- | --- |
| `STEAM_DISABLED` | `1` |
| `CAMPAIGN_QA` | 空字符串，不使用旧工具的 `1` |
| `LSH_CONTINUE_FLOW_QA` | `1`，仅私有 profile 的原有测试门闩 |
| `CC_PROFILE`、`LSH_CONTINUE_FLOW_PROFILE` | 同一个绝对目录，两个环境字符串完全一致 |
| `APPDATA`、`LOCALAPPDATA`、`TEMP`、`TMP` | 分别为该 profile 下 `appdata/localappdata/temp/tmp`，全部已创建 |
| `CC_PROJECT` | 本轮实际冻结候选工程绝对路径 |
| `CC_RUN` | 本批输出绝对目录，control 中所有输出/前序文件位于其内 |
| `CC_WORKERS` | 四个外部 worker 所在绝对目录 |
| `CC_BINDINGS` | 三个依赖文件 SHA 字典路径 |
| `CC_NONCE` | 全六阶段共同的非空批次标识，与 control.run_id 相同 |
| `CC_PROCESS_NONCE` | 每次 Popen 独有的 32 位小写十六进制；宿主另记 PID 与起止区间 |
| `CC_MODE` | 上表相应阶段，与 control.case 相同 |
| `CC_CONTROL`、`CC_CONTROL_SHA256` | 本阶段 control JSON 路径及原始字节 SHA |
| `CC_EXPECTED_CONTENT_VERSION` | 本轮实际 Provider 身份，例如 `source-v1:<sha256>`，不得借用旧候选 |
| `CC_EXPECTED_ENGINE_SHA256` | 实际执行 Godot 二进制 SHA-256 |

清除继承的 gameplay QA/TEST/AUDIT、`AUTO_MICRO`、`SKIRMISH`、`LEVEL`、`SCENARIO`、`CUSTOM_DEFENSE`、截图/性能等测试钩子。不要注入 campaign/defense 旗标；全部由真实菜单选择。允许设置 `LSH_LANGUAGE=zh_CN`；驱动也会通过 Localize 选择简体中文。不得使用 headless：本批要求真实 GL，避免把渲染替代差异当作存档结果。

调用形状（各参数单独传 subprocess 列表，不拼 shell）：

```text
<Godot executable> --path <CC_PROJECT> --rendering-method gl_compatibility
  --audio-driver Dummy --resolution 1280x720 --position -32000,-32000
  --script <CC_WORKERS/bootstrap.gd>
```

control JSON 必需字段：

```json
{
  "run_id": "<CC_NONCE>",
  "case": "new_economy",
  "report": "<CC_RUN>/<stage>/report.json",
  "state": "<CC_RUN>/<stage>/state.json",
  "events": "<CC_RUN>/<stage>/events.jsonl",
  "progress": "<CC_RUN>/<stage>/progress.json",
  "screenshots": "<CC_RUN>/<stage>/screenshots",
  "previous_state": "",
  "previous_sha256": "",
  "previous_report": "",
  "previous_report_sha256": "",
  "max_sim_seconds": 1800,
  "diagnostic_seconds": 0,
  "source_sha256": {"scripts/continue_flow.gd": "<frozen actual sha256>"}
}
```

宿主先创建输出目录。`source_sha256` 应覆盖本候选 20 个脚本及宿主要求的其他运行输入；Provider 另外验证完整实际安装身份。首阶段前序字段为空，其余阶段引用紧邻的真实终态 state/report 和逐字节 SHA。报告会绑定 state SHA、前序阶段、profile、slot、batch、process nonce 和真实 Provider 身份。状态里保留 lossless snapshot，禁止宿主修改后续再作为通过依据。

## 收尾与验收边界

宿主在共享锁下核对当前引擎归属、候选完整身份、四 worker 哈希和真实玩家目录保护；每子进程前后复核，失败保留原始 report/state/log，不清收据或抢其他进程。只有六阶段全部成功、日志无编译/运行错误、前后 identity/worker hash 一致，才可写本候选经典回归通过。

本切片不覆盖：真实 SDK/账号授信与服务器读回、handoff credited 纠正故障矩阵、跨设备、公开发行 EXE、OS 输入、人工体验、性能、所有在途动作类型或发布。终局自然胜利不保证某类非空在途队列曾被实际覆盖，须依据保存时 witness 实报。所有这些资格均保持 false。
