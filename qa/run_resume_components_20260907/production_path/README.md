# 正式模块加载路径复测

本子层保留五个模块晋级后的三轮实际进程。它重复同一组组件检查，验证正式加载路径；不扩展为新游戏场景或完整 Battle 续玩。

| 组件 | Run（UTC） | PID / exit | 检查数 |
| --- | --- | --- | --- |
| Unit | [20260906T184545958515Z](runs/20260906T184545958515Z/report.json) | 37352 / 0 | 149：20 来源前后 + 129 其余，其中身份边界 83 已计入 |
| Projectile | [20260906T184626953535Z](runs/20260906T184626953535Z/report.json) | 38640 / 0 | 54：18 来源前后 + 36 其余 |
| Map v2 | [20260906T184706533703Z](runs/20260906T184706533703Z/report.json) | 5628 / 0 | 63：40 来源前后 + 23 其余 |

三轮完整报告、唯一 stdout JSON、PID、私有 user://、manifest 及报告 SHA 一致；全部 exit 0，严格日志通过，来源和玩家前后摘要一致，进程退出确认、锁释放。`summary.json` 保留统计，`archive_manifest.json` 保留 36 份原字节复制的来源与摘要。

原始 [promotion.json](promotion.json) 的五份映射已核对：Unit、身份、Projectile、Scenery 与原型同字节；Map 只修改固定 Scenery preload 路径。五份正式脚本是 [source_index.json](source_index.json) 明确列出的**仓库外部依赖**，需从对应提交取得 `scripts/run_unit_state.gd`、`scripts/run_graph_identity.gd`、`scripts/run_projectile_state.gd`、`scripts/run_map_state.gd` 和 `scripts/run_scenery_state.gd` 并严格匹配 SHA；本子层没有重复复制它们。

归档期间根任务继续修改了 `scripts/battle.gd` 和 `project.godot`。本轮受测的旧字节已在父层 `sources/` 保留，source index 明确记录历史 SHA 和归档时观察到的 live SHA。不得将这些历史组件收据用于证明后续 Battle 或 project 变更通过。

复跑需要独立完整 checkout。将本子层 `sources/scratchpad/run_resume_production_qa/` 的五份文件恢复到**尚不存在**且受 `.gdignore` 覆盖的原相对目录；`.gd.txt` 只去掉最后 `.txt` 后缀。复用父层归档的 RNG R1 runner 和两个固定 SHA helper，已存在的路径只核对、不覆盖。生产文件与其余受测源码必须先匹配本层 source index；原 manifest 的历史路径保持不变。

```powershell
python scratchpad/run_resume_production_qa/run_smoke.py --godot "<实际非 console Godot 路径>" --suite unit
python scratchpad/run_resume_production_qa/run_smoke.py --godot "<实际非 console Godot 路径>" --suite unit --run
python scratchpad/run_resume_production_qa/run_smoke.py --godot "<实际非 console Godot 路径>" --suite projectile --run
python scratchpad/run_resume_production_qa/run_smoke.py --godot "<实际非 console Godot 路径>" --suite map --run
```

不带 `--run` 仅执行 runner 预检；实际引擎验证须保持独占。引擎身份和完整操作边界见 [父层说明](../README.md)。新证据生成到新的 scratchpad run，不回写历史归档。
