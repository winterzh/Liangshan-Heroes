# 连环马：自然招募与同局三进程续玩

状态：三进程完整切片`20261026_175247_098b8c87`终态通过，27/43/30共100项，前后源码/引擎/驱动身份通过、锁已释放。实际训练累计20.0秒，仅首进程下单一次，同槽代际1→2→2、相同token，唯一新兵在第三进程继续21秒后没有重复生成。[汇总](evidence/success_20261026_175247/summary.json)与[原始收据索引](evidence/success_20261026_175247/manifest.json)。生产源码、公开续玩入口未修改；黄泥冈原版键鼠完整路线仍待验收。

`training.gd` 只下达一次普通 `Battle.queue_train(original_barracks, "gou_lian")`，通过真实菜单与开场/开战按钮进入连环马。真实扣除 36 金、24 木，预占 2 人口，训练时间由生产定义提供且必须为 20 秒；保持 60 Hz、倍率 1。工人继续正常采集，因此精确费用在同一次命令前后即时核对，后续资源按实际状态记录。

| 独立进程 | 行为与验收 |
| --- | --- |
| `save_training` | 正常模拟至少 5 秒，仍未成军时通过真实 capture barrier 和 RunSession 写入固定槽 `user://lian_train/v1`，得到槽代际 1。 |
| `resume_complete` | 读回前阶段的实际槽 SHA、建筑实体 ID、队列内容、剩余时间、资源、人口和逻辑时钟；继续剩余训练，只生成 1 名新钩镰手。训练完成时间在生产 Unit 更新之后的实际物理步读取，跨进程累计须为 20 秒（允许至多 2 个 60 Hz 物理步的边界/浮点舍入）。保留恢复所得 lifecycle 对象，以同槽及原 SHA 的 compare-and-swap 再保存，槽代际为 2。 |
| `verify_resave` | 第三进程恢复代际 2，核对相同新兵实体 ID、空队列和人口；正常继续 21 秒，确保没有重放训练、重复单位或二次人口预占，槽与 lifecycle 原始字节不变。 |

生产队列是字符串数组，**没有独立 job ID**。报告如实记录 `producer_entity_id + queue_index + key + order_tick` 作为此次队列观测身份，并明确 `native_queue_job_id_exists=false`；不伪造生产队列标识。报告同时给出原始钩镰手 ID 集合和唯一新兵 ID。

首轮headless `20261026_174132_583f4391`正常费用/5秒训练通过，首次保存因fog `TEXTURE_IMAGE_MISMATCH`拒绝（19/20项），故后继改屏幕外真实GL，未放宽生产纹理检查。

第二轮GL`20261026_174606_8c000c7a`已成功写入并在独立进程恢复同槽；首阶段26项通过，第二阶段21项中完整state/lifecycle字典比较两项失败。可读JSON中的状态值一致，但JSON读回会改变整数Variant类型并损失浮点位精度。驱动v2增加既有`RunStateValueCodec`编码的`exact_checkpoint`，前驱读回时还原精确类型及浮点位，再执行原严格相等检查；不改容差、不改生产存档。原GL失败终态、源码身份通过及锁释放记录保留；后继无损编码三阶段已完整通过，未回写旧失败。

当前生产 `RunSession` 能恢复并保留原 uncredited lifecycle token，无需 R12 候选即可执行此活动期切片。其 `local_continue_lifecycle_v1` 文档内部仍使用经典防守 context；报告分别保留**真实槽的 level4 context**与**真实 lifecycle 文档的经典 context**。这不证明 R12 的战役 context/账号绑定、终局 pending→applied、CFG 原子提交或奖励仅一次；这些资格全部为 false。没有清空 `_continue_receipt`、切换槽或重建 token 来掩盖差异。

## 宿主接线

三个进程必须串行，使用同一份已导入、内容冻结的生产工程和同一个全新短路径 profile。QA 两文件放在工程外，逐个 SHA 固定；不能向冻结工程的 canonical 输入目录放入 QA。

由 `run_training.py` 管理独立 profile、外部 bootstrap、前序报告 SHA、共享引擎锁和原生进程证据。以工程根为工作目录运行：

```powershell
python qa/lianhuanma_resume_20261026/run_training.py --base-run <已有冻结批次根> --timeout 360 --wait-lane 1800
```

`--base-run` 必须指向已有且身份可复核的冻结批次；复用其已导入 project，不修改该生产工程。下面列出 runner 与驱动的环境契约，供审查接线。

通用环境：

```text
STEAM_DISABLED=1
LR_PROFILE=<全新绝对 profile 根>
APPDATA=<profile>/appdata
LOCALAPPDATA=<profile>/localappdata
TEMP=<profile>/temp
TMP=<profile>/tmp
LR_PROJECT=<实际冻结 project 绝对路径，无末尾斜杠>
LR_WORKERS=<外部 bootstrap.gd 与 training.gd 所在目录>
LR_WORKER_SHA256=<training.gd 精确 SHA-256>
LR_NONCE=<同批随机值>
LR_MODE=<本阶段模式>
LR_REPORT=<本阶段新的绝对 report.json 路径>
```

B/C 额外传入 `LR_PREVIOUS=<直接前阶段成功报告>` 与 `LR_PREVIOUS_SHA256=<该报告 SHA-256>`。宿主先清除既有测试/模式环境变量，固定 bootstrap SHA，执行前后核对冻结内容和引擎身份；不沿用旧 V16 bridge/baseline。每阶段进程都执行：

```powershell
& $godot --path $frozenProject --rendering-method gl_compatibility --resolution 1280x720 --position 30000,30000 --script "$workers/bootstrap.gd"
```

宿主应保留实际 argv、PID、退出码、报告 nonce/模式/身份、日志与 profile 文件清单；三阶段报告均通过且原生进程正常退出后，才能给本切片完成标记。每阶段建议外层墙钟限额至少 300 秒，训练自身边界保持代码中的正常时间。不得据此声明自然教场演练、交战、终局、公开入口、发行程序或真实 Steam SDK 验收完成。
