# 剩余7项四方向网页源图与选择记录（2026-09-03）

本目录收拢复用复核后仍不合规的7个状态所需网页原图：`lin_chong_escort idle`、董超/薛霸各自的 `idle/walk`、`bound_shi_xiu idle`、`shi_qian_lantern idle`。本批只生成和接入战役美术，不修改 Steam、发布或导出目录。

## 原著边界

- 林冲、董超、薛霸：120回本第八回、第九回。林冲受二十脊杖，戴七斤半团头铁叶护身枷，由董超、薛霸押解；六月炎热，董超、薛霸携包裹并持木质水火棍。用户补充视觉约定为戴枷时双手应套入枷板孔内；本批选图的两个前侧方向已满足这一更强约定。第九回鲁智深割断绑树绳索后，枷仍保留到柴进庄上。
- 祝家庄石秀：第五十回。石秀故意让孙立捉住并“自把囚车装了”；原文没有写此处戴林冲式木枷，所以只画背后缚腕，不擅自增加木枷、铁链或伤残。
- 大名府时迁：第六十六回。时迁提着装有硫磺、焰硝等引火物的篮子，篮上插数个“闹鹅儿”，扮作售卖；不是一直举着火把。

原文链接：

- https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第008回
- https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第009回
- https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第050回
- https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第066回

## 网页生成原图

| 状态 | 提示词 | 网页会话 | 采用原图 | 尺寸/模式 | SHA256 | 决定 |
|---|---|---|---|---|---|---|
| `lin_chong_escort idle` | `01_lin_chong_escort_idle_1x4_prompt.txt` | https://chatgpt.com/c/6a9901e2-e620-83e9-9f2d-43db2cd760cb | `lin_chong_escort_idle_1x4_v1_raw.png` | 1774×887 RGBA | `E98036FDCD732486F34D708C8E3E767FB9A9E6B309F2256C6260EB996BE90034` | 重画并采用；前两格双手穿过枷孔，后两格可读木枷和受伤脚部 |
| `dong_chao_escort idle/walk` | `02_dong_chao_idle_walk_5x4_prompt.txt` | https://chatgpt.com/c/6a990231-f85c-83ea-a156-1e6c151e375d | `dong_chao_idle_walk_5x4_v1_raw.png` | 1122×1402 RGBA | `080BDCE4380E63DC3CF09EF755753E3AE9B439F8E36DCD39023B5ADCE38BE469` | 重画并采用；宽体褐色素公服、单根木棍，1行idle加4行真实步态 |
| `xue_ba_escort idle/walk` | `03c_xue_ba_idle_walk_5x4_v2_prompt.txt` | https://chatgpt.com/c/6a99040e-678c-83ea-b217-73183c371363 | `xue_ba_idle_walk_5x4_v2_candidate3_raw.png` | 1122×1402 RGBA | `482FFC3A8214C4A4AA1972344DAEEC67109E88F776AF00198DCADEC930965B9D` | 重画并采用V2候选3；瘦体深灰素公服、单根木棍，1行idle加4行真实步态，四条行间alpha>15透明带均成立 |
| `shi_qian_lantern idle` | `04b_shi_qian_cuiyun_idle_1x4_textonly_prompt.txt` | https://chatgpt.com/c/6a9906d0-55d8-83ea-a887-0d39f1dd1ef1 | `shi_qian_cuiyun_idle_1x4_v1_raw.png` | 1536×1024 RGBA | `5FB72647809BC007C33A58432A3565DF118E33DE6AE9B9DCBBBA4B761FF087EC` | 重画并采用；提篮、闹鹅儿、无常驻火把 |
| `bound_shi_xiu idle` | `05b_bound_shi_xiu_zhujiazhuang_idle_1x4_textonly_prompt.txt` | https://chatgpt.com/c/6a9906f5-2be4-83ea-bdf4-c42535d12db0 | `bound_shi_xiu_zhujiazhuang_idle_1x4_v1_candidate2_raw.png` | 1536×1024 RGBA | `0F5046CD59F7F7299E7F0FFF1CD343DF706F6BFD6A972908A1E99509299F165A` | 两候选中采用候选2；背后缚腕更清楚，四方向更稳定 |

石秀候选1 `bound_shi_xiu_zhujiazhuang_idle_1x4_v1_candidate1_raw.png` 保留作审计证据，SHA256 为 `552D989AC29114927820AE5C3D73A96032FA053D43088617CF5D295842B28E2C`，未进入清边与生产候选。

薛霸V1 `xue_ba_idle_walk_5x4_v1_raw.png` 及其网页清理结果保留作历史证据，但因相邻动作行存在人物像素叠压而拒绝接入。V2前两稿也因行间隔不足被拒绝；V2候选3经原尺寸目检与只读alpha统计后采用，未用本地裁切掩盖跨行问题。

## 网页精确清边

- 输入 ZIP：`yezhulin_remaining_p0_accepted_raw_for_web_alpha15.zip`
- 输入 ZIP SHA256：`B8CA9668416EE57F863C11C8BD49BD46C177C912AD111DD0038FA67079BB8E5B`
- 提示词：`06_alpha15_exact_web_prompt.txt`
- 网页会话：https://chatgpt.com/c/6a990898-b844-83ea-a44b-236f9f801582
- 唯一规则：`alpha<=15 -> RGBA(0,0,0,0); alpha>15 -> RGBA四字节完全不变`
- 网页报告输出 ZIP SHA256：`2513ACB173DD711737AEF9DFDE3F72959B30A0052472E08AD2F2DA5C88BB3894`
- 网页 ZIP 下载按钮被 Edge 拦截后，同一会话把5个既有清理结果逐张作为附件展开，并内联完整 `alpha15_exact_manifest.json`；没有重新处理。
- 本地允许的后续操作仅为字节复制、只读像素比较、连续矩形裁切、统一等比缩放、透明留白与PNG编码。禁止本地清边、掩膜、连通域抠取、镜像、补画或重绘。

只有 `web_alpha_cleanup_verification.json` 独立逐像素复核通过后，清理图才可进入候选切片。

薛霸V2候选3另在原网页会话执行单图精确清理，避免改写上述含V1的历史清单：

- 网页处理提示词：`07_xue_ba_v2_alpha15_exact_web_prompt.txt` 与文件名映射确认 `07b_xue_ba_v2_alpha15_exact_filename_mapping_prompt.txt`
- 原图 SHA256：`482FFC3A8214C4A4AA1972344DAEEC67109E88F776AF00198DCADEC930965B9D`
- 网页输出：`web_alpha15_cleaned_xue_ba_v2_from_web/xue_ba_idle_walk_5x4_v2_candidate3_alpha15_exact.png`
- 输出 SHA256：`8189173846A60F56B5AB7D1ADFB79CC3A4CC872C1FE2DDE306DE506B4A339A1B`
- 本地只读复核：`xue_ba_v2_web_alpha_cleanup_verification.json`，输入 `alpha<=15` 像素1306272个，其中80139个实际归零；`alpha>15` 区域RGBA不一致为0，低alpha输出非全零为0。
