# 2026-09-23 Steam 创意工坊公开验收

## 已核实

- Windows 候选 ZIP 为 339,681,712 字节，SHA-256 `dedc6b1f3bdfa348553703f4362bd060730da8fdc1452b8b6234b428843769e0`。Steam Build `25476210` 先在 `steam-integration` 验证，用户手机确认后已切至 `default`，生成版本页与部署历史回读成功。Depot `5088121` Manifest `4175538259787899440`；服务器清单六文件与 ZIP 大小、SHA-1 一致。Steam 客户端安装目录六文件在 22:35 后再次逐一匹配，详见 [结构化收据](publication_receipt.json)。
- Steamworks 工坊品牌图 `workshop_header_948x203.jpg`、所有人可见及发布日期差异已审阅并发布，回执为 `Publish to steam OK` / `Publishing successful!`；重新进入发布页不再有未发布更改提示。公开首页显示本地化标题、简介与示例作品。
- 当前账号在游戏内发布《示例地图 · 水泊练兵》，作品 ID `3806632089`，类型标签 `Map`，含简中和英文说明及实机截图封面。[作品页](https://steamcommunity.com/sharedfiles/filedetails/?id=3806632089)可回读标题、说明、封面和订阅按钮。Steamworks 的“至少 1 个公开可见物品”清单已完成，“所有人可见”选项已解锁。
- 当前账号订阅该作品后，Steam 下载 `content.json`（21,983 字节）、`manifest.json`（38 字节）和 `preview.jpg`（32,856 字节），三文件 SHA-256 与游戏上传目录逐一相同。`content.json` 为 48×48 地图、两波、一个胜利条件与一个失败条件；游戏订阅列表显示“可游玩”，点击后实机进入关卡并打完两波，结算“旗开得胜／练兵完成”。
- 测试前完整备份当前玩家目录 172 文件、13,230,237 字节，逐文件 SHA-256 相等。测试后 `campaign.cfg`、`settings.cfg`、`language.cfg` 与备份哈希相同；云镜像状态文件有变化，尚未据此宣称跨设备同步通过。
- 四语公告 `694273194214817894` 于 18:15 CST 公开，关联 Build `25476210`，工坊页曝光开启；正文包含入口、编辑器、示例链接、接口修复和成就限制。公开 DOM 分别回读四语标题、正文与链接，简中页面目检排版。封面使用已有 `announcement_800x450.png`，Steam 对其他语言回退同图。
- 22:35 后不携带 Cookie 的工坊首页请求为 HTTP 200，包含标题、作品 `3806632089` 和公告。四语公告 HTTP 均为 200，公开响应 `logged_in=false`、`published=1`、`hidden=0`、`build_id=25476210`；对应正文成就说明和示例链接均匹配。已发布文案保存在 [announcement_public_copy.json](../../marketing/steam_workshop_20260923/announcement_public_copy.json)，不纳入原始网页中的账户或站点会话字段。

## 待完成

- 本机 Steam appmanifest 仍为 BetaKey `steam-integration`，Build/Manifest 与已上线 default 相同。恢复操作时 Steam 主窗口短暂出现后消失，重新枚举无可操作窗口，故未修改客户端分支。默认分支客户端切换仍待完成，不能与当前账号的同构建实战验收混为一项。
- 当前没有第二台 Steam 电脑或第二个测试账号，跨设备 Cloud 读回和跨账号工坊验收未做。本次当前账号的订阅与实战通过不替代这些检查。
- 示例据守内容仅为文案候选，尚未上传公开。

本批收尾只更新发布文档与作品封面来源，没有修改游戏代码或重新打包。GitHub 按白名单同步 stable 分支，排除无关 `assets/ui/items/health_potion.svg.import`、Steam 缓存、玩家数据和候选 ZIP。
