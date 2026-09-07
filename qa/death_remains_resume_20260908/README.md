# 死亡残留恢复 QA

来源7a36b1c73fdf72b6523e9cdb7459667db808fc18。R1—R5是原始失败，R6为真实死亡+世界核心准备/残留生命周期通过，R7为既有混合图及无贴图回退回归通过，R8是直接与真实源对象逐字段对照的最终通过。失败细节和范围见[实现说明](../../docs/DEATH_REMAINS_RESUME_20260908.md)。

`runs/r1`至`runs/r8`保存原始日志、实际候选/驱动、执行器、manifest/freeze、收据和存在的报告；R1无最终报告，没有补造。SOURCE_PINS记录每份原字节SHA与来源。candidate是R6/R7包，final_candidate是R8最终包；两者生产源码相同，驱动和freeze不同。preparation中的旧/最终helper分别保留。installation最后一行记录R8与重新安装的原生UID。QA通过.gdignore隔离，原字节由Git属性保留。

## 重现最终检查

在上述来源SHA的独立checkout配置Godot4.6.3，核对SOURCE_PINS。将final_candidate的三个生产.gd.txt、driver.gd.txt、mixed_driver.gd.txt还原为.gd原名，连同freeze.json和overlay_manifest.json放入scratchpad/death_remains_20260908，并添加.gdignore。不把归档UID复制进来源scripts，原生import会生成隔离UID。来源执行器与归档runner/guard SHA须相符，保持私有user://和Godot独占。

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 7a36b1c73fdf72b6523e9cdb7459667db808fc18 --freeze-sha256 151ac9e3d6083129edbc859db6b650c0bc03d5c2d8b6f05fefed9d4433a3c02e --candidate scratchpad/death_remains_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/death_remains/driver.gd --suite death-remains-native --prefix "[death remains QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

复现R7可用candidate包的freeze d358a841634c397bcac8b00fe209339933a835f5780471fd07cce19d30150a44，driver改mixed_driver.gd、destination改tools/death_remains/mixed_driver.gd、suite改mixed-fx-native、prefix改“[mixed Fx QA] ”，省略--rendered-driver。profile-root可换为本机受控短绝对路径；历史收据中的绝对路径不是新写入目的地。preparation脚本只供审计，不从QA目录直接运行。

R8为5847项=5782来源SHA+65其他；R7为6233项=5782来源SHA+451其他。真实死亡是受控致死调用，残留生命周期夹具缩短时间；两者均不等于自然完整30波、像素显示、完整Battle挂载、跨进程或Steam账号验收。
