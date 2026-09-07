# 江州法场宋江、戴宗四方向源图审计

日期：2026-09-03

## 采用结论

- `song_jiang_bound` / `song_jiang_rescued`：采用 `song_jiang_bound_rescued_walk_4x4_v2_raw.png` 经网页精确阈值清理后的版本。
- `dai_zong_bound` / `dai_zong_rescued`：采用 `dai_zong_bound_rescued_walk_4x4_v3_raw.png` 经网页精确阈值清理后的版本。
- 被缚和获救待机采用两张基础图的前两行；获救步行改用两张后补的严格四行四列源图，每个方向都有四个真正不同的步行姿态。四列始终依次为 SE、SW、NE、NW。
- 第一行木枷均有颈孔和两个独立手孔，宋江、戴宗的双手从手孔穿到枷板正面。没有采用旧图中“无枷、双手藏在背后”的错误被缚姿势。

## 原著边界

采用百二十回本第四十回：<https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第040回>。

- 戴宗受拷后“取具大枷枷了”。
- 行刑前宋江、戴宗被缚，头发用胶水绾成鹅梨角，各插一朵红绫子纸花，并被押往十字路口纳坐。
- 刽子手在行刑前才开枷。
- 劫法场后两人先被背走，到白龙庙才得衣休息；戴宗一度昏沉，随后苏醒。

因此被缚造型保留木枷、鹅梨角和红纸花；获救待机、步行去掉木枷、绳索、红花和镣铐，只保留同脸、同衣的疲惫连续性。宋江的米白旧衣、戴宗的灰褐短衣及具体鞋袜属于本项目连续性设计，不冒充原文逐字描写。

## 生成记录

基础提示词：

- `01_song_jiang_bound_rescued_walk_4x4.txt`，SHA-256 `3FE75B7BFA6F9E012DEFD718CE906A5B93A65F835F9C8A9663F35D3F5F6E79F4`。
- `02_dai_zong_bound_rescued_walk_4x4.txt`，SHA-256 `A6B1D037A09DD27411892F7A9312437D652E18F108B16F0D2C584F15D7725157`。
- `03_song_jiang_rescued_walk_4x4.txt`，SHA-256 `13B577F57A49236E80ED2E79951BEE92D0466E1CA2AE50F0E57967E6C0AF12C3`。该文件明确标注为本次采用图生成调用的等义审计归档，不冒充 PNG 元数据中的逐字原提示。
- `04_dai_zong_rescued_walk_4x4.txt`，SHA-256 `56CB1258DC04CCDA56286486AC5544F490829ACCF519669FD6AA5D04E5C1E58C`。该文件采用相同的诚实归档口径。

原始生成物及处理决定：

- 宋江初版 `song_jiang_bound_rescued_walk_4x4_raw.png`，SHA-256 `CA9F832975075B7D30D43B9BCDA3B9A6A03EE800E9AD9A820E4942CA900D7679`，1254×1254 RGB，烘焙棋盘格，整张拒绝。
- 宋江二版 `song_jiang_bound_rescued_walk_4x4_v2_raw.png`，SHA-256 `77B82F441620BC1F80EEBB6C3EDCE2EADB0D417E6CC2D0F73AE47EE5AF6BF867`，1207×1303 RGBA，采用。Codex ImageGen 原始保存位置：`C:/Users/rsb/.codex/generated_images/01a060ed-ea65-74f1-aa47-a8daa91a06d0/exec-843daf01-bf92-4917-8124-b3f47f2b3d2b.png`。二版是在初版构图上要求真实透明背景、不得烘焙棋盘格的修正版。
- 戴宗初版 `dai_zong_bound_rescued_walk_4x4_raw.png`，SHA-256 `380372A6FE45BEF3025937BE4B86D9B454422AB1BF87C3953A2A32D50991B2E6`，1254×1254 RGB，烘焙棋盘格，整张拒绝。
- 戴宗二版 `dai_zong_bound_rescued_walk_4x4_v2_raw.png`，SHA-256 `C16A10312149BBEE0AB3E71956CB8242DD11A6AD782B809D18D2B0E5F319BB34`，1254×1254 RGB，仍为烘焙棋盘格，整张拒绝。
- 戴宗三版 `dai_zong_bound_rescued_walk_4x4_v3_raw.png`，SHA-256 `4AE2CBF2609E4DEE81D2755A319D536A894E73AA20ECFFA4E5215EF922C927FF`，1254×1254 RGBA，采用。Codex ImageGen 原始保存位置：`C:/Users/rsb/.codex/generated_images/01a060ed-ea65-74f1-aa47-a8daa91a06d0/exec-04439634-e5e6-4ba1-b127-f0d01df9ffae.png`。三版重新生成并强制真实 alpha 透明、两处手孔和双手穿孔。
- 宋江两次 2×4 尝试 `song_jiang_walk_cd_2x4_raw.png` / `song_jiang_walk_cd_2x4_v2_raw.png`，SHA-256 分别为 `830254DC394BF3F43237E3512C168D86B90C9FA43A1BABC6AEC0068B999A5C39` / `FB77B046F9CBF135DB6D8F8067419B264BD5DEE466CF2276BB5FC6ABBD5DB083`，均为 RGB 固底且帧数不足，拒绝。
- 宋江 `song_jiang_walk_4x4_checker_rejected.png`，SHA-256 `6616A5487E841C630642391B09B6A252EEC3A95164EF1D1A39081444884C552F`；戴宗 `dai_zong_walk_4x4_checker_rejected.png`，SHA-256 `139C59D97618A4A2CE61353CC0118DC8AA7817861038CF9045C9DBD0B5219A82`。两张均为 RGB 烘焙背景，拒绝。
- 宋江后补四帧图 `song_jiang_walk_4x4_v2_raw.png`，SHA-256 `AD60404A3229A1808BFE6B48BEFBB0868C1F17865B6A8EBBB5D79DDCF1DD801F`，1254×1254 RGBA，采用。Codex ImageGen 原始保存位置：`C:/Users/rsb/.codex/generated_images/01a060ed-ea65-74f1-aa47-a8daa91a06d0/exec-3fee5dde-ea55-4792-8e25-f30981f46aac.png`。
- 戴宗后补四帧图 `dai_zong_walk_4x4_v2_raw.png`，SHA-256 `3BCC830C1690C21706DCBDD61B3F4A6E64C5C3D524515FB708135A30D74D752A`，1297×1212 RGBA，采用。Codex ImageGen 原始保存位置：`C:/Users/rsb/.codex/generated_images/01a060ed-ea65-74f1-aa47-a8daa91a06d0/exec-0b475dbb-251c-48e0-9965-bfc7722ddfd3.png`。

拒绝的 RGB 棋盘格源图只作为审计证据保存，绝不进入候选或生产。

## 网页精确清理

网页工具会话：<https://chatgpt.com/c/6a98aaad-027c-83ea-b636-31a9014935ce>。

- 输入 ZIP：`jiangzhou_prisoners_alpha15_input.zip`，SHA-256 `9DFC0E1DF5B036282216B290F3B34ABA81C4C44040884F9650633E8604972D22`。
- 输出 ZIP：`jiangzhou_prisoners_alpha15_exact.zip`，SHA-256 `9277A7A51B36AA7209D2685E519F3C3C1ED10EBD4DFE25DE8E39CB269C1B2C38`。
- 宋江清理输出：`web_alpha15_cleaned_from_web/song_jiang_bound_rescued_walk_4x4_v2_alpha15_exact.png`，SHA-256 `E125DD1F3BDF4D1BFDC88B5B5A51D1294CA07439EC635480F0A020AB2F8F4EB8`。
- 戴宗清理输出：`web_alpha15_cleaned_from_web/dai_zong_bound_rescued_walk_4x4_v3_alpha15_exact.png`，SHA-256 `CFF90AEE6CF8BF8D50855240CCA5615A03FBDDDB0D706813D2E918B3FF3D7105`。
- 唯一像素规则：输入 `alpha<=15` 时输出精确设为 `RGBA(0,0,0,0)`；输入 `alpha>15` 时输出 RGBA 四字节必须完全不变。
- 网页报告两图 `alpha>15` 不一致数均为 0。本地独立逐像素复验见 `web_alpha_cleanup_verification.json`，总不一致数为 0。

四帧步行图另行锁定并清理，避免把基础图的两帧动作重复或平移伪装成四帧：

- 网页工具会话：<https://chatgpt.com/c/6a98fa22-6638-83ea-bfb1-693b1607bd4c>。
- 输入 ZIP：`jiangzhou_prisoners_walk4_alpha15_input.zip`，SHA-256 `4A11246FD4B70B3545B77B3281A4F10A6CC685B749042D1BBCA2B8135576D3F0`。
- 输出 ZIP：`jiangzhou_prisoners_walk4_alpha15_exact.zip`，SHA-256 `955657A8A9F51FFDD93D07C359FA63DEF24ED4131C55F4F43163007DD365DA50`。
- 宋江输出：`web_walk4_alpha15_cleaned_from_web/song_jiang_walk_4x4_v2_alpha15_exact.png`，SHA-256 `43294359CFF81E89EB2FD2013058FB27E4B5DF7C7BAC00E26931F68E0FA7342B`。
- 戴宗输出：`web_walk4_alpha15_cleaned_from_web/dai_zong_walk_4x4_v2_alpha15_exact.png`，SHA-256 `B23AA98F16E81F4632D0DB1A0BFBFF7094D032DEAD219FEB2567CD7D5D4EF81D`。
- 网页 manifest SHA-256 `E786D564345DB678A09ACA4B8BC99AA4796A5FAB214FD93C224BFA61D5032F4F`；本地独立复验 `web_walk4_alpha_cleanup_verification.json` SHA-256 `C0D549DDABC9DADAE89BA4AEF8AAF66F6D69DBB6EB824FDA437B60ADCDF08AFA`，两图总不一致数为 0。

本地未进行背景移除、遮罩、连通域筛选、镜像、补画、局部清除或其他像素修补。后续仅允许固定网格内连续矩形裁切、共同等比缩放、透明补边、横向拼帧和 PNG/JSON 编码。

本批不导出，不修改 `C:\Users\rsb\Documents\Steamworks\Liangshan_5088120`，不上传、不发布。
