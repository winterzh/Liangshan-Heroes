# 战役旗号文字白名单

2026-09-01建立，2026-09-02追加祝家庄门前两面白旗。此记录说明旗文的原著依据、改编压缩和素材来源。它不把游戏中的位置关系说成宋代实地复原；本批也没有触碰 Steam 发布目录或上传任何内容。

## 原著依据与改编边界

原文核对：[第四十八回](https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第048回)、[第七十一回](https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第071回)、[第七十八回](https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第078回)、[第七十九回](https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第079回)、[第八十回](https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第080回)。

| 原著位置 | 本作接入与限制 |
| --- | --- |
| 第四十八回，祝家庄门前一对白旗 | 原文两行严格使用 `填平水泊擒晁盖`、`踏破梁山捉宋江`。第3关只在两处已绑定的门前 `banner` 标记显示；两旗在本作地图中的上下落点是关卡排版，不声称原著规定左右顺序。 |
| 第七十一回，梁山山顶杏黄旗 | `替天行道`。第5关只在已绑定的山顶 `banner` 标记显示，不扩散给通用旗帜。 |
| 第七十一回，忠义堂前两面红绣旗 | `山东呼保义`、`河北玉麒麟`。第5关两面已绑定的堂前 `banner` 标记显示；左右落点是地图排版，不声称原著规定东、西顺序。 |
| 第七十八、七十九回，刘梦龙等官军水战 | 原文写到手旗、青红旌旗等，但没有给出可安全采用的旗面文字。因此普通 `official_warship` 保持无字；这不是说原著没有旗，而是不杜撰 `刘梦龙水军` 等文字。 |
| 第八十回，高俅中军 | 原著叙述高俅中军旗位。本作把这一中军识别压缩为 `gao_flagship` 上的 `帅` 字旗，不能反推成原著指定某一艘唯一座船的旗面文字。 |
| 第八十回，丘岳、徐京、梅展所领前队 | 原著为三人管领三十只大海鳅船，且两面大红绣旗合书 `搅海翻江冲巨浪，安邦定国灭洪妖`。本作把前队压缩为一艘 `official_vanguard` 与四艘无字普通官船；先锋头船不是丘岳、徐京或梅展任一人的私旗船。十四字仍作为一组编制旗文，前、后两块旗布各排七字只是本作画面布局，原著没有给两面旗或三名将领分别署文。 |

第八十回后续涉及三阮诱敌白旗及李俊、张横、张顺等水军的旗位，本批没有永久接入，不能据此声称全章旗号已复原。杨温、王瑾、叶春所领五十只小海鳅船亦未见可采用的旗面文字，仍不凭空加姓名旗。

明确拒绝：`梁山好汉`、`梁山军`、`宋军`、`刘梦龙水军`。其中梁山是地名，前两项并非这里的原著旗文。

## 路由与文字绘制

`scripts/campaign_art.gd` 的 `FLAG_TEXT_SPECS` 是唯一文字白名单。动态旗文须同时匹配单位键、战役物件键及所需剧情 context；先锋的单位键和物件键均须为 `official_vanguard`，且 context 须为 `chapter80_vanguard_headship`。静态旗文须同时匹配独立 marker、稳定关卡 ID 和布景键；祝家庄两旗只接受 `level3 + banner`，梁山三旗只接受 `level5 + banner`。普通官船、普通梁山船和任意通用 `banner` 都没有文字路由。

`scripts/campaign_flag_overlay.gd` 只按白名单排固定字形，不接受关卡传入任意文字。`scripts/campaign_scenery.gd` 与第5关专用布景走同一套 marker + level + decor 路由，避免继承布景覆盖基础 `setup` 后漏画，也避免四字段通用装饰误带原著旗文。高俅与先锋均要求自身真四向资源；先锋四种船况均保留同一组旗文。这样不会因单位名、关卡复用或通用物件而生成未经原著支持的旗号。

## 网页端素材来源

先锋头船 v3 原图仅由网页端 ChatGPT 生成：<https://chatgpt.com/c/6a96b875-8320-83ea-80ad-57f1790022b9>。源文件为 `assets/direction4/source/web_direction4_official_vanguard_states_v3.png`（1254×1254 真 alpha，SHA-256 `ADE7510DB70BE9FC2FB0DC8F4442855CF3B3D921D9BEB09D65F810A18BF50FD0`）；提示词为 `assets/direction4/web_prompts_20260901/official_vanguard_states_4x4_v3.txt`（SHA-256 `1270E91A308CA1282A63CC33F1E004B1D0D54CE925C3BDAF3FC75A93AC0DD180`）。来源、16格布局和裁切清单见 `assets/direction4/campaign_object_manifest.json`。

v3 是 4 状态 × 4 真方向的无字双红旗图表。裁切只利用审计过的透明缝、统一缩放和透明补边，没有镜像、遮罩修补、补像素或本地重画；缝隙复核最小竖向 36 像素、横向 21 像素。v1 因旗布和可书写区域不足以容纳竖排七字而淘汰；v2 因第一列第1、2行之间仅有 6 像素透明横缝而淘汰。两张淘汰源保留追溯，但未进入运行时资源。

## 验证边界

2026-09-02祝家庄追加验证：`qa/zhujiazhuang_static_flags_20260902/campaign_flag_overlay_contract.json` 为28/28，覆盖精确文字、白名单和关卡/布景负例；`runtime_contract.json` 为18/18，加载真实第3关并确认两处各生成一个文字节点；`liangshan_static_flags_regression.json` 为14/14，确认第5关既有三面旗未被污染。`visual_final/report.json` 为8/8，两张1280×720 Vulkan截图已经人工查看，两句七字纵排无截断，且能看见两旗与祝家庄门的关卡关系。此次只放大这两处运行时 `banner` 到144，没有生成、修改或重画任何 PNG。

自动合同：`qa/direction4_20260901/campaign_flag_overlay_contract_vanguard.json` 为 24/24，通过白名单、静态标记、先锋 context、四船况双旗和真四向资源检查；`qa/campaign_gameplay_depth_20260901/finale/depth_contract.json` 为 58/58，确认终章是 1 艘先锋头船、4 艘普通官船与独立高俅中军的压缩编制。

视觉 QA：`qa/direction4_20260901/runtime_official_vanguard_final/report.json` 为真实第5关 Unit 渲染夹具 77/77，通过 1280×720、四状态四方向、对应资源和旗号选择检查；`official_vanguard_level5_default_1280.png` 及其近景裁切已用于人工核对两段旗文。

上述自动合同和画面夹具不证明水路寻路、战斗平衡、整关通关、性能或真人试玩。真人试玩仍未完成；本批未导出、未改 Steam 发布目录、未上传。
