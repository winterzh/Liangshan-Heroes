# 2026-10-09 公司电脑 Steam 更新完成

当前：Build25821275 / Windows Depot5088121 / Manifest1831225442917801106 已default上线；四语公告703281660030879826公开回读通过，服务器与实际客户端六文件一致，Steam库启动窗口响应和自然退出码0通过。最新状态见release_closeout.json；下方旧准备、拒绝和上传未激活记录保留其历史语境。

用户明确授权“更新steam”，随后说明是公司电脑，另明确允许跨聊天协调盲盒暂时让出Godot。已按授权协调安全保存现场；水浒本地验证全部实际退出/源锁释放后已通知对方恢复，没有直接停止外部进程或把其未完成批记为通过。

来源 main/stable `6d3bab21189a1bd74d22a88238e9474fe22f98cb`。相对线上来源 `bf9e192d` 为13份生产脚本变化，涉及存档校验与景物状态处理；没有新美术/场景/vendor/导出配置变化。十四份R12恢复候选未晋升，公开续玩仍限经典固定30波；原完整战役恢复、自然全章、持续性能与Android真机目标未完成。

本次真实结果：

- Steam原生219项；成功QA `.godot/steam_integration_qa/20261009_120649_3b258f03`。仅复用旧纹理缓存，当前来源完整重跑。
- 正常保存/跨进程恢复/覆盖冲突/失败重试/终局拒绝302项；13阶段完整退出。证据 `qa/continue_flow_20260909/20261009_120933_fbd22058`，不是完整30波或真人验收。
- 唯一候选 `.godot/steam_candidates/20261009_122012_eb6ef6bc`；包内1152项，来源与包内身份各10项，实际EXE八关/据守/清敌/主菜单11场景均通过。源码、真实玩家目录与EXE前后不变。
- ZIP881,531,409字节，SHA256 `d810068b7f76a2cf5cc1aab0e9cfccdd6b54848462fd658415d4a064e8819ac3`；EXE950,408,448字节，SHA256 `6bef76a1a444cf0f8089002262a8498c0ca7fb6c4165ef08c79a8c5af833b089`。

本机新官方SteamCMD位于 `D:/CodexTemp/lsh-steamcmd-company-20261009/client/steamcmd.exe`，下载/更新后Valve签名均Valid。匿名实时app_info已退出0，当前default/public仍 Build25768878 / Windows Depot5088121 / Manifest7052320823704356026，作为回滚基线。

启动已有Steam客户端后，公司电脑正常下载了既有线上版，ACF Build/TargetBuild均25768878、Manifest匹配、六文件SHA256全部匹配10月7日冻结包。未覆盖任何Steam管理文件，未启动旧版本游戏；该结果不代替本次新候选上线或客户端启动验收。

六成员上传副本在 `D:/CodexTemp/lsh-steam-release-company-20261009/transfer`，内容另解压到其content下并逐大小/SHA256/SHA1核对。VDF在同批pipe下，只含Windows Depot与六显式映射、无凭据、无SetLive。原始SteamCMD日志/凭据缓存和导出ZIP/EXE全部留外部，不进Git；匿名拒绝保存独立事实。

四语补丁说明草稿见patch_notes_draft.json，尚未关联新Build或公开。候选验证结果与冻结包足够进行后续发布准备，但上线仍须构建账号Preview成功→Upload成功→新Build/Manifest六文件回读→default/mobile确认与权威回读→四语公开回读→干净客户端/实际运行验收。此文档明确保留待完成状态。

## 2026-10-09：公司电脑已有登录复用，Steam上传成功、正式分支待切换

用户说明公司电脑此前上传过。找到原ContentBuilder，SteamCMD签名Valid/Valve，复用原保存的登录状态，无需收集密码或验证码。实际Preview退出0，六成员名称/大小/SHA1与冻结候选完全一致；正式Upload退出0，Steam返回Build25821275、Windows Depot5088121 / Manifest1831225442917801106。只改变一个EXE，0新增/0删除文件；没有重导出或重压候选。

上传后独立app_info退出0，public仍为25768878，故新包尚未给玩家。新Manifest隔离下载两次实际exit14/No connection，未核成服务器六文件或客户端新版本验收。网页控制工具此前重置后仍路径错误，打开Builds面板返回queued，不代表已操作或上线。正式default切换、手机确认、四语公告公开和新客户端验收仍待完成；四语草稿已关联25821275。匿名Preview拒绝、旧本地准备收据和下载失败事实全部保留，不覆盖历史。当前仍不得说Steam更新已上线。详情qa/steam_release_20261009/authenticated_upload_receipt.json。


## 2026-10-09：Steam 正式上线与客户端验收完成

用户授权更新Steam并完成手机确认。控制连接恢复后，将唯一冻结候选设为default；Steamworks成功提示、default分支/构建行和独立SteamCMD public回读均为Build25821275，Windows Depot5088121 / Manifest1831225442917801106；macos=0、steam-integration=25476210未变。回滚基线25768878。

服务器新Manifest隔离下载实际exit0，六文件大小/SHA256均与候选一致。Steam客户端正常下载5,641,936字节，ACF Build/TargetBuild25821275、StateFlags4，新Manifest与库内六文件全部一致，未手动覆盖库文件。Steam库-applaunch实际进程45716来自正确库路径，窗口“水浒英雄传：八幕战役”响应正常，自动短测自然exit0，Vulkan日志目标错误0；这不是完整通关或菜单画面的人工验收。

四语小型补丁说明已公开，Event703281660030879826关联Build25821275；简中/繁中/英语/日语标题与完整正文逐页回读一致，四张公开截图图片已加载。共用英文封面保存成功，Steam小型补丁公开布局显示游戏图片。公开链接 https://store.steampowered.com/news/app/5088120/view/703281660030879826 。仅宣传存档校验与景物维护，公开续玩仍限经典固定30波；不宣称R12完整战役续玩、真人完整通关、10分钟性能或Android真机完成。

客户端串行验收窗口按用户已有跨聊天授权协调，实际进程退出后已通知盲盒恢复；未停止外部进程或把对方中断批记为通过。源锁不存在，生产源仍等于6d3bab21。此前匿名拒绝、两次回下载No connection、旧版客户端/本地准备和上传未激活收据作为历史证据原样保留。最新权威收据qa/steam_release_20261009/release_closeout.json；本次Steam发布完成，原完整开发目标未完成。
