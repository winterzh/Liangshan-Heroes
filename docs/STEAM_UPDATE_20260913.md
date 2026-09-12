# 2026-09-13 Windows Steam 更新与交接

**当前状态：Build `25276077` 已正式在default上线。** 来源为 `71098183af98df1a0279dd205dc25d1b8d85f235`，App `5088120` / Depot `5088121` / Manifest `4630656200603476714`。用户手动上传并完成上线确认，随后报告手机Steam令牌验证完成；2026-09-13 06:01:22（UTC+8）的Steamworks回读显示上线成功提示、default当前Build25276077，以及该构建的default标签和正确Manifest链接。服务器6个文件名称、大小及SHA1全部匹配验证候选。[最终发布收据](../qa/steam_release_20260913/publication_followup_receipt.json) · [本轮QA](../qa/steam_release_20260913/README.md)。

已发布的唯一成品为[已验证Windows ZIP](E:/CodexTemp/steam_release_20260913/upload/LiangshanHeroes_Steam_candidate.zip)。上传、服务器核对和正式分支回读均已完成，无需再次选ZIP、重传、重建或重复上线操作。

## 发布内容与来源

相对9月11日发布后记录基线 `19ec8c2c`，本次生产变化来自黄泥冈 `de0f8bd6` 与野猪林 `71098183` 两次提交，共18个脚本及UID文件；素材、场景、词库、字体、地图定义和导出配置没有新增变更。

- 修复相邻任务的手动认领：按玩家原始点击目标选择要办理的任务，避免前往目标途中经过另一担或任务点时被抢先认领。
- 修复黄泥冈挑担人倒下后残留的携担标记，并及时重绘；原贡担落地后可由其他同伴接力。
- 野猪林“选中鲁智深/相送队伍”改用本关固定回调，保留原有选择与镜头定位行为。

本包还包含黄泥冈与野猪林的内部整世界恢复接入：场景和角色引用、携担关系、林冲两次实体替换、护送命令、暂停状态下HUD/高度恢复，以及保存边界的阴影失效引用清理。这些属于内部能力，**玩家“保存并退出/继续上次战斗”入口仍隐藏，不能将本次发布写为玩家已经可中途保存或续玩。** 未扩大为八关或九种玩法全部恢复验收。[黄泥冈实现](HUANGNIGANG_WORLD_RESTORE_20260912.md) · [野猪林实现](YEZHULIN_WORLD_RESTORE_20260913.md)。

## 构建与验证

| 层级 | 实际结果 | 收据 |
| --- | --- | --- |
| 原生Steam整合QA | `20260913_050905_caedb7cf`，185项通过 | [原生收据](../qa/steam_release_20260913/source_qa/20260913_050905_caedb7cf/receipt.json) |
| Windows候选包 | `20260913_051624_8356851e`，1120项通过；source/PCK身份检查各10项通过 | [候选收据](../qa/steam_release_20260913/candidate/20260913_051624_8356851e/receipt.json) |
| 实际EXE串行短测 | `20260913_052835_0ca1bd88`，11例全部通过、退出0，覆盖八关启动、据守、清敌及主菜单 | [EXE短测收据](../qa/steam_release_20260913/smoke_20260913_052835_0ca1bd88/receipt.json) |
| 源码世界与经典回归 | 040000完整默认世界916项、042455经典296项；2960份生产文件同SHA | [独立联合核验](../qa/yezhulin_world_restore_20260913/validation_summary.json) |

EXE短测确认 `source_unchanged`、`players_unchanged`、`exe_unchanged`、`child_exit_confirmed`、`lock_released` 全为true。它验证启动和已有短测断言，未覆盖玩家菜单交互、各关完整通关或真实Steam在线写入。源码恢复回归与发行包检查分别记账，不把916+296项称为在导出EXE内重跑。

本次新增 `qa/steam_release_20260913/collect_evidence.py` 和 `smoke_verified_package.py` 两个本机适配QA工具，仅负责复制证据及隔离短测，没有修改生产逻辑。发行与短测使用同一验证候选，没有以当前工作区重新拼包。源码继续在 stable 分支同步，本次不合并 main。

## 唯一上传包

- 候选ZIP：`.godot/steam_candidates/20260913_051624_8356851e/LiangshanHeroes_Steam_candidate.zip`
- 上传副本：[LiangshanHeroes_Steam_candidate.zip](E:/CodexTemp/steam_release_20260913/upload/LiangshanHeroes_Steam_candidate.zip)
- ZIP：237,201,655字节；SHA256 `e2c35f3acc2813042b6e39463547d1b8cbf19316c93e00433d879fa1576ba6e5`
- EXE：305,879,976字节；SHA256 `3409d0ccd2bd2d45095b99bd45be257ba2a5f58ae6d72ee2067082687f0a827a`
- 六成员清单与候选收据逐项一致，上传副本逐字节一致。[候选交付清单](../qa/steam_release_20260913/candidate_delivery.json)保留每个成员的SHA256和SHA1；[证据复制清单](../qa/steam_release_20260913/evidence_copy_manifest.json)保留原始收据/日志复制来源。

| 文件 | 字节 | SHA1 |
| --- | ---: | --- |
| `GODOTSTEAM_LICENSE.txt` | 1,110 | `3891aeb1976703fc639c168329d90e27c7680a68` |
| `LiangshanHeroes.exe` | 305,879,976 | `60a075025390b1e0b0ab203c3b42a7d64759086a` |
| `STEAM_STATS_READER_GODOT_CPP_LICENSE.txt` | 1,093 | `0b594319d5af0b833d7c0da47459b7d51e1fdbd2` |
| `libgodotsteam.windows.template_release.x86_64.dll` | 3,961,344 | `c056eb4e85d902bd548dc9efb22a416b9c658dda` |
| `steam_api64.dll` | 319,128 | `05ea59cc2b15a10c66277659d5d0b51750460d28` |
| `steam_stats_reader.dll` | 352,768 | `ac9a932af32cef47cb41a80fc766fd2a401b13ba` |

## Steam上传与上线确认记录

首次尝试时Steam网页已登录，选择已验证ZIP的 `fileChooser.setFiles` 返回 `Not allowed`。官方故障说明要求用户为Edge的ChatGPT扩展开启“Allow access to file URLs”；代理随后只读打开 `edge://extensions/` 也被浏览器URL安全策略明确阻止，未绕过限制或修改设置。本机PATH及已检查的常见工具目录未找到SteamCMD；旧D盘工具属于另一台电脑。这是[05:35首次阻塞收据](../qa/steam_release_20260913/publication_receipt.json)的历史状态，随后用户已手动完成上传。

用户通过Steamworks标准ZIP方式完成上传后，页面返回 `Building depot done` 与 `Build commit successful`，分别给出Manifest `4630656200603476714` 和Build `25276077`。服务器清单已按6个文件的名称、大小和SHA1逐项核对，全部一致。[后续收据](../qa/steam_release_20260913/publication_followup_receipt.json)记录上传与核验成功；`candidate_delivery.json` 的本地准备值和原 `publication_receipt.json` 的 `blocked_before_upload` / false / null保持原样，不覆盖历史。

正式default的两次自动确认框接受调用都在 `Emulation.setFocusEmulationEnabled` 超时。第一次之后权威构建页仍为旧Build `25250466` / Manifest `416479225955196133`；第二次超时后由用户手动确认，用户另报告手机Steam令牌验证完成。06:01:22回读[Steamworks构建页](https://partner.steamgames.com/apps/builds/5088120?submittedbuild=25276077)明确显示新构建已向default玩家上线，default当前值为25276077，构建行带default标签并关联Depot5088121的Manifest4630656200603476714。最终收据为 `published_on_default`，待办为空；自动调用超时保留为过程记录，不再作为当前阻塞。Steam预览估算更新下载量28.8MB，仅为平台估算，未做客户端下载测量。

打包上线阶段未发布公告，随后已于Steam显示的2026-09-13 06:16 HKT发布[四语更新公告](STEAM_ANNOUNCEMENT_20260913.md)，关联Build25276077，保存16字段和公开24片段回读全部匹配；原始包发布收据保留当时公告尚未发布的状态。本次未改动浏览器设置或合并main，未声称客户端已下载更新或真实Steam统计写入已验收。内部保存入口仍关闭，完整30波同版、剩余五关世界恢复、真实Steam持久确认、长跑/性能、双机/双账号与真人检查继续遵循[统一交付门槛](CONTINUE_DELIVERY_20260908.md)。
