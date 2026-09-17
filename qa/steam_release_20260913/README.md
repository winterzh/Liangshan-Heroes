# 2026-09-13 Windows Steam 发布证据

**当前状态：Build `25276077` 已正式在default上线。** 来源 `71098183af98df1a0279dd205dc25d1b8d85f235`，App `5088120` / Depot `5088121` / Manifest `4630656200603476714`。用户手动上传并完成上线确认，另报告手机Steam令牌验证完成；2026-09-13 06:01:22（UTC+8）的Steamworks回读同时核实上线成功提示、default当前Build、构建行default标签及Manifest链接。服务器6个文件名称、大小和SHA1全部匹配候选。[最终发布收据](publication_followup_receipt.json) · [发布内容与交接](../../docs/STEAM_UPDATE_20260913.md)。无需再选ZIP、重传、重建或重复上线。

## 本地证据

| 记录 | 实际覆盖 |
| --- | --- |
| [source_qa/20260913_050905_caedb7cf/receipt.json](source_qa/20260913_050905_caedb7cf/receipt.json) | 原生Steam整合QA185项通过，原始来源位于 `.godot/steam_integration_qa/20260913_050905_caedb7cf`。 |
| [candidate/20260913_051624_8356851e/receipt.json](candidate/20260913_051624_8356851e/receipt.json) | Windows候选1120项通过；source/PCK身份检查各10项通过。 |
| [smoke_20260913_052835_0ca1bd88/receipt.json](smoke_20260913_052835_0ca1bd88/receipt.json) | 同一实际EXE的八关启动、据守、清敌及主菜单11例通过，全部退出0且无错误；源码、玩家目录和EXE未变化，子进程退出确认且锁释放。 |
| [candidate_delivery.json](candidate_delivery.json) | 唯一ZIP及6个成员的尺寸、SHA256/SHA1、上传副本位置和字节一致性；仅证明本地准备完成。 |
| [evidence_copy_manifest.json](evidence_copy_manifest.json) | 从原生QA及候选目录逐字节复制的原始收据、日志和身份报告来源；不修改原记录。 |
| [publication_followup_receipt.json](publication_followup_receipt.json) | 用户手动上传及确认、Build25276077 / Manifest4630656200603476714、服务器6文件核对及default正式上线回读通过；`status=published_on_default`。 |

ZIP为237,201,655字节，SHA256 `e2c35f3acc2813042b6e39463547d1b8cbf19316c93e00433d879fa1576ba6e5`；EXE为305,879,976字节，SHA256 `3409d0ccd2bd2d45095b99bd45be257ba2a5f58ae6d72ee2067082687f0a827a`。唯一上传副本为[已验证Windows ZIP](E:/CodexTemp/steam_release_20260913/upload/LiangshanHeroes_Steam_candidate.zip)。发行包和私有缓存保留本机，不作为Git证据上传。

`collect_evidence.py` 与 `smoke_verified_package.py` 是本次本机适配的证据归档/隔离短测工具，没有生产逻辑改动。前者保留文件来源与哈希，后者只对已验证EXE串行运行私有profile短测，不重新导出。

## 开发者复现

本轮已完成且冻结的成品无需重跑。以下三阶段说明本轮固定 `71098183` 来源的命令与可配置参数，须串行执行；后续新批应另取新目录并绑定新收据，不能覆盖本次证据。当前 `collect_evidence.py` 固定核对 `71098183`，不适用于其他生产版本：

1. 原生整合QA，使用 `godot.local.txt` / `GODOT_PATH` 或显式 `--godot` 配置本机引擎。

   ```powershell
   py -3 -X utf8 -B tools/run_steam_integration_qa.py --native --profile-root "<本机绝对短路径>" --run
   ```

2. 从成功原生QA生成候选。

   ```powershell
   py -3 -X utf8 -B tools/build_steam_candidate.py --qa-run "<成功原生QA目录>" --profile-root "<本机绝对短路径>" --run
   ```

3. 对成功候选做实际EXE串行短测，再收集成功证据和上传副本。

   ```powershell
   py -3 -X utf8 -B qa/steam_release_20260913/smoke_verified_package.py "<成功候选目录>" "<本机绝对短路径>"
   py -3 -X utf8 -B qa/steam_release_20260913/collect_evidence.py --qa-run "<成功原生QA目录>" --candidate "<成功候选目录>" --smoke "<成功短测目录>" --upload-root "<全新本机绝对上传目录>"
   ```

原生QA和候选原始目录仍在 `.godot/`，本目录的43份归档证据由复制清单绑定，并通过专用Git属性保留跨设备原字节；归档不包含发行包或缓存。以上工具不执行Steam上传或正式分支激活。

## 来源与验收边界

当前源码另外具备[040000完整默认世界916项与042455经典296项联合核验](../yezhulin_world_restore_20260913/validation_summary.json)，2960份生产文件同SHA。这是源码层的恢复证据，不是本次11个EXE短测在包内重跑了全部恢复流程。候选的1120项、身份各10项和原生185项分别按原始报告解释，不能混称完整九玩法验收。

EXE短测仅证明启动和相应短测断言，不计八关完整通关、玩家菜单交互、完整30波、真人体验、性能或真实Steam在线写入。黄泥冈与野猪林内部恢复能力已随生产源码进入包，但玩家保存/继续入口保持隐藏。

## 发布尝试与最终回读

首次选择已验证ZIP的 `fileChooser.setFiles` 调用返回 `Not allowed`。官方故障说明要求用户在Edge的ChatGPT扩展详情开启“允许访问文件URL / Allow access to file URLs”。代理只读访问 `edge://extensions/` 也被浏览器URL安全策略阻止，未绕过或修改设置。本机PATH和已检查的常见工具位置未找到SteamCMD；另一台电脑的旧D盘工具不适用于本机。上述[首次发布收据](publication_receipt.json)保留05:35时点尚未HTTP上传的事实，后续用户已手动上传成功。

用户通过Steamworks标准ZIP上传创建Build `25276077` / Manifest `4630656200603476714`；服务器6文件名称、大小及SHA1全部匹配。两次自动default确认框接受调用在 `Emulation.setFocusEmulationEnabled` 超时，第一次之后权威构建页仍为旧Build `25250466` / Manifest `416479225955196133`；第二次超时后，用户手动完成确认，并报告手机Steam令牌验证完成。06:01:22回读显示上线成功提示，default当前Build25276077，构建行带default标签并关联正确Manifest。[最终收据](publication_followup_receipt.json)记录 `published_on_default`、`default_activated=true` 和空待办。

上传、服务器文件核对与正式上线回读均完成，无需重复操作。`candidate_delivery.json` 的本地准备false值和原 `publication_receipt.json` 的 `blocked_before_upload` / false / null均保持原字节；先前文件权限阻塞及自动确认超时保留历史。平台预览估算更新下载量28.8MB，不代表客户端实测。打包上线阶段未发布公告，随后已于06:16 HKT发布[四语更新公告](../steam_announcement_20260913/README.md)；原始收据保留各自时点。本次未改设置或合并main，也未进行客户端安装验收。
