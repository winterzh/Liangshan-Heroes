# 网页地表整图映射候选（2026-09-02）

2026-09-06核查：当前四张生产地表与下表生产SHA一致，但原图、安装清单及normalization证据在本checkout缺失，因此不能复跑完整来源验收。工具已支持显式的仓库内证据路径映射，并现场重跑当前完整路由，拒绝过期绿报告。见 [跨电脑验证与缺口](ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md)；以下48项等结论为历史记录。

本批把四张网页版 ChatGPT 地表接成可逆的本地运行候选。它们不再作为 256px 重复图块使用，而是每张图在整幅关卡地图上只采样一次。这样不需要本地修缝，也没有放宽重复图块门槛：九张尝试在 repeat 模式下仍全部淘汰，报告保留在 `qa/environment_surface_normalization_20260902/`。

## 变换和来源

四张采用图全部保留完整 1254×1254 RGB 原图，只追加恒定 `alpha=255`，再整张等比缩放到 2048×2048 RGBA。没有裁切、透明补边、镜像、拼接、wrap、blend、补画、局部重绘、遮罩或局部滤镜。安装清单 `qa/environment_map_clamped_20260902/install_manifest.json` 逐张绑定网页会话、基础提示词 SHA、修正提示词 SHA、raw SHA、normalized SHA 和目标 SHA。

| 地表 | 采用 raw SHA-256 | 2048 RGBA SHA-256 | 网页会话 |
|---|---|---|---|
| 干土 | `d8abfa294df59b9ccd7631421bbc108a34028d04a46409ddb67da9faeb6eedb9` | `d8f5170630d2cbadf771f6289b966de642adc6560b15711fab13a31e01676142` | <https://chatgpt.com/c/6a977e6b-1eb4-83ea-8381-6910d6e75a83> |
| 林地 | `ccbe91dbc753b654df49be9ffc97d81a7649804db8a90a9565c49f5e21ff0052` | `4993b09c8951bbe48eff6d7c10dc3f3f60b9e11661560ec745e1b4b750a72280` | <https://chatgpt.com/c/6a978398-621c-83ea-b4d7-58f8a75180fb> |
| 湿岸 A | `5bce084d08be903e2579beb296d91e30255dbb3cad8ae6d478c4d7893396e23b` | `93834ce973eba6cb3ec5145e1b4088d9edfda7632bf36e75821e3369148186b8` | <https://chatgpt.com/c/6a978570-c1e4-83ea-9295-59b13beff5cf> |
| 硬地 | `94eb19ffccea979d8af0dc41b1bf36ccfb9ab61405affcb9e5e9ee1ca36267fa` | `563da8bb4f096b83c633153311775db08ae0edb14ddfe052953cd047dd785481` | <https://chatgpt.com/c/6a978587-f160-83ea-b8de-1f8149f855af> |

`surface_field` 没有合格网页原图，继续使用旧 atlas 回退。写源码和素材前已备份到 `C:\Users\rsb\Desktop\AI项目\水浒\implementation_20260902\pre_map_clamped_surface_20260902_102426`；备份清单 SHA-256 为 `98c6738b614daa2ddf7693b1d2011d7ee0398c5da938a7c1ff6a4e36cf5b87f5`。

## 运行时实现

`liangshan_coast.gdshader` 将五个网页地表 sampler 设为 `repeat_disable`。网页地表 UV 为 `(ground_position + detail_warp) / world_size`，细节扰动以零为中心，范围最多正负 2px，最终夹在原图半 texel 内。旧 atlas 回退继续使用原有 `fract(... / 256.0)` 的 `tile_uv`，两种路径不会混淆。

每像素只读取权重大于零的材质。这个分支不删除任何非零混合项，只避免在纯林地、纯湿岸等区域同时读取五张 2048px 图。优化后的黄泥冈、梁山中央画面与优化前同机位 ROI 基本逐像素一致：四张复核图的平均 RGB 差为 `0` 到 `0.00145/255`，差异集中在瞬时单位/UI 像素。

`liangshan_scenery.gd` 在运行时合同中逐项记录 `map_clamped` 或 `atlas_tile_uv`、是否加载和 repeat 状态。八关原有地表权重、碰撞、陆军/官军/水军通行、寻路权重和高度场均未修改。

## 验证结果

- Godot 4.6.3 Forward+ / Vulkan 导入和 shader 编译退出 0。
- 当前路由静态合同 `785/785`；四张地表已存在，因此当前报告如实列出其余 65 个网页环境资源缺失。旧的 69 缺失冻结报告没有覆盖。
- map-clamped 来源与源码合同 `48/48`；检查四张目标与候选逐字节一致、2048 RGBA 全不透明、完整原图矩形、零局部修改、半 texel clamp、repeat_disable、atlas 回退和零权重跳读。
- 八关运行合同 `90/90`；每关加载/回退标志与关卡作用域一致，视觉开关前后网格、三种通行、权重、高度和战役存档字节相同。
- 八关固定机位共 32 张 1280×720 图已检查。黄泥冈、梁山另在最终 shader 上复跑 100%/150%，`8/8` 通过；未看到 256px 方格、整图重复缝或可见边缘拉伸。人工结构硬边仍保留。
- 性能采用同一场景、同一材质的 atlas 回退与网页整图交替对照，每关各三组一秒窗口并预热纹理。组合报告 `32/32`：八关最大选定 Web P95 `16.17ms`，最大 P99 `22.293ms`，最大 Web/atlas P95 比 `1.0021`，符合 `16.7ms / 33.3ms / 不劣化超过10%` 门槛。

性能测试期间曾遇到共享机器 CPU 64%—70% 的并发负载；失败轮与同轮 atlas 的 24—42ms 异常一起保留，没有删除或冒充通过。最终组合只替换全量轮中同时受负载影响而失败的 level5、level8，使用随后独占窗口的通过结果；其他六关保留全量轮原结果。它是静态固定机位证据，不是战斗高峰、30分钟稳定性或真人节奏验收。

## 证据入口

- `qa/environment_map_clamped_20260902/install_manifest.json`
- `qa/environment_map_clamped_20260902/map_clamped_contract.json`
- `qa/environment_map_clamped_20260902/runtime_router_current.json`
- `qa/environment_map_clamped_20260902/contract_final/report.json`
- `qa/environment_map_clamped_20260902/render/` 与 `render_sparse_level1_level5/`
- `qa/environment_map_clamped_20260902/performance_composite.json`
- `qa/environment_map_clamped_20260902/performance/`、`performance_recheck/`、`performance_sparse_all/` 保存未采用失败轮。

当前是源码仓库内的本地生产候选。没有导出、没有写 Steam 发布目录、没有上传或发布，也不能据此声称完整战役或真人试玩已验收。

## 当前关键 SHA-256

- `scripts/liangshan_coast.gdshader` `5719a11adb1504b7b9b0ab9edbd713e9eb588a3916e6e101e597cebc4e1adabf`
- `scripts/liangshan_scenery.gd` `9d12a4f4237dcc33961c84a43c7c01b1534bbdadfd986f6faa9ae9e3c218d05b`
- `tools/natural_terrain_contract.gd` `1652b4d0d983def11bc04061e875250f08e3aece0db3ad6917d825390522b4dc`
- `tools/natural_terrain_render_qa.gd` `e7732975f9fa2f82299bfb6d27257dc2a057174d80ddc1e4dca0aacd990c80c7`
- `tools/environment_map_clamped_contract.py` `46547b6b764e740663cae990cd5723e952bbd2d88547a71c155145e8eaf75b7d`
- `tools/environment_map_clamped_performance_qa.gd` `3cc26d6e3e52d505e0d8a05ea894d7c154fae34c36a264bc230af792cf783359`
- `qa/environment_map_clamped_20260902/map_clamped_contract.json` `ce2f17d18e9b2a7ac61f6fb190fe8fd750cdb07feeb49fd8006115cbaf66d9b6`
- `qa/environment_map_clamped_20260902/contract_final/report.json` `809c7cd5d718ab7b28354f88ce5950b6ac5533c2b3fbb21bc6a7cea59c66a432`
- `qa/environment_map_clamped_20260902/performance_composite.json` `4168a620272c1f5eecec79a5fe0b52bbf7acc67bb5f6d96aef634e1f90ef1386`
