# 家里 Git 接续验证（2026-09-05）

## 输入与环境

- 仓库：`https://github.com/winterzh/Liangshan-Heroes.git`。
- 分支：`codex/sync-20260905-stable`；继续 PR #1，base 为 `main`。
- 接续源码 SHA：`513ee3369726acb92dd9d464eabb6ec235f527b2`。
- 工程：`E:\ChatGPT\水浒\project.godot`；此前是无提交、无文件修改的空 Git 仓库。
- Godot：`4.6.3.stable.official.7d41c59c4`；本机 EXE 路径仅存在忽略文件 `godot.local.txt`。
- 真实图形：NVIDIA GeForce RTX 3070 Ti、Vulkan 1.4.351、Forward+、1280×720。

Git 首次默认 schannel fetch 因服务器提前断开而失败。单次命令使用 `git -c http.version=HTTP/1.1 -c http.sslBackend=openssl fetch origin codex/sync-20260905-stable` 后成功，再建立跟踪分支；未降低 TLS 验证、强推、覆盖文件或改 main。PR 状态和分支随后经 GitHub API 只读核实。

## 本轮结果

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Godot 首次导入 | 退出 0；无脚本、解析或资源错误 | `receipt.json`（完整导入日志留本机 `.godot/home_setup_20260905/`） |
| 启动器增量导入、Windows PowerShell 5.1 | 通过；缓存完整直接返回 | `windows_powershell_launcher.log` |
| 无界面主菜单 120 帧 | 退出 0，无错误 | `menu_headless_console.log` |
| 真实图形主菜单 | 退出 0，保存 1280×720 PNG；已目检标题、背景、六入口和全屏按钮，无截断 | `menu_graphics_console.log`、`menu_1280x720.png` |
| 核心合同 | 68 项 PASS；失败列表为空 | `core_console.log` |
| 默认驻守阵容四向路由 | PASS；缺少资源的 coverage gates 仍为 false | `direction4_console.log`、`direction4_report.json` |
| 四类官军 walk/attack/death × 四向 | 48/48 单元；失败 0 | `actions_console.log`、`action_contract.json` |
| 新增/调整 PowerShell 脚本 | 4 文件语法解析通过；显式参数、环境变量、本机配置、GUI→console 与无效环境路径拒绝通过 | `receipt.json`、`resolver_checks.log` |

主菜单图来自 Godot 实际渲染，使用本机临时夹具加载正式 `scenes/menu.tscn`，等待绘制后保存 viewport，并通过 `AppLifecycle.request_quit` 正常退出。没有改生产 UI。图形检查独占运行，检查结束没有残留 Godot 进程。

核心和动作回归使用库中现有脚本，设置 `CAMPAIGN_QA=1`。动作测试原先固定输出到历史 QA 路径，本轮复制重跑产物至本目录后还原该历史文件；未覆盖旧记录。导入造成的 1168 个已有 `.import` 换行改写也已还原，新增 139 个 sidecar 在本机 `.git/info/exclude` 逐项排除，未将其提交。原始日志的 SHA-256 收据见 `receipt.json`；本目录 `.gitattributes` 禁止对证据日志/JSON 自动转换换行，以便在另一台电脑复验原始字节。

## 复跑

在工程根目录配置 `godot.local.txt`，执行：

```powershell
& .\tools\run_local.ps1 -Mode import
$env:CAMPAIGN_QA = '1'
& .\tools\run_local.ps1 -GodotArgs @('--headless', '--quit-after', '120')
$godotCheck = & .\tools\resolve_godot.ps1
& $godotCheck --headless --path . --script res://tools/campaign_core_test.gd
& $godotCheck --headless --path . --script res://tools/skirmish_direction4_contract_test.gd
& $godotCheck --headless --path . --script res://qa/skirmish_direction4_fix_20260905/action_contract.gd
```

后两项有固定输出路径，复跑前应保留已有证据，完成后将新报告存到本轮独立目录。图形主菜单正常启动可用 `Play.cmd`。模式切换长测和音频矩阵保留原入口，本轮只适配它们的 Godot 路径，未借用旧结果计为本机复测。

## 待办与范围

尚需补齐四向/环境美术、修正旧阴影夹具地图前提、进行真人八关/30 波试玩和 30 分钟稳定性测试。48 动作单元通过不证明完整 hurt、全部兵种或高帧率动画；68 核心检查不证明平衡和节奏。本轮未导出安装包、未执行 Steam 操作、未合并 main；提交和推送结果由 Git 历史及最终远端回读确认。
