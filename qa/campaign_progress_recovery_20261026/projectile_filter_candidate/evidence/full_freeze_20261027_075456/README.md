# b22 完整冻结及其首次冷导入原件归档

原批次：`20261027_075456_3e4a48ab`。准备已终态，随后自己的首次冷导入 `import_cold__20261027_080446_b18740e4` 已终态成功。实际 Godot PID **55952**，退出 **0**，用时 **77.656 秒**，`errors=[]`，`stopped_for=null`；原收据没有 `error` 字段。前后身份、命名 pins、生成身份、子进程终态、锁归属、空闲引擎通道和锁释放均为 true。

完整 source identity 为 `source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132`，7062 文件、2,402,358,281 字节；跟踪 manifest 为 26 脚本 + 1 native helper。相对 3365 完整冻结，文件集合、目录和 native 元数据相同，只替换 `scripts/run_visual_graph.gd`，增加 203 字节。`generation.identity` 与 preimport 元数据完全一致，expected identity 与其规定投影一致。这里比对现有完整清单，没有重哈希资源工程。

准备阶段没有旧 `.godot` 缓存种子。真正导入启动前、共享锁持有期间再次核实冷库存：目录集合为空，只存在新生成的 `extension_list.cfg` 登记，98 字节，SHA `a74ea4039f6c83259935b61609c96f1d7efa7b41f2cc8334e5735e7dbe0a50b0`。这不是声称 `.godot` 完全为空；登记不包含旧 imported/editor/shader 缓存。原 first-attempt 标记、紧邻启动的 cold_before、导入命令/日志/原始收据均保存，未把准备时库存替代实际导入前证据。

`raw/` 保存本轮准备/导入原件、12 份本轮冻结候选与准备工具、生成身份，以及无法按原字节引用 Git 的旧小脚本。`source_index.json` 覆盖准备 374 和导入 379 个命名 pin：367 个非 EXE 来源与本次 frozen inputs 逐字一致；旧重复对象按已提交归档或精确 commit/blob/SHA 引用。7 个 EXE 路径仅保留原收据的 SHA 元数据，未重读或复制。root_source 使用已提交旧归档精确引用。归档不复制资源、EXE/DLL、缓存文件、私有 profile、IPC 或业务 Slot/LC。路径、PID、nonce、命名来源 SHA 和导入资源路径属于可审计本机元数据。

本包只证明完整候选准备和自己的首次冷 editor import；导入没有运行自然玩法。此前组件 44 检查结果仍属独立组件原件，本包不把它扩大为战役流程。这里不授完整 61 阶段、原 19 故障、公开 Continue、Steam SDK、发行 EXE、人工或发布资格。后续 Gao/Daming 实跑必须单独保存自己的收据。
