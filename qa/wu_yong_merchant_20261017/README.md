# 吴用黄泥冈同脸、朴刀动作与远距近战修正

完整PCK `20261017_034038_5ac6ad8a`：**1092项/234图通过**。6386冻结来源主/私有工程零漂移，32纹理原生像素/mipmap/尺寸一致，冷导入/脚本解析/真实OpenGL运行退出0，锁已释放。PCK 1174422964字节，SHA256 `f91ab67818c080b1e4681c3cd0ae7020d9f24d29bc02453c438cb4c673432a1e`。包、DLL、缓存与私有档案留在工程外。

`final/`原样保留receipt、输入、纹理引用、五段日志和report。`screenshots/`保留94张代表原图，完整234张SHA已逐一核对，工程外原始位置见`raw_evidence_index.json`。`visual_review.md`列明直接查看的30张最终截图；`source_preflight.json`记录24原稿/44引用SHA、18选用图/20资源/56姿势和普通吴用等保留来源；`alpha_samples.json`为只读背景取样。

当前短章和QA选择的旧长章使用原地图与部署；演员冻结、关闭迷雾，在未受遮挡的原地面插入瞬态样本，结束后演员/地图/场景指纹保持。包含四向相位、真实移动/命中/受击恢复/四段倒地淡出和三尺寸四语言HUD。旧长章仍为未注册/custom，不等于完整章节游玩。

实际110距离目标回归：
```json
[
  {
    "captured": true,
    "distance_travelled": 61.776123046875,
    "distant_melee_first_hit_distance": 48.223876953125,
    "fixture_context": "current_short"
  },
  {
    "captured": true,
    "distance_travelled": 61.776123046875,
    "distant_melee_first_hit_distance": 48.223876953125,
    "fixture_context": "legacy_long"
  }
]
```
两种上下文均先移动超过40，首次伤害距离小于60（含双方身体半径），验证旧射程200隔空近战问题已纠正。本关射程设26/挥砍profile2.1与0.48，HP150/攻击11/CD1.2/速度78保留，普通吴用远程与旧技能未改。

`rejected/`保留首轮1092项/234图自动通过但横卧离落点偏高的原收据、日志/report和截图，未计作最终画面通过。仅修正三个横卧相位的Godot支撑锚点，PNG不变。

早期换手、重复步态、刀尖贴边和采样间距不足的草图保留在原稿目录并注明拒用或仅采用部分格，未用脚本裁图/改色/镜像。服饰设计和原著事实边界见[实现](../../docs/WU_YONG_MERCHANT_20261017.md)。本批不是普通技能原著核查、搬担/战船、完整战役/续玩、平衡/性能、SDK/Steam发布或全美术验收。
