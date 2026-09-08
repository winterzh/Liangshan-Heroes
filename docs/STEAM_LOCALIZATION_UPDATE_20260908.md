# 2026-09-08 四语与图鉴校订 Steam 更新

用户在四语、原著文本和 UI 校订完成后要求“更新”。本批准备 Windows Steam 更新，具体上传、分支上线和客户端状态以本文件后续收据为准；准备中的包不得称为已上线。

内容起点为 stable `7c9b66dc43352d700b680e6202cdfb881f611a2e`，包含四语、108 人校订生平、77 条其他文本修订及布局修复。另补据守编辑器表头“攻击间隔(秒)”术语，三语词库重建后仍为 4,358 个显示词条、缺失及格式错误 0。

旧 Windows Steam 候选复制白名单未包含本地化资源。现明确纳入运行 catalog、Noto CJK 字体与导入描述、OFL；Steam 导出预设显式包含 catalog 和 OFL。Steam 同包探针新增四语注册/实际译文/目录排除、词库哈希及字体区域字形，以及 108 篇生平和回目检查。源翻译分片及原文缓存不随 Steam 候选复制。

`tools/run_steam_integration_qa.py --run --native --visual --profile-root <新的短绝对根>` 生成当前源码 QA；随后 `tools/build_steam_candidate.py --run --qa-run <本轮 QA 目录> --profile-root <短绝对根>` 导出并核对实际 Steam EXE、release DLL、资源及身份。不能把已有 EXE 传给 `run_localization_package_qa.py --pack`，该参数是输出路径且使用 Windows Desktop 预设，会覆盖目标。

原始材料位于 `.godot/steam_integration_qa/`、`.godot/steam_candidates/` 和独立 D 盘测试 profile。交付记录归档于 `qa/steam_localization_update_20260908/`，不包含玩家存档、Steam 缓存、EXE、DLL 或 ZIP。自动验证禁用真实 Steam；双账号、实际客户端下载、完整通关及长时性能另行验收。
