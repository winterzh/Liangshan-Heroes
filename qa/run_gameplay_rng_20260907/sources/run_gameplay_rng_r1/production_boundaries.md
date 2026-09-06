# 生产随机调用接入边界（只读核查）

这是一份未来迁移清单；当前生产源没有使用新模块。读源 raw/LF SHA 见 `callsite_source_pins.json`，下面行号对应该次读到的源。已有 `_physics_process` → `_phys_body` 性能分派是被读源码的原有调用结构，不是本次新增插桩。本清单不是全八关恢复 schema。

## 标准驻守共用玩法调用

| 来源与方法 | 行 | 必须保留的行为 |
|---|---:|---|
| Unit.leave_garrison | 855 | 出驻扎点的随机 x 偏移影响实际落格；先 draw 再 nearest_open 的顺序不能调整。 |
| Unit._phys_body | 1176–1177 | 醉态阶段更新两次范围 draw，保留 _drunk_t 门槛与 move/atk 顺序；恢复要保存原相位而不是重新触发 start_drunk。 |
| Unit._deal_hit | 1930、1937、1970、2012、2018 | 攻击失误、目标闪避、暴击、重击、骑兵吸血触发。保留前置条件/建筑资源排除/短路，不能每次攻击预抽固定五个值。 |
| Unit._try_li_brawn_axes | 2075 | 仅 proc_roll < 0 才 draw；上游已给 roll 时必须复用。延迟斧体的玩法状态另需保存，不能只迁移 draw 就认为恢复完成。 |
| Unit.lifesteal_frac | 2707 | 近战花荣每次吸血在等级区间随机，名字类似查询但实际消耗玩法流；捕获/校验/恢复不能调用它重算。 |
| Unit.start_drunk | 2927–2928 | 首次激活直接生成 move/atk 两个值；新局使用它，恢复写已有值与时钟。 |
| Battle.spawn_group | 711、713 | 每单位两个格点偏移 draw，再两个攻击移动目标偏移 draw；每个循环的原顺序、寻路结果以及失败路径都影响后续流。 |
| Battle._eco_traps | 3267、3273 | 己方/敌方陷阱选点随机影响实际场地；保留已有 AI/经济条件和所选分支，不能因相同方法在多个模式共享就漏掉。 |
| Battle.trigger_item_event | 6488 | proc_ready 后随机概率判断，随后才 hp_below/目标等判断；不要把概率调用移动到所有验证之后，这会改变流推进顺序。 |

这批核心路径当前直接使用 `randf/randi_range/randf_range`。`randi` 也保留为模块基本 API，供现有随机编队和模式接入，但标准 30 波的固定 WAVES 不为选单位主动调用 randi。

## 视觉与声音流

- Unit._spawn_dust:3258 的尘土偏移，以及 Projectile.setup:38/43/47 的 `_spin`，是视觉全局随机消耗。Projectile.setup 同时设置真实弹道/伤害目标，不能为了恢复视觉自旋重新执行整个 setup。未来只把这些 draw 交给独立视觉流，绝不调用 gameplay_rng 来生成视觉 seed。
- Battle 中下列具体随机值只生成演出数组/形状/角度：ArrowRainFx:13410–13413、FlameburstFx:13523–13531、LightningFx:13578–13583、RallyFx:13611–13614、SlashArcFx:13676、IronStaffSweepFx:13709、WaterSplashFx:13749、PoisonCloudFx:13788–13794、MeteorFx:14210、GroundFireFx:14282–14292、StompFx:14333–14336、WhirlFx:14373、BloodFx:14410–14413、SpearSweepFx:14817–14818、BlackRainFx:15099–15102、IceWallFx:15141–15142、SilenceFx:15482–15485、ArmorCrackFx:15521–15524。
- 这里分类的是这些 rand 调用的输出用途，不能因此删除整个效果节点。GroundFire 的 _ground_dot_pass、流星命中、LiBrawnAxesFx 等玩法/延迟对象继续按各自权威状态保存；该模块没有处理它们。精简画质开关未来应只改变视觉流消耗，玩法流应不受影响。
- LiangshanScenery.setup:46 与 _cache_reeds:259 已有局部固定 seed RNG；CampaignScenery.setup:27 也已有局部实例。Music._mk_rng:113 与 Sfx._build_ability:291 使用各自音频 RNG。这些实例不应被收编进玩法流。QA 的额外 visual RNG 仅验证隔离机制，没有实际运行全部这些生产演出。
- GameMap.scatter:230 的 seed_mix 是确定整数公式，不是随机流；当前 GameMap 与 HeroInventory 未发现上述原生随机 API、shuffle、pick_random 调用。地图恢复仍需自己的权威数据，不能由“未 draw RNG”推导可重新生成任意地图。

## 模式和 QA 入口边界

- Skirmish._waves:191–195 在非 random 且 n==WAVES.size() 时使用固定 30 波表。_make_random_wave:272/274/275/277/278 的单位、门、将领/战象概率是玩法；281 的随机提示文字是展示。若以后支持随机驻守，应保存已生成编队并迁移相应玩法 draw，同时把提示文字拆到视觉流。现在完整恢复只能继续明确拒绝未覆盖的模式。
- Arena:99/114 的随机兵种/敌将，以及 SkirmishAI:187/314/336/517/554/579/608/642/719 的实际落点/目标偏移/加权训练选择，也属于各自模式玩法。只列边界，本次不扩展这些模式的恢复适配。
- Battle._huarong_test:12551 是测试夹具的兵团位置随机；公共性能/功能工具还可能设置全局 seed 或预期旧流。将来接入时必须给夹具显式 gameplay seed 并重定验证基准，不能继续把 seed(global) 当作新玩法流初始化。本文未修改任何现有工具。

## 最小生产接入前置条件

1. Battle 在新局与恢复两条入口明确拥有唯一 gameplay_rng：新局只调用 start 一次；恢复从已验 checkpoint restore，不通过 deploy/购买/装备/技能激活重建随机状态。Unit 从所属 Battle 取得同一实例，禁止每单位临时新建流。
2. 逐处替换上表玩法 draw，并把视觉全局 draw 明确保持在其他流。原短路、循环、事件顺序不变；迁移不是只把 `randf()` 文本全部替换。当前模块字典结果与严格浮点端点需要真实调用方检查/适配，不能忽略 `ok` 直接读 value。
3. 在完整物理步/延迟回调结束的统一快照屏障保存流；禁止保存到半次多 draw 操作之间，禁止其他线程共享无锁实例。本模块没有加线程同步，也没有改任何模拟频率。
4. 存档外层绑定玩法源码/资源、标准驻守设置和 schema；该 RNG 的引擎/source compat 不能取代整体内容版本。旧存档若只有共享全局 seed 没有独立 state，不可虚构兼容续接。
5. 运行真实跨进程 QA 后，再做实际标准驻守保存点前后确定性对照，覆盖画质/视觉消耗变化、伤害事件、物品触发、单位落点、异步效果、实体顺序和各时钟。模块 QA 成功不能提前满足 M3 30 波恢复验收，也不构成 FPS 结论。

当前模块从 source-mode 的 res:// 脚本真实字节取得 SHA。以后导出 PCK 若脚本被转换/重映射，必须先设计并验证构建来源身份策略；不能在导出中拿不到 raw source 时静默放宽 SOURCE_ID。此项本次没有解决，Steam 发布不包含本草稿。
