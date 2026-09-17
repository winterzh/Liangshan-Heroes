# 持久局与世界会话原生QA

来源`6738b3fe9f996a0da034d8237b4f7fbaeb5d831b`，freeze`0683d4069e03a6ff4361cfdef3b79bb4f79b35f0097ba728ac5133e0aed337fe`。持久会话`overlay_20260908T031211Z_fe3853a5`、原未计统计路径`overlay_20260908T031706Z_0f7b87d5`均保留报告及实际子进程证据；计数、限制与接口见[合同](../../docs/PERSISTENT_RUN_SESSION_20260908.md)。SOURCE_PINS固定每份实际输入、日志、报告和合成收据/槽，不含真实玩家配置或Steam缓存。

在独立checkout检出上述来源，将candidate/*.gd.txt还原为原名至scratchpad/persistent_session_20260908，其他candidate文件保持原字节。使用已配置Godot4.6.3，以下两个套件串行执行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 6738b3fe9f996a0da034d8237b4f7fbaeb5d831b --freeze-sha256 0683d4069e03a6ff4361cfdef3b79bb4f79b35f0097ba728ac5133e0aed337fe --candidate scratchpad/persistent_session_20260908 --expected-files 4 --driver driver.gd --driver-destination tools/persistent_session/driver.gd --suite persistent-session-native --prefix "[persistent session QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 6738b3fe9f996a0da034d8237b4f7fbaeb5d831b --freeze-sha256 0683d4069e03a6ff4361cfdef3b79bb4f79b35f0097ba728ac5133e0aed337fe --candidate scratchpad/persistent_session_20260908 --expected-files 4 --driver driver_uncredited.gd --driver-destination tools/world_slot/driver.gd --suite world-slot-native --prefix "[world slot QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可改为受控绝对短路径；不在玩家目录运行。新模块UID只从最终持久会话原生导入晋级。此QA使用假SDK，内部模式尚未由正常启动启用，玩家菜单和真实Steam发送待完成。
