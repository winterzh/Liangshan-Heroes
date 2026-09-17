# 死亡残留接入战斗恢复

此前正常单位死亡生成DeathRemains后，混合Fx图会因未登记脚本拒绝整场捕获。本批新增 `run_death_remains_state.gd`，把残留加入现有有序图，并将所属Battle的残留列表及贴图缓存纳入world core准备事务。三份生产脚本以最后实际受测字节接入；新模块UID来自原生导入。

## 保存与恢复合同

显式保存14项原生值：remaining、lifetime、fade_duration、reveal_delay、reveal_fade_duration、age、visual_size、frame_scale、merge_count、frame_index、frame_anchor、captured_direction、fall_offset、ground_basis。frame_texture保存为固定受信图集的切片描述，保留region、margin和filter_clip；无贴图时保留原来的null回退。图集只通过现有Art服务的death_remains标识获取，记录中的路径只作身份比对，不能驱动资源加载。

ground_basis拆为三组Vector2，贴图矩形拆为位置和大小，以现有精确数值编码器往返。新增字典字段使用普通String键，避免GDScript点赋值产生StringName键。恢复按原值赋值，不调用configure或refresh_from_merge重置时间，也不重播死亡、重新抽装备或补画贴图。

保存七类已知元数据（存在时）：残留标记、帧、初始方向、倒地偏移、合并次数、最近合并方向、render_height。未知元数据拒绝。GameMap对高地的修正只写入RenderingServer，不改变Node2D.transform；激活时按保存的render_height重放这份绘制变换，不重新采样地形，随后请求重绘。该绘制变换路径已执行，但本批没有截图/像素视觉验收。

Battle的 `_death_remains` 顺序通过同一Fx节点ID列表保存，保留旧节点合并/淘汰查找语义；`_death_remains_atlas_checked`和缓存贴图分别保存，包含“已尝试但无贴图”的状态。捕获检查每个残留唯一登记、属于完整图，并仅连接原Battle的expired清理回调；恢复连接到新的Battle。缺失/重复ID、图中未登记残留、坏图集/切片、非法寿命和未知元数据均拒绝。准备后的所属列表被改动也会阻止激活。

world core内部schema从v1升为 `classic_world_core_preparation_v2`，新增第15分区death_remains。它在Fx节点准备后、根安装前绑定，根中的残留序号仍由已有root分区负责。此为尚未开放的内部格式，没有玩家存档迁移承诺；当前内容/引擎身份仍必须匹配。为后续定位失败，core捕获错误现保留分区与原始cause。

## 验证与失败记录

R6在真实Windows/Vulkan/RTX4060经典开局中，对实际普通单位调用正常take_damage造成死亡，确认生成一个登记残留。正常引擎再推进120个physics观察帧，等到真实HELD屏障后捕获/JSON往返并准备新核心。不是直接伪造一个DeathRemains代替死亡流程，也不是自然AI战斗或整场通关验收。

从该记录准备两份新核心后，只将两份Fx子树挂在可处理暂停帧的独立测试父节点下。为了快速验到末端，夹具明确缩短remaining并设置显现/合并测试时间；未手动调用_process。76个双方存活观察帧中字段、显现透明度和自然删除一致；同一refresh_from_merge方法保留age，两个expired清理回调各执行一次，所属列表最终为空。完整Battle仍未挂载激活，不能把这项当作整场继续运行。

最终R8加强了逐项对照：两份恢复对象的全部14原生字段、切片和元数据都与暂停中的真实源残留相等，而非只比较两个恢复副本。R8共5847项，其中5782来源SHA、65其他断言；保留world core的地图、迷雾、单位顺序、波次/RNG、15坏分区及跨分区计数检查。具体生命周期帧数见[安装收据](../qa/death_remains_resume_20260908/installation.json)。

R7使用相同生产候选做既有混合图回归：6233项中5782来源SHA、451其他；13个定时场景、Blink实际idle、图腾+箭矢+飞斧固定消费者以及真实混合physics/idle通过。六个源/恢复弹道各退出一次，目标HP972/974一致；另加缺少可选图集的回退场景，checked-null缓存、高地元数据、激活及再次捕获均保持。该回归是headless，原生图像显示不计为通过。

原始失败保留：R1的常量数组拼接不能作为GDScript常量表达式；R2发现Transform2D/Rect2不在通用编码器类型内；R3至R5仍遇到新增StringName键的UNSUPPORTED_TYPE。R4补core错误cause，但驱动尚未读到它；R5修正驱动后得到精确路径$/1/value5/value0/key14，随后用String键修复。R6/R7通过后，R8仅加强驱动，三份生产候选字节未变。准备阶段还保留一次PowerShell多行字符串构造失败的说明，未当作原生运行。

八轮的生产/玩家目录/私有源码/候选保护、子进程退出和公共锁释放均验证。最终[QA与复现](../qa/death_remains_resume_20260908/README.md)保留失败原文、候选和原始SHA证据；最小化窗口不提供可见画面验收。

## 继续工作

完整world/Battle显示层仍需水面铺底、斑驳、阴影批次和保留尸体引用、氛围、相机、HUD及容器/兄弟顺序；其他未登记英雄特效仍拒绝保存，不静默丢弃。随后在新局初始化之前分流恢复入口，同帧安装根时钟、Unit信号、Steam持久局身份与激活，再做磁盘单继续槽、保存成功才退出和跨进程继续至胜利。祝家庄/其余七关、真实Steam双账号、长时性能、两台Windows和真人门槛继续开放。本轮只同步开发分支，未更新Steam包。
