# 2026-10-20 冗余整理与历史恢复

本轮完成两项整理：六份入口文档由 **16,405行缩至191行**；按逐文件清单移除 **1,458个重复导入缓存 / 835,962,369字节（约797 MiB）**。D盘清理前后空闲增加839,913,472字节（约801 MiB），同时有文档压缩和并行任务影响，不能把磁盘变化等同缓存逻辑字节。C盘无删除目标，其空闲变化不计清理成果。

## 保护与验证

- 六份旧文档先完整ZIP归档，所有成员解压读回与原始字节及SHA-256一致，再精简当前入口。完整验收条件、原著要求及未完成范围保留，专题文档/原图/原始证据不删除。
- 缓存仅限四个旧私有工程的 `project/.godot/imported`；本次按**文件内容**比较，识别出不同文件名但字节相同的副本。每个目标都有不参与删除的相同SHA保留文件；764个私有缓存继续保留。
- 删除前校验绝对路径、限定目录、无reparse祖先、单硬链接、大小/SHA和独占打开；检查Godot空闲，PowerShell逐文件 `Remove-Item -LiteralPath`，无递归目录删除。
- 主缓存、保留副本及原107个未跟踪文件共4,659个保护文件前后SHA一致；未跟踪清单不变。运行代码、生产资源、原著依据、原图/提示/父图、发布包、玩家存档与Git对象库不在删除清单。
- 未启动游戏、运行Godot功能验收或再次发布Steam。缓存与文档整理不改变任何候选的采用资格。已发布版本仍是Build26048429。

## 历史文档归档

本机ZIP：`D:\AI项目\水浒\归档\水浒_入口文档历史_20261020.zip`；971,181字节。

SHA-256：`df4fee89b36c52d07b072ebef26329f1f5503f3662c22243edeb074410978fb9`。

下表链接指向整理前的不可变Git提交 `391f2cc686703d7c38780c5a116d33ba2376d906`；换机或仅在GitHub浏览时仍能阅读完整旧文档，不依赖本机ZIP。

| 原文件及完整历史入口 | 原行数 | 原字节SHA-256 |
| --- | --- | --- |
| [README.md](https://github.com/winterzh/Liangshan-Heroes/blob/391f2cc686703d7c38780c5a116d33ba2376d906/README.md) | 400 | `ea89bb2287870c58079817a7db36e480934085e2ef864ef24cc0fa6ca5ac3c6c` |
| [docs/PROJECT_STATUS.md](https://github.com/winterzh/Liangshan-Heroes/blob/391f2cc686703d7c38780c5a116d33ba2376d906/docs/PROJECT_STATUS.md) | 1794 | `e5892707eac070a2b8ffdc98dd64c4c291bc58074edb164e55f27e3504c89dbb` |
| [docs/DEVELOPMENT_PLAN.md](https://github.com/winterzh/Liangshan-Heroes/blob/391f2cc686703d7c38780c5a116d33ba2376d906/docs/DEVELOPMENT_PLAN.md) | 1489 | `57b04ea61876eefb785331ba716f05f9036ef07a687d7f3fe5c77cdff8d3f926` |
| [docs/WORKLOG.md](https://github.com/winterzh/Liangshan-Heroes/blob/391f2cc686703d7c38780c5a116d33ba2376d906/docs/WORKLOG.md) | 4850 | `fdbfab87d52638f35a23682ffe08643722bb798afd9adb704582de97da858085` |
| [docs/SOURCE_SETUP.md](https://github.com/winterzh/Liangshan-Heroes/blob/391f2cc686703d7c38780c5a116d33ba2376d906/docs/SOURCE_SETUP.md) | 4363 | `0f7c9a79a1da18f008e652567094e4144ab8ed248aaa04b98bcf9e9e63b800f7` |
| [docs/DIRECTORY_INDEX.md](https://github.com/winterzh/Liangshan-Heroes/blob/391f2cc686703d7c38780c5a116d33ba2376d906/docs/DIRECTORY_INDEX.md) | 3509 | `60051f05a326f20c8d446aec5bd0fd74ca9b64371b0124588473656b8ebe066f` |

恢复旧文档时，先把ZIP解压到新的空目录，核对 `document_archive.json` 中每个文件的SHA；只从中查阅或挑选需要的内容，不覆盖当前入口。也可从上表指定Git提交读取同一路径；原六份文档全部保留，不靠摘要重建历史。Git抓取可能按配置归一化行尾；需要严格逐字节恢复时，以ZIP与原SHA为准。

## 缓存恢复

`plan.json.gz` 的每条目标包含原位置、大小、SHA与 `retained_copy`。需要恢复某个旧测试工程时，先确认目标缺失、保留文件SHA匹配，再复制到原位置，保留原文件名；不要覆盖现有差异文件。也可按该批固定Godot版本重新导入。保留副本是缓存，后续清理前须继续维护其映射，不能误删后再称可直接复制恢复。

## 收据

- `document_archive.json`：六份原文与新文档哈希、行数、ZIP及Git历史定位。
- `inventory.json`、`plan.json.gz`：限定缓存目录与逐文件删除/保留映射。
- `deleted.jsonl.gz`：实际删除流水；`protected_before.json.gz`：4,659个保护文件的前验哈希。
- `verification.json`：删除与文档归档后验、未跟踪清单、磁盘变化及本轮资格边界。
- `execution_sources/`：本轮实际脚本副本；工程外执行收据在 `D:/CodexEvidence/shuihu/storage_cleanup_20261020`。

ZIP与原始发布二进制不上传Git，仓库保留恢复索引、哈希与执行证据。当前文档在README、PROJECT_STATUS、DEVELOPMENT_PLAN、SOURCE_SETUP、WORKLOG和DIRECTORY_INDEX各自维护一个入口，后续不要再把同一段批次日志复制到所有文件。
