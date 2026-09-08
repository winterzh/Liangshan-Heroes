# 2026-09-08 四语与图鉴校订 Steam 更新

## 16:39 公告与商店语言表发布完成

关联本次 default Build25182453 的四语[小型更新/补丁说明708907988310559012](https://store.steampowered.com/news/app/5088120/view/708907988310559012)已于北京时间 2026-09-08 16:39 公开发布。四语标题、副标题、每语 14 个正文文本片段及各 4 张原图完成公开回读；商店语言表 revision 4→5 已公开，简中、英、日、繁中仅界面勾选，音频与字幕未标注。本批未修改运行代码/EXE、未重跑 Godot。封面使用英文槽的无文字水寨图，其他三语按官方机制回退；各平台封面露出、客户端下载与玩家推送不计作已验收。详情及原始证据见[公告发布记录](STEAM_LOCALIZATION_ANNOUNCEMENT_20260908.md)和[公告 QA](../qa/steam_localization_announcement_20260908/README.md)。

## 正式版构建与验证记录

用户在四语、原著文本和 UI 校订完成后要求“更新”，随后明确确认发布到公开正式版 default，并完成 Steam 手机验证器确认。Windows Steam 更新包 Build **25182453** / Manifest **4066863387208539897** 已在 **default 正式版生效**，服务器四文件大小/SHA1 与成品逐项一致。canonical 分支显示 default 从 25164373 切换为 25182453，发布历史记录匹配；steam-integration 仍为 25179481。后台预估正式版增量下载 25.2 MB，真实客户端下载尚未验收。上传时选择“无”为此前历史步骤，随后单独完成正式版激活；服务端收据见本批 QA 的 `steam_server_receipt.json`。

内容起点为 stable `7c9b66dc43352d700b680e6202cdfb881f611a2e`，包含四语、108 人校订生平、77 条其他文本修订及布局修复。另补据守编辑器表头“攻击间隔(秒)”术语，三语词库重建后仍为 4,358 个显示词条、缺失及格式错误 0。

旧 Windows Steam 候选复制白名单未包含本地化资源。现明确纳入运行 catalog、Noto CJK 字体与导入描述、OFL；Steam 导出预设显式包含 catalog 和 OFL。Steam 同包探针新增四语注册/实际译文/目录排除、词库哈希及字体区域字形，以及 108 篇生平和回目检查。源翻译分片及原文缓存不随 Steam 候选复制。

`tools/run_steam_integration_qa.py --run --native --visual --profile-root <新的短绝对根>` 生成当前源码 QA；随后 `tools/build_steam_candidate.py --run --qa-run <本轮 QA 目录> --profile-root <短绝对根>` 导出并核对实际 Steam EXE、release DLL、资源及身份。不能把已有 EXE 传给 `run_localization_package_qa.py --pack`，该参数是输出路径且使用 Windows Desktop 预设，会覆盖目标。

原始材料位于 `.godot/steam_integration_qa/`、`.godot/steam_candidates/` 和独立 D 盘测试 profile。交付记录归档于 `qa/steam_localization_update_20260908/`，不包含玩家存档、Steam 缓存、EXE、DLL 或 ZIP。自动验证禁用真实 Steam；双账号、实际客户端下载、完整通关及长时性能另行验收。

运行内容及原生 QA 冻结于 `697b3132e7ef9e981c587b7395f2d10cf81e5d74`；构建工具冻结于 `398a90f50c11bac96026100e3a94f4873591b864`，后者仅为外部包探针的 bool 类型声明修复，运行资源逐文件哈希未变。成功 QA `20260908_155519_1deaacd4` 为 182 项通过，六张界面截图逐张复看。失败候选 `20260908_155834_9ef41adb` 因探针类型推断报错结束，未生成可交付 ZIP，未上传；由下述成功批次替代。

成功候选为 `20260908_160006_4ad9cdeb`：825 项同包检查通过，四语各 4,361 个词库键实际译文零不一致，108 篇生平与回目结构完整；源码/同包身份各 10 项通过，实际发行 EXE 600 帧启动及两个 release DLL 路径/哈希通过。同一 EXE 的 `smoke_20260908_160254` 串行 11 例短测（八关、据守、末波清理、主菜单）通过，据守 9 项及清理 12 项内嵌合同均为 ALL=true，源码、玩家文件及 EXE 未变、进程退出、锁释放。

ZIP 为 238,034,173 字节，SHA256 `6f1758ebc59624f63b1d8bb656c42e1d416de331cc64039a973154605f3bb757`；EXE 为 305,670,840 字节，SHA256 `73fa772539afbfe2a20c1dcd6ad2ca55c9ea8eb3774bc9b00b8be3bdb5edb2a5`。四成员交付哈希另见 `candidate_delivery.json`。同包结构和字形检查不替代原著逐条核对或所有页面视觉验收，相关依据沿用 [文本校订 QA](../qa/text_review_20260908/README.md)。
