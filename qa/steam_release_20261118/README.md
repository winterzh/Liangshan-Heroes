# 2026-11-18 Windows Steam 发布

## Windows Build 26752476

Steamworks 正式分支 `default` 已通过用户手机确认切至 26752476。Windows Depot 为 5088121，Manifest 为 8273375024262905155，回退构建为 26735223。服务器清单六文件的大小和 SHA-1 与上传包一致。SteamCMD 从正式分支干净下载后，六文件的大小和 SHA-256 也一致。隔离离线启动下载所得 EXE，退出 0，错误 0。 [机器收据](release_26752476.json)

同一冻结版本在发布前用授权 Steam 账号验证野猪林中途保存、独立重启续玩和演义 3/3。Steam 胜场增加 1 次，解锁野猪林演义成就。独立重启拒绝已结算的旧槽，胜场和成就不再增加。新隔离档案和从 Steam 官网下载的云档均读到同一战果。下载包的启动验证用隔离离线档案执行。

公开补丁说明已关联 Build 26752476，简中、繁中、英语和日语的标题、六条正文和插图均从公开页回读。四语使用同一张通用封面。 [公开公告](https://store.steampowered.com/news/app/5088120/view/680767470935474309) · [四语正文](../../docs/STEAM_UPDATE_20261118_CANDIDATE_0f133709.json)

## Windows Build 26735223

冻结源码 492e64370557315e529122f9beb1d23bf5089e2e，使用原候选 ZIP。传输副本经六文件大小及 SHA-1 核对，SteamPipe Preview 的根路径、名称、大小及 SHA-1 一致后上传。取得 Build 26735223、Depot 5088121、Manifest 9099660322002044845，Steamworks 服务端六文件均与原候选一致。 [机器收据](report.json)

首轮浏览器恢复被物理 Escape 中断，初次只读 public 为 26719792，原状态保留在 previous_readbacks。后续仅用后台网页控制提交正式分支请求，用户完成手机确认，刷新 Steamworks 的 default 为 26735223。

公告活动 708914425087657757 已关联新构建并公开。简中、繁中、英语、日语标题、各八条正文和正文图片已逐项回读。封面沿用公告图库中 event_cover_800x450.png，保存为通用英语封面供四语使用。 [公开公告](https://store.steampowered.com/news/app/5088120/view/708914425087657757) · [四语正文](patch_notes.json)

本机 Steam 的静默启动请求停在 SynchronizingCloud syncfailed，游戏进程未启动。首次核验的本机安装为 26719792。后续回读确认本机 Steam 已安装正式 Build 26735223、Manifest 9099660322002044845，六个发行文件的大小和 SHA-256 均与发布收据一致。此次只读核验未启动游戏。 [本机安装回读](client_install_verified.json)SteamCMD 从 public 下载到独立目录，Build 26735223、Manifest 9099660322002044845 和六文件大小、SHA-256 均与候选一致。下载所得 EXE 用独立资料、STEAM_DISABLED=1 和 CONTENT_UPDATE_NO_AUTO=1 启动无窗口主菜单，23.16 秒退出 0、错误 0。 [服务器下载与启动收据](server_download_verified.json)客户端正式启动及 Steam 环境的战役存读链继续待验。

用户本轮要求上传。路线图中真人试玩和 Android 手机、平板验收仍待完成。
