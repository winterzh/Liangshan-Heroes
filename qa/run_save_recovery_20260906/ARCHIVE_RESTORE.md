# R01 草稿归档的恢复映射

本目录中的 README/pins/运行收据是原 `scratchpad/run_save_recovery_v1/` 的历史原文。R01 仅检查候选并返回经复验的 payload，没有安装存档、清锁或恢复 Battle。不要从 QA 归档位置直接执行 Python 入口：其中按文件位置计算原 scratchpad 路径及共同锁。

复现时使用另一份新 checkout，确认 `scratchpad/run_save_store/` 与 `scratchpad/run_save_recovery_v1/` 都不存在且将被 Git 忽略；存在即停止，不删除或覆盖实验。先按 `tools/contracts/run_save_store_draft_20260906/README.md` 恢复 store 的精确原文。R01 会严格检查以下依赖：

| 依赖恢复路径 | raw SHA-256 |
| --- | --- |
| `scratchpad/run_save_store/run_save_store.gd` | `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3` |
| `scratchpad/run_save_store/run_qa.py` | `233dcd47bfe99af5419c38a2a135060860dbf46719683521c8e5610776b73fd2` |

然后新建 `scratchpad/run_save_recovery_v1/`，逐字节恢复下表及原 `pins.json`、`prepare.py`、`run_qa.py`、`process_runner_original.py`、`inspector_methods.gd.in` 和 `.gdignore`。恢复前按原 pins/归档清单核对来源摘要，恢复后再次核对；不复制旧 runs、project/profile 或实际 fixture。

| 归档文件 | 原恢复名称 |
| --- | --- |
| `store_original.gd.txt` | `store_original.gd` |
| `store_r01.gd.txt` | `store_r01.gd` |
| `qa_driver.gd.txt` | `qa_driver.gd` |

默认 `python scratchpad/run_save_recovery_v1/run_qa.py` 只验证精确来源。`prepare.py` 会重建若干草稿与 pins，只能在新 scratchpad 副本运行，不能指向本归档或历史 runs。需要真实引擎时才由根任务取得共同锁，以原 README 的 `--run --godot <实际非 console exe>` 入口串行运行；输出进入新的 UTC 目录。原入口创建小私有项目及独立用户环境，无需恢复历史缓存或玩家数据。

当前证据为 `runs/20260906T113756778956Z`：1,625 条断言中，1,232 条是目录快照打开/枚举、257 条是宽目录布置、136 条是其余来源/布置/行为检查。29 次记录的只读调用有前后快照，包含 18 inspect 和 11 read；另两次路径拒绝没有该快照记录，不能写成 31 次完整无副作用证明。边界与独立复核见 `result_summary.json` 和 `handoff.md`。
