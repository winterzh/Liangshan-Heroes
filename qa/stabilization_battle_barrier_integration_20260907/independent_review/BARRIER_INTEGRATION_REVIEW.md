# 实际 Battle 屏障接入独立复核

2026-09-07。本 QA 支线只读审查四个候选源码，并独立回读 ROOT 执行的
`overlay_20260907T090717Z_76d7e04e` 原始 report/receipt。没有自行启动
Godot、修改生产或 Git。本结论支持把本轮已验证的经典新游戏捕获基础模块
交给 ROOT 按白名单接入；不等于“继续本局”功能完成。

## 源码身份

逐文件核对：最初封存候选、`attempt_r4/candidate/scripts/` 和 R4 私有
工程实际执行源码三个位置 SHA-256 完全相同。

| 文件 | 复核 SHA-256 |
| --- | --- |
| battle.gd | 89898d76b40a1fb850aabd205f7906a6aef481c5b3e5fa19d5a56156f69aab1e |
| run_battle_barrier.gd | 21adddbda03066a1f1a2ec62e21f79cfdd675892c6481bdd545f89b643c4f227 |
| run_battle_clock.gd | 36d1cf72985e6f4edb6ada44bef0c67a121fba89566c0174752095414f9ff099 |
| run_battle_root_state.gd | 26e935a223dac79b1399056301d02469b63e7dd7cbb2cfe223fb3910942e3637 |

R4 来源提交 `f3da82f7452a2164c704c34a97c6b2696e99b9c3`；冻结 SHA
`cde2ddf8e6b99b45f309868b4d9715acc49680e055183a963dce6e84725f72d6`。
Godot 为 4.6.3，二进制 SHA
`ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`。

## 原生回读结果与计数口径

- Import PID 44364、driver PID 37040 均退出 0，错误数组均为空。
- `complete=true`、`passed=true`、失败 0。生产、玩家、私有源码和候选
  不变保护全为 true；所有子进程已退出，Godot PID 列表为空，共享锁已释放。
- 总计 **6,556 项检查 = 5,774 项源码 SHA 前后核对 + 782 项其它检查**。
  782 项包括注册表、元数据、字段和行为断言，不能写成 782 个游戏场景。
- 三个严格根状态往返用例 `default`、`viewport`、`fractional_negative`
  各有 203 项带该前缀的检查，共 609 项；根字段仍为 105 项，显式时钟 1 项，
  外部字段 66 项，对应 172 个声明。全部原始测试字段在恢复运行前已还原。
- 两个 `exit drain` 各 18 项，共 36 项；其余 137 项包含真实开场、注册表、
  暂停屏障、首批效果伤害、负例及释放检查，不是额外 137 个场景。

## 实际伤害与清理事实

真实 `spawn_unit` 创建测试单位，只有两测试单位的自主 physics 被关闭；
Battle、空间格更新、Projectile 和飞斧消费者由真实引擎推进。两对象都采用
真实 Battle 创建器，不手动调用命中、寿命或 `_process` 消费函数。

| 用例 | 实际回读 |
| --- | --- |
| Projectile 待命中时捕获 | HELD 五个真实物理帧期间 HP、位置、寿命保持；释放后真实物理伤害一次并自行释放；进一步运行无重复 |
| LiBrawnAxes 待命中时捕获 | HELD 五个真实物理帧期间 HP、elapsed、resolved 保持；释放后真实 idle 伤害一次并自行释放；进一步运行无重复 |
| Projectile 真正 tree_exiting 请求捕获 | 回调一次、请求成功；观察到 physics=true，Engine physics=262 / process=573；HELD 前原对象已释放且 HP/英雄伤害统计已结算一次 |
| LiBrawnAxes 真正 tree_exiting 请求捕获 | 回调一次、请求成功；观察到 physics=false，Engine physics=301 / process=669；HELD 前原对象已释放且 HP/英雄伤害统计已结算一次 |

两个 exit 用例均继续验证 HELD 五个物理帧稳定，释放恢复运行后十二个物理帧
没有重复伤害/退出，原进程缓存时钟仍与 Engine 域一致，RNG 和时钟健康。
这里的相位数值是 `queue_free` 退出回调的观察值，不扩展为所有版本的内部
伤害回调顺序保证。原先 HUD/镜头输入关闭及保留用户暂停的检查也继续通过。

## 接入边界

当前 `_ready()` 仍为新游戏入口，会初始化新时钟/屏障，并对恢复 RNG 分支
返回 `RESTORE_FACTORY_REQUIRED`。根 v3 的脱树绑定不能直接通过这一路挂载。
后续恢复工厂必须保留已绑定时钟，使屏障引用同一个时钟对象，完成所有世界
引用后仅激活一次，并避免重复 deploy/on_start。

本轮没有验证完整世界创建、跨进程恢复、全部特效和死亡残留、嵌套异步任务、
实际磁盘继续槽或玩家继续菜单。屏障 `health()` 的树内检查也不能自动证明
任意 SceneTreeTimer、Autoload 或未来战役协程已静止。继续限制为官方经典
30 波模式的运行中捕获基础；不扩大到 AI、自定义、工坊或八关完整保存。

原始回读文件：

- `.godot/stabilization_overlay/overlay_20260907T090717Z_76d7e04e/report.json`
  SHA `d12fe932aff0a9540e55b5c1e27837e82cbcb261ace052b12928592b00a3bb67`。
- 同目录 `receipt.json`
  SHA `15ab154f4e32152205d4dc8a7fbd74a372bb582bd4a613e754a8c0f13453d21a`。

ROOT 收尾应保存这两份原始记录及失败尝试，按上述四份已执行源码和实际生成
UID 白名单接入，更新文档后再提交、推送和回读远端。
