# 三十类程序化特效恢复

run_visual_graph通过run_procedural_fx_state显式注册30个受信TimedFx子类。每类继承dur/t，加上自身字段，共167个原生字段；只读取固定字段名、只构造当前代码白名单中的Script，不从记录加载路径、资源、脚本或回调。视觉图仍标记为部分支持，core保持v7及20分区；兼容性仍受当前受信content_version约束。

| 类 | 含继承时钟的字段数 |
| --- | --- |
| HuaTargetArrowFx | 8 |
| LinCounterFx | 5 |
| LinDuelResolveFx | 2 |
| LightningFx | 6 |
| RallyFx | 5 |
| HasteFx | 4 |
| SlashArcFx | 5 |
| IronStaffSweepFx | 5 |
| WaterSplashFx | 5 |
| PoisonCloudFx | 6 |
| StoneFx | 7 |
| StompFx | 6 |
| WhirlFx | 5 |
| BloodFx | 6 |
| ChargeFx | 5 |
| PinFx | 5 |
| AbilityBeamFx | 9 |
| AbilitySweepFx | 7 |
| SpearSweepFx | 6 |
| ThrustFx | 6 |
| ChronoFx | 7 |
| IceWallFx | 7 |
| EarthCrackFx | 8 |
| EchoSlamFx | 4 |
| SplitMirrorFx | 4 |
| FireLineFx | 5 |
| ShadowWaveFx | 4 |
| AmpCastFx | 4 |
| SilenceFx | 5 |
| ArmorCrackFx | 6 |

浮点/向量/颜色必须有限，持续时间/剩余时间、几何及数组数量受限；缓存字典要求精确键和类型。雷击的折线/分支、鼓舞粒子、水滴、毒云/气泡、震地裂纹/碎石、血滴、定身桩、冰晶、地裂点、沉默符纸和破甲碎片保留原缓存。Lightning._segs与EarthCrack._pts用显式Vector2列表经过既有编码器，读出恢复为PackedVector2Array并核对原生类型及坐标，未扩大通用编码器接受范围。

每个普通_ready只增加_run_restore_prepared闸：正常新局仍执行原有随机形状/寿命/投影计算，恢复时使用保存缓存及阶段，避免重置或重新抽样。准备中的节点DISABLED并阻断信号，图激活前拒绝被修改的播放状态。未知元数据、回调、额外子节点及渲染覆盖拒绝；生命期结束继续使用原TimedFx._process和queue_free，不重播技能/伤害。

最终原生6246条记录通过：5806来源SHA、439非来源断言、1条像素诊断。包含30类原生字段清单与167字段覆盖、JSON往返、每类坏字段/类型/时钟、全部缓存缺失、打包向量类型、就绪不重抽样/不重启、激活前篡改拒绝。两个相同投影层中的原/恢复特效在真实idle中逐帧对照变量与变换，169帧内各自自然结束一次；Chrono/IceWall/EarthCrack的life由正常构造入口设置为0.5秒以覆盖结束，不伪造_process(delta)。

另把30个正常构造的特效加入真实HELD经典Battle，完成整个core的capture/JSON/prepare，确认数量不变且Battle仍禁用；随后释放新增夹具，原世界保持HELD。前序HUD/相机/世界显示/残留/环境像素及20分区坏记录回归全部保留。主窗口0×0；新增30类的证据为原生状态/生命周期及整体准备，不是其可见画面、实际战斗重新激活或跨进程验收。[QA](../qa/procedural_fx_20260908/README.md)、[晋级收据](../qa/procedural_fx_20260908/installation.json)。

当前尚未接入的TimedFx：HuaSnipeAimFx、HuaSnipeMarkFx、LinGuardFx、LinSpearStackFx、LinDuelFx、AbilityProjectileFx、AbilityImpactFx、OrbitAxesFx、BlackRainFx、FireflyFx；另有非TimedFx的HuaLockMarkFx和FadingMark。这些类涉及共享单位引用、贴图或独立失效行为，不能忽略或替代为空节点；当前遇到仍明确拒绝保存。之后推进完整世界/Steam持久局/光标/场景上下文安装、磁盘继续槽、跨进程持续行为和八战役。完整30波、1800秒、两台Windows、60FPS及真人验收不变。本批仅GitHub stable同步，无Steam更新。
