# 2026-09-14 Windows Steam 发布证据

固定生产来源 `50558b053998f8dbad2f54aae27b5610f8ac61ec`。目标 App5088120 / Windows Depot5088121 / default。用户明确要求更新Steam，并已连接登录Edge；上传前线上仍为Build25276077、Manifest4630656200603476714。[更新内容](../../docs/STEAM_UPDATE_20260914.md)。

最终上线状态由 [publication_receipt.json](publication_receipt.json) 记录；本地候选准备记录不会回写为线上已发布。候选及EXE只保留本机，不提交到Git。

## 验证层级

- 原生Steam整合：20260914_081008_cd74022b，全新导入，185项通过。Steam实际初始化/在线写入禁用。
- Windows候选：20260914_081517_64e1d433，从同一成功QA来源和缓存生成；包内1126项，source/PCK内容身份分别验证。实际结果以候选收据为准。
- 11例实际EXE串行短测：八关启动、据守、清敌及主菜单；绑定同一EXE的SHA256，私有profile与源码/玩家目录守卫。
- 导出PCK图鉴专项：私有编辑器主机加载同一EXE内嵌PCK，四张完整肖像实际1024方、解码像素身份不同，图鉴真实角色/方向信号验证32方向动作路由和占框。该专项不等同官方EXE支持--script，也不另导出候选。
- 源码图鉴3739项与13截图人工目检为[上一批源码证据](../codex_identity_20260913/README.md)，不混算为本轮EXE完整画面验收。

## 复现

引擎沿用 godot.local.txt/GODOT_PATH/--godot，工程外 profile 父目录请换成本机可写绝对短路径。新批使用新目录，不能覆盖本批：

```powershell
py -3 -X utf8 -B tools/run_steam_integration_qa.py --native --profile-root "X:/QA/steam/profiles/source" --run
py -3 -X utf8 -B tools/build_steam_candidate.py --qa-run "<成功原生QA目录>" --profile-root "X:/QA/steam/profiles/candidate" --run
py -3 -X utf8 -B qa/steam_release_20260914/smoke_verified_package.py "<成功候选目录>" "X:/QA/steam/profiles/smoke"
py -3 -X utf8 -B qa/steam_release_20260914/run_codex_pack_probe.py --repo "<checkout绝对目录>" --candidate-run "<成功候选绝对目录>" --work-root "X:/QA/steam/codex" --timeout 240 --run
py -3 -X utf8 -B qa/steam_release_20260914/collect_evidence.py --qa-run "<成功原生QA目录>" --candidate "<成功候选目录>" --smoke "<本目录成功smoke目录>" --upload-root "X:/QA/steam/new_upload"
```

以上引擎步骤串行使用共享锁。collector仅适用于本次50558b05来源，检查同源、依赖、ZIP成员与源码/PCK身份、短测退出和玩家目录保护，再逐字节归档并创建唯一上传副本。它不执行HTTP上传或上线。图鉴专项另归档其原始receipt/report/log/harness，私有profile不归档。

四人身份、低帧动作与原著范围见实现文档；宋江战斗肤色、孙立战斗头饰和须式仍未关闭。本次不开放玩家保存/继续，也不声称完整八关/30波、性能长跑或真实Steam统计写入全部验收。不提交用户目录、凭据、浏览器会话或Steam缓存。

## 包内图鉴专项结果

最终20260914_082800_9b7c044b通过449项，4肖像、32动作路由、4组占框见证齐全，EXE/宿主/依赖/工具守卫不变、独占锁已释放。前一批082718为外部QA脚本的局部类型推断错误（第59行path），明确String后在同一未改动候选上重跑通过；两批原始收据均保留。本补充探针没有修改发行包。

## 当前交付状态

用户手动提供ZIP后，Windows Depot上传完成，Manifest为 **53262799732835110**；随后提交为 Build **25290621**。服务器六成员的文件名、大小和SHA1逐一匹配candidate_delivery.json，总磁盘326730715字节，压缩250192576字节。default预览仅更新Windows Depot5088121，旧Build25276077，增量下载预估28.1 MB。

已提交default上线请求，Steam显示必须由手机验证器确认；尚未取得default已切换的成功回读。先前Edge选文件限制已由用户手动操作解决，旧阶段收据保留于publication_before_upload.json；本地candidate_delivery仍保留创建时未上传的历史状态。最终状态以publication_receipt.json为准。
