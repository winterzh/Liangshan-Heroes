# RunSaveStore 磁盘草稿封存（2026-09-06）

这里保存实测原文，未接入生产。`.gd` 以 `.gd.txt` 封存，目录另有 `.gdignore`；不要直接从本归档目录运行 `run_qa.py`。该 runner 用自身位置定位根工程和共同锁，必须恢复至一个新 checkout 下、原本不存在且被 Git 忽略的 `scratchpad/run_save_store/`。

`SOURCE_PINS.json` 给出原文件名、封存文件名、字节长度和 raw SHA-256。`run_qa.py` 与两份 QA GD、store 都是实测原文，没有为归档重写路径、PIN、进程或夹具行为。`README.original.md` / `QA_USAGE.original.md` 是原草稿说明的精确副本，其中相对 `runs/` 链接保留原语境；封存证据实际位于根工程 `qa/run_save_store_20260906/runs/`。新的归档说明不更改原收据内容或其历史本机路径字符串。

当前有限结果为 49 个案例、54 次进程阶段，其中 50 次正常 exit=0，4 次到达精确检查点后由持有句柄终止的 exit=1；1,233 次断言来自 50 份正常报告。旧失败不计入此数。源码、故障说明、结果边界见根目录 `docs/RUN_SAVE_FOUNDATION_20260906.md`，原始失败及空摘要修复见 QA 归档。没有真实 Battle codec、场景恢复、继续按钮、自动残留恢复、同时读写或断电保证。

## 恢复原名以复现

在一个新的源码 checkout 根目录执行下列 Python。必须已有根 `.gitignore` 的 `scratchpad/` 规则；使用 `git check-ignore --no-index scratchpad/run_save_store/run_qa.py` 先确认忽略。若 `scratchpad/run_save_store/` 已存在，立即停止，使用另一份新 checkout；不要删除、改名或覆盖原实验目录。嵌套 `.gitattributes` 保证封存 raw bytes 不被 Git 自动换行；摘要不符时停止，不能按本机换行重新锁定 PIN。

```python
from pathlib import Path
import hashlib, json

root = Path.cwd().resolve()
archive = root / "tools/contracts/run_save_store_draft_20260906"
target = root / "scratchpad/run_save_store"
if not (root / "project.godot").is_file() or target.exists():
    raise RuntimeError("Need a source checkout and a new absent scratchpad/run_save_store")
pins = json.loads((archive / "SOURCE_PINS.json").read_text(encoding="utf-8"))
payloads = []
for row in pins["restore_files"]:
    raw = (archive / row["archived_name"]).read_bytes()
    if len(raw) != row["bytes"] or hashlib.sha256(raw).hexdigest() != row["sha256"]:
        raise RuntimeError("Archived raw bytes differ: " + row["archived_name"])
    payloads.append((row["original_name"], raw))
target.mkdir(parents=True, exist_ok=False)
for name, raw in payloads:
    with (target / name).open("xb") as output:
        output.write(raw)
```

此操作只恢复 store、driver、faults、runner、静态检查器、原说明和 `.gdignore`，不恢复历史 `runs/`、fixture、profile、缓存或旧锁。恢复后原名为 `run_save_store.gd`、`qa_driver.gd`、`qa_faults.gd`、`run_qa.py` 等，SHA 与实测准备收据一致。

```powershell
python -X utf8 scratchpad/run_save_store/run_qa.py --suite all
python -X utf8 scratchpad/run_save_store/run_qa.py --prepare --case roundtrip
```

第一条仅预检/列案例；第二条创建新的极小私有项目，均不启动引擎。原测试依赖 Windows、Godot 4.6.3，实际引擎 SHA 见运行收据。先确认共享 `.godot/redraw_rejection_source.lock` 不被其它任务占用，且没有其它 Godot，再传已核实的实际非 `_console.exe` 引擎（冻结 runner 不自动替换 console 路径）：

```powershell
python -X utf8 scratchpad/run_save_store/run_qa.py --run --case roundtrip --godot $godot
```

完整重跑可用 `--run --suite all`；需另外安排独占时段。当前冻结 runner 要求共同锁父目录 `.godot/` 已存在，新 checkout 若尚无它，应只创建该本地被忽略目录，无需先启动整个游戏。每次 `--run` 另建新 `runs/<UTC>/`，不复用 `--prepare` 的夹具。`fixtures/<case>` 位于此极小私有项目中，实际 store 仍拒绝一般玩家路径。不要以改 FIXTURE_ROOT 的方式直接开放生产保存。
