# 默认迷雾状态恢复 QA

第 15 个恢复组件 `scripts/run_fog_state.gd` 已按候选原字节晋级，并通过独立正式资源路径验证。模块为 17,770 B，SHA-256 `caef97f9a10ca7dfaa39bd51a997c1bce8eb5575e7210a4a085ccfba57567d30`。R3 与正式轮各 276 行，其中 206 行是 103 个源码的前后核对、70 行是其余检查；两轮重复同一矩阵，不增加独立场景。累计效果数组覆盖仍为 12/17。

| 运行 | 实际结果 |
| --- | --- |
| [GL 首轮](runs/gl/receipt.json)，20260906T223109968612Z | PID 20512，exit 1；2D MSAA 不受 GLES3 支持的 warning 触发严格停止，无 report |
| [R1](runs/r1/report.json)，20260906T223430986013Z | PID 32308，exit 1；211 行含 206 来源，首次 capture 返回 PAUSED_QUIESCENT_BARRIER_REQUIRED |
| [R2](runs/r2/report.json)，20260906T224007277021Z | PID 33716，exit 1；report.complete=true 但 passed=false，273 行中 3 项黑/透明 Canvas 判据失败 |
| [R3](runs/r3/report.json)，20260906T224445455084Z | PID 21104，exit 0；276 行全部通过 |
| [正式路径](runs/formal/report.json)，20260906T225726913555Z | PID 3508，exit 0；276 行全部通过，独立运行约 23.485 秒 |

五轮源码/玩家保护与锁释放均为 true，历史失败保持失败。R1 使用正常桌面 Forward+，driver 与首轮相同；R2 等待真正的暂停且非 physics 帧边界，没有放宽模块屏障。R2 的黑色清屏且无可见背景，使透明和黑雾同黑；R3 加入独立白色 ColorRect 并要求已知点精确黑/白，继续使用真实 FogLayer。正式 driver/runner 只替换模块路径和测试目录，逆替换与 R3 原字节一致。

三阶段为安装时的滞后图像、首次继续后的真实 fog pass、探索记忆。R3 和正式轮各实际产生左右 6 张 64×64 原生 PNG，共 12 次原始观察。归档只保存正式轮的 6 个实体文件；R3 的 6 个原始路径及 SHA 分别映射到同阶段、同侧的正式文件。映射前逐字节核对，两轮原始报告和日志完整保留，不能据此理解为 R3 未产生图片。每轮左右逐字节相同，跨轮对应阶段 SHA 也一致。已知黑点为 `000000ff`、透明区白底为 `ffffffff`。三阶段 SHA 分别为：

- `a9c8e8ad0c9bac85db806f99bffccf035ac91917b00b7b5850cc5db998ef6d07`
- `8bade0c783a5f5d7f8f643b3f97e1cf2314746eb6851c1e16e44edd9d23c7d65`
- `0fa72b9d812c220193e87423c46d54a30fd1d35b2c771d29906df4f2ebc87c2c`

模块同时保存 `fog/_vision/_sight_now/_reveal_t/_fog_t`、真实 RGBA8 图像/纹理与默认 FogLayer 状态。reveal 可先改变逻辑，图像与 Unit 可见标志等下一次 fog pass 才更新；恢复保留这一时差及剩余刷新时间。bind 不调用 `_init_fog/_fog_pass`，不改 Unit 可见标志，不重新部署。

夹具使用两脱树 Battle、独立 60×60 草地 GameMap 和 3 个真实 Unit；Unit 的两个可见标志由外层显式复制。world 为恒等变换，Canvas 为 1:32，白底是渲染夹具。完整 Map/Unit 图、ISO 世界和相机、复杂节点顺序、任意 Node 扩展、完整引擎帧、PCK、退出后续战及性能均未验收。根状态候选及其 QA 不在本批。

[source_index.json](source_index.json) 使用仓库根相对 archive 路径：每轮 103 个运行来源中 101 个精确复用已提交归档，模块与各 driver 按 SHA 去重。索引另保留全部 harness、冻结 pins、修改补丁、准备/晋级脚本及精确 host helper；原始 preparation 中的未运行描述保持原时点。复现时先还原该轮 source_set、harness 与 helper 的原路径，再使用该轮 report_process 的实际入口和固定 runner；引擎及原生导入资源按其来源准备，不包含在本档案。原 pins 是整个 scripts/scenes 源集，不能直接在不断新增脚本的 checkout 上重新 freeze 后冒充历史复现。

正式报告 SHA 为 `aa08f12ae10062fd5585a22e50c0d20f006351b4e1bdb84d90c505e5fcd2ab4b`；实际 provider 返回 `source-v1:3c8d05abd2ce2d4167a859de9e153b42b6041c759c6ff58652dc65768b761f16`。基线 HEAD `56adcacb78356fb9ecc33bc62eb0db252cb35ea6` 只标识晋级时的 checkout，各轮受测字节以自己的 manifest 为准。原型和正式资源路径不同导致运行源集身份不同，不能互换。

[manifest.json](manifest.json) 记录全部原件、6 个 PNG 实体文件及 12 次原始观察的 SHA/字节；source_index 的 image_mappings 保留 R3 到正式图片的明确映射；[archive_verification.json](archive_verification.json) 给出最终文件和来源统计。玩家目录清单、私有 profile、缓存、安装包、无关图片与根状态工作均未纳入。
