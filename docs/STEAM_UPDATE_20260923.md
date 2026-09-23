# 2026-09-23 Steam 创意工坊公开发布

Windows `default` 已上线 Build **25476210**，Depot `5088121` / Manifest `4175538259787899440`。Steamworks 手机确认完成后，生成版本页的默认分支与部署历史均回读到本构建。回滚基线保留为 Build `25460867` / Manifest `2563454806170954821`。

本次交付 GodotSteam 4.22.1 的订阅读取及作品标签接口修复，并公开创意工坊。后台差异仅包含工坊品牌图、公开曝光与发布日期；发布回执为 `Publish to steam OK` / `Publishing successful!`。

- [创意工坊首页](https://steamcommunity.com/app/5088120/workshop/)
- [示例地图 · 水泊练兵](https://steamcommunity.com/sharedfiles/filedetails/?id=3806632089)
- [四语上线公告](https://store.steampowered.com/news/app/5088120/view/694273194214817894)，定期更新，2026-09-23 18:15 CST 发布，关联本 Build，并开启工坊页展示。

示例地图在当前账号完成游戏内上传、Steam 订阅下载及两波实战胜利；三个下载文件与上传内容哈希相同。候选、服务器清单及 Steam 安装目录六文件已比对。原生 QA 189/189、包内检查 1136 和候选身份检查见此前阶段记录，本次收尾未修改游戏代码或重建安装包。

简体中文、繁体中文、英语、日语公告均完成公开页面 DOM 回读。22:35 后另以不携带 Cookie 的 HTTP 请求核验四语 `published=1`、`hidden=0`、标题、正文、示例链接与构建关联；工坊首页可见作品及公告。封面复用已有 800×450 游戏品牌图，其他语言按 Steam 规则回退英文封面。

本机仍在 `steam-integration`，但 Build 和 Manifest 与 default 一致，六文件重新核验一致。尝试打开 Steam 后主窗口消失，重新枚举没有目标窗口，故未切回默认；不能据此声称默认分支客户端切换已完成。跨设备 Cloud、第二账号工坊与示例据守作品尚未验收/发布。

完整[QA 说明](../qa/workshop_public_20260923/README.md)与[结构化收据](../qa/workshop_public_20260923/publication_receipt.json)保留各项边界。
