# 2026-09-30 GitHub 历史 QA 整理

本轮整理以 `dffaa3fc545f0a37429010143907f9e4c05a09b8` 为恢复源，保留 Git 历史、不改写提交、不删除 Release。原 main 为 `c3bedf5d`；本轮通过 stable 推送并提交面向 main 的 PR，未自动合并。

## 实际范围

扫描三个 QA 类别的 103 个批次和 17,526 个跟踪文本文件。保留最新批、完整验收批、旧格式 complete=true 批，以及批次标识在其他批次/文档/工具中出现的批。25 个未完成、无外部引用的 2026-09-11 世界恢复中间批纳入归档，只移除 558 个 `source_snapshot` 文件，共 29,089,555 字节（27.74 MiB）。所有原收据、日志及其失败状态原样保留，各批新增 `ARCHIVED.md` 指向恢复方法。收据中列出的历史快照清单仍描述原测试输入，不能解释为快照还在当前路径。

全部素材、截图、已引用证据、最终验收批、Steam/Android 包、GitHub Release 均保留。本次最终筛选没有移除截图。虽然历史 QA 约 2.99 GiB，但不能仅按大小或日期删除。

已删除远端合并分支 `codex/github-conventions`，原 tip `984358bd9b1e04a71559acd7f1b5d3baeedbbd6b` 是 main 的祖先，没有开放 PR，分支未保护。删除后远端仅保留 main 与 stable。

## 恢复与验证

完整清单见 [archive_manifest.json](archive_manifest.json)，含每个路径、Git blob、源提交、SHA-256、原 Git 字节数和 Windows 工作区字节数。部分源码存在 Git 换行转换：归档与 Git 恢复使用仓库规范字节；删除前另核对实际本地字节，未混用两种哈希。

本机 ZIP：`D:/AI项目/水浒/归档/水浒_GitHub中间QA源码_20260930.zip`，8,737,966 字节，SHA-256 `d04a4853fe33cc857bd381446a830b61155578f7356532139dcd404f0cd294c1`。ZIP 完整性和全部 558 份载荷 SHA 通过；ZIP 不入源码仓库。换机不依赖该本地 ZIP，可从仍在祖先历史中的源提交恢复：

```powershell
# 只校验 Git 中的所有归档字节，不写文件
python -B tools/restore_archived_qa.py
# 完整恢复到一个新的、工程外目录；不覆盖现有文件
python -B tools/restore_archived_qa.py --output D:/RecoveredQA/watermargin-20260930
```

浅克隆若尚无源提交，先补取历史：`git fetch origin dffaa3fc545f0a37429010143907f9e4c05a09b8`。恢复后在输出目录按原相对路径浏览，不必复制回工程。若需复跑历史实验，再显式恢复需要的快照；不要用旧源码覆盖当前生产代码。

558 份 Git blob 全量恢复校验通过；另实际写出一份并核对 SHA，6 类非法路径和已有目标覆盖均被拒绝。清理后 23,613 个其余跟踪文件、4,465,829,588 字节全部 SHA 一致。这个后验在本轮文档与归档标记写入前完成；没有游戏逻辑或素材变化，未运行玩法/性能测试。

普通提交只精简当前检出树，不等于 GitHub 历史仓库体积同步减少。同内容 Git 已去重，本轮不宣称远端释放 27.74 MiB。

## 证据

- [selection.json](selection.json)：103 批筛选原因、外部引用。
- [archive_manifest.json](archive_manifest.json)：恢复白名单和双格式哈希。
- [preflight.json](preflight.json)、[deletion_receipt.json](deletion_receipt.json)、[verification.json](verification.json)：归档、删除与保护后验。
- [protected_before.json.gz](protected_before.json.gz)：其余文件保护基线。
- [recovery_check.json](recovery_check.json)：实际恢复和拒绝覆盖验证。
- [branch_cleanup.json](branch_cleanup.json)：旧分支删除前后状态。
