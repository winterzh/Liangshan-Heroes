# 2026-09-15 Windows Steam 发布证据

目标 App5088120 / Windows Depot5088121 / default；用户明确要求“发布steam”。固定生产来源 `dd4046fdfd398fec43d992cb315982da35de0c2c`。构建前通过已登录Steamworks页面核实线上 Build25290621 / Manifest53262799732835110。[更新说明](../../docs/STEAM_UPDATE_20260915.md)。

最终线上状态以 [publication_receipt.json](publication_receipt.json) 为准；候选创建时的 `uploaded:false` 保留其历史含义，不回写原始机器收据。发行ZIP和EXE只保留本机，不提交Git。

## 验证层级

- 原生Steam整合 `20260915_142655_042b3d73`：全新导入，185项通过；独立源码/profile，实际Steam初始化和写入禁用。
- Windows候选 `20260915_142823_e9f44c57`：同源QA与缓存，包内1128项通过；源码和PCK内容身份各10项；实际EXE确认加载三份正确的原生DLL。
- 包内补员专项 `20260915_143159_b0782496`：[29项通过](recovery_probe/20260915_143159_b0782496/report.json)。编辑器宿主直接挂载本次EXE内嵌PCK，自动关卡接入、四语文本、定位信号、招募/撤单、默认空资源观察钩、退款及终局隐藏成立。候选、宿主、DLL和测试输入哈希不变，独立profile与锁回收通过。
- 实际EXE短测结果见 [smoke收据](smoke_20260915_143217_df42aca4/receipt.json)，覆盖八关启动、据守、清敌和主菜单；每例串行，绑定同一EXE哈希并保护源码和玩家目录。

包内专项明确使用冻结状态夹具、生产接口和按钮信号，不冒充物理鼠标或自然接敌。没有重新生成截图；原源码250项检查/11张目检见[原批次](../zhujiazhuang_recovery_20260915/README.md)。本批不验收完整通关、真人理解/趣味/平衡、性能长跑、客户端更新或真实Steam持久写入。玩家中途保存/继续未开放。

## 候选身份

- ZIP：254520023字节，SHA256 `80f112a8f1fafebb4bc0ff3c08348385e5c7137a14ea6a5f56a961e0da69532b`。
- EXE：322105960字节，SHA256 `d478eca24766ad5fb67210d867dd8d5f19a48858a8da4a268df18bc711e1f2ca`。
- 六个根成员：主EXE、GodotSteam DLL、steam_api64.dll、steam_stats_reader.dll和两份许可证。完整名称/大小/SHA1/SHA256及上传副本在 [candidate_delivery.json](candidate_delivery.json)。

物理发行白名单排除QA、工具、源码调研、本地化源分片、浏览器会话、存档和缓存；只保留生成后的本地化目录。现有四人美术和已上线功能沿用生产来源，本轮没有再调玩法数值或素材。

## 复现

```powershell
py -3 -X utf8 -B tools/run_steam_integration_qa.py --native --profile-root D:/CodexTemp/steam_release_20260915/profiles/source --run
py -3 -X utf8 -B tools/build_steam_candidate.py --qa-run <成功QA目录> --profile-root D:/CodexTemp/steam_release_20260915/profiles/candidate --run
py -3 -X utf8 -B qa/steam_release_20260915/run_recovery_pack_probe.py --repo . --candidate-run <候选绝对目录> --work-root D:/CodexTemp/steam_release_20260915/recovery --timeout 120 --run
py -3 -X utf8 -B qa/steam_release_20260915/smoke_verified_package.py <成功候选目录> D:/CodexTemp/steam_release_20260915/profiles/smoke
py -3 -X utf8 -B qa/steam_release_20260915/collect_evidence.py --qa-run <成功QA目录> --candidate <成功候选目录> --smoke <本批成功smoke目录> --upload-root <新的绝对ASCII目录>
```

引擎步骤串行使用共享锁，新批次使用唯一目录。collector固定本次dd4046fd来源，验证同源、ZIP六成员、全部检查和玩家目录守卫后逐字节归档，并生成独立上传副本；它不执行线上操作。本批helper由9月14日已提交流程复制后改日期、来源和专项内容；旧批文件未改。

包内专项首次CLI传入相对候选路径被预检拒绝，未启动引擎、未修改包。改用绝对路径后一次运行29项通过，未发生游戏/脚本失败。

## 当前交付状态

**已正式上线**：Steam成功提示与default分支均回读为 **Build25316671**，Windows Depot5088121 / Manifest **7776799335954834384**。服务器六成员名称、字节数及SHA1全部匹配已验证候选；磁盘326741403字节、压缩250198816字节，Steam预计从上一版更新下载 **5.7 MB**。

用户完成手动上传后，新Build已出现在构建页。本轮完成服务器核对和default上线；macos仍为0、steam-integration仍为25179481，其他Steamworks未发布设置和公告未改。原等待选文件阶段保留于 [publication_before_upload.json](publication_before_upload.json)，候选创建时的历史状态保留不回写。最终 [publication_receipt.json](publication_receipt.json) 与 [服务器核对](server_manifest_verification.json) 为本轮交付依据。未追加客户端下载试玩或真实Steam持久写入验收。
