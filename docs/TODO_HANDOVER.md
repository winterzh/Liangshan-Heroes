# 技能系统 V2 · 历史交接归档

这份文件原本是 2026-07-02 的待办交接清单。对应工作已经完成，当前状态以
[`ABILITY_V2_COMPLETION.md`](ABILITY_V2_COMPLETION.md) 为准。

## 当前结论

- taunt / channel / transform / hex / invis / dispel / `homing:false` 直线弹已经落地。
- KIT2 自检已从 6 条扩展到 14 条。
- 108 将技能签名同构检测仍应保持 0 组。
- 平衡数值仍属于实测后再调的后续工作。

## 继续开发时先看

1. [`ABILITY_V2_COMPLETION.md`](ABILITY_V2_COMPLETION.md)：已完成内容、验证矩阵、已知残留。
2. [`ABILITY_SYSTEM_V2.md`](ABILITY_SYSTEM_V2.md)：技能系统三轴模型和新增 kind 的设计背景。
3. [`TESTING.md`](TESTING.md)：当前测试入口、可靠 gate、已知不稳定 smoke。

不要按旧待办清单重复实现 §1-§4。新增技能 kind 时仍遵守三件套：`_do_ability` 分支、`Defs.ability_levels`
tooltip 分支、KIT2/DOTACAST 覆盖。
