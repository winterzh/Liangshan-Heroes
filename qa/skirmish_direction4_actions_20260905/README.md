# 驻守战四种官军四向动作 QA

本目录记录 `guan_dao`、`guan_gong`、`guan_jingqi`、`guan_qi` 的四向
`walk` / `attack` / `death` 生产接入验收。

## 自动合同

```powershell
$godotCheck = 'C:\path\to\Godot_v4.6.3-stable_win64_console.exe'
& $godotCheck --headless --path . `
  --script res://tools/skirmish_top4_direction4_actions_test.gd
```

输出 `action_contract.json`。验收不接受 `Art.unit_anim_frames` 的旧无方向动作回退，
也不接受同向 `idle` 冒充动作。要求每个单元、方向和状态底层来源精确为：

`assets/anim/<unit>_<state>_<direction>.png`

帧数下限为 `walk >= 2`、`attack >= 3`、`death >= 4`，且至少一帧须与同向
`idle` 像素不同。素材未落盘时测试必须明确失败并记录实际回退来源。

## 图形化矩阵

```powershell
$godotCheck = 'C:\path\to\Godot_v4.6.3-stable_win64_console.exe'
& $godotCheck --path . `
  --script res://tools/skirmish_top4_direction4_actions_visual_test.gd
```

输出 `runtime_visual/action_matrix_1920x1080.png` 和 `runtime_visual/report.json`。矩阵共 48 格；
精确命中才绘制实际帧，缺图、旧动作回退和 `idle` 回退统一显示为红色诊断格。

## 候选切片、组装与晋升管线

专用工具为 `tools/skirmish_direction4_action_pipeline.py`。管线配置明确使用 schema v2；
锚点来源兼容当前人工复核文件的 schema v1 对象框和模板 schema v2 数组框，但两者都必须
逐格提供完整 `manual_source_rect`。只接受四张原生 RGBA、单帧、至少 1024×1024 的方形 4×4 网页清理附件，
不再要求整张图存在贯穿横向或竖向的透明缝。四张分别对应 `walk_step`、`attack_strike`、
`death_fall`、`death_down`。行顺序固定为 `guan_dao / guan_gong / guan_jingqi /
guan_qi`，列顺序固定为 `SE / SW / NE / NW`。

每一格必须在 `source/semantic_anchors.json` 中手工记录：

- 绝对半开矩形 `manual_source_rect: [x0, y0, x1, y1]`，或当前复核文件中的等价
  `{x0, y0, x1, y1}` 对象；
- 绝对语义锚点 `source_x_px / source_y_px`；前三种姿势使用 `foot_or_hoof`，
  倒地终态使用 `lowest_contact`；
- 人工测量说明 `review_note`。

同一张图的 16 个框不能重叠，且必须维持四列、四行语义顺序。每个 `alpha>0` 源像素
必须恰好属于一个框，不能漏在框外或多重归属。每框四边须有配置的纯透明余量；真实批次
当前使用 3 像素硬门，并在 manifest 逐格记录左、上、右、下及最小实测余量。框内可有
多个连通组件，以容纳武器、骑手和战马，但所有组件必须在配置距离内合并为唯一主体组。
锚点必须落在保留矩形内且附近存在 `alpha>0` 证据，不允许 alpha-bounds 底部回退。

本地处理严格限定为：从手工框内取完整 `alpha>0` bbox，保留 bbox 内全部 RGBA。每个兵种
先用四向“现有 idle bbox 高度 / 新 walk 源 bbox 高度”的中位数确定参考世界尺度；只有当
16 个新姿势中的任一实际 bbox 装不进留 4px 边距的 248×248 区域时，才对该兵种统一限缩。
随后先把语义锚点放到 `(128,210)`，若矩形越界则逐帧做最小 canvas-fit 平移，而不是继续
缩小；walk/attack 单轴平移不得超过 20px，death 可方向性平移以保留完整倒地 bbox。
最后只做 LANCZOS 等比缩放和无蒙版 RGBA 矩形粘贴。不会镜像、旋转、阈值裁边、蒙版、
清像素、补画或重绘。manifest 逐帧记录 `reference_scale / fit_limited_scale /
fit_shift_xy_px / placed_anchor_xy_px`，并记录 16 组 idle 与 walk 的 alpha bbox 比；高度比
硬门为 0.85–1.15，首选区间为 0.90–1.10。

来源链同时冻结三种不同文件，禁止互相冒充：最初浏览器生成下载
`raw_generated_file/raw_generated_sha256`、浏览器上传发生重编码后保留在
`source/web_upload_canonical/` 的清理输入，以及最终 alpha 清理输出。清理精确性只相对于
`web_upload_canonical` 输入；每项还必须实体匹配固定的
`source/alpha_cleanup_verification.json` 及其 SHA-256。candidate manifest 原样保留整条链，
production manifest 再复制同一份 `source_chain` 并以 candidate manifest 哈希绑定。

动作条带固定为：

- `walk = idle + walk_step`，512×256、2 帧；
- `attack = idle + attack_strike + idle`，768×256、3 帧；
- `death = idle + death_fall + death_down + death_down`，1024×256、4 帧。

准备新批次配置时，可从模板复制配置；已经人工复核的 `source/semantic_anchors.json` 不得用
占位模板覆盖。应核对四个网页附件、四份最初 raw、四份重编码输入、稳定会话、
浏览器清理回执/验证文件和 64 个手工锚点；随后更新 `anchors_sha256`。模板已冻结当前 16 张四向 idle
的实际 SHA-256，任何共享盘漂移都会拒绝继续。

```powershell
Copy-Item 'qa/skirmish_direction4_actions_20260905/pipeline_config.template.json' `
  'qa/skirmish_direction4_actions_20260905/pipeline_config.json'

# 只检查人工锚点哈希；不要用 semantic_anchors.template.json 覆盖它。
Get-FileHash 'qa/skirmish_direction4_actions_20260905/source/semantic_anchors.json' -Algorithm SHA256

# 真正零写入：只在内存里完成 64 格规范化、48 条组装和审批总览并输出计划。
py -3 -X utf8 -B tools/skirmish_direction4_action_pipeline.py dry-run `
  --config qa/skirmish_direction4_actions_20260905/pipeline_config.json

# 只写 QA staging；不会写 assets/anim。
py -3 -X utf8 -B tools/skirmish_direction4_action_pipeline.py stage `
  --config qa/skirmish_direction4_actions_20260905/pipeline_config.json
```

`stage` 会先在同级临时目录生成和校验完整文件集，再用一次目录改名发布；目标已存在就
拒绝覆盖。它输出独立的 `staging/candidate_manifest.json`，记录源图、提示词、会话、
清理回执、64 个手工框和锚点、逐格可见像素归属/透明余量/主体组、原始矩形像素哈希、
idle/walk 参考尺度、16 姿势画布限缩、逐帧最小平移/最终锚点、16 个 idle、64 个候选姿势
和 48 条动作条带。

同时生成 `staging/candidate_contact_sheet.png`：按 4 兵种×3 动作×4 方向展示 idle 与
所有非 idle 关键姿势，并标注参考/实际/fit-limit scale、alpha bbox、fit shift 和 walk/idle
高度比。它只是 QA 排版，不参与生产条带。第一版尺度判退证据保存在 `rejected_scale_v1/`。
人工审批应先查看该总览；上面的 Godot 图形化矩阵读取生产路径，须在批准并晋升后用于
运行时复验。批准回执必须绑定这一份 candidate manifest 的文件 SHA-256。

晋升前须先复制并填写 `commit_approval.template.json`，把审查身份、范围、结论与
`candidate_manifest.json` 的文件哈希绑定。真实晋升还必须显式给出固定确认短语：

```powershell
py -3 -X utf8 -B tools/skirmish_direction4_action_pipeline.py commit `
  --config qa/skirmish_direction4_actions_20260905/pipeline_config.json `
  --confirm COMMIT_SKIRMISH_TOP4_ACTIONS
```

提交前会重新计算配置、工具、四张源、四份提示词、64 锚点文件、16 个 idle、暂存清单
及全部图片哈希，并拒绝目标碰撞。若确实要替换配置中逐项冻结过旧哈希的文件，还须加
`--replace-approved-targets`。生产来源清单写到
`assets/direction4/skirmish_top4_actions_direction4_manifest.json`，以便总覆盖审计追踪。
提交为每批建立 `PREPARING → PREPARED → COMMITTING → COMMITTED`
事务日志及备份；普通失败会立即整批回滚。若进程被强制中断，先执行：

```powershell
py -3 -X utf8 -B tools/skirmish_direction4_action_pipeline.py recover `
  --config qa/skirmish_direction4_actions_20260905/pipeline_config.json `
  --confirm RECOVER_SKIRMISH_TOP4_ACTIONS
```

## 管线自测

```powershell
py -3 -X utf8 -B tools/skirmish_direction4_action_pipeline_selftest.py
```

自测使用会自动删除的程序化仿真图，只验证工具机械行为，不作为美术。当前报告为
`pipeline_selftest_report.json`：34/34 通过，并确认真实 `assets/anim` 的 1040 个文件
在测试前后路径和字节哈希完全不变。

## 边界

2026-09-05 本批已在用户明确要求实施后完成晋升。审查回执明确记录为助手视觉 QA，
不是用户本人视觉批准。生产清单为
`assets/direction4/skirmish_top4_actions_direction4_manifest.json`，事务日志为
`checkpoints/20260905T022914_626f20ea28/journal.json`，状态 `COMMITTED`；48 张正式动作条带
已经写入 `assets/anim`，逐文件哈希与生产清单一致，Godot 4.6.3 编辑器导入 exit 0。

本批最终结果：

- 4 个驻守战高频官军 key：`guan_dao / guan_gong / guan_jingqi / guan_qi`；
- 4 个真实方向：`se / sw / ne / nw`；
- 3 个动作：`walk / attack / death`，共 48 个方向动作条带；
- 严格动作合同 257 项通过，48/48 格命中精确正式资源，缺图或任何 idle/旧动作回退均判失败；
- Vulkan 1920×1080 运行时矩阵 48/48 通过，渲染器为 NVIDIA GeForce RTX 4060 Laptop GPU；
- 通用方向回归 67/67、真实 Unit 四向图形夹具 191/191、战役核心 68/68；
- 死亡血迹专项无头 21/21、图形 22/22，验证四向倒地偏移、0.35 秒延后显现、36px 合并、
  四帧死亡条带结束后残留及既有 45 秒生命周期；
- 全战役严格四向状态覆盖为 109/347（31.412%）。驻守战宽口径五状态合同仍如实显示
  “完整动作门未通过”，因为本批没有制作 `hurt`，也没有给其他低频敌军补齐全套动作。

首个机械通过的候选因人物相对既有 idle 偏小而判退；保留判退说明与可复核总览在
`rejected_scale_v1/`。最终候选的 16 组 walk/idle 可见高度比为 0.9596–1.0357，优选区间
失败为 0。`staging/candidate_contact_sheet.png`、`assistant_visual_review.json`、
`action_contract.json`、`runtime_visual/report.json` 和本目录日志共同构成本批 QA 证据。

上述仍不等于用户视觉批准、真人 30 波试玩或兵海性能验收。本批没有导出游戏、修改
Steamworks 发布目录或上传 Steam。
