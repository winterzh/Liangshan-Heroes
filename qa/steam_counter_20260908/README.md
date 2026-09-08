# 实际战斗累计击杀原生QA

来源`0df8997952cb5a7616a6bf3839da1fd30b9645bd`，最终`overlay_20260908T020526Z_ec75c46c`，freeze`0930e47353841769df76aaf0c7510abc6f2d0d3b54c4be3be8f14607d3fdde84`。6694记录通过=5826来源SHA+866非来源断言+2诊断。三个生产脚本原字节与隔离受测版本一致，既有完整世界回归和第三次实际世界替换后的累计防重通过。Steam为driver内假SDK，未调用真实账号；持久局/跨进程/玩家槽仍待接通。[合同与范围](../../docs/STEAM_BATTLE_COUNTER_20260908.md)。

保存每次实际运行日志、报告、freeze、manifest及执行输入。SOURCE_PINS逐文件SHA，installation列晋级范围与工具三行适配边界。candidate/*.gd.txt需还原原名至独立来源checkout的scratchpad/steam_counter_20260908，随后运行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 0df8997952cb5a7616a6bf3839da1fd30b9645bd --freeze-sha256 0930e47353841769df76aaf0c7510abc6f2d0d3b54c4be3be8f14607d3fdde84 --candidate scratchpad/steam_counter_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/steam_counter/driver.gd --suite steam-counter-native --prefix "[steam counter QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可换受控绝对短路径。Godot4.6.3，Windows Vulkan，隔离玩家目录及共享Godot锁；不在当前玩家目录运行。真实Steam、长时/整场性能、真人八关和美术门槛不由本报告替代。
