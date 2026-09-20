# 2026-09-20 Windows Steam 发布记录

用户授权“上传到steam，然后同时发布公告”。生产源码固定为 `3d69b57dbff38e2ad0a7057187e811b2024e55b0`，App `5088120` / Windows Depot `5088121` / `default`。本批使用正式 Steam 构建器重新导出，未拿前批私有诊断 EXE 发布。

## 当前状态

上传成功并已提交 **Build 25416073 / Manifest 4282617870240600843**，服务器六文件名称、字节数、SHA1 全部与唯一候选一致。上线预览只改变 Windows Depot，预计从旧版更新下载 87.1 MB。

**尚未确认 default 上线，公告尚未公开。** 原生浏览器确认框的自动操作连续超时；随后权威 Builds 页仍为旧 Build `25320696`，已请用户完成页面确认和可能出现的手机验证。四语公告草稿 `698776157349217078` 已保存，重新加载后 16 个文本字段全部精确匹配。关联构建对话框仍显示旧 default，故未关联、未发布。后续只需完成上线、关联本批 Build、发布同一条公告并逐语言公开回读，不再重复上传或创建活动。最新状态以 [publication_receipt.json](publication_receipt.json) 为准。

## 已验证证据

| 范围 | 结果 |
| --- | --- |
| 原生 Steam 整合 QA | 185 项通过；纹理导入缓存复用已记录 |
| 正式六文件包检查 | 1132 项通过 |
| 源码 / 包内身份 | 各 10 项通过 |
| 实际 EXE 短测 | 八关、守城、清场、主菜单共 11 项通过，退出 0 / 错误 0 |
| 保护性核验 | 生产源码、真实玩家目录、候选 EXE 前后哈希一致，测试进程退出、锁释放 |
| 服务端 Manifest | 六个成员名称、字节数、SHA1 一致 |
| 公告草稿 | 简中、繁中、英语、日语共 16 字段回读一致 |

原生批 `.godot/steam_integration_qa/20260920_105032_89b2a16f`；候选 `.godot/steam_candidates/20260920_105442_c9bb1d61`；短测 `smoke_20260920_105937_87a42e4b`。复现命令沿 [项目发布指南](../../docs/STEAM_RELEASE_GUIDE.md)，随后用本目录 `smoke_verified_package.py` 与 `collect_evidence.py` 收集实际包证据。独立 profile 位于 `D:/CodexTemp/lsh_steam_qa_20260920`、`D:/CodexTemp/lsh_steam_candidate_20260920`、`D:/CodexTemp/lsh_steam_smoke_20260920`。

唯一 ZIP 339617547 字节，SHA256 `fb84635a905bd0ba1984b9fd7aadeec4b03996dc48dfdc2463d5ff34fcbbb4d0`；EXE 407497088 字节，SHA256 `8afaef779c095b279cf3c9f990455a181c7e8ea0cf88e0961ac7dae5b728337a`。上传副本位于 `D:/CodexTemp/steam_release_20260920/upload/LiangshanHeroes_Steam_candidate.zip`，字节一致。

## 收据与范围

- `candidate_delivery.json` 是上传前候选收据，历史 `uploaded=false` 不回写；最终外部状态看 `publication_receipt.json`。
- `server_manifest_verification.json` 保存服务器清单和上线预览范围。
- `announcement_notes.json` 保存四语原文；`announcement_draft_verification.json` 保存草稿回读结果。
- `evidence_copy_manifest.json` 逐文件记录已归档证据的原始哈希。未纳入玩家存档/目录清单、缓存、凭据或安装包。

回滚目标是本轮操作前实时核实的 Build `25320696` / Manifest `1900491985471109610`，并非旧文档中的 `25316671`。macos 分支 `0`、steam-integration 分支 `25179481` 未改。玩家“保存退出/继续本局”入口仍关闭；连环马内部恢复不作为玩家已开放功能宣传。实际 EXE 短测不等于八关自然通关、30 波完整守城、性能长跑、Steam 客户端更新试玩或真实成就持久写入；这些未在本轮追加验收。
