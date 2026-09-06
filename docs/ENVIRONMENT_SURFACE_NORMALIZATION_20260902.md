# 环境地表网页原图规范化候选记录

本批只建立生产目录外的候选和客观报告。网页版 ChatGPT 下载图均为 1254×1254 RGB；候选只追加全 255 alpha，并对完整原图或一个连续正方形原图矩形等比缩放到 2048×2048。没有拼接对边、wrap、blend、羽化、补画、无缝修补、镜像、局部滤镜或像素清除。

工具为 `tools/environment_surface_candidate_normalize.py`，说明和隔离自测分别为 `tools/environment_surface_candidate_normalize.README.md`、`tools/environment_surface_candidate_normalize_selftest.py`。裁切搜索下限为 896 像素，使用固定的 16 像素尺寸步长、8 像素偏移步长，并加入 896、960、1024、1088、1152、1216 常用尺寸。它是确定性的网格搜索，不冒充逐像素穷举。每个候选仍使用既有 `environment_web_art_intake.py` 的 2048 精确门槛复核。

| 批次 | 网页原图 SHA-256 | 完整图左右/上下 16px 均值 | wrap 比 | crop 搜索 | 结论 |
|---|---|---:|---:|---:|---|
| `surface_dry_earth` attempt2 | `e4a21d6afa7c66ff1ccedac618ebc83c632a5558b552bec4d06b470b7ad868d0` | 18.538 / 20.672 | 1.481 | 21,390 proxy / 69 exact，0 通过 | 淘汰 |
| `surface_dry_earth` attempt3 | `d8abfa294df59b9ccd7631421bbc108a34028d04a46409ddb67da9faeb6eedb9` | 20.711 / 21.267 | 1.750 | 21,390 proxy / 66 exact，0 通过 | 重复模式淘汰；整图路由候选 |
| `surface_forest_earth` attempt1 | `14f2c121ee26fd980950cd255867bc3935653a25033d6c2f49cb56dd9480217e` | 24.326 / 24.646 | 1.447 | 21,390 proxy / 64 exact，0 通过 | 淘汰 |
| `surface_forest_earth` attempt2 | `ccbe91dbc753b654df49be9ffc97d81a7649804db8a90a9565c49f5e21ff0052` | 21.199 / 21.476 | 1.716 | 21,390 proxy / 66 exact，0 通过 | 重复模式淘汰；整图路由候选 |
| `surface_wet_bank` attempt1 | `51dee0440ed86e028d8b5205501b7c87692ffef5c7ef492f1e8a08a39675eee6` | 18.563 / 19.432 | 1.746 | 21,390 proxy / 66 exact，0 通过 | 淘汰 |
| `surface_wet_bank` attempt2A | `5bce084d08be903e2579beb296d91e30255dbb3cad8ae6d478c4d7893396e23b` | 16.166 / 16.726 | 1.702 | 21,390 proxy / 61 exact，0 通过 | 两张修正版中较优；整图路由候选 |
| `surface_wet_bank` attempt2B | `f5d7992fa95c896497cec3974010f7ac77e669e46c7279c3c0a62e393e429faf` | 17.114 / 19.310 | 1.545 | 21,390 proxy / 64 exact，0 通过 | 淘汰 |
| `surface_compacted_stone` attempt1 | `208a62b27118d630648530eb58f042a3430dc4e0fee496640aa1a87b63d080f6` | 17.684 / 17.405 | 1.700 | 21,390 proxy / 65 exact，0 通过 | 淘汰 |
| `surface_compacted_stone` attempt2 | `94eb19ffccea979d8af0dc41b1bf36ccfb9ab61405affcb9e5e9ee1ca36267fa` | 18.569 / 19.671 | 1.629 | 21,390 proxy / 62 exact，0 通过 | 重复模式淘汰；整图路由候选 |

固定门槛为左右与上下均值各不超过 10，wrap 比不超过 1.25。九次原图尝试的整图候选全部失败；合法方形裁切也没有找到通过项，因此不能把它们作为 256px 重复图块使用，也没有采用任何裁切。湿岸两张修正版只按三项硬指标比较：以“最差归一化指标”计，2A 为 1.673，优于 2B 的 1.931。3×3 预览还能看出同一大块图案周期重复；该观察只是重复模式的辅助记录。

后续运行时方案不再重复网页原图。dry attempt3、forest attempt2、stone attempt2 和 wet attempt2A 均使用完整 1254×1254 原图，只追加全 255 alpha 并整图等比缩放到 2048×2048；没有裁切、拼接、修缝或局部处理。Shader 将每张图只映射一次到整张地图，UV 使用最多正负 2px 的低幅细节扰动并夹到半 texel；未接入的 `surface_field` 继续走旧 atlas 的 256px 重复回退。该路线的接入、备份、实机和性能证据另见 `docs/ENVIRONMENT_MAP_CLAMPED_20260902.md`。

每份报告记录 raw SHA、normalized SHA、稳定网页会话 URL、冻结 prompt SHA、修正版使用的 correction prompt 文件与 SHA、输入输出尺寸与模式、crop rect、缩放倍率、零局部修改和全部禁用操作。候选与报告位于源码仓库外的 `implementation_20260902/web_sources/environment/normalized_candidates/`。被后续下载覆盖的原图由主流程按 SHA 归档到 `rejected_raw/`，QA 汇总另记实际保存路径，不把不同 attempt 混用。

隔离自测包含 1254 RGB 到 2048 RGBA、幂等候选、合法单矩形裁切、不可修复接缝和拒绝由规范化工具写入 `assets/` 五项。既有 `environment_web_art_intake_selftest.py` 也保持六项通过。九份完整报告、候选/3×3预览绝对路径与 SHA、精确命令、自测输出和两种使用结论集中在 `qa/environment_surface_normalization_20260902/summary.json`。规范化工具本身仍只写仓库外候选；另一个有备份、有清单的安装步骤写入四张本地运行候选。没有导出或触碰 Steam 发布目录。
