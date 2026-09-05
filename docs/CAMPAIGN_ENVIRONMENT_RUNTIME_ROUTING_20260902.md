# 战役环境美术关卡隔离路由

2026-09-06更新：历史原批次清单未随本checkout同步。现以仓库保留且哈希吻合的生产映射恢复当前完整静态检查，790项通过；运行路由794项通过。生产36/69存在，来源仍缺证据。新报告明确区分路由与来源验收，详见 [跨电脑验证](ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md)。以下785项和冻结清单描述为历史记录。

2026-09-06 用途扩展：无字 `stockade_segment` 原图按墙脚两端校准后用于梁山两轴，并明确允许祝家庄 `level3` 复用；PNG、alpha及原生产路径不变，其他关卡无该权限。下面“只用于一种方向”的说明是历史行为，已被本次修正替代。静态合同仅增加这一项有源SHA校验的用途差异；794项运行路由和相对基线路由表比对见 [新QA](../qa/wall_naval_20260906/README.md)。本机没有历史冻结清单原文件，未声称完整静态合同重跑通过。

冻结依据为 `implementation_20260902/environment_prompt_drafts_v2/environment_batch_manifest.json`，SHA-256 是 `162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf`。本轮没有生成、修改或导入位图，也没有向 `ArtDB` 增加全局键。

`scripts/campaign_environment_art.gd` 提供四个严格限域入口：

- `object(active_level_id, route_key, state="default")`
- `overlay(active_level_id, route_key)`
- `static_flag(active_level_id, route_key)`
- `surface(active_level_id, surface_key)`

64 个图集格对应 40 个物件键、41 个物件状态、20 个覆盖层和 3 面静态旗；另有 5 类可平铺地表。每次查询都先检查活动关卡和状态。跨关、未知键、未知状态或缺资源均返回 `null`，现有贴图、程序绘制和地表 atlas 继续显示。翠云楼的 `default` 与 `signal` 按两个状态分别验证；状态切换缺图时只复用该节点创建时保存的显式 `fallback_key`，不会拿剧情键回查全局美术。

消费者现已覆盖冻结清单的 69 个生产目标：

- 黄泥冈七辆枣车按 01—07 索引取图；枣担、生辰纲担、酒担和酒具走 level1 路由。
- 梁山树木复用现有节点，四种芦苇只允许四个固定锚点叠加，密集苇丛仍由原静态线网格合批。哨楼、寨墙、主门、两段码头和忠义堂均有缺图回退。寨墙新图只用于原图真实等距方向的墙段，另一方向不靠旋转或镜像合成。
- 三面梁山旗底调用 `static_flag`；新旗底和文字只有在同一源图 SHA 已完成矩形校准后才同时启用。此前继续显示现有旗面与原著白名单文字。
- 快活林四家酒肆逐位置绑定 A—D，主酒楼为 level7 独占景物，独立酒望的“河阳风月”仍要求源 SHA 绑定文字矩形。
- 祝家庄庄门走 level3 任务单位入口；厅堂、大名府铺屋、灯摊及翠云楼仍在战役景物层隔离。
- 五类 surface 已绑定岸线材质的五个独立 sampler 与开关；关卡不在各自 `level_scope` 或 PNG 缺失时，开关为 false 并继续采样现有 atlas。

文字矩形目前仍为 `null`，包括七个建筑或招牌表面和三面静态旗。只有网页源图通过 intake、记录源 PNG SHA、实测空白面，并在 100%/150% 下复核后才能填写。因此“69/69 consumer-ready”只表示生产路径已有真实运行时消费者，不表示 69 张资源已生成或美术已验收。

验证证据：

- `tools/campaign_environment_art_static_contract.py`：785/785 PASS；`qa/environment_runtime_router_20260902/report.json` 内含 64 个图集格逐 `(resolver, route_key, state)` 的消费者文件、文件 SHA 和行证据，以及 5 个 surface 消费者证据。
- `tools/campaign_environment_art_runtime_contract.gd`：758/758 PASS；覆盖资源缺失、跨关拒绝、surface 越界、翠云楼双状态和显式 fallback 正负例。
- Godot 4.6.3 editor 解析退出 0；八关固定机位实渲染 32/32 PASS；战役、竞技场、遭遇战、AI 战、自定义防守和场景夹具 100/100 PASS。相关日志均未检出脚本错误、Godot ERROR、WARNING、孤儿节点或 RID 泄漏字样。
- 快速真实渲染中，祝家庄 P95 9.097 ms、梁山 P95 12.425 ms；均低于 16.7 ms。梁山相对当前 11.979 ms 样本增加约 3.7%，在 10% 回归边界内。本轮没有执行 30 分钟 soak，也没有真人节奏或美术观感验收。

水战脚本后续增加四行注释后，只重绑了受影响的源码证据：忠义堂仍为 `level5_liangshan.gd:102`，堂前东旗、西旗和山顶旗分别为 `:696`、`:697`、`:699`。冻结批次清单仍为 `162e7454...9430cf`，提示词静态复核仍为 `f8e562d4...aa77`（502/502 PASS）；运行路由、素材和关卡逻辑没有因本次证据重绑而改动。

生产素材仍为 69/69 缺失。下一步只能通过用户已打开的网页版 ChatGPT 生成，再按 intake 清单验收、裁切和导入；不得在本地补画、镜像、抠图或生成方向。

## 本路由批改动文件

运行时代码：

- `scripts/battle.gd`（本批只增加战役环境事件图入口；同文件当前还包含另一独立任务的光标退出清理，最终共享文件 SHA-256 为 `88241a976f71fe9691d019d7bd998b50dc666bdcc1d39b851f6bb5d7ca0ff394`）
- `scripts/campaign_environment_art.gd`
- `scripts/campaign_environment.gd`
- `scripts/campaign_flag_overlay.gd`
- `scripts/campaign_scenery.gd`
- `scripts/levels/level1_huangnigang.gd`
- `scripts/levels/level3_zhujiazhuang.gd`
- `scripts/levels/level5_liangshan.gd`
- `scripts/levels/level7_kuaihuolin.gd`
- `scripts/liangshan_coast.gdshader`
- `scripts/liangshan_entrance.gd`
- `scripts/liangshan_gate.gd`
- `scripts/liangshan_scenery.gd`
- `scripts/liangshan_stockade.gd`
- `scripts/unit.gd`

合同与说明：

- `tools/campaign_environment_art_static_contract.py`
- `tools/campaign_environment_art_runtime_contract.gd`
- `docs/CAMPAIGN_ENVIRONMENT_RUNTIME_ROUTING_20260902.md`

Godot 在解析新增脚本时生成了 `scripts/campaign_environment_art.gd.uid` 和 `tools/campaign_environment_art_runtime_contract.gd.uid`。`scripts/game_map.gd`、`scripts/levels/level8_dongchangfu.gd` 和 `scripts/liangshan_layout.gd` 相对本批备份没有变化；它们只作为既有消费者或上下文证据被合同读取。

## 最终证据索引

完整文件、SHA-256、验证报告、日志和截图清单写入 `qa/environment_runtime_router_20260902/evidence_index.json`。主静态报告 SHA-256 为 `16dda6894bfc1bb54584ac90180de2227d6df6a34174192a6638fd8068405f43`；runtime 报告 SHA-256 为 `638af1e60acff498b2df52997db9c756466e2e05c1cfa9e5a9e446f8033aee05`；总证据摘要 SHA-256 为 `5e0e29795c7963deb2ff845096311cc3d5e89e14952e1e7f2e9943fd19e9dfef`。Intake 已按逐状态、范围、消费者文件 SHA 和精确行证据锁定 64 个图集格及 5 个 surface，`tools/environment_production_mapping.template.json` 的最终 SHA-256 为 `af1204a50a865096be47917440a36c67d9290f295fd5ee1ac2f8e000b1d441f1`，6 项隔离自检通过。
