# Battle Fog 测试原文与复现

本目录封存 run `20260906T162217847550Z` 实际执行的 adapter、QA、私有 runner 和依赖原字节。对应 182 条实际断言及范围见 `qa/run_battle_fog_20260907/current_qa_summary.json`。GD/Python 存为 `.gd.txt/.py.txt`，不在归档内运行；`.gdignore` 与 `.gitattributes` 保证忽略和原始换行。整合收尾不得用新内容覆盖这两个已锁定文件。

复现需要完整且已导入、与 pins/controller contract 相符的专用 checkout，不是只把两个 GD 放进空项目。三项运行生产依赖为 `scripts/battle.gd`、`scripts/game_map.gd`、`scripts/run_state_value_codec.gd`；controller 还核对 `project.godot` 和两个公共 helper，公共 guard 依赖原有资源/脚本/`tools/contracts/reduced_effects` 等目录。原 2713 文件来源账本在 QA run/sources.json。本归档不包含完整工程或导入缓存。

先确认新的目标 `scratchpad/run_battle_fog_state/` 不存在；已存在时不要覆盖、合并、删旧结果或修改 pins，另选兼容的干净 checkout。表中其他文件也不能覆盖：已有且完全同字节的依赖可核对后复用，存在不同内容则换用兼容 checkout。建立新的被忽略目录，按原名还原：

| 归档文件 | 新 scratchpad 中的原路径 |
|---|---|
| fog_values.gd.txt | run_battle_fog_state/fog_values.gd |
| qa_driver.gd.txt | run_battle_fog_state/qa_driver.gd |
| README.preparation.md | run_battle_fog_state/README.md |
| pins.json、field_contract.json、qa_contract.json、remaining_coverage.md、.gdignore | run_battle_fog_state/ 下同名 |
| preparation_receipt.json | run_battle_fog_state/preparation_receipt.json（历史证据，不改） |
| frozen_runtime/run_battle_fog_qa.py.txt | run_battle_fog_qa.py |
| frozen_runtime/run_battle_fog_qa.contract.json | run_battle_fog_qa.contract.json |
| frozen_runtime/run_resume_adapters_qa.py.txt | run_resume_adapters_qa.py |
| frozen_runtime/unit_adapter_run_qa.py.txt | run_unit_state_adapter/run_qa.py |

这些路径关系必须保持：runner/helper 用 `__file__` 定位根目录。common 的原 contract 和 Unit/Inventory GD 并非本 Fog runner 的运行依赖；本轮只从其固定原文调用 read/no_links 等函数，不运行旧 common.main。lifecycle 只复用固定 run_process，由 Fog runner 在内存中选择脚本，不修改 helper 文件。

两份公共 helper 的文本副本分别对应 `tools/run_reduced_effects_qa.py`、`tools/run_polish_performance.py`。checkout 里的实际文件若已经匹配，就保留它们；若不匹配，换到相容专用 checkout，不覆盖当前工作的公共工具。runtime_freeze.json 记录原路径、字节数和 SHA；pins.json 与 runner contract 锁定受测文本，不能通过改摘要追认漂移。

准备后运行 `python scratchpad/run_battle_fog_qa.py` 只预检来源。由根任务在无其它 Godot 进程、共享 `.godot/redraw_rejection_source.lock` 可用时串行运行 `python scratchpad/run_battle_fog_qa.py --run`，引擎路径通过本机 `godot.local.txt`、GODOT_PATH 或 --godot 提供。不要直接启动 GD 绕过私有环境和生命周期保护。

原 runner 创建新 run/private_profile，并仅对子进程设置 APPDATA/LOCALAPPDATA/TEMP/TMP，生成 manifest 后传入 `BATTLE_FOG_QA_MANIFEST`。必需字段为 `run_id,run_dir,private_user,report,source_sha256`，五份 runtime 源在 pins 中；report 固定为新 run/report.json，private_user 必须位于新 run/private_profile 内。GD 要核对实际 user、manifest 和源前后摘要，外部再核对真实 PID、stdout 唯一 JSON、sidecar、24 强制标签、分组/非空结果、严格日志、完整来源/玩家保护及最终锁。

每次运行保留新收据，不能覆盖旧 run 或把准备期“未运行”回写成新结果。frozen_runtime/controller_preflight.json 是原 14 条合成拒绝记录，不能充当新引擎检查。归档只选择明确的 QA 报告/日志/收据和文本源码，不复制 private_profile、玩家配置、fixture、缓存、引擎或导出包。

该模块尚未实现赋值恢复、纹理/导航重建、Unit 可见性与引用图重整、physics/process 屏障、玩法 RNG 状态或磁盘接入；同一 PID 的树外真实对象检查不等于恢复后继续标准 30 波。
