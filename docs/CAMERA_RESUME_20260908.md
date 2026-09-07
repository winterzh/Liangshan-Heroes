# RTS 相机状态与输入恢复

新增run_camera_state，world core内部schema v4增加第17分区camera。保留RTSCamera的10个脚本字段、27个已声明Camera2D属性、当前镜头标志及既有Node2D绘制/处理状态。位置、非等比缩放、限制、震动强度/相位、近期手动操作计时和触屏模式按原值恢复；没有保存的资源路径、脚本名或任意对象反序列化入口。

## 屏障与安装

捕获要求真实Battle的HELD屏障与原相机归属。屏障临时把camera.process_mode设DISABLED并关闭unhandled_input，模块从该屏障已保存的原值恢复这两个字段，避免把临时封锁持久化成永久失灵。未提交中键/触摸手势仍依既有屏障清空，不在继续时恢复按住状态；touch_mode保留。

prepare创建禁用的Camera2D并关闭处理与输入，按保存值赋值，加仅限内存的_run_camera_prepared标记，再归属新Battle。相机的_ready遇到标记不执行make_current或zoom=1.1；Camera2D.enabled也保持false，避免原生入树阶段抢占旧镜头。没有标记的新局仍走原初始化。

camera_module.activate只能在所属Battle/相机关系有效、暂停且已入树、准备标记和禁用状态仍完整时调用。它恢复屏障前处理/输入优先级与标志，再启用、make_current和force_update_scroll，清除准备标记；重复调用拒绝。此步骤必须由完整安装事务与HUD、根时钟、Unit/Fx/Fog、Steam一起调度，目前core只返回待激活模块。

## 当前支持边界

本工程RTSCamera使用一个启用的当前镜头，未启用Camera2D原生位置/旋转平滑、平滑限位或拖拽边界。模块要求这一实际合同：这些需要隐藏历史状态的选项若被打开会明确拒绝，不重置后假装等价。自定义Viewport、子节点、未知信号连接、材质/元数据覆盖拒绝。27属性的定义对照[Godot Camera2D源码](https://github.com/godotengine/godot/blob/4.6/scene/2d/camera_2d.cpp)。这不是所有Camera2D用法的通用序列化。

## 原生证据

单次运行5909项=5790来源SHA+119其他断言全部通过。在真实经典战斗正常推进120个physics观察帧后，夹具设置非默认位置、非等比缩放、平移速度、震动/相位、触屏模式、PAUSABLE处理及优先级，并构造未完成手势，再由真实屏障清空手势和完成捕获。JSON准备后，全部10脚本值、支持的引擎属性及继承绘制属性逐字段等于暂停源。

准备相机挂载时保留原缩放，旧相机仍为current；暂停激活才切换current并还原屏障前输入。独立启用该相机的实际idle回调后，震动/相位/手动操作计时继续推进。真实Viewport输入分发接受滚轮缩放、中键拖动和松开；不是直接调用_unhandled_input。结束时恢复旧镜头并确认源屏障仍HELD。

零缩放、未释放手势、原生平滑、未知字段和错误类型均拒绝并释放临时Battle/身份对象；保留17坏分区、原地图/迷雾、世界顺序/纹理/阴影、4096阴影槽、自然尸体退出和死亡残留回归。私有玩家/源码/候选保护通过，子进程退出且锁释放。[原始QA](../qa/camera_resume_20260908/README.md)、[安装收据](../qa/camera_resume_20260908/installation.json)。

窗口最小化、viewport0×0，无截图/视觉布局、真实操作手感、完整30波或跨进程结论。下一步是HUD及其交互状态、氛围/浮尘时间、剩余特效和Battle根最终安装，随后原子继续槽、保存成功才退出与冷启动未来行为验证，再适配八战役。源码同步stable，本批不更新Steam包。
