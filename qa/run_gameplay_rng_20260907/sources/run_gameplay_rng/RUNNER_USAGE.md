# 两进程 RNG QA 运行器

`run_qa.py` 是本目录新增的单用途运行器，不修改原先冻结的 module、driver、pins、README 或 QA 合同。默认只核对原始 raw SHA 与指定 Godot 二进制，不启动引擎、不创建 run。

只读预检（PowerShell）：

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python39\python.exe' -X utf8 'E:\ChatGPT\水浒-art-validation\scratchpad\run_gameplay_rng\run_qa.py' --godot 'C:\Users\Administrator\Desktop\新建文件夹 (2)\Godot_v4.6.3-stable_win64.exe'
```

实际两进程 QA 由根任务在独占 Godot 时段执行；同一条命令最后加 `--run`：

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python39\python.exe' -X utf8 'E:\ChatGPT\水浒-art-validation\scratchpad\run_gameplay_rng\run_qa.py' --godot 'C:\Users\Administrator\Desktop\新建文件夹 (2)\Godot_v4.6.3-stable_win64.exe' --run
```

每阶段默认超时 120 秒，可用 `--timeout 30..240` 指定。引擎必须是给定非 console exe，raw SHA 为 `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`；命令行路径不会写入生产文件。

实际运行会新建 `runs/<UTC stamp>/`，只复制 codec + module + driver 三个原始文件，并生成一个无 Autoload 的最小 project.godot；不导入主工程，也不复制主缓存或玩家文件。原生直接脚本加载若生成 UID，仅允许三个原 `.gd` 对应的 `.gd.uid` 和标准 UID 文本；writer 后记录实际字节，reader 前后必须保持这些字节。私有 `.godot/` 缓存可新增，不作为源码归档。

复用来源严格固定：

- `scratchpad/separation_sections_diag/frozen/process_safety.py`：`7983b00449f8d606e4f1be55ca13596239fbc8b47c3894ff3c31da03757835a1`。直接调用其中 `run_godot`，由其保存实际 `Popen` 句柄、处理异常和确认退出；只在加载的内存模块内设私有 ROOT、严格 ERROR 模式及调用前后只读 guard，不改 helper 字节。
- `tools/run_reduced_effects_qa.py`：`1cecf1c3e6bb7c15992e6955fcad67e959cf836a198e9ceca28d744a1a573c0c`。复用已审查的源码枚举/摘要与生产项目用户目录名称识别，不调用它的引擎入口或环境/镜像生成器。

共同 `.godot/redraw_rejection_source.lock` 从复制前保持到所有最终检查完成。writer 必须实际退出，严格日志、唯一 stdout JSON、sidecar、全部 checks/labels/来源/PID/user 检查通过后，才能生成 reader manifest 并启动第二个独立进程。失败的 writer 不启动 reader，原 helper 进程收据保留原文。无法证明实际子进程退出或最终 source/player guard 失败则保留锁并在 receipt 写出原因，不按进程名杀别人的 Godot。

两个子进程分别使用 `private_profile/writer/` 和 `private_profile/reader/` 下的 APPDATA/LOCALAPPDATA/TEMP/TMP；不改 HOME 或父进程环境。真实生产玩家目录和原 APPDATA 下同名 QA 目录做完整文件/目录前后核对；缺失目录的存在性同样受保护。源码保护复用 public guard 的确切生产范围，另独立锁住本 RNG 冻结输入、runner 和 helper 字节；不声称扫描全磁盘。

主收据为 `receipt.json`；每阶段有 `*_manifest.json`、`*_report.json`、`*_report.log`、`*_report_process.json`、`*_validated.json`。writer 的 `handoff.json` 和 `writer_report.json` raw SHA 成为 reader 的不可变输入。只有最终 `complete=true`、`lock_released=true`、两阶段 validated 都成功才算该两进程合同通过；静态准备不是 Godot 解析或 RNG 运行证据。

成功范围仍为七种子、448 次混合后缀的独立 RNG 续接；没有接入 Battle、迁移全局随机流、完成标准 30 波恢复或得出性能结论。归档只取明确报告、日志、manifest、handoff、摘要和收据；不要复制整个 project/private_profile/.godot。
