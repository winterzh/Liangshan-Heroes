# Steam 后台配置与测试包 QA（2026-09-07）

本目录将离线候选证明与后台/实机事实分开记录。用户已授权后台配置发布、独立测试分支上传和双账号联调；当前后台仍未发布、本轮 ZIP 未上传，独立回读确认测试分支创建未成功，default 仍是 Build `25154403`。

## 已有证据

- [后台状态摘要](backend_state.json)：交互 UI 的保存后回读、失败信息和恢复条件；这是页面观察摘要，不是原始 HTTP 响应或成功发布收据。
- [candidate/](candidate/README.md)：源码 `df7ed189c1b04a501ca6c3d2fe1c45e781231c18` 的 fresh 原生 QA 176 项、实际 PCK 65 项、真实发行 EXE/DLL 检查，以及新增 8 个恢复模块的实际入包核对。源码前后摘要一致，锁及引擎进程已释放。
- [交付清单](candidate/delivery_manifest.json)：ZIP 为 219,811,886 字节，SHA-256 `768d1c15dedfd0cd19f89bb3528028171f2abf0115d3ca51a244e90e8f3b44d5`，仅 EXE、两个 DLL 和许可证。
- [归档验证](candidate/archive_verification.json)：原始收据/脱敏副本哈希和检查数量已复核。原始绝对路径收据、导出包、缓存及私有 profile 留在本地忽略目录，不提交 Git。
- [提交前检查](review_checks.json)：文档链接、60张PNG、大小/敏感内容及Git对象字节检查。归档沿用本项目`-text -whitespace`规则保留日志原文；初次暂存的换行转换在提交前已纠正，21份QA暂存对象逐字节一致，17份归档对象SHA全部复验通过。

后台操作事实和完整 30 行图标映射见 [后台交接](../../docs/STEAM_BACKEND_SETUP_20260907.md)。4 项 stats 已保存；30 项成就 API Name、英文和 10 项累计阈值已 DOM 回读。中文逐项保存并重新加载后，后台明确显示 English、Simplified Chinese 均已全部本地化，30 项中文完整表已回读；60 图标尚未上传。Workshop 文案、UGC 和分类已保存，保持 developer only。Cloud 保留原 1,000,000,000 字节、无 AutoCloud 路径和动态同步原值，仅把文件数由 20 保存为 1000；独立重新导航确认 `ufsFiles=1000`、`ufsQuota=1000000000`。这些保存状态还没有配置发布或真实客户端读取收据，图标补齐前不发布缺图版本。

## 尚缺的验收

| 项目 | 当前状态与补证条件 |
| --- | --- |
| 图标上传 | 首次 `filechooser.setFiles` 返回 `Not allowed`。CUA 官方排查说明指向扩展文件 URL 访问权限，需用户在 Edge 的 ChatGPT 扩展 Details 中开启 `Allow access to file URLs` 后恢复正常 API 上传；否则需正常窗口手工选择，再逐项回读 60 张预览。该错误不是内容安全风险证据 |
| 测试分支 | 新建分支 prompt 的 `getJsDialog.accept` 超时；随后独立回读仅有 default/macos，确认 `steam-integration` 创建未成功。需正常创建并回读 |
| 测试组/第二账号 | testers 设置需要 Steam 组；第二可用测试账号安排尚未提供，双账号用例未执行 |
| 后台发布 | 未执行；需最终字段/图标回读及正常发布收据 |
| ZIP 上传 | 标准上传页已打开，Windows Depot `5088121` 待选择 ZIP；页面提示有未发布 depot 配置，需补齐图标并发布完整配置后再上传，取得 BuildID、Manifest、服务器文件清单/哈希 |
| 测试分支激活 | 未执行；需目标分支与 BuildID 的服务端回读，不能代替 default 发布 |
| Steam 实机 | 未执行；需初始化、Overlay、解锁、统计、持久化、旧档迁移与账号切换证据 |
| Workshop 双账号 | 未执行；需两类作品 ID、发布/订阅/下载/实际战斗、同 ID 更新及异常用例证据 |

自动化拒绝没有被绕过；当前缺的是工具可完成的正常交互与测试条件，不是再次等待同一发布授权。后续证据必须保留实际结果和失败原文，不能将本轮 176/65 项离线检查改写为 Steam 服务器或双账号验收通过。
