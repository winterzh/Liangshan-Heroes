# 2026-09-09 最新源码 Steam 正式更新

Steam Windows `default` 正式分支已更新为 **Build 25200149**，Depot `5088121`，Manifest `7045932649257457621`。服务端六文件名称、字节数与 SHA1 已逐项核对本地候选；canonical 正式分支与部署历史均回读确认，激活时间为北京时间2026-09-09 11:16。

本次发布源码 HEAD 为 `1102a9b629142524061a1b1fc005407c8da5fc07`，功能源码为 `cf746f1a0864355df7f80cd4f18c6882088f4b7e`。构建后新增的发布收据与交接文档不属于游戏运行内容。

[四语公开公告](https://store.steampowered.com/news/app/5088120/view/714538122294067212)已发布，活动 `714538122294067212`，收据记录发布时间 `2026-09-09 11:17 CST`（北京时间11:17）；四语各8段、共32段公开可见文本逐项一致，新闻列表已出现新标题。

## 本次内容与开放范围

本次包含任务定位、人物选择提示及祝家庄选择按钮的语言处理，以及本局设置、任务界面、景物与特效恢复的内部准备。战斗中途保存与继续仍未开放；经典30波和八关的统一续玩验收继续推进。

新增原生 observer DLL 尚未晋级，发行包保留既有 vendor DLL；facade 对不可用能力安全拒绝。真实 Steam 持久写入确认仍为 `WRITE_CONFIRMATION_UNPROVEN`，不将读取成功或普通保存通知视为可归属写确认。

## 候选与验证

原生整合191项、同包1112项、源码与同包身份探针各10项通过；同一实际 EXE 的11例串行短测通过。编辑器挂载同一发行包的公开菜单/战斗流程64项通过，其胜负由受控触发，不代表自然通关。六张原生界面 PNG 已逐张目检，视觉范围仅限这些截图。首次公共流程探针因 Godot 消费 `--main-pack` 参数导致驱动读不到包路径失败，修正驱动后通过；失败证据保留且不计入通过数。

本批不计完整八关通关、九玩法续玩验收、1800秒长跑、性能达标、两台 Windows、真实双账号或真人验收，也未验收 Steam 客户端实际下载和安装。

候选 `20260909_104555_e2451f6f`；ZIP 为 238,339,231 字节，SHA256 `4d35279d7ef92d29dd7150d4d8209e7146b5e98ed4774121e744f7380b9d985b`。EXE 为 305,829,856 字节，SHA256 `f22a44e96b7a0f4b42f599b1d9177e53312bcb3cbd5a6c48484172b21369dc2d`。ZIP 和安装包留在本机候选目录，不纳入 Git 文档同步。

网页标准 ZIP 上传两次返回 `Error 9: Did not receive entire file`，未取得有效完整构建，随后使用 SteamCMD 已有缓存登录。首次命令因 Unicode 路径在 PTY 中乱码而中断，退出1且尚未开始构建；改用已核实的既有 ASCII junction 配置，Preview 与正式上传均退出0。配置精确映射六个候选文件，没有扩大上传范围。构建差异列表的 EXE 约8.46MB，Steam 部署预览估算玩家增量约6.3MB；这两个平台值不等于已测得的客户端下载量。脱敏 SteamCMD 日志单独保留，原始失败没有改写为通过。

[SteamCMD 脱敏证据](../qa/steam_latest_update_20260909/steamcmd/)。

| 服务端文件 | 字节数 | SHA1 |
| --- | ---: | --- |
| `GODOTSTEAM_LICENSE.txt` | 1,110 | `3891aeb1976703fc639c168329d90e27c7680a68` |
| `LiangshanHeroes.exe` | 305,829,856 | `154760bf283282ac52d19501c56a95e4d5b17b63` |
| `STEAM_STATS_READER_GODOT_CPP_LICENSE.txt` | 1,093 | `0b594319d5af0b833d7c0da47459b7d51e1fdbd2` |
| `libgodotsteam.windows.template_release.x86_64.dll` | 3,961,344 | `c056eb4e85d902bd548dc9efb22a416b9c658dda` |
| `steam_api64.dll` | 319,128 | `05ea59cc2b15a10c66277659d5d0b51750460d28` |
| `steam_stats_reader.dll` | 352,768 | `ac9a932af32cef47cb41a80fc766fd2a401b13ba` |

## 公告与交接

四语公告采用已校对的16个字段，文案 SHA256 `08e3043021739186f12e2dc93e4080168b5ab50e5d58e9a9139bf3c439dbecf9`；英语摘要163字符。每语公开页的标题、副标题、3个小标题和3段正文共8片段逐项一致，四语合计32片段；摘要属于后台已校对字段，不混计为正文页第9段。

活动封面复用既有800×450无文字英文图，四语共用该图，源图 SHA256 `508a9c882c68579ebdcc4832890f83ccd36448269ade8347b027bfdb035a56da`。公开媒体返回的400×225变体 `2105fa26234a9377723de86a7519262f3f5949cb_400x225.png` 已确认加载完成；正文未额外插图。此结果不表示所有 Steam 展示位置都使用该封面。简中与日语公开页当前视口已目检，未扩大为四语整页视觉验收。

[复用封面源图](steam_announcement_20260901/event_cover_800x450_english_v2.png)。

[文案与维护信息](../marketing/steam_latest_update_20260909/README.md) · [发布收据](../qa/steam_latest_update_20260909/publication_receipt.json) · [QA范围与原始证据](../qa/steam_latest_update_20260909/README.md) · [续玩后续计划](CONTINUE_DELIVERY_20260908.md)。

历史收据保持原样；候选 delivery 中上传/激活字段表示生成时的本地状态，当前状态以独立 publication_receipt.json 为准。后续维护使用本构建和既有公告活动ID，避免重复上传或重复发帖。GitHub 同步由白名单提交、推送和远端回读另行确认，本文不预写尚未产生的 Git 提交。
