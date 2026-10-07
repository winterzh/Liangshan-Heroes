# 2026-10-07 角色与动作 Windows 更新发布

用户授权“上传steam，发布更新公告”，随后确认 Steam 已登录；最新指示“直接干”取消额外连续空闲等待。来源为 GitHub stable 冻结提交 `bf9e192de68e561870881cee27533834d1b55a71`，发布前独立回读远端一致。本轮不恢复暂停的长期开发目标。

**当前：Build 25768878 已在 default 正式上线，四语公告已公开且逐语言全文/封面回读通过；本机客户端仍旧Build，目标客户端验收未完成。**

App `5088120`，Windows Depot `5088121`，新 Manifest `7052320823704356026`。回滚 Build `25498721` / Manifest `1253492451014755378`。原生 QA 219、包内 1148、来源与包内身份各10、实际 EXE 11例均通过，源码、真实玩家目录、EXE前后无漂移。

唯一候选 `.godot/steam_candidates/20261007_113055_4eb710f7`；来源 QA `.godot/steam_integration_qa/20261007_112500_b2d1e068`；短测 `qa/steam_release_20261007/smoke_20261007_115116_00338121`。ZIP 880,370,340字节，SHA256 `91a44e83e9a3be3e3b57d787af4eea66c5ab0b2c522bc9d2020dbc70e41e5eb8`；EXE 950,378,024字节，SHA256 `ad1049bcdf6a0a87720ae3453faeb1f73cbfdd7c5f57f0a79f80aa8894ab7ac2`。六成员清单与哈希见 `candidate_delivery.json`。

Edge文件选择被插件“Allow access to file URLs”权限阻断，未改变插件权限、未提交网页上传。改用现有 Valve 签名 SteamCMD、独立 ASCII 传输目录、逐文件六映射；Preview 退出0，六行大小/SHA1与冻结包一致。正式上传遇到代理408/超时后由 SteamCMD自动补传，最终退出0，创建 Build25768878；新服务器 Manifest六文件名称/大小/SHA1全部匹配。原认证日志保留外部且不进Git，QA只归档App日志与去除分块URL的Depot日志。

已单次点击将 Build25768878设为default；原生确认accept调用和后续浏览器focus回读超时，不能推导上线成功，也不能重复提交。匿名SteamCMD app_info_update1独立回读仍为旧default25498721。已请求用户在现有Edge页面完成确认；若出现手机验证提示需批准。用户随后回复“批准了”。本次刷新权威构建页确认default为25768878，新Build行带default标签且唯一Windows Depot为预期Manifest；没有重复点击Set Live。成功收据default_live_readback.json与原待确认收据独立保存。

复用既有Event `703281660030877705`，关联Build25768878并保存，12:29 HKT发布成功，编辑页显示公开可见。公告已在新闻列表出现，四语公开标题、完整正文各段与封面加载通过；封面统一使用既定英语回退艺术作品。公开链接：https://store.steampowered.com/news/app/5088120/view/703281660030877705 。Steam库可见性仍待平台管理审核。没有新建重复公告。简中“角色形象与战斗动作更新”、繁中“角色形象與戰鬥動作更新”、英语“Character art and combat animation update”、日语“キャラクター画像と戦闘アニメーションの更新”。

仅交付已验证的人物比例、普通站姿/行走、选定英雄/兵种动作、祝家庄俘虏/获救状态、头像/图标及林冲护身画面。公开续玩仍限既有经典30波，战役完整世界恢复/跨进程续玩、自然结局、持续性能和Android真机门槛仍开放。隔离服务端下载未执行。本机Steam -applaunch5088120请求已执行，内容日志记录旧安装短暂启动后退出；ACF仍Build25498721/Manifest1253492451014755378，所以目标客户端更新/六文件哈希/启动验收均未通过。没有覆盖库内文件、重启共享客户端或停止其他任务；不以本地11短测替代真人完整通关。

失败与取消批次、原始producer/收据均保留：A因外部Godot恢复主动取消；B启动异常0xc06d007f且0日志/0检查；C导入49%时外部Godot恢复取消；D监测外部恢复自动停止自身；E未执行producer，按用户指示取消等待；F同SHA独立引擎、仅复用D纹理缓存，完整重跑成功。未控制或发送消息给其他任务。

证据入口：[本批QA](../qa/steam_release_20261007/README.md)、`steamcmd_upload_receipt.json`、`server_manifest_readback.json`、`default_readback_pending.json`。原始待确认事实保留；成功default_live_readback.json、announcement_public_readback.json、client_update_pending.json和release_closeout.json追加本次实际结论。上传验收前批已远端同步2b8b564c，本次最终回读文件按白名单提交推送并独立读SHA，随后暂停steam心跳。
