# 续玩组件恢复：Unit、Projectile 与 Map（2026-09-07）

本轮已在真实 Godot 对象上验证 Unit、Projectile、Map 的局部恢复，并将五个适配模块放入正式 `scripts/`。这仍是完整续玩的基础组件：Battle 尚无调用方，未接菜单“继续本局”，也未验证整局跨进程恢复、持续战斗等价性或导出 PCK。

## 实现范围

- [run_unit_state.gd](../scripts/run_unit_state.gd)：显式运输 Unit 的 243 个局部值、Node 状态、metadata、Inventory 状态及对象引用；先创建树外禁用对象，再绑定依赖，最后由外层统一激活。实际 QA 保留活目标、已释放目标、数组顺序/重复项、驻扎双向关系、int64 物品 UID 和待完成攻击/施法状态。
- [run_graph_identity.gd](../scripts/run_graph_identity.gd)：处理三个原生目标整数和两个效果来源池。外层必须提供冻结战局的完整活 Unit 清单；registry 必须与该清单对象集合一致。历史 token 在恢复后再次保存时保留，新历史 token 避开旧 token。它不分配完整战局的实体顺序、物品 UID 或模拟时钟。
- [run_projectile_state.gd](../scripts/run_projectile_state.gd)：显式恢复飞行值、Node 状态与射手/目标引用。实际 QA 从飞行中的原对象经 JSON 重建，调用原 Projectile 物理方法继续推进，核对一次真实护盾/HP 命中、queue-free/退出，以及已释放目标不受伤。尚未覆盖溅射、物品联动、吸血或整场战斗。
- [run_map_state.gd](../scripts/run_map_state.gd) 与 [run_scenery_state.gd](../scripts/run_scenery_state.gd)：恢复标准梁山地图的地形、占格计数、导航修订和五份导航表、高度 RF 数据、固定场景结构与海岸材质参数。创建原测试地图时使用正常绘图入口；恢复阶段不以重新绘图、部署或推进战斗代替存档状态。

Map/Scenery v2 已将运行时依赖原始源码摘要的条件改为由外层显式传入并比对可信 `content_version`；不从存档自身推导可信版本。空版本、外层版本和嵌套场景版本不匹配均被拒绝，并检查目标保持未改。宿主 QA 的源码摘要仍只是本轮源码模式证据；这项改动不能直接证明 PCK 可恢复。外层还须约束总文件大小、完整事务及构建/内容兼容性。

## 实际验证

五个模块晋级后，正式加载路径完成相同组件复验：

| 正式路径组件 | Run（UTC） | PID / exit | 检查数 |
| --- | --- | --- | --- |
| Unit | `20260906T184545958515Z` | 37352 / 0 | 149 |
| Projectile | `20260906T184626953535Z` | 38640 / 0 | 54 |
| Map v2 | `20260906T184706533703Z` | 5628 / 0 | 63 |

原型路径的原始成功证据继续独立保留：

| 成功组件 | Run（UTC） | PID / exit | 全部检查 |
| --- | --- | --- | --- |
| Projectile | `20260906T183751958907Z` | 5032 / 0 | 54（18 来源前后检查 + 36 其余） |
| Unit | `20260906T183947533726Z` | 10560 / 0 | 149（20 来源前后检查 + 129 其余） |
| Map v2 | `20260906T184102784624Z` | 4188 / 0 | 63（40 来源前后检查 + 23 其余） |

这些数量是包含环境、夹具和聚合断言的检查行数，不能当作独立游戏场景。Unit 的 83 条身份边界检查已包含在 149 条中：使用真实 Unit 和不同身份上下文，经过 JSON 恢复及再次保存，核对旧 token、新死亡 token、正数来源域及 int64 非法输入。它没有启动第二个进程继续同一场 Battle。

三轮均核对真实 PID、私有 user://、runtime manifest、唯一 stdout JSON 和 sidecar 报告，严格引擎日志通过，源文件及真实玩家文件的前后摘要一致，共同锁已释放。Map 的 63 条仅覆盖 headless 下的原生数据、导航、高度图字节、节点和材质参数；没有截图视觉验收，也没有运行 Battle._ready、新局部署或战斗模拟。

此前 Map `20260906T182530446009Z` 和 Unit `20260906T183329072195Z` 两次失败完整保留。前者为入口过早加载依赖导致 `Art` 编译错误并最终超时；后者 strict log 捕获 ObjectDB 槽错误。失败日志、退出收据及受测旧源码均在归档中，没有被成功结果覆盖。

晋级时 Unit、身份、Projectile、Scenery 四份与成功原文同字节；Map 只将固定 Scenery preload 指向正式路径。随后正式路径三轮也通过相同的日志、报告、进程和保护核对，证据单列于 [production_path](../qa/run_resume_components_20260907/production_path/README.md)，没有改写原型收据或把两组 266 条检查累加为新场景。归档期间继续修改的 Battle/project 文件不属于这三轮已受测字节，历史副本和差异摘要已单列。

[玩法 RNG 的双进程 184 条检查](RUN_GAMEPLAY_RNG_20260907.md) 是另一份模块合同；它没有将本轮组件测试变成跨进程 Battle 恢复验收。

证据、逐轮源码映射、失败原文和复跑说明见 [QA 归档](../qa/run_resume_components_20260907/README.md)。这批模块没有降低 M3 的整局验收要求：标准 30 波的 Battle 字段、玩法 RNG 与时钟、持续效果、快照屏障、失败原子性、关闭后再开和持续行动对照，仍需由完整恢复事务验证。

## 合入成就与工坊后的组件复测

受测源码集为 `fe1faf5a71b92a81b4404c8f35cce2b648d50a49` 加上述五个正式模块，具体文件以每轮 manifest 为准。Unit `20260906T190047879205Z`（PID13232/149条）、Projectile `20260906T190128073061Z`（PID14024/54条）、Map `20260906T190208572861Z`（PID36160/63条）均 exit0、完整报告与严格日志通过，源码和真实玩家文件前后摘要一致，锁已释放。新 Autoload 与 Battle 源码的精确身份随 [integrated_head](../qa/run_resume_components_20260907/integrated_head/README.md) 单列保留。

这是同一组组件在新源码集上的兼容复验，不增加独立场景数量，也不代表 Steam 成就/工坊联调、完整 Battle 或导出包续玩已经验收。当前发布版本仍由 Steam 发布记录单独管理。

## 李逵飞斧待结算效果恢复增量

[run_li_brawn_axes_state.gd](../scripts/run_li_brawn_axes_state.gd)已按原型同字节晋级，SHA256为`cd8662a38012cc4739e403a4b9eb12023c55eb5bf0d750cbf6640b063f591fde`。它显式保存pending时钟、Node状态、caster及有序hits/原伤害，纹理只使用固定可信引用或原程序绘图标记；先创建禁用的真实嵌套效果，再绑定新Battle/Unit图，交由外层统一激活，不在恢复时提前结算伤害。

原型run`20260906T190607921584Z`（PID5796）和正式路径`20260906T191522544612Z`（PID30268）各46条检查通过，均exit0、来源/玩家前后摘要一致且共同锁释放。每轮16条来源前后与30条其余检查，覆盖真实JSON、暂停绑定、首个已释放目标后的活目标一次命中、新Battle一次impact、重复resolve保护及实际queue-free/退出。同组检查复验不累加为独立场景；[飞斧归档](../qa/run_axes_20260907/README.md)保留原始报告、进程、晋级与精确源码映射。

归档/晋级时既有已同步基线为`9bcda9ef510cab041081d0e2bf23addfe0593d02`；较早原型受测文件仍以其manifest为准，不回写Git归属。本增量未接完整Battle/RunSession，未覆盖其他全部持续效果、整局跨进程续战、菜单或PCK恢复，不改变M3验收要求。

## ground/hua/lin 三数组持续效果增量

[run_continuous_effect_state.gd](../scripts/run_continuous_effect_state.gd)与原型同字节，SHA256为`4b1d6214cd760039110b7154555c06a86ffd8ea9dbeb6ca6da8102e24bb2726d`。仅显式保存`_ground_dots`、`_hua_snipe_dots`、`_lin_duels`的剩余字段、时钟、数组顺序和none/已释放/活对象引用；不重启计时，不在绑定时结算伤害、治疗或奖励，缺失引用及已占用目标数组在赋值前拒绝。

原型`20260906T191947368450Z`（PID40452）及修正后正式`20260906T192639802801Z`（PID40280）各52条通过，其中16来源前后与36其余；exit0、源码/玩家摘要一致、锁释放。真实pass续算剩余3次地火和4次按当前最大生命计算的百分比流血；真实队友击杀后直接调用原决斗死亡消费者，回血、Q/W复位与奖励效果只发生一次，重复回调和奖励后再保存恢复均不重复发奖。[持续效果归档](../qa/run_continuous_effects_20260907/README.md)保留完整两组版本证据。

首轮正式`20260906T192154836197Z`实际运行正式driver，但runtime manifest仍指向原型driver；其52项与exit0原文保留为manifest coverage gap，不改成引擎失败，也不充作正式driver完整版本证明。仅修正runner目录后新增最终run，旧runner和修正记录独立归档。相同组件复验不累加为新场景；本增量不覆盖其他14类效果、完整`_on_unit_died`清理、玩法RNG或Battle/RunSession整局，不改变菜单/PCK及M3验收要求。

## Unit sibling 与 active 顺序图增量

[run_unit_graph.gd](../scripts/run_unit_graph.gd)与原型同字节，SHA256为`633b631234664fb1abf17d738a6be8599d0c1c9eb55620d495cab51da06f6319`。组合已受测Unit与整数身份模块，先完整校验所有记录，再依root顺序创建并绑定新Unit；root_order包含dying节点，active_order独立保存，持久ID不由字典顺序或native ID推导。实际五Unit夹具核对矿工/等待、驻军双向及重复关系、命令/失效引用、身份池和物品UID/相位；末条坏记录在分配前拒绝，原图不变。

prepare不赋值Battle数组，不挂接、连接系统信号或激活；成功返回两份顺序、新图和同一份仍开放的identity，以及仍存活的typed tombstones，`tombstones_released=false`。外层必须先通过该identity完成所有Battle/FX/整数图绑定，再统一`identity.release_tombstones()`、安装顺序与监听并激活。测试证明后续未见的retired目标/来源仍能绑定，显式外层finish后引用才成为真实已释放对象。后续保存保留同一identity；它不是全局实体/物品UID或tick分配器。

原型`20260906T192949868331Z`（PID41376）及正式`20260906T193154174815Z`（PID33580）各73条通过，含20来源前后与53其余；两轮实际command入口及driver SHA与manifest完全对应，exit0、源码/玩家保护和锁释放通过。[Unit图归档](../qa/run_unit_graph_20260907/README.md)保留原准备pins/README，不将“尚未运行”历史改写。相同组件复验不新增场景；不运行Battle._ready/部署，不证明经济/效果/磁盘恢复、整局失败原子性、全局UID/tick、跨进程Battle、菜单UI或PCK验收。

## 第9组件：运行时玩法 RNG 与独立 PCK

[run_gameplay_rng.gd](../scripts/run_gameplay_rng.gd)与runtime原型同字节，SHA256为`7705f9e054f3cf4e422623b280dea3bebc1ec4509f768ed8094078f0123d7e45`。构造时由外层注入可信content_version，兼容校验继续约束引擎/平台和模块、codec合同；不让存档自证版本，不依赖导出后不可读的原始`.gd`哈希，保留原seed后state恢复顺序及独立原生随机调用。

源码run`20260906T193936497244Z`的writer161/reader47通过；PCK R1`20260906T195011243688Z`（PID20224/41908）与正式资源路径`20260906T195239912542Z`（PID1400/2596）各writer24/reader33通过。三份原始`.gd`不可读而编译资源可加载，七种有符号种子各64个后续混合值及终态跨进程一致，不受无关全局随机噪声影响。实际PID/user、stdout、manifest、handoff/报告哈希及源码/玩家保护均核对；正式路径重验同一57项矩阵，不新增独立场景。

原PCK`20260906T194037811287Z`导出exit0，writer虽落盘24项true且内部complete=true，报告Dictionary复读守护仍令其exit2，stdout缺失、reader未启动；整轮失败原文保留。已定位旧_write在成功写出报告后、stdout前返回false；Engine元数据经JSON往返的类型变化是可能解释，StringName/String键型未单独实测，具体根因未确定。R1只改_write为精确落盘字节加parse成功，其余driver和RNG判断保持，随后整轮通过。[运行时RNG归档](../qa/run_gameplay_rng_runtime_20260907/README.md)保留旧/新driver、runner/pins、模板及精确复用依赖，不保存PCK、私有工程/profile或玩家文件。

该模块是第9个正式恢复组件，但未迁移Battle随机调用，也未接RunSession、整局跨进程持续战斗、菜单或整游戏PCK续玩。本批独立夹具PCK合同不替代M3整局验收，后续其他生产变动不纳入其历史源集。

## 第10/11组件：物品 UID 与四数组区域效果

[run_item_id_state.gd](../scripts/run_item_id_state.gd) SHA256 为 `8bb221e918790ef8e8cd898c7222438cf7316c4ba180c09a8dd5663180ebfae4`；[run_zone_effects_state.gd](../scripts/run_zone_effects_state.gd) 为 `69c66e349fbb508673856e6377e7fe24b3c76a4adc300cc1e98c0bee70c78c38`。两者与原型同字节。同批 Battle/Inventory 实测字节为 `d88caffd78a8530a79521262199a7ce116b2d0f5631c16cac136b6fa38552af5` / `ab2d40f51695a4141bea1566a997883cc839f36bf6781fc0977151162d4fc595`，原始候选、builder及修改前来源保留。

Battle next_item_uid 替代 ObjectID 与局部序号计算；换格、同域转移和可信复活保留UID，满栏/跨域/坏域/耗尽时在破坏源库存前拒绝。INT64_MAX为耗尽哨兵；补已有stack不占号，未接收数量返回调用方。counter用既有int64 codec通过真实JSON保存高水位，安装只接受尚未使用的新Battle。外层可信最大UID证明须覆盖所有活/死亡库存、退休进度及proc/待施放等别名，不能取存档自报值或活动六槽最大值；先完成整图验证与counter安装，才允许创建物品。

53项allocator run `20260906T195440680513Z`（PID28160，16来源+37其余）及原Unit回归 `20260906T200247535257Z`（PID34988，原149项）通过。真实复活 `20260906T200720412333Z`（PID37340）231项=198来源+33行为/宿主，通过正式counter在两个空Battle间的JSON和后继检查；另在两场依次完整释放的标准驻守Battle完成原物品自检及真实付费复活链。原自检唯一九项及ALL全true。坏库存导致生成失败时保留付费队列/退休进度，反复重试不多扣费、不留失败Unit；取消全额退款，正确原snapshot重练保留UID/数量/两类冷却和成长，成功只装一次。战斗暂停、训练计时显式加速；不代表所有spawn/购买/正常训练时长验收，也不另计一次53项负例。

区域只恢复 `_chrono_zones/_orbit_zones/_fire_trails/_ice_walls`。原型 `20260906T195639137986Z`（PID30560）与正式 `20260906T195836771214Z`（PID17848）各81项=42来源+39其余，20组真实原pass对照验证剩余两次orbit伤害、trail第2/5/8/11步落火及叠墙第3/6步按份释放、独立建筑计数保留。先恢复地图权威与导航再绑定墙数组，不重复登记墙；全部图共享引用上下文并完成绑定后，统一释放临时墓碑、安装和激活。Unit状态与既有地火由外层夹具提供，既存视觉Node未由本模块重建。

[本批五轮档案](../qa/run_item_identity_zones_20260907/README.md)保留全部真实日志/收据、99个复活运行源码映射与精确旧依赖。五轮入口均被各自manifest覆盖，exit0、源码/玩家前后与锁释放通过。原Unit与正式区域只重验既有矩阵，不新增场景计数。本批推进至11组件，尚未完成RunSession整局事务、全部效果与视觉、Battle随机调用接入、跨进程整局继续、菜单或PCK验收；后续标准驻守关卡草稿不在本批证据内。

## 第12组件：陨石与守卫

[run_meteor_wards_state.gd](../scripts/run_meteor_wards_state.gd)与原型同字节，SHA256 `35d7ed60320167d1c72e840a2ce6193fe6ea3bba62abac319033a4bcc3636fa3`。新增 `_meteor_zones/_wards`，权威数组累计9/17；原型 `20260906T201655159599Z`（PID40312）及正式 `20260906T201847036187Z`（PID41376）各54项=18来源+36其余，同矩阵复验不增加独立场景。[归档](../qa/run_meteor_wards_20260907/README.md)保留精确模块、两driver/runner、原准备合同及复用来源，两轮入口均在manifest中，report/stdout/PID、源码/玩家前后、exit0和锁释放核对通过。

meteor有序hit使用真实identity目标域entity/retired token，映射新正整数ID；不复制旧ObjectID，不接受scalar/source-pool token或重复/碰撞。payload保存ward_serial并返回required_ward_serial，bind只接受根已安装的精确serial，不代写或递增。Unit既有攻速/减伤来源池属于Unit层，不能重新施法补造；任何bind失败丢弃整份私有事务，即使Battle数组未写，decoder也可能已经分配墓碑。先完成所有图绑定，再统一释放墓碑、安装、启用。

25组原_zone_pass/_ward_pass与真实Unit _physics_process计时对照证明旧陨石目标不重击、新目标仅一次、地火第10/20步按余程生成、守卫脉冲相位保持，忠旗到期降到仍有效义旗并逐来源TTL清空；空数组不重授。下次真实建桩使用serial6，不复用旧1–5。Unit局部值和既有来源池由夹具独立提供，非完整Unit恢复组合。

MeteorFx/WardFx等既存视觉仍需保存life、t/dur、style及私有动画/随机字段，不能重新_ready生成替代原状态。本批只证明两数组、真实消费者和Unit计时，未验收旧视觉重建、RNG隔离、一般未来实体分配、其余8数组、整局跨进程继续或菜单/PCK。后续标准驻守关卡草稿不在本批；M3整局未完成。

## 第13组件：标准驻守 Level 与完整 Unit 图安装

[run_defense_level_state.gd](../scripts/run_defense_level_state.gd) SHA256 `5cb83ac01cddcdab0865434caa5e0de5ec8e5d1f28a746c657dc745e7ca4aa91`，与原型同字节。覆盖标准skirmish全部12个声明状态：10个值字段（含30波cache）、hall和末波采样身份；只接受已started的经典30波原表。注入可信版本与固定Script，不动态load存档路径、不读源GD或调用_waves/on_start/deploy。

原型 `20260906T203250821538Z`（PID37800）和正式 `20260906T204006999300Z`（PID34732）各253项=200源码前后+53功能/入口，均exit0、完整/源码/玩家保护/锁释放true。每轮100运行源码完整映射，实际入口在manifest中，报告/stdout/PID/user与SHA一致。正式重验同矩阵，不新增场景。

每轮只初始化一个真实Battle，通过原启动下达五工人采集后给一人Stop。剩余102.75秒时保存完整Unit图和Level，经JSON→UnitGraph.prepare→同一开放identity下Level.restore，根夹具再释放旧Unit、连接原died/story回调、按保存顺序挂接激活。完整Unit值/库存/引用与Level回捕一致；Stop不被重发采集覆盖，余时不提前，原process实际生成6刀兵/3弓兵/1投石车并进入下一波32秒，继续推进不重复。

末波显式设置wave30作为边界，未实际打完30波；真实采样保存quiet4/tick1.25。显式移除敌军、实际spawn同位置/血量替代者，旧采样含1retired+9entity；第二次Unit+Level安装保留这些身份与余拍，quiet到点同参考分支增至6，再因真实40px移动归零，真实四拍累计8秒才触发Battle.final_wave_cleanup。该替代不是击杀/奖励验收。

两次安装复用同一个Battle/Map/Defs容器，金木与地图grid/block_count/revision保持；_ai_spawn_serial由夹具保存值回设。全局RNG未迁移/重seed，兵组与攻击移动意图匹配不等于随机坐标/精确路径重演。身份解码途中失败应丢弃私有上下文，全部系统绑定后才释放墓碑；此单层结果不能代替完整根事务。

[归档](../qa/run_defense_level_20260907/README.md)保留原pins/preparation/README及晋级脚本。正式pins的driver字节数仍为原型22,071，实际22,056；其rawSHA及运行manifest正确，source index按实际值记录并单列描述差异，不将整轮改为失败。未测试Battle/地图整体恢复、全部效果与既存视觉、退出重启、菜单/磁盘/PCK；权威数组仍9/17，施法流程候选与后续RNG工作未计入，本批后M3整局仍未完成。

## 第14组件：走近、抬手与引导

[run_cast_flow_state.gd](../scripts/run_cast_flow_state.gd) 与原候选同字节，15,409 bytes，SHA256 `127a230696570b50207fd06a3c4e7a4f33dad7bb24d33a333e4d136343976587`。覆盖_walk_casts/_pending_casts/_channels，权威数组累计12/17；walk全部c/slot/tgt/point/serial/t/age、pending全部caster/slot/lp/tgt/serial、channel全部caster/center/eff/sc/rank/r/tick/tick_t/ad显式保存。eff/ad完整走有预算codec，缺失可选键保持缺失；单体walk的Vector2.INF仅在该字段编码为unit_target标记，点地要求有限point，不放宽普通codec。

首轮 `20260906T204913855863Z`（PID40952、exit1）保留原生产真实错误：_tick_pending_casts中target != null漏过previously freed Object，再传给_do_ability第4个typed Unit参数，strict log触发host失败且无report，不能推算检查数。原Battle SHA `d88caffd78a8530a79521262199a7ce116b2d0f5631c16cac136b6fa38552af5`；仅pending/walk两处加typeof Object且无效前置拒绝，再把pending已检查局部变量传入原API，修复SHA `47357265c54a8cd6c2a5fef24998e357773974843559c4e23965ea3e0d51b629`。三处编辑在unified patch中为两个hunk，不含物品consumer修改。

R1 `20260906T205452854069Z`（PID23352、report `2df604f8d1773044c458754dec8006c2a8db9b33ccfc13af093df75e651cc9a0`）及正式 `20260906T205651467321Z`（PID32308、report `f5035b08449ab4803d4c1624a82e1f98c2ea1059b34806c5ca3426476a03f841`）各63项=32来源+31功能/宿主通过。R1 driver与首轮原字节相同；正式只改模块preload路径。各轮16来源、实际入口、PID/退出与源码/玩家保护/锁均核对；通过轮report与stdout/user/SHA一致，正式重验不新增场景。[归档](../qa/run_cast_flow_20260907/README.md)保留全部原始失败/通过材料、旧/新源码映射、patch/application和三版准备/runner/pins。

模块由可信版本和固定Script构造，不运行时读GD哈希或动态load存档路径。bind只接受树外DISABLED且阻断信号的空Battle壳，完整校验后一次赋三数组，不下命令、寻路、重新施法或扣冷却。Unit原_cast_t/_cast_serial、channel时钟、ability_slots、order serial/路径/队列/目标/控制状态必须由外层先恢复；required_unit_fields仅是依赖声明，不是完整Unit适配验收。过期计时/不匹配serial保留给原消费者；expired引用绑定同一开放identity的活类型墓碑，所有图完成后再统一释放并安装激活。

真实Battle/Unit/GameMap/LevelBase/HUD空壳与原creator产生两个walk模式、剩余抬手和已走一跳的channel及真实释放引用；JSON绑定后回捕与Unit局部状态相同且无新FX/CD/命令。25步原consumer及真实Unit计时体对照验证pending第3步一次、walk第7步一次、channel第4/8/12/16/20步五次；真实新order_move及apply_silence取消对应流，过期目标不扣CD，空数组不重复。第3步到达位置由夹具显式供应，非完整移动仿真。新生成FX数量对照不代表旧视觉Node恢复。

本批仍依赖夹具供应Unit局部值/库存外层/原路径/可信能力定义，没有完整UnitGraph+Battle事务组合；旧视觉、物品施法与其他效果、一般未来实体分配、RNG隔离/迁移、退出重启、菜单/磁盘/PCK续玩未验收。后续物品候选与其消费者缺口未纳入，本批M3整局仍未完成。
