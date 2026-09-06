# 冻结忽略目录复核与第二次计划拒绝

本轮只改本 scratchpad 工具，运行静态/stub 和只读 Git 检查/plan；没有 materialize、Godot 或生产修改。

Godot 4.6 [官方文档](https://docs.godotengine.org/en/4.6/tutorials/best_practices/project_organization.html#ignoring-specific-folders)说明 `.gdignore` 忽略所在目录，内容不支持 patterns；[引擎 `_should_skip_directory`](https://github.com/godotengine/godot/blob/4.6/editor/file_system/editor_file_system.cpp#L3208-L3227)直接检查标记存在并跳过该目录，因此后代也不进入递归扫描。原始生成图/淘汰来源不应强求历史 importer 产物。

只读核对固定提交 `4baafc11af55b0e46a57a48e54df181b8c1917a2`：运行复制白名单内只有 `assets/campaign/source/.gdignore`，Git blob `9e8e5ec4e9a53531c71fdc65feb2f05b2f7b929d`。其它标记属于已排除的 qa 和 tools/contracts。冻结 scripts/scenes/resources/data/addons/content/scenarios/shaders/project.godot 对 `assets/campaign/source` 没有字面引用；新 plan 另审项目/GDScript/scene/resource/shader 字面前缀。这不是任意动态路径构造的通用证明。

该目录全部文件仍保留在 source_files，按固定 blob 复制；ignored_source_files_retained 和 ignored_imports 记录路径、blob、控制 marker 和不复制 importer 的理由。仅按目录分量匹配祖先，`source_extra` 不能误入，嵌套不能反向解除祖先忽略，跨到运行资源的 remap 拒绝。未冻结的新 marker 不会成为跳过缓存的依据。

标记内容本身只有 CRLF/LF 差异，经明确确认只对该文本使用 CRLF→LF；冻结 Git raw/blob、live raw/LF 摘要全部保留。其它素材字节、source_md5、缓存摘要规则未改。61 项静态/stub 包含上述边界、删除/内容/冻结 blob 漂移、运行引用、缺缓存反例；不声称真实引擎已验证。

重跑真实只读 plan 已越过第一次 bailong 来源缓存问题，随后在普通 `icon.svg` 拒绝：冻结 224 字节、live 225 字节。LF 后文本相同，但现有 importer 的 source_md5 明确对应 live CRLF：`7ec76db75886a437fd72296c84692de6`；冻结源 MD5 是 `9a83e77a52d8b8c234eceb45ca76d71a`。此处没有套用 marker 文本例外，不能声称这份缓存来自冻结 raw 源。

第二次拒绝时尚未生成有效 plan SHA、完整缓存复制总量或本轮派生类缓存计划；第二失败收据见 `plan_failure_icon_svg_receipt.json`，第一次收据保留。需根任务决定普通 SVG 缓存来源的下一处理方式；没有自动重新导入、跳过根图标或松绑哈希。

后续根任务已明确选择严格私有重新导入。当前计划完整通过：不匹配者标 needs_reimport 并不复制旧缓存，冻结源全部保留；仅 icon.svg 一项，普通资源哈希没有宣称匹配。最终 plan SHA `cb051680f879c5cbf47fd44536c127eddaa1e393ea799afff2d9692c28537ed5`，详情见 plan_review_receipt.json。65 项静态/stub 已验证 pending 导入、缺少新缓存 pins 或新 source_md5 不对时不能进入诊断；当前没有执行复制或引擎。
