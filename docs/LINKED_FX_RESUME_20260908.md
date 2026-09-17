# 单位跟随及贴图特效恢复

视觉图补齐12个固定Battle类，合计68个原生脚本字段（含继承时钟、Unit引用和Texture2D字段）。run_linked_fx_state校验固定字段/缓存，run_visual_graph只创建当前Script白名单；10个_ready增加恢复闸，普通新建仍执行原有投影、随机采样和寿命初始化。HuaLockMarkFx和FadingMark保持原Node2D行为。当前列出的剩余12类已接入；不把类型覆盖称为完整世界恢复，core仍v7及20分区，玩家继续入口尚未开放。

| 原生类 | 标量及缓存字段数 | Unit引用 | 贴图 |
| --- | --- | --- | --- |
| HuaSnipeAimFx | 4 | caster, target | 无 |
| HuaSnipeMarkFx | 3 | target | 无 |
| HuaLockMarkFx | 2 | source, target | 无 |
| LinGuardFx | 4 | target | 无 |
| LinSpearStackFx | 4 | target | 无 |
| LinDuelFx | 4 | source, target | 无 |
| AbilityProjectileFx | 7 | 无 | tex, impact_tex |
| AbilityImpactFx | 5 | 无 | tex |
| OrbitAxesFx | 6 | target | tex |
| BlackRainFx | 7 | follow | 无 |
| FireflyFx | 5 | follow | 无 |
| FadingMark | 1 | 无 | 无 |

共享Unit引用以稳定编号绑定新世界实际节点，空值和已释放引用分别保存；已释放引用必须先绑定共享脱树Unit占位，所有绑定完成并真正释放后才允许激活。该生命周期检查也覆盖既有Bolt链起点；激活前比较实际绑定对象及编号/有效性，拒绝被替换为旧世界指针、改号或提前释放。时钟、绘制缓存、贴图、节点变换和渲染覆盖在准备到激活间的变化会拒绝，额外元数据或回调也拒绝。关闭未提交图时清理本模块的引用记录。

默认世界工厂从当前安装的Art固定脚本登记4种物品、16种技能弹体、16种技能命中图以及当前受信建筑定义的坍塌图；调用方显式资源登记保持优先级。普通飞斧默认使用当前物品axe图，缺失时按正常创建逻辑回退到技能弹体axe。符号标记匹配当前资源对象及图集区域/边距/尺寸/基础资源签名，保存的路径只参与比较，不作为资源加载入口；空贴图继续使用原程序化绘制分支。未登记资源或改变图集签名均拒绝。

原生夹具使用12种实际构造器，确认完整脚本字段清单、JSON往返、缓存和生命周期保持、真实单位编号绑定。三组分别覆盖有效、空、已释放引用；有效组在真实idle中移动双方单位，然后结束蓄力/锁定、令目标死亡及释放引用，逐帧比较原/恢复效果的字段、变换、存在性和单次退出。黑雨失去跟随单位后保持原位置直到自身寿命结束，没有被错误改成即时消退。原生帧记录：['linked_entity_frames=164', 'linked_none_frames=252', 'linked_expired_frames=237']。

完整HELD经典Battle加入12类效果、非空建筑坍塌图及有待命中列表的贴图飞斧后，默认工厂完成capture/JSON/prepare，新效果绑定恢复后的实际Unit，数量一致且Battle仍DISABLED。飞斧绑定新Battle/Unit并保持未结算，不在准备阶段重放伤害。前序30类程序化特效、HUD/相机/世界显示/环境像素及分区坏记录回归保留。最终6587条记录通过=5810来源SHA+776非来源断言+1像素诊断。[实际输入与日志](../qa/linked_fx_20260908/README.md)、[晋级收据](../qa/linked_fx_20260908/installation.json)。

验证为Windows原生状态与生命周期、暂停全core准备，不是新增特效可见画面的人工验收、整场游戏重激活或跨进程继续。完整安装仍需Unit/视觉/显示激活的统一事务、场景与光标、Steam持久局绑定，随后继续槽/菜单/跨进程、经典30波和八关。1800秒、两台Windows、60FPS及真人/真实Steam双账号要求保持开放。GitHub stable同步，无Steam构建更新。
