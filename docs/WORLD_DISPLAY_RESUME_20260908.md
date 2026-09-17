# 世界显示层与恢复准备入口

新增run_world_display_state，world core内部schema v3增加第16分区world_display。恢复保留world/units容器的完整已声明Node2D绘制状态、world子节点实际排列、水面铺底、斑驳光影、阴影批次及死亡中Unit引用。map、units、fx、fog仍使用各自恢复模块，新的分区只绑定它们的同一对象和顺序。未知或重复world子节点、未知回调/元数据/材质覆盖均拒绝，不静默省略。

## 资源与状态

水面和斑驳纹理由当前受信Art与已有Battle._build_dapple逻辑重建，对照尺寸、格式、mipmap和像素SHA；存档中的纹理描述不驱动资源路径加载或脚本执行。图集水面按原初始化逻辑抽取为独立纹理。继承绘制属性包括变换、颜色、可见性、深度、过滤、重复和插值方式；处理状态单独保留到激活阶段。

阴影网格和着色器只用当前WorldShadow.ShadowBatch.setup创建并检查固定资源，保存MultiMesh容量、可见实例数、完整float32缓冲和保留尸体的有序实体ID。恢复的引用指向同一UnitGraph中新对象，尸体继续排除在Battle.units之外。缓冲按有界十六进制放在独立信封中，最大4096槽，避免挤占通用codec的节点和字符串计费上限；解码检查长度、十六进制、有限数与容量关系。未经验证的对象序列化不参与恢复。

Godot会自动给容器连接child_order_changed的两个Viewport原生回调。仅按当前viewport对象、完整方法名、绑定参数和REFERENCE_COUNTED标志精确放行，交给引擎在入树时重建。依据为实际原生诊断和[CanvasItem](https://github.com/godotengine/godot/blob/4.6/scene/main/canvas_item.cpp) / [Control](https://github.com/godotengine/godot/blob/4.6/scene/gui/control.cpp)源码。其他连接拒绝。

## 准备与安装边界

core在其余状态全部验证后绑定显示树，再加仅限内存的_run_core_prepared标志。Battle._ready在看到该标志时验证暂停、禁用、已恢复RNG、无新时钟/屏障及world归属，跳过整段新局初始化。异常准备入口停止而不回落新局。正常开局没有此标志，继续原逻辑。此入口允许准备树在正确Battle父子关系下入树，不会新建局、重复deploy、申请Steam局或启动玩法。

水面节点带独立准备标志，_ready仅请求重绘，避免覆盖已保存的z_index和texture_repeat。显示模块必须在暂停且已入树时激活，核对world实际顺序后恢复处理标志并清掉水面标志。完整根时钟、Unit信号、HUD/相机/氛围、Steam续局和最终玩法激活仍归后续外层安装事务负责；core.prepare本身仍返回mounted=false、activated=false、complete_world=false，并拥有显式dispose释放责任。

## 验证与失败

最终R8共5884项=5786来源SHA+98其他。在真实经典开局正常推进120个physics观察帧后，对普通单位受控致死，并等待真实HELD屏障，保留尚未消失尸体。测试另明确改变源world颜色、units位置、水面位置/深度/重复及斑驳兄弟顺序；这些是恢复夹具，未改变正式默认布局。JSON恢复后，容器与新增显示节点的全部声明绘制字段、纹理像素、阴影缓冲与尸体身份顺序均与源相等。

按真实Battle祖先关系挂载准备树，验证_ready不重建时钟/屏障、RNG或Steam局，不重新部署；Battle保持禁用。显示子树单独允许处理，临近消失的恢复尸体通过原Unit激活和真实physics帧释放，退出一次、阴影引用随后自然清除。另有4096槽缓冲往返、畸形/非有限缓冲、重复/缺失/未知节点、纹理变化、坏实体引用、非法容量、16分区损坏回滚和死亡残留生命周期回归。固定已知数量断言不能替代整局玩法验收。

R1把引擎内部连接当成未知回调；R2增加诊断确认child_order_changed；R3仅用未限定方法名仍拒绝；R4诊断确认方法名实际带Viewport::前缀。R5世界子树单独挂测试Node2D父节点，liangshan_entrance沿祖先取Battle.units失败，执行器终止该进程，未补造报告。随后保留完整Battle祖先并加入受控准备入口。R6通过5871项，R7容量/自然消失通过5878项，R8补继承字段/挂载边界并仅修正core注释。原始失败/通过、输入和保护收据均保留在[QA](../qa/world_display_resume_20260908/README.md)。

这是最小化Vulkan原生数据与回调验收，无截图或玩家可见排版结论；未做完整30波、跨进程、两台Windows或真实Steam双账号。后续仍需氛围/浮尘时间、相机/HUD/输入恢复、其他英雄特效、根同帧安装及Steam局身份，再完成原子继续槽、保存成功才退出、冷启动未来行为对照和八战役适配。本批仅同步stable，不更新Steam包。
