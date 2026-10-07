# r1b 静态闭环与当前阻断

`run_daming_safe_retreat_v25_r1b.py` 是未执行新 sibling。原 e1a6 producer 和两份静态收据原位保留，并逐字节复制到 `archive_unexecuted_e1a6/`；原r2/v24o/旧v25 runner未修改。仅AST compile与源码检查，无CLI/base import/Godot。

len4疑点已闭环：base.preflight明确调用 `self.select_candidate`，V25Runner确实完整override该方法为 `len(rows)==6`，因此旧len4方法不会被调用。prepare使用 `self.candidate_rows.items()`构建完整expected_rows，4替换+2添加维持5041/5037、5014+88=5102；旧base的“四路径”仅遗留失败诊断文本，代码不按4截断候选。该文字作为原始base证据保留，不能被解读为v25资格。

修复一项前置检查缺口：新r1b会审查GD/scene中所有literal `res://tools/`引用都有明确冻结目标、scene绑定实际复制的GD、route模块名一致及文件名无冲突。51个mandatory report labels从实际runner/route源码核对；49个直接literal，mission/root两个由原固定for循环拼接，源码已核同一wrapper equality check，不凭猜测。

真实r2结果现已暴露旧 `_hold` 连接生命周期缺陷：首次HELD未发capture_rejected，one-shot连接残留；B第二次_hold重复connect报ERROR，C未运行。当前v25旧runner的_hold与旧admit完全同字节（LF method SHA见收据），所以历史static review不足以启动未来pipeline，不能声称其合格。

r1b新增明确前置阻断：没有实际ABC全部成功、锁释放、各native process terminal0和原日志/报告SHA闭合的successor证明，返回 `V25_KNOWN_HOLD_SIGNAL_RESIDUE`。未来新runner还必须采用该实际通过successor的同一_hold方法SHA与新审查。继承r2.execute仍会装旧admit工具；显式successor安装adapter当前尚未实现，因此即使提供successor证明也继续 `V25_ORIGINAL_ADMIT_SUCCESSOR_TOOL_INSTALL_ADAPTER_NOT_IMPLEMENTED`，不会只凭新收据去跑旧坏工具。

两项negative实现、active matrix与精确consumer报告API仍未闭合；保持其门禁，无skip。当前源码是可审实现与明确缺项，尚不可运行，也没有任何new native through、Campaign持久、Steam奖励、公开Continue或EXE资格。未来只在passed successor可独立回读、runner新sibling/adapter/negative API完成后，再写新的producer sibling和新pins。
