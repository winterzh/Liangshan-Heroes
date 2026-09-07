# FIGHT HUD 与暂停安装顺序

core内部schema v6新增第19分区hud；hud_messages继续使用既有第18分区。run_hud_state保存触屏模式、物品栏开关、面板/小地图/物品按钮/已有英雄头像的刷新相位、HUD选区身份、顶部文本、暂停及确认动作、自动镜头按钮状态和CanvasLayer变换/显示/处理状态。地图缓存保存原RGBA8像素；图标、技能/生产命令、肖像、库存对象和资源文本从同一个已恢复Battle/Unit及当前受信HUD代码重建。旧Control地址、资源路径、回调和运行时实例ID不进入存档。

## 安装顺序

prepare仍创建离树禁用世界，新增隐藏的HUD骨架。mount_disabled要求暂停树和非physics回调，在离树Battle上调用已验证RootState.bind，生成真实恢复时钟与根字段，再挂载Battle。临时_run_core_clock_bound记录时钟对象和当次physics/process帧，Battle._ready只接受一致的绑定，跳过新局部署、Steam.begin_run等初始化；准备节点固定使用受信main.tscn作为原有重开回调的场景资源路径。HUD就绪先造控件，随后finish读取已恢复数据、重建选区/命令卡/物品栏、即时刷新资源、绑定小地图、恢复消息及暂停状态；所有控件仍禁用并阻断信号，HUD不可见且不抢焦点。

hud_module.activate只允许同一个暂停安装帧，验证全部原有及动态控件的输入闸，连接既有Battle菜单回调、Settings/视口回调，再恢复HUD处理/显示。暂停确认恢复后焦点落在取消按钮。过帧、重复调用、控件被改动或晚期地图缓存不匹配均拒绝；挂载失败释放新世界与时钟。完整世界的Unit/Fx/Fog/显示/相机激活、共享失效占位对象释放、Steam持久局和current_scene切换仍须由最后事务在同帧统筹，不能把此内部HUD测试入口当玩家继续功能。

活动单位查询带懒更新，finish结束恢复原根_active指针，避免UI准备改写捕获数据。资源刷新从原_process块抽成共用方法，构造不调用伪造delta的_process。新视口按既有触屏/安全区规则重排，宽屏可用内联物品栏时遵循原布局规则关闭弹窗。开局/剧情/结算界面仅在FIGHT捕获时要求关闭；将来相应状态由原玩法事件生成。

## 手势与回滚

真实屏障现在取消原生GUI拖拽、清除HUD长按/瞄准/组按钮手势和悬停提示，释放该HUD的键盘焦点；已经提交的命令不受此步骤影响。三个自定义物品/技能/命令控件只处理具有对应新按下的松开，防止取消后重放操作。原生拖拽接口依据[Viewport公开API](https://docs.godotengine.org/en/4.6/classes/class_viewport.html#class-viewport-method-gui-cancel-drag)。

准备世界把_cursor_resources_released置true，因为尚未接管全局光标；挂载后失败释放时不清除旧世界光标。原_install_target_cursor仍在真正接管时清除此标志。HUD原有UITheme和Settings热键标签路径复用，没有另造布局。

## 证据与未完成项

最终6002项=5798来源SHA+204其他检查通过。[QA](../qa/hud_resume_20260908/README.md)、[安装收据](../qa/hud_resume_20260908/installation.json)。覆盖真实根绑定和禁止重新部署、全部控件禁用、资源首次正确显示及后续原生idle更新、共享Unit选区/物品栏/命令/肖像、小地图像素、暂停确认的两次Viewport Escape、取消手势后孤立松开、0/1/10/12选区和生产建筑、晚期错误整树回滚与过帧拒绝，另保留消息/相机/世界显示/死亡残留和19分区坏记录回归。原始失败全部保留，不把来源哈希数量当功能用例数。

下一步是氛围/浮尘、Overlay/光标和剩余Fx的完整准备，以及全世界/Steam最终安装和跨进程持续行为，随后原子继续槽、保存成功才退出及菜单入口，再适配八战役。完整30波、1800秒、两台Windows、真实性能和真人验收仍开放。本轮仅开发分支同步，没有更新Steam。
