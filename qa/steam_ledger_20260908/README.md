# 独立Steam局记录原生QA

来源`dbb101cd8dfab4c11c7410a956ff7d6eea073826`，最终`overlay_20260908T014855Z_09dbe1e9`，freeze`b0de344194c9e50293b9f193b777c076c280729a7dc32e43d8587140ef1e40b4`。8208条记录通过（5826来源SHA、2382其余断言），2100次实际写入、7次核对PID后的强杀和7次新进程恢复、11类坏账本。真实SDK、Battle绑定及玩家继续入口未测试。完整接口/边界见[实现说明](../../docs/STEAM_RUN_LEDGER_20260908.md)。

R1完成8153项检查但出现3条Unicode解析警告，来源是旧候选中重复的NUL字符串检查。R2保留字节层UTF8/NUL拒绝，移除会自行触发警告的字符串字面量，并新增八关/据守/AI、失败终局、饱和值及活跃写者竞争检查。两轮原始输入、报告、日志、manifest、隔离fixture均保留；测试生成的记录只含固定虚拟账号，未归档实际用户profile或Steam缓存。

所有文件映射与SHA见SOURCE_PINS.json。candidate为最终受测输入；.gd.txt需还原原名至独立来源checkout的scratchpad/steam_ledger_20260908，按原manifest/freeze复现：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head dbb101cd8dfab4c11c7410a956ff7d6eea073826 --freeze-sha256 b0de344194c9e50293b9f193b777c076c280729a7dc32e43d8587140ef1e40b4 --candidate scratchpad/steam_ledger_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/steam_ledger/driver.gd --suite steam-ledger-native --prefix "[steam ledger QA] " --profile-root D:/CodexTemp/lshqa --run
```

profile-root可换受控绝对路径。真实Windows/Godot4.6.3，无渲染性能或真人结论；仅文件进程崩溃验证，不等同断电。改动不触发Steam上传。
