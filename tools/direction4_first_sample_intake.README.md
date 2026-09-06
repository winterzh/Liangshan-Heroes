# 首批十张四向网页图接入

`direction4_first_sample_intake.py` 只处理
`implementation_20260902/prompt_drafts_v2/batch_manifest.json` 定义的八个身份、十张状态图集。它不会打开网页、生成图片或上传 Steam。

正式记录与提交只接受 `tools/direction4_first_sample_frozen_registry.json` 中冻结的批次清单路径、清单 SHA、十份提示词 SHA、逐批 acceptance checks SHA 和审计报告 SHA。注册表本身另由工具内硬编码 SHA 校验。替换 `--batch-manifest`、清空提示词或验收项后自行重算 SHA，均不能进入 `--record-attempts` 或 `--commit`。仅开发检查可显式增加 `--allow-unfrozen-batch-dry-run`；该选项不能和记录或提交同时使用。

## 来源清单与每次尝试

把 `tools/source_manifest.template.json` 复制到
`implementation_20260902/web_sample_sources_20260902/source_manifest.json`。`attempt_roots` 必须覆盖 `downloads`、`accepted`、`rejected`；这些目录中的每一张 PNG 都必须在 `entries` 中出现，反之亦然。

尝试账本位置由冻结批次固定为 `implementation_20260902/web_sample_sources_20260902`。来源清单中的目录字段只能保留字面值 `attempts` 和 `downloads/accepted/rejected`，不能改成绝对路径、其他相对路径或新目录。工具始终扫描固定目录下的全部历史 PNG 与全部 `*.attempt.json`；切换目录不能隐藏旧淘汰稿。`frozen_batch_manifest_sha256` 也必须等于冻结注册表中的批次清单 SHA。

每次网页生成都是一条独立 entry，不能用新图覆盖旧条目。字段如下：

- `attempt_id` 固定为 `<atlas_id>:<source_sha256>`。
- `atlas_id`、`source_png`、原始 PNG 的 `source_sha256` 和 `[宽, 高]`。
- 不含查询参数的稳定 `https://chatgpt.com/c/...` 会话地址。
- 与批次清单一致的 `prompt_sha256`、`group`、`design_state`、`directions` 和 `rows`。
- `decision` 为 `adopt` 或 `reject`，`reason` 必须写具体采用或淘汰依据，不能只写“通过”“采用”“不行”。
- 十一项 `human_review` 布尔门禁：身份行序、真实四向、非镜像、装备动作、视觉真透明、无地面或烘焙阴影、无文字水印、无跨格、脚锚实测、状态身份一致、引用附件确认。采用图十一项必须全部为 `true`。
- 采用图的 `anchor_measurements` 必须恰好16项，逐格记录 `art_identity`、`direction`、`measurement_kind`、原图绝对坐标 `source_y_px`。站立状态用 `foot_or_hoof`，`down` 用 `lowest_contact`。工具按透明分隔带得到的实际单元高度计算82%目标像素并执行正负3像素硬门禁。
- `down` 的坐标是最低接地点；其他状态是实际承重脚底或着地马蹄。最终透明画布以这项人工语义坐标定位；自动 alpha 外接框最低点只单独记录作参考，既不决定脚锚位置，也不是脚锚证据。
- 后四个状态的每次生成尝试（包括淘汰稿）都必须填写 `reference_idle_sha256`，并绑定同一会话中已经采用的本组 idle 原图；idle 留空。
- 首张兵种图必须把清单中规定的本地参考图 SHA 写入 `attached_reference_sha256s`。其他图通常为空列表。

`selected_attempt_ids` 最终为十个 atlas 各选择一个 attempt。淘汰后重生成时，旧 entry、原 PNG 和旁证都必须保留，只新增新 attempt 并更新选择。

## 追加式旁证

每次完成网页下载和人工取舍后立即运行：

```powershell
py -3 -X utf8 -B tools\direction4_first_sample_intake.py `
  --source-manifest C:\path\to\source_manifest.json `
  --record-attempts `
  --report qa\direction4_first_sample_intake\record_attempts.json
```

工具为每个源 SHA 创建 `<attempt_sidecar_dir>/<sha256>.attempt.json`。文件存在时只允许字节完全相同的重复验证，任何改写都会失败。来源目录中有未登记 PNG、清单里有丢失 PNG、SHA/尺寸/URL/提示词/理由不符，也会失败。淘汰图同样必须保留原图和旁证。

`--batch-manifest` 的候选副本只能用于显式开发 dry-run。正式旁证记录会重新读取冻结注册表和实际审计报告，任何路径、SHA 或批次清单漂移都会直接失败。

## Dry-run 严格检查

十个采用候选都选定、每次尝试旁证已记录后运行：

```powershell
py -3 -X utf8 -B tools\direction4_first_sample_intake.py `
  --source-manifest C:\path\to\source_manifest.json `
  --report qa\direction4_first_sample_intake\dry_run.json
```

逐张检查包括：

- 原文件是 PNG 原生 alpha 色彩类型，既有精确 `alpha=0` 也有可见像素；不接受调色板 `tRNS`。
- 十一项人工门禁全部通过；真透明视觉、无地面/阴影、无文字水印和无跨格不能由简单 alpha 检查替代。
- 声明尺寸、源图 SHA、提示词 SHA、四行身份、五个状态和 `SE/SW/NE/NW` 列映射与批次清单一致。
- 后四状态的每个采用或淘汰 attempt，其 URL 和 `reference_idle_sha256` 都同时匹配已采用 idle；只在同一对话不够。
- 兵种首图参考附件从清单路径重新验 SHA；提交时将同一字节归档。
- 三条横向、三条纵向分隔带均至少24像素且整条 `alpha=0`。
- 16格实测锚点按各自实际单元高度满足82%±3px；最终 PNG 的同一语义锚点还必须准确落在目标画布82%位置。切片器把 `source_alpha_bbox_bottom_only` 另存为参考，并明确标为 `semantic_anchor_evidence: false`，不能用它代替脚底、马蹄或倒地最低接点。
- 每格只做完整矩形裁切、同一行等比缩放和透明补边。没有组件分离、镜像、清像素、格内蒙版或补画入口。
- dry-run 列出160个目标 PNG、文件碰撞、manifest键碰撞以及全部 attempt/sidecar 证据，不修改生产美术。

## 原子接入

人工检查 dry-run 后才可增加 `--commit`。提交要求十张选择图全部采用并通过门禁；工具生成 checkpoint、逐文件原子替换、归档采用源图、原提示词和本地参考附件。覆盖率审计或持久化 `commit_result.json` 失败时都会回滚，只有生产文件与提交结果证据同时落盘才报告成功。

网页设计态 `down` 写入普通单位运行时的 `death` 文件名，同时在 manifest 保留 `design_state: down`。

本批通用 `wu_song` 是大名府及自由模式使用的行者武松。快活林的头巾布衫、徒手 `wu_song_mengzhou` 必须另做独立批次；本批结果不能计入其覆盖。

checkpoint、网页原图、提示词、参考图和 attempt 旁证仅用于追溯，候选导出仍须确认它们未进入 Steam 包。
