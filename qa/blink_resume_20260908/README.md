# BlinkShotFx 原生保存恢复 QA

唯一原生运行：`overlay_20260907T194830Z_4165ce9f`，来源 `aae6593e103286f2d79610150808dcedd3dc3009`。原生导入、驱动、全部保护通过；6188断言=5774来源SHA+414其他断言。详细行为范围见[实现说明](../../docs/BLINK_RESUME_20260908.md)。

`run/` 保留原始日志、报告、来源manifest、runner/guard及freeze；`candidate/` 保存实际受测两源码和完整驱动的原字节（.gd.txt），以及原冻结清单。`SOURCE_PINS.json` 逐文件记录来源路径、归档路径、大小与SHA256。`installation.json` 记录复制前后SHA及受测字节接入。`preparation/` 是本轮准备脚本来源，非直接从QA目录执行入口。

## 重现

使用上述来源SHA的独立checkout，配置本机Godot4.6.3路径至被忽略的 `godot.local.txt`。不要在含未提交修改或正在运行Godot的共享目录执行。将本QA的 `candidate/battle.gd.txt`、`run_visual_graph.gd.txt`、`driver.gd.txt` 分别按原名恢复到 `scratchpad/blink_resume_20260908/`，并复制原 `overlay_manifest.json` 与 `freeze.json`。先按SOURCE_PINS验证归档SHA，再验证恢复名字后的字节等于freeze输入。该scratchpad必须含 `.gdignore`。

在来源checkout根目录执行以下命令（Windows PowerShell可写为一行）：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head aae6593e103286f2d79610150808dcedd3dc3009 --freeze-sha256 a3b4bb8c7a95ab7ae5b3ce3bfca3472e95d92ce9629994cc48d3aea9f3fad6bc --candidate scratchpad/blink_resume_20260908 --expected-files 2 --driver driver.gd --driver-destination tools/blink_resume/driver.gd --suite blink-resume-native --prefix "[blink resume QA] " --profile-root D:/CodexTemp/lshqa --run
```

profile-root可换成本机受控短路径；必须为空闲可写父目录。runner持有公共锁，复制生产白名单、覆盖两个候选，导入后将真实驱动放到可导入tools路径，并设置新的私有环境/报告。每次执行创建新run；原始报告及其中旧绝对路径只作为历史证据，不是新运行的写入目标。换源码基线需重新审查before SHA与冻结清单，不能改旧成功收据伪装成新测试。

原13场景使用实际创建器、单位/特效适配器、JSON及每场65对固定步长消费者。新的独立箭光场景才使用真实idle调度；46个双方存活帧一致、各自然退出一次，未手动推进该场景的计时。没有新进程加载战斗、真实渲染像素对照、完整30波或玩家保存菜单验收。全局视觉RNG仅验证恢复不多抽；未来图腾创建仍使用已声明的配对测试种子。

辅助查看driver.log尾行时PowerShell读取超大JSON较慢，本轮终止了该只读查看进程；原生runner已独立退出0且收据complete=true，未停止或重启Godot验证。
