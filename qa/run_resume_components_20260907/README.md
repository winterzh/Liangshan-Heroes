# 真实组件恢复 QA（2026-09-07）

这里保留三个成功的组件恢复 smoke，以及此前两个失败进程。全部使用实际非 console Godot 4.6.3；它们没有运行完整 Battle 的保存、关闭程序、重新启动和继续战斗流程。

模块晋级后，另有三轮相同检查通过正式 `scripts/run_*` 加载路径复验，见 [production_path](production_path/README.md)。原型与正式路径各自的源码、manifest 和结果独立保留，不重复计算场景数量。

| 组件 | 原始 run（UTC） | 结果 / PID | 检查数 |
| --- | --- | --- | --- |
| Map 首轮 | [20260906T182530446009Z](runs/20260906T182530446009Z/receipt.json) | 失败 / 20836 | 无完整报告 |
| Unit 首轮 | [20260906T183329072195Z](runs/20260906T183329072195Z/receipt.json) | 失败 / 42676 | 无完整报告 |
| Projectile | [20260906T183751958907Z](runs/20260906T183751958907Z/report.json) | 通过 / 5032 / exit 0 | 54 = 18 条逐源前后 SHA + 36 条其余检查 |
| Unit | [20260906T183947533726Z](runs/20260906T183947533726Z/report.json) | 通过 / 10560 / exit 0 | 149 = 20 条逐源前后 SHA + 129 条其余检查 |
| Map v2 | [20260906T184102784624Z](runs/20260906T184102784624Z/report.json) | 通过 / 4188 / exit 0 | 63 = 40 条逐源前后 SHA + 23 条其余检查 |

“其余检查”每轮仍包含私有 user:// 检查、夹具和聚合断言；Unit 的 83 条 identity boundary 检查已包含在 149 条内。不得将检查数或来源检查重复累加为独立游戏场景。

三份报告的唯一 stdout JSON、sidecar、真实 PID、manifest、实际 user:// 和报告 SHA 均一致。五轮原始 sources/players before/after 摘要各自完全一致，子进程退出已确认、cleanup_error 为空、共同锁释放。players 文件只有路径/大小/摘要，没有复制玩家文件内容。

## 失败原文与受测源码

Map 首轮日志包含 `Art` 未定义、依赖编译失败和后续空对象错误，旧 runner 最后触发 120 秒超时。保留的四份 failed_source 文本分别对应该轮 Map adapter、Scenery adapter、Map driver 和 runner。`source_correction.json` 的修正后 SHA 指向中间版本，不能当作最终成功 Map v2 的身份。

Unit 首轮因 ObjectDB `slot >= slot_max` 错误被 strict log 拒绝。日志没有定位具体整数输入的调用栈；旧身份实现对候选整数查询 ObjectDB 的代码，以及旧 boundary/Unit driver 三份原文均保留。成功版改为调用方在冻结战局时显式提供完整活 Unit 清单，核对它与身份 registry 的对象集合相等，不通过猜测整数查询 ObjectDB 来证明完整性。

[archive_manifest.json](archive_manifest.json) 为原字节复制清单，含 source、destination、bytes 和 SHA256；[source_index.json](source_index.json) 逐轮对应原始 manifest 和 runner。未变化的来源只复制一份，失败轮变化的来源直接指向其 failed_source 文本，所有历史 runtime SHA 都能解析到原字节。[archive_verification.json](archive_verification.json) 记录复制后复核；[summary.json](summary.json) 给出小型统计。

`sources/` 收录三份成功 driver、identity boundary、组件草稿、manifest 指定生产源码，以及当前 `run_smoke.py`、它复用的 RNG R1 runner 和两个固定 SHA helper。GDScript、shader 和 project.godot 以 `.txt` 存储，根目录有 `.gdignore`。没有复制私有工程、private_profile、夹具数据、Godot 缓存、玩家存档、美术二进制或引擎。

## 复核与复跑

本目录不是独立 Godot 工程。先在独立、完整的同版本源码 checkout 中按 `source_index.json` 校对被测生产文件及相关内容资源。历史 manifest 中的绝对路径是原进程证据，不能改写为新机器路径。

恢复 `sources/scratchpad/run_resume_integration/` 到**尚不存在**且由 `.gdignore` 覆盖的 `scratchpad/run_resume_integration/`：GDScript 文件去掉最后的 `.txt` 后缀，Python 保持原名和原字节。恢复 RNG R1 runner 与 process_safety helper 到清单声明的原相对路径；已存在时只核对 SHA，不覆盖。`tools/run_reduced_effects_qa.py` 必须匹配归档 SHA，不能以覆盖公共工具的方式凑通过。其他归档生产源码用于核对，不自动覆盖现有生产文件。

`run_smoke.py` 只导入 RNG R1 runner 的公用函数，不执行其 RNG writer/reader，也不要求把 RNG 的整套私有测试工程复制过来。Godot 非 console 可执行文件须为 SHA256 `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`。在独占引擎条件下逐个执行；不带 `--run` 只做该 runner 的只读来源预检：

```powershell
python scratchpad/run_resume_integration/run_smoke.py --godot "<实际非 console Godot 路径>" --suite unit
python scratchpad/run_resume_integration/run_smoke.py --godot "<实际非 console Godot 路径>" --suite unit --run
python scratchpad/run_resume_integration/run_smoke.py --godot "<实际非 console Godot 路径>" --suite projectile --run
python scratchpad/run_resume_integration/run_smoke.py --godot "<实际非 console Godot 路径>" --suite map --run
```

新进程产生新 run 和私有 profile；不得回写本归档。runner 保留实际 Popen 句柄、私有 APPDATA、共享锁、严格日志和源/玩家保护。完整实现边界见 [正式说明](../../docs/RUN_RESUME_COMPONENTS_20260907.md)。
