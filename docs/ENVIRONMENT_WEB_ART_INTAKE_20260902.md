# 环境网页美术接入门禁

2026-09-06核查：本checkout未带原批次清单、自检、九份提示词与旧路由报告，旧完整接入验收当前不能复跑。默认路径已迁到仓库内 `tools/contracts/environment/legacy/`，原SHA和来源门槛保留。缺原件的自测退出2、0项执行，不计通过。当前独立路由及来源缺口审计见 [跨电脑说明](ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md)；以下为历史实现与结果。

本批只实现来源验收和原子导入工具，没有生成或接入任何新环境图片，也没有运行 Godot。

依据是冻结的 `environment_batch_manifest.json` schema v2，SHA-256：

`162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf`

同目录静态复核 `static_self_check.json` 的 SHA-256 为 `f8e562d4aeebbd64519acf83ecfb54385742b3d7f89dd72684149a953386aa77`，502/502 PASS，0 个 legacy `code_targets`。导入工具同时校验静态复核对应的是这一份 manifest、九份提示词和 64 个逐格路由。

工具验证九份精确提示词 SHA、稳定的 ChatGPT 会话地址、源 PNG SHA、采用或淘汰决定和人工复核记录。五张地表使用 2048 RGBA 全不透明、3×3 wrap、对边 16 像素和梯度 P95 门禁；四张图集使用 2048 RGBA、外圈 24 像素、三条横纵 32 像素精确透明带和 16 格非空门禁。

图集行列按 1 到 4。冻结清单中的 64 个 `output_id/output_path/level_scope/route_scope/reuse_policy/route`，以及每格状态，会被逐项核对，映射不能改成全局 `town_house`、`zhu_hall`、`tree` 或其他跨关别名。黄泥冈车辆、梁山建筑、城镇物件和共享覆盖层各自保留逐格路径及关卡范围。

生产映射已绑定 `scripts/campaign_environment_art.gd`、静态合同、报告和 15 个消费者文件的 SHA。当前静态报告是 785/785 PASS，对 64 个图集格逐项记录 resolver、route key、state、输出路径、level scope、消费者符号和精确源码行；五张地表也有独立的材质消费者、shader 开关和 fallback 证据。

当前报告 SHA-256 为 `16dda6894bfc1bb54584ac90180de2227d6df6a34174192a6638fd8068405f43`，生产映射模板 SHA-256 为 `af1204a50a865096be47917440a36c67d9290f295fd5ee1ac2f8e000b1d441f1`。

`cuiyun_tower` 的 default 与 signal 不再共用一个 route-key 结论。default 由大名府场景默认标记证明，signal 独立绑定 `scripts/levels/level8_dongchangfu.gd:276` 的 `set_story_object_state("cuiyun_tower","signal")`。工具核对每个证据的文件 SHA、行号和当前行内容，报告后任一消费者文件改动都会 fail closed。

映射模板因此已有 69 个明确目标和 69 组消费者证据，均标记 `integration_ready: true`。这只是接线门禁：当前 69 张目标 PNG 仍全部缺失，尚未实际绘制或导入任何新网页素材。该 PASS 也不证明未来网页源图的美术质量、Godot 实机显示、性能或真人玩法已验收。任何采用图的所需输出有空目标、空关卡范围、空 resolver、消费者证据不匹配或文件 SHA 漂移时，`--commit` 都会拒绝。

本地变换边界固定为：地表原 PNG 按字节复制；图集只从固定 512×512 格子取完整矩形，可等比缩放并放到透明画布。工具没有按连通组件裁切、镜像、补画、方向合成、alpha masking、异物像素清除或烘焙阴影修补代码。

提交事务先为全部目标建立 SHA checkpoint，再在临时目录 staging，最后逐文件原子替换。替换中断会恢复原 SHA、删除新增文件和本次新建的空目录。来源图、提示词和 manifest 证据归档在 `qa/environment_art_intake/`，与运行时 PNG 分开。

隔离自测已经覆盖六项：

1. dry-run 不创建生产目录，消费者文件 SHA 漂移时立即拒绝。
2. 地表按字节复制，图集按固定整格生成 16 个输出。
3. 透明分隔带出现一个非零 alpha 像素即拒绝采用。
4. 未确认接线路由时 dry-run 报缺口、commit 拒绝；翠云楼 signal 缺少 276 行独立证据时也拒绝。
5. 目标路径重复或偏离 schema v2 时拒绝。
6. 模拟第三次原子替换中断后，所有既有目标 SHA 精确恢复，已安装的新目标被删除。

这份 PASS 只证明工具自身的输入、像素和事务门禁。它不证明将来网页生成图片的美术质量，不证明 Godot 集成、1280×720 近景效果、性能或真人试玩。
