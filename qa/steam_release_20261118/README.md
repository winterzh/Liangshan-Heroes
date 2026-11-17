# 2026-11-18 Windows Steam 发布

冻结源码 492e64370557315e529122f9beb1d23bf5089e2e，使用原候选 ZIP。传输副本经六文件大小及 SHA-1 核对，SteamPipe Preview 的根路径、名称、大小及 SHA-1 一致后上传。取得 Build 26735223、Depot 5088121、Manifest 9099660322002044845，Steamworks 服务端六文件均与原候选一致。 [机器收据](report.json)

首轮浏览器恢复被物理 Escape 中断，初次只读 public 为 26719792，原状态保留在 previous_readbacks。后续仅用后台网页控制提交正式分支请求，用户完成手机确认，刷新 Steamworks 的 default 为 26735223。

公告活动 708914425087657757 已关联新构建并公开。简中、繁中、英语、日语标题、各八条正文和正文图片已逐项回读。封面沿用公告图库中 event_cover_800x450.png，保存为通用英语封面供四语使用。 [公开公告](https://store.steampowered.com/news/app/5088120/view/708914425087657757) · [四语正文](patch_notes.json)

本机 Steam 的静默启动请求停在 SynchronizingCloud syncfailed，游戏进程未启动。本机安装尚为 26719792。SteamCMD 从 public 下载到独立目录，Build 26735223、Manifest 9099660322002044845 和六文件大小、SHA-256 均与候选一致。下载所得 EXE 用独立资料、STEAM_DISABLED=1 和 CONTENT_UPDATE_NO_AUTO=1 启动无窗口主菜单，23.16 秒退出 0、错误 0。 [服务器下载与启动收据](server_download_verified.json)客户端正式启动及 Steam 环境的战役存读链继续待验。

用户本轮要求上传。路线图中真人试玩和 Android 手机、平板验收仍待完成。
