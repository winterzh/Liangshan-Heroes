# 前段首次资源/技能音归因备忘

2026-09-06。只读研究；未运行 Godot，未修改生产、公共工具或 Git。补充 `scratchpad/pressure_hotspot_next.md` 第 4 节的具体调用集合，不重复物理步预算与历史帧率分析。以下是可测假设，**没有把任何首次调用认定为已出现长卡顿的原因**。

## 1. 结论与来源边界

- 标准 `defense200` 是**含李逵在内共 6 英雄**。李逵 Q/W/R 以及 E 蛮力触发的双斧都用启动时预建音效；不应以“李逵第一次放技能合成音频”为首要假设。其首次斧头贴图请求只创建图集区域对象，整张图集已由 Art 启动加载。
- 惰性技能音集合是公孙胜 4 个、武松 4 个、宋江 R、花荣 E/R，共 11 个能力 ID；**可合成不等于标准前段实际施放**。花荣 E/R 的托管高价值目标条件不被初始刀盾/弓手满足。应记录实际事件，不能强放这 11 招冒充夹具。
- 动画首次动作/方向仍会同步 `load`，然后切帧或解析 SpriteFrames 子资源；宋江、林冲 `.tres` 路径首次解析有两次加载函数调用。需测实际耗时与缓存状态，不能按调用次数假定两次磁盘读取。

根任务给定同步基线 `4baafc1`。阅读时真实 Battle/Unit 正被其他代理临时插桩，因此本文这两个文件的行号统一按已核验的 `scratchpad/physics_step_diag/frozen/{battle,unit}_original.bin` 对应生产正文；没有把临时插桩当稳定源码，也没有执行 Git。冻结文件与 `scratchpad/physics_step_diag/pins.json` 摘要相符。其余脚本直接只读当前文件。LF SHA-256：

| 来源 | SHA-256 |
|---|---|
| Battle 冻结正文 | `784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c` |
| Unit 冻结正文 | `c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec` |
| `scripts/sfx.gd` | `ed3e9e5527b68d47ff02ffc53e75256d1483287dd29f512165c8086c75232f1b` |
| `scripts/art_db.gd` | `e3e871b85fa87e17c047de58a5d2ea13bed34fd7772027145b64026383024996` |
| `scripts/defs.gd` | `a2f9a9fe9a669829871c0bcb9fd9295b451e8b9744993deb4f007ab1d80607fb` |
| `scripts/ability_visuals.gd` | `4d980ca87f5269a307ff36c3dbd4733d93aab4c80ac54b41b1438eeecb323ab8` |
| `tools/polish_performance_probe.gd` | `04a47115c8cd05670b465086653491466fdae99f6fadf9c41c40379aee0c1407` |

## 2. 实际入口与六英雄声音路由

`project.godot:30,33` 的实际 Autoload 是 `Art → scripts/art_db.gd`、`Sfx → scripts/sfx.gd`。M1 探针 `:91–106` 保持声音逻辑，只静音 Master；`:169–174` 等待 Music 线程完成 4 首 calm 与 4 首 battle 曲，不验证技能音缓存。`:108–123` 在场景建立前和夹具生成前各 `seed(5088120)`；`:181–190` 经过 300 个实际物理步及一次真实画面提交才开始采样。因此“前 10 秒”指**预热后的 10 秒墙钟采样**；首次生成既可能发生在启动/预热，也可能落在测量段，需跨越三个阶段记录。

`Battle._perf_bench_setup:2290–2313` 使用宋江、花荣、林冲、公孙胜、李逵、武松，槽位全 rank 2、CD 归零、托管 3，初始 200 敌仅两种普通兵。调用链：`_physics_process:2340` → `_auto_micro_pass:4496`（战斗生成序号分相位）→ `_auto_micro_hero:4809` → 各 `_brain_*` → `_ai_cast_slot:8824` → `_begin_cast:6777` → `_tick_pending_casts:6828` → `_do_ability:6982`。最后在目标、就绪和关卡接管检查后，`:7009–7013` 才选声音；不能把 AI 尝试等同于已经施放。

| 英雄与实际槽位 | 声音路由 | 标准前段触发限制 |
|---|---|---|
| 李逵 Q `li_axes`、W `li_charge`、R `li_fury` | 预建 `sk_axes` / `sk_charge` / `sk_fury` | `_brain_li:4968`：W 中距 90–210，Q 120 内，R 150 内被围或低血；没有首次合成 |
| 李逵 E `li_brawn` | 被动；`Unit._try_li_brawn_axes:2066` → `Battle.spawn_li_brawn_axes:816–843` → 同一 `sk_axes` | 普攻概率触发及飞斧命中属于实际战斗，不能提前执行来准备资源 |
| 林冲 Q `lin_thrust`、W `lin_sweep`、R `lin_chrono` | 预建 `sk_thrust` / `sk_sweep` / `sk_thrust`；E `lin_predator` 纯被动 | `_brain_lin:4867`；R 只对敌将，初始两种兵不满足 |
| 宋江 Q/W/E `song_rally` / `song_banner` / `song_fire` | 预建 `sk_rally` / `sk_rally` / `sk_fire` | 战团/血量/范围条件 |
| 宋江 R `song_lead` | 惰性 `ab_song_lead`；传入 `rally_heroes`，兜底通用主题 | `_brain_song:5217`，英雄重伤/关键控制或自身受威胁；虽有 passive 标记，仍有 active_kind，不能漏计 |
| 花荣 Q/W `hua_blink` / `hua_rain` | 预建 `sk_blink` / `sk_rain` | 逃离贴脸或覆盖敌群 |
| 花荣 E/R `hua_pin` / `hua_blade` | 惰性；`hua_pin_target` / `hua_snipe`，均兜底通用主题 | `_brain_hua:5051`、`_hua_high_value_target:8672` 要高价值目标；`Defs:32–33` 刀盾 85HP/9 攻、弓手 55HP/7 攻/165 射程均不达门槛；后续波次另记 |
| 公孙胜 Q/W/E/R `gong_blackrain` / `gong_icewall` / `gong_slow` / `gong_dragon` | 四者惰性；依次 `black_rain→fire`、`ice_wall→ice`、`beast_stampede→通用`、`summon→beast` | `_brain_gong:5153`；R 无存活龙且敌在 720 内，Q 成团，E 成团/近身，W 保命或骑兵拦截 |
| 武松 Q/W/E/R `wu_tigers` / `wu_wine` / `wu_blades` / `wu_drunkgod` | 四者惰性；`summon→beast`、`drunk_buff→通用`、`smite→通用`、`drunk_god→通用` | `_brain_wu:5000`；Q 缺虎且有敌，R 被围/低血，E 周围有敌，W 健康且附近有敌 |

集合依据 `Defs:12,18,22,57,70,137`，具体效果 `:433–437,449–461,497–563`，映射 `Battle:211–216`。**`AbilityVisuals:6–12,32–53` 明确排除六英雄及其技能**；当前 `content/` 不存在。因此不能从“黑雨/双刀/醉神”等名字推定 shadow/blade/holy 主题；上表是空 visual theme 经 `Sfx._KIND_THEME:283–289` 兜底的实际结果。

## 3. 真实同步工作与缓存边界

| 路径 | 冷/热边界与耗时性质 |
|---|---|
| `Sfx._ready:19–25` → `_build_bank:106–147` | 普攻、死亡、点击、已映射技能 WAV 在 Autoload 启动生成，并建立 10 个 AudioStreamPlayer；不是每次攻击重新生成 |
| `Sfx.play_ability:79–85` | 缺 `ab_<aid>` 才同步 `_build_ability` + `_wav`；热调用直接 `play`。无线程/await，确有同步 CPU 循环，毫秒成本尚未测 |
| `_build_ability:291–354`、`_wav:150–161` | 22050Hz 逐样本 tone/glide/noise/pops/mix，归一两次遍历，再逐个编码 16bit 样本并分配 AudioStreamWAV。嵌套函数耗时不能重复相加 |
| `Art._ready:277–310` → `_try_load:313–316` | 常规人物/地形/肖像/建筑/物件/技能图集在启动同步加载；李逵使用的 `fx_items.png` 在 `:308` 已加载 |
| `Art.item_texture:459–462` → `_atlas:343–352` | 首次 `item_axe` 创建一个 AtlasTexture 区域并缓存，不在这里重读整张 PNG。Q `Battle:7238–7247` 与蛮力 `:838–840` 共用它 |
| `Art.unit_anim_frames:595–688` | 按别名后的 unit/state/direction 缓存；首次动作/方向通过 `_load_generic_directional_frames:716–733` 同步 `load`；PNG 由 `_slice_anim_strip:736–747` 创建 AtlasTexture，TRES 解析依赖并读取已有帧；legacy 在 `:662–672` load+切片 |
| `.tres` 首次查找 | `_resolve_generic_directional_path:703–712` 在 PNG 不存在、TRES 存在时调用 `_load_generic_directional_frames(path)` 验证，返回后 `unit_anim_frames:638` 再调用一次。可能命中引擎缓存，也可能重复解析/分配；代码自身没有持有 SpriteFrames 的专用缓存。只证明两个边界，不证明两次 IO |
| Art 其他首次路径 | `_content_override:335–340` 负查缓存；`tower_sheet:498–502` 惰性塔图；`portrait_texture:542–548` 独立肖像；`_campaign_texture:789–795` 战役资源。是否落入本段须看实际调用 |
| 地形平均色 | `terrain_avg_color:856–875` 首次 `get_image/convert` 和稀疏采样，之后缓存；入口 `GameMap._blend_color:579` / `_draw_blends:818`，不是英雄技能成本 |
| 公孙胜 E 图与实例 | `BeastStampedeFx:15154` 使用 `preload("res://assets/vfx/gong_beast_charge_run.png")`，不是首次 E 才调用 load；但不据此断言 GPU 已热。实例 `_ready` 建 7 个布局项是每次工作 |

`SkirmishFrameAlignment.annotate:65` 用常量元数据，不运行像素扫描。虎/龙由 `Battle._do_summon:8988` → `spawn_unit:579` 产生新 Unit；首次显示可加载虎/龙 walk/attack。召唤、特效对象和伤害处理属于每次技能工作，不能全标成首次资源成本。

只读确认的相关动画分布：宋江四向 idle/walk/attack/death 为 `.tres`；林冲相同，另有 hurt `.tres`。例 `assets/anim/song_jiang_attack_se.tres:3–20` 依赖独立 idle、attack PNG，并定义 AtlasTexture 子资源。李逵四向 idle/walk/attack/hurt 为 PNG，death 仅 legacy，另有四向 down；标准死亡调用 `Unit:3348` 的 death，不能把 down 图算入标准死亡。刀盾/弓手有四向 idle/walk/attack/death PNG，缓存按类型/动作/方向共享，不是 200 敌逐个加载。花荣、公孙胜、武松常规四动作仅 legacy；虎/龙只有 legacy walk/attack。花荣虽有旧 melee 文件，当前 R 不切武器，不能据文件存在断言调用。

真实画面入口 `Unit._draw:3711` → `_draw_sprite_animated:3317` / `_anim_frame_for_state:3613`：受击取 hurt（`:3643`）、攻击/施法抬手取 attack、移动/待机取 walk/idle、死亡另取 death。受击/死亡或镜头/追逐改变朝向可能晚于预热；实际时间待测。

## 4. 预热副作用

1. **全局 RNG 会改变。** `_build_ability:292–294` 虽用局部 RNG 和 aid hash，`_noise:182–188` 却调用全局 `randf_range`。通用主题冷合成固定消耗 `int(0.16×22050)=3528` 次全局噪声随机数；黑雨 fire 噪声长度由局部 RNG 决定；ice 主题合成本体不调用 `_noise`。正常 `play:100` 通过节流后还消耗一次全局音高随机。全局随机同时用于 Unit 暴击 `:1970`、武松醉酒 `:1176–1177,2927–2928` 等。
2. **第二次 seed 前预建也不等价。** 虽重置预热阶段随机消耗，真实首次施放随后会跳过本应消耗的数千次噪声随机数，后续战斗仍可能偏移；第二次 seed 后预建则提前消耗。不能靠重设种子宣称行为相同。
3. **播放状态改变。** 预播改 `_bank`、`_last` 墙钟节流、`_next` 池位置、流/音高和播放状态。总线静音仍合成/播放；`enabled=false` 在生成前早退，删掉真实工作及随机消耗，不能作为无副作用基线。
4. **对象分配时机改变。** WAV、局部 RNG、AtlasTexture、载入的 Resource 都是实际对象；提前生成可能改变后续 ObjectID。Art 未发现随机调用，但不等于无身份/渲染影响。`Unit._queue_motion_redraw:1051` 在 mob>260 时按 ID 分 stride 2/3；本标准初始约 206 活动单位、正常虎龙约 209，不能声称此门槛在首段必然开启。英雄 AI 已在 `Battle:607–609,4523–4525` 使用战斗生成序号，**不是 ObjectID 分帧**。
5. **不可提前执行技能。** 召唤、旗阵、飞斧、CD、控制、目标、生命和随机收益都会变；先打一次再清几个字段不足以恢复。延长 M1 warmup 也改变测量压力与首次入战体验。

## 5. 最小归因实验（未执行）

先做一次“原行为 + 首次事件时间账本”，不先比较关音效或预热 FPS。以冻结摘要建立临时工程镜像，生产 checkout 的 scripts/assets/tools 不写入；镜像只对 Sfx/Art 加记录，采用原 M1 夹具和现有物理步账本边界。镜像记录器的初始化与对象数在诊断模式一致，并在夹具建立前准备。Godot 独占运行仍由根任务安排；本稿未生成/运行实现。

- Sfx：`play_ability` 记录 aid/theme/kind 与 miss；仅实际 miss 分开计 `_build_ability`、`_wav`，另计整体。原函数只调用一次、顺序/参数/输出不改；热调用仅累计次数，同时区分预建命中。
- Art：仅在真实 `load(path)` 边界记录路径和起止，标明 resolver 验证/directional 正式读/legacy；切片与帧数组工作分开计。`_atlas` 实际 miss 计次数/耗时，不为日志主动调用加载器。启动、预热、测量边界记录已有缓存键，防止把预热前首次算入测量。
- 共用 `Time.get_ticks_usec`，附物理 tick、process frame、`Engine.is_in_physics_frame()`、阶段；对齐真实 `frame_post_draw` 帧时间及每帧物理回调数。预分配基本数值数组；热循环不 print/写文件，不新增 Node/RefCounted，不额外取随机数；结束后导出，缓冲溢出即无效。

先 fixed 1×10 秒预检；有效后再 fixed 两个独立进程窗口，总计 3 次。保持正常 Music 完成、300 步、60Hz/1x、1440×900、Vulkan Forward+、Master 静音，并记录整个启动/预热。另跑一次同镜像关闭详细计时、保留同等初始化/容量的控制窗估计记录开销；它不是生产候选。不先扩到 auto 或海量预加载矩阵。

输出：来源前后摘要、参数、初始单位/血量/槽位/AI 相位、三个阶段边界、原始事件和帧行、命中/未命中数、每资源/技能首次耗时、按帧合并的**区间并集**和长帧占比。不得重复相加嵌套时间；load 内测到的是调用者同步等待，不能全改名纯 CPU，也不能把余下帧时间全叫 GPU。

判定：若合成都发生在预热前，或测量中耗时微小且不与长帧重合，此集合不能解释长帧，提交否定结果后回到物理预算；若某个 miss 占长帧显著比例，记录独占/并集时间与复现率，仍区分相关与因果。只有命中后，再在**无战斗的独立进程**重放记录到的 aid/theme/kind 或 Art 路径，对比首次与缓存命中同步成本；声音调用原合成/WAV函数，不执行战斗技能。该夹具可使用独立种子，因为没有活战斗需要保持；Art 引擎进程未载入不等于 OS 磁盘冷缓存，加载与第一次真实 Canvas 提交分开报告。函数成本不能冒充 FPS 收益。

尚待测：11 个技能实际首次时刻/前段子集、Art 真实加载与重复调用耗时、长帧重合度、记录开销。无真人或性能达标结论。
