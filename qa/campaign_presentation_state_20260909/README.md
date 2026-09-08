# Campaign presentation 状态验证

本目录收纳真实 `CampaignMission` 控件、`MissionMarker`、Localize descriptor，以及当前祝家庄 `level3_zhujiazhuang_rts.gd` 获救者选择回调的隔离验证。Battle 使用无部署的合成宿主，Unit 与地图投影方法使用生产类型；这不等于完整战场保存、八关恢复、真人视觉验收或 Steam 发布。

当前最终批：[`20260909_050932_4cb652ff`](20260909_050932_4cb652ff/receipt.json)，`complete=true`，**348/348 项检查通过：组件 218、独立进程重启 130**。全新导入、组件及重启退出 0/错误 0；错误 profile 保护预期退出 2/错误 0。2,954 个来源的当前/冻结 SHA 共 5,908 次核验通过。受测基线为 `64b7e05a0181dbd56c7310e1656aa12ba953cb77` 加本批明确冻结修改；尚未接入 WorldCore。

| 步骤 | 进程 PID | 退出/错误 | 耗时 |
| --- | --- | --- | --- |
| 全新导入 | 5436 | 0/0 | 22.81 秒 |
| 私有 profile 保护 | 46784 | 2/0 | 5.63 秒 |
| 组件 | 28016 | 0/0 | 7.05 秒 |
| 独立重启 | 25576 | 0/0 | 5.43 秒 |

进程身份依据 runner 的 Popen 记录与各独立日志；行为报告本身未写 PID。结果不扩大为完整 Battle、八关胜利、真人视觉或 Steam 证明。

| 历史批次 | 实际失败与保留范围 |
| --- | --- |
| `20260909_043154_927bd27c` | 原面板挂载信号被拒绝；15 项中 11 个 true 不构成有效负例验收。 |
| `20260909_043917_701d9831` | 诊断锁定父 Control 到直接子 Control 的 `item_rect_changed` 原生连接。 |
| `20260909_044407_d82b74c2` | 诊断锁定当前 Viewport 的 `canvas_parent_mark_dirty` 连接，并一次记录全部 47 条原生连接。 |
| `20260909_045444_e400e039` | 已越过信号/内部控件审计，但数值范围遗漏 accessibility focus 模式；31 项中 6 项失败。 |

四个失败批次均为导入 0/错误 0、profile 保护 2/错误 0、组件退出 1/错误 0，未运行独立重启；`complete=false` 和受测快照不改写，不并入最终 348 项。前版 `20260909_045952_0c7abd1d` 的 328 项通过也原样保留；其后增加文本格式上限修复和 20 项检查。最终批覆盖布局重置变换、被阻断滚动信号、错误回调 flags，以及异常大格式宽度/精度和非法格式在 prepare 分配前被拒绝。

最终 receipt SHA-256：`63ef6d2fb1fb6fa4fdbcaa6396974f22cae78851b1e47bcd3649c250d4cf32e7`。

独立 [只读验证器](validate_evidence.py) 已核对最终批的 5,908 次当前/冻结源码哈希、15 个归档源码/场景、4 份日志、2 份报告与 fixture 包。348 条断言全部为 true，报告与日志一致；fixture 实际含 41 个 Control、25 个按钮、3 个 marker、48 个绑定。复核结果在 [final_review_20260909.json](final_review_20260909.json)，SHA-256 为 `06f718b30c4cbd120f38a33e46aa34b94b0fcc532b878361e77cc016497f4d86`。

```powershell
py -3.14 -X utf8 -B qa/campaign_presentation_state_20260909/validate_evidence.py 20260909_050932_4cb652ff
```

该命令不启动引擎、不修改游戏数据。以后源码改变会正确报告 current-source drift，不能为了维持旧 PASS 改写历史 receipt。

| 最终关键来源 | SHA-256 |
| --- | --- |
| `scripts/campaign_mission.gd` | `6514aa9cd028ab4af513b2349ccd0076104cebc193765203b14e932416b88171` |
| `scripts/run_campaign_mission_state.gd` | `c9ae212121a4ed234f1aff2fc6e9d1c8242a47b70e097eb3d4a7c05fdd2077d5` |
| `scripts/run_campaign_presentation_state.gd` | `3e50c78484c2a9b3b99c6669361793d89c56115a06fd10ecee244558cee70085` |
| `tools/campaign_presentation_state_qa.gd` | `b9e5afa61869ceb33e9612c90c1749add482692c13c7672101b153dda3f0f080` |
| `tools/run_campaign_presentation_state_qa.py` | `c3a424491bc296debefa30ecff29f58ef3085be8a68e87b25e6ede9c727c8481` |

入口：`tools/run_campaign_presentation_state_qa.py` 默认只做预检；传 `--run` 才获取共享引擎锁、冻结受测来源、建立独立 profile，并依次进行全新导入、错误 profile 拒绝、组件行为检查和独立进程重启。`STEAM_DISABLED=1`，四个用户环境目录均指向该私有 profile；运行器只会终止自己创建的超时或错误子进程。

覆盖重点：真实混排按钮和标记、隐藏与禁用状态、字号 override、变换和高度、source/format/render 翻译绑定、清空格式历史后的新对象恢复、不同语言、失败恢复的局部清理、挂树后仍 gated 的布局与滚动恢复，以及激活按钮访问新 Mission/新 Level/新 Unit。保存动作不调用关卡部署；恢复动作不得重放 `begin()`、关卡事件或战斗 tick。

运行后每个唯一批次保存 receipt、四步日志、两个行为报告、仅含 fixture 数据的 JSON 重启包和明确列出的受测代码快照。真实 profile、完整复制工程、导入缓存不进入本目录。失败批次保留 `complete=false`，不得并入通过数；每批结果以当批 receipt、报告和来源 SHA 为准。
