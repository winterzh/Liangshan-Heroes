# 祝家庄地图、景物与任务特效恢复

本批从 `dca4e4e` 继续，接入恢复组件并修复暂停边界。玩家续玩入口仍关闭，尚未进入祝家庄完整世界的 Core/Session 安装流程；九种玩法统一验收和真实 Steam 持久确认仍按[交付状态](CONTINUE_DELIVERY_20260908.md)推进。

## 生产改动

`run_battle_barrier.gd` 保留经典默认配置，只有显式安装内容上下文才能选择祝家庄捕获边界，并核对实际 Battle、Level3 和 Mission 脚本。保存请求后，最后物理步或延迟任务回调可能新增按钮；DRAINING 最终检查前补登记新 HUD 节点，各节点原始处理模式与信号状态只保存一次。HELD 健康检查核对整个 HUD，释放时还原新旧节点。

`run_map_state.gd` 将可信上下文传入景物适配器。`run_scenery_state.gd` 使用固定祝家庄景物工厂恢复原有节点和绘制状态，核对地图、五套导航、地形高度、资源、单位引用及随机状态不被工厂修改。恢复阶段不运行关卡部署或任务初始化；返回待激活适配器，挂载后仍禁用，最终暂停边界显式激活。失败清理只移除所属景物和牌示的翻译连接。景物组件不写原存档；完整菜单和战斗槽回滚待 Session 整合。

原生跨进程诊断发现候选显示记录 v1 中冗余的 `context.waves=0` 经 JSON 变为浮点 0，导致完整重捕获比较失败。正式组件改用 `level3_scenery_state_v2`，显示身份仅含两个严格字符串 `mode/level_id`；外层安装上下文仍必须提供 `waves` 整数 0，固定地图/关卡/内容验证不变。旧 v1、额外 waves、缺字段或错误身份均明确拒绝；不改写旧文件，不把数值类型差异作为通用例外，激活前完整比较保持不变。

`run_visual_graph.gd` 增加显式 `level3_visual_graph_partition_v1`。任务标记在完整特效树中保留顺序位置，但记录仅含 id、parent、index、kind、token；标记值和激活状态由 Presentation 保存。准备时先创建自身特效，再绑定实际 Presentation 生成的标记，恢复全部节点的混合顺序。未知节点、重复标记、错误层级、改动后的任务或标记都拒绝。失败清理保留 Presentation 所属标记，并释放私有特效树中的异常子节点。

分区配置交叉核对 Presentation 与 Mission 的动作、标记及滚动记录。捕获、绑定和激活前重新核对实际任务的稳定字段、事件、报告、动作及人物引用。阶段年龄仍由外层时钟负责；分区不证明重启后的年龄换算，只在绑定后检查阶段起点未被改动。Presentation 完成跨帧布局后，Visual 激活自身特效，Presentation 再单独激活任务标记，避免两处同时创建或激活同一对象。

`run_campaign_presentation_state.gd` 的固定模板按真实父容器选择 CanvasLayer 或 Control，修复生产 HUD 与旧组件宿主的原生布局差异。平地没有 `render_height` 时保留缺省值，不伪造高度；缺失必要元数据则返回受控错误。

准备对象挂树时所有信号仍被阻断，Godot 调试版本在 ready 中安装的原生尺寸警告清理连接可能保留。现在只允许已注册、已挂树且 ready、无脚本的 Control 指向自身的精确 `Control::_clear_size_warning`，flags 必须为 5、无绑定或解绑参数；错误 flags 仍拒绝。行为依据[当前引擎源码](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/gui/control.cpp#L3588)，原生恢复测试覆盖该连接及错误 flags 反例。

## 验证范围

原生结果、准确断言数、失败尝试及逐文件来源哈希见本批 QA 目录。完整世界与真人验收不能由这些组件结果替代。

- [地图与景物 QA](../qa/level3_scenery_20260909/README.md)：真实菜单启动祝家庄，真实暂停边界捕获，私有组件恢复、跨进程对照、按钮禁用与释放、四语牌示绘制。
- [任务与特效 QA](../qa/campaign_fx_partition_20260909/README.md)：实际 Battle/Level3/Mission 与 CanvasLayer 宿主，合成平地图和普通单位；非空 FloatLabel/Bolt、嵌套容器和两个任务标记。QuietHUD 不执行完整游戏 HUD 初始化，也不部署关卡。
- [经典流程 QA](../qa/continue_flow_20260909/README.md)及已有 Presentation 回归：确认共享代码修改后的兼容性；不作为最终冻结版本的完整 30 波或八关验收。

当前祝家庄六条可选地表装饰路线没有可加载的对应贴图，因此实际生成零个 GroundOverlay。测试核对安装内容的实际分支，非空 Overlay 恢复尚未验证。非零景物计时和透明度为受控注入；牌示四语截图临时显露文字并隐藏迷雾绘制层，截图后恢复并对照 Map/Fog，不代表正常可见范围。原样恢复全景另行保留。

## 下一步

在官方祝家庄工厂中串行接入 Map、Unit、Level、Mission、Presentation、FX、Root、HUD、Camera 和环境。Root 需显式支持祝家庄正常浮点阵营资源；跨帧布局后才能最终换算时钟和提交 Session。任何失败必须清理翻译连接、撤销目标设置并保留菜单与原槽。

章节成绩还需持久结算意图和幂等令牌，补齐“终局收据已写入、章节成绩未保存就退出”的恢复窗口。随后按关键任务阶段、英雄状态、在途伤害及终局拒绝完成祝家庄，再推进其余七关。Steam 写确认、完整同版长跑、双机双账号与真人检查仍为独立验收条件。

## 本轮最终原生证据

| 范围 | 批次 | 检查 |
| --- | --- | --- |
| 地图与景物 | [20260909_083845_5a3ee678](../qa/level3_scenery_20260909/20260909_083845_5a3ee678/receipt.json) | 197 |
| Mission/特效分区 | [20260909_083711_bf4595d7](../qa/campaign_fx_partition_20260909/20260909_083711_bf4595d7/receipt.json) | 622 |
| 原Presentation兼容 | [20260909_084056_42d119f2](../qa/campaign_presentation_state_20260909/20260909_084056_42d119f2/receipt.json) | 348 |
| 经典短流程 | [20260909_085735_9439525c](../qa/continue_flow_20260909/20260909_085735_9439525c/receipt.json) | 295 |

[共同来源回读](../qa/level3_scenery_20260909/final_freeze_readback.json)确认四批2953份共同生产文件等于当前文件；各批还单独回读自己的完整QA来源。未在当前冻结版重新跑完整30波、1800秒、双机双账号或真人验收。
