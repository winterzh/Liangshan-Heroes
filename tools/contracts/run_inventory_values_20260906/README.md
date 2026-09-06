# Inventory 局部值测试原文

这里封存实际 run 20260906T154102953512Z 使用的适配器、QA 和 controller/helper 原字节。GD 以 .gd.txt 保存并设 .gdignore，Python 以 .py.txt 保存；归档本身不运行。pins.json 仍是原准备期收据，当前结果见 qa/run_inventory_values_20260906/current_qa_summary.json。

复现需要完整、已导入的 Godot 项目和原三项生产依赖：scripts/hero_inventory.gd、scripts/defs.gd、scripts/run_state_value_codec.gd。它们的 bytes/raw/LF SHA 在 pins.json 中；本归档不复制整个工程。完整当时源码路径账本在 QA run/sources.json。来源漂移应明确拒绝，不能通过修改原 pins 或旧收据凑通过。

在专用兼容 checkout 中，先确认下列还原目标全部不存在；已有目标时不要覆盖、合并或删除，另选干净 checkout。把 inventory_values.gd.txt、qa_driver.gd.txt 去掉 .txt 后放到新的、被忽略的 scratchpad/run_inventory_state/；同时复制本目录 pins.json、preparation_receipt.json、.gdignore，并将 README.preparation.md **还原为 README.md**。原 README 是受测 support pin，不要用本说明替代它。

把 frozen_controller/run_resume_adapters_qa.py.txt 还原到 scratchpad/run_resume_adapters_qa.py，配套 contract.json 还原到 scratchpad/run_resume_adapters_qa.contract.json；将 unit_adapter_run_qa.py.txt 还原到 scratchpad/run_unit_state_adapter/run_qa.py。这三份文件必须保留原路径关系，因为它们用 __file__ 定位项目。controller_freeze.json 记录所有原路径/字节数/摘要。

两个公共 helper 的 .py.txt 是实测原文证据，恢复前应先检查 checkout 中 tools/run_reduced_effects_qa.py、tools/run_polish_performance.py 是否已经逐字匹配；若不同，选择相容的专用 checkout，不覆盖当前工作的公共工具。前者还要求完整工程中原有 tools/contracts/reduced_effects 等目录和 QA 固定入口；仅这些文本文件不足以组成独立项目。lifecycle 只借用 run_process 函数；选择 inventory 时不读取另一个 unit-references suite 的 pins/GD，contract 中仍保留当时两个 suite 的历史身份。

完成还原并核对所有 pins 后，运行 `python scratchpad/run_resume_adapters_qa.py --suite inventory` 只做预检。由根任务在没有其他 Godot 进程、共用锁允许时串行加 `--run` 执行；引擎使用本机配置的实际非 console 包装 exe。原 controller 管理新私有 APPDATA/LOCALAPPDATA/TEMP/TMP、实际进程句柄、源/玩家保护和严格日志检查。不创建新的 runner，也不要直接绕过它运行 GD。

每次复现创建新的 run 与私有用户目录，不能覆盖旧证据。独立报告必须核对实际 PID、user 路径、五源摘要、非空检查、stdout、退出和锁。旧 QA run 中的绝对路径只说明当时环境，不是应创建的玩家目录。

该模块仅 capture/validate；没有赋值恢复、owner/效果/来源关系、有效物品定义、全局 UID 分配或 Battle/磁盘接入。完整续玩验收保持原要求。

归档 .gitattributes 用 -text 保存原始 CRLF/LF；归档 .gdignore 使用原一字节 LF。整合时不要让收尾脚本再生成内容不同的同名文件。
