# 非人物图标与场景来源一致性 · 2026-09-27

## 修订范围

基础定义的 `market`、`scaffold`、`zhu_gate` 从 `Art.ART_ALIAS` 的聚义厅占位映射移除。保留既有头像/单位/建筑/物件/地形查询顺序，直接使用已有生产素材；没有新增位图或重复导出一份图标。

| 定义 | 场景与界面共用来源 | 范围 |
| --- | --- | --- |
| 集市 `market` | `assets/buildings3.png`，2×2 图集左上格 | 可建造建筑的默认 UI 图标 |
| 法场 `scaffold` | `assets/terrain2.png`，4×4 图集 (2,2) | 无变体图标；江州 `jiangzhou_scaffold` 本来就使用同格 |
| 庄门 `zhu_gate` | `assets/terrain2.png`，4×4 图集 (1,3) | 无变体图标；战役庄门仍按各自变体查询 |

图集原字节、区域、过滤配置、世界绘制、脚点、碰撞和导航均不修改。人物标准头像、剧情身份校验与此前独立脸型修订沿用原入口。

## 修正盘点口径

全库基线统计的是不带变体的定义。基础图标使用聚义厅，不足以说明实际战役同样显示聚义厅：

- 第二幕：法场赋予 `jiangzhou_scaffold`，白龙庙借用 `tavern` 定义但赋予 `bailong_temple`。
- 第三幕：正门、偏门通过 `CampaignGateVisual.configure_zhujiazhuang` 设置 `zhu_gate_native_20260906`。
- 第七幕：酒望使用 `roadside_tavern`，招牌使用 `heyang_tavern`；世界绘制还有受关卡限制的环境路由。截图确认店招在场景中是木牌，但其 HUD 仍是酒楼；这项现存差异需后续按关卡路由修正。
- 第八幕：大名府南门使用 `daming_south_gate`。
- `jiangtai` 在旧 `level4_lianhuanma.gd` 有创建代码，但当前入口是独立的 `level4_lianhuanma_rts.gd`。本批不将旧入口截图作为当前帅旗缺图证据。
- `dongchang_yamen` 仍有定义，本批未找到当前关卡的直接创建调用；使用范围待进一步盘点。

不把白龙庙强制变成酒馆，也不将关卡专用环境素材注册成全局基础别名。未声称酒望、帅旗、府衙等全部补齐。

## 验证

工具：`tools/run_nonperson_icons_qa.py`、`tools/nonperson_icons_qa.gd`。先从未修改的生产脚本采集完整路由，再用新冻结工程对比修订版。两轮都执行真实 Godot 导入，并使用独立用户目录、共享引擎锁及来源哈希。

覆盖全部基础定义与命名变体的纹理路径/哈希/图集区域，要求仅三项的 `ui` / `avatar` 改变；比较真实图鉴、HUD 和当前第二、三、七、八幕的相关物件。结果与目检范围见 [QA](../qa/nonperson_icons_20260927/README.md)。

这是图标路由修复，不计为新增人物四向或战斗动作。常规启动方式不变；仅同步源码 stable 分支，不发布 Steam 或 Android。
