# 2026-10-07 角色与动作 Windows 更新发布

用户授权“上传steam，发布更新公告”，随后确认 Steam 已登录；最新指示“直接干”取消额外连续空闲等待。来源为 GitHub stable 冻结提交 `bf9e192de68e561870881cee27533834d1b55a71`，发布前独立回读远端一致。本轮不恢复暂停的长期开发目标。

**当前：已上传 Build 25768878，服务器六文件核对通过；default 尚待 Steam 最终确认，四语公告尚未公开，发布收尾 GitHub 同步尚未完成。**

App `5088120`，Windows Depot `5088121`，新 Manifest `7052320823704356026`。回滚 Build `25498721` / Manifest `1253492451014755378`。原生 QA 219、包内 1148、来源与包内身份各10、实际 EXE 11例均通过，源码、真实玩家目录、EXE前后无漂移。

唯一候选 `.godot/steam_candidates/20261007_113055_4eb710f7`；来源 QA `.godot/steam_integration_qa/20261007_112500_b2d1e068`；短测 `qa/steam_release_20261007/smoke_20261007_115116_00338121`。ZIP 880,370,340字节，SHA256 `91a44e83e9a3be3e3b57d787af4eea66c5ab0b2c522bc9d2020dbc70e41e5eb8`；EXE 950,378,024字节，SHA256 `ad1049bcdf6a0a87720ae3453faeb1f73cbfdd7c5f57f0a79f80aa8894ab7ac2`。六成员清单与哈希见 `candidate_delivery.json`。

Edge文件选择被插件“Allow access to file URLs”权限阻断，未改变插件权限、未提交网页上传。改用现有 Valve 签名 SteamCMD、独立 ASCII 传输目录、逐文件六映射；Preview 退出0，六行大小/SHA1与冻结包一致。正式上传遇到代理408/超时后由 SteamCMD自动补传，最终退出0，创建 Build25768878；新服务器 Manifest六文件名称/大小/SHA1全部匹配。原认证日志保留外部且不进Git，QA只归档App日志与去除分块URL的Depot日志。

已单次点击将 Build25768878设为default；原生确认accept调用和后续浏览器focus回读超时，不能推导上线成功，也不能重复提交。匿名SteamCMD app_info_update1独立回读仍为旧default25498721。已请求用户在现有Edge页面完成确认；若出现手机验证提示需批准。确认后先刷新权威分支/Manifest，再处理公告。

既有隐藏四语草稿 Event `703281660030877705` 保留，标题/摘要/全文已保存并回读。复用已保存品牌封面；须关联新Build，构建上线后公开，再逐语言回读标题、完整正文与图片。不得重复新建。简中“角色形象与战斗动作更新”、繁中“角色形象與戰鬥動作更新”、英语“Character art and combat animation update”、日语“キャラクター画像と戦闘アニメーションの更新”。

仅交付已验证的人物比例、普通站姿/行走、选定英雄/兵种动作、祝家庄俘虏/获救状态、头像/图标及林冲护身画面。公开续玩仍限既有经典30波，战役完整世界恢复/跨进程续玩、自然结局、持续性能和Android真机门槛仍开放。服务端下载、本机客户端更新启动尚未执行，不以本地11短测替代真人完整通关。

失败与取消批次、原始producer/收据均保留：A因外部Godot恢复主动取消；B启动异常0xc06d007f且0日志/0检查；C导入49%时外部Godot恢复取消；D监测外部恢复自动停止自身；E未执行producer，按用户指示取消等待；F同SHA独立引擎、仅复用D纹理缓存，完整重跑成功。未控制或发送消息给其他任务。

证据入口：[本批QA](../qa/steam_release_20261007/README.md)、`steamcmd_upload_receipt.json`、`server_manifest_readback.json`、`default_readback_pending.json`。发布和Git同步完成后暂停steam心跳。
