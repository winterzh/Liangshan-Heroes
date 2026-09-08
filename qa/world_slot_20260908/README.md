# 单槽跨进程原生QA

来源`ef2d87b4c13fb84802f3c3d99927e2ba3b811290`，最终freeze`492ab815af248f32b4af98261f1e08805022ee58337fe1cedcbf70b58f7aa93a`。世界套件`overlay_20260908T024849Z_d0fb85ff`，存储回归`overlay_20260908T025311Z_7eba1971`；各自完整计数与边界见[合同](../../docs/WORLD_SLOT_20260908.md)及installation.json。保留所有失败轮次，SOURCE_PINS固定实际受测输入/日志/报告/合成夹具。fixtures仅包含本次私有QA槽与虚拟Steam数据，不含玩家配置、真实账号或SDK缓存。

复现需独立检出上述来源，将candidate/*.gd.txt去掉.txt放回scratchpad/world_slot_20260908并保留其他candidate文件；使用当前配置的Godot4.6.3。两个套件串行运行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head ef2d87b4c13fb84802f3c3d99927e2ba3b811290 --freeze-sha256 492ab815af248f32b4af98261f1e08805022ee58337fe1cedcbf70b58f7aa93a --candidate scratchpad/world_slot_20260908 --expected-files 4 --driver driver.gd --driver-destination tools/world_slot/driver.gd --suite world-slot-native --prefix "[world slot QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head ef2d87b4c13fb84802f3c3d99927e2ba3b811290 --freeze-sha256 492ab815af248f32b4af98261f1e08805022ee58337fe1cedcbf70b58f7aa93a --candidate scratchpad/world_slot_20260908 --expected-files 4 --driver driver_ledger.gd --driver-destination tools/steam_ledger/driver.gd --suite steam-ledger-native --prefix "[steam ledger QA] " --profile-root D:/CodexTemp/lshqa --run
```

profile-root可换为受控绝对短路径；不得在玩家目录执行。三个进程使用相同导入后的安装身份，新UID只从最终世界运行晋级。普通玩家按钮、持久Steam绑定及完整范围仍未交付。
