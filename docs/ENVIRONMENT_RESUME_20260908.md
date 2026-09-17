# 战场环境状态恢复

内部核心schema v7新增第20分区environment，保存Overlay、浮尘与可选氛围层的显式Node2D渲染/处理属性、场景内动画相位及Battle直接显示子节点顺序。真实保存屏障不算显示子节点，仍由最终安装流程创建；其它陌生根子节点、材质、元数据、回调、重复角色及无效值拒绝。Overlay绑定新Battle，因此选框、命令指示、范围圈等继续读取同一套已恢复根状态。

原浮尘Time.get_ticks_msec和滤镜shader TIME改为场景节点的delta相位，暂停会冻结，恢复赋值不重新起算；不改变60Hz模拟或战斗规则。着色器采用当前受信代码，保存记录不接收shader文本、路径、资源或回调。氛围可选开关以实际捕获节点为准，不因当前设置重新添加缺失滤镜。新AtmosphereLayer管理原有ColorRect，暖色/对比/饱和/暗角及水面微光公式保持；发现原ColorRect在Node2D下的FULL_RECT锚点实际尺寸为零，无法铺满屏幕。本批改为显式视口尺寸，并通过受信screen子Node2D抵消画布/相机变换；每个原生idle、视口尺寸变化及同帧激活后重排，保留z=3700及Overlay/浮尘/HUD层序。该修复使原设置开启时的氛围滤镜真正可见，最终观感仍需人工验收。

Godot4.6公开文档明确shader TIME不随暂停停止，见[CanvasItem着色器](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html)。原生尺寸回调Control::_size_changed只在item_rect_changed、来源为唯一受信screen子Node2D且目标为其唯一ColorRect、无绑定参数且flags=0时认可；两个Viewport子序回调沿用严格限定。陌生连接不会写入存档。

prepare创建离树隐藏、DISABLED且阻断信号的环境节点，按保存顺序排列world/overlay/camera/atmosphere/motes/hud。mount_disabled仍先绑定真实根数据及clock，再挂载禁用世界。environment_module.activate仅在相同安装帧、暂停树、根仍禁用且全部节点/顺序/相位/受信材质未改变时开放；重复、过帧、篡改拒绝。该入口只开放显示消费者，不代表完整战斗激活。最终事务须统筹Unit/Fx/Fog/相机/HUD、屏障/共享占位对象、Steam持久局、光标与current_scene。

最终原生6037项通过，其中5802来源SHA、235非来源记录（234断言+1条像素诊断）检查。见[QA](../qa/environment_resume_20260908/README.md)及[安装收据](../qa/environment_resume_20260908/installation.json)。真实HELD冻结、原生idle相位等价续接、shader uniform、可选氛围、坏记录/来源/安装/回滚和前序HUD等回归均保留。离屏Vulkan像素使用128×96视口，旧着色器TIME替换成12.5常量、显式设置全屏矩形作为独立公式参考，容许单通道最多1/255量化误差，实际最大差值和不同通道数在原始报告中，另检查暂停稳定、修改相位改变微光、192×108重排。主游戏最小化窗口仍为0×0，这不是整场可见画面或人工体验验收。

尚未开放玩家继续：剩余Fx、完整世界/Steam绑定、光标所有权与退出/重开上下文、磁盘原子槽及跨进程、八战役适配仍要推进；完整30波、1800秒、两台Windows、真实性能和真人验收继续开放。本批仅同步GitHub stable，不更新Steam。
