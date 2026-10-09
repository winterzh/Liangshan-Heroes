# 2026-10-09 公司电脑 Steam 更新准备

当前：新的 Windows 候选本地验证完成，尚未上传、尚未切 default、尚未发布四语说明。匿名 Preview 实际退出6，服务器拒绝 Access Denied；须 App5088120 构建账号登录后重跑 Preview。浏览器与原生电脑控制工具重置后仍报 kernel assets 路径不存在，尚不能自动控制Steamworks页面。

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
