# Steamworks 配置发布，2026-09-07

本批通过正常浏览器表单完成60张生产成就图标上传并逐项保存，沿用用户已给出的后台配置发布授权。App为5088120，属于配置发布；本批没有上传新包或更改构建分支。

## 发布及回读

- 发布前：4个INT统计、30个API名称、中英文名称/说明与10个累计阈值核对一致。图标在刷新页面后仍为30对，英文与中文页面对应URL一致。
- 待发布范围为stats/community/policies/depots/ufs/common，与既有已授权草稿一致。Workshop Depot为5088120；Cloud文件数20→1000，原字节配额1,000,000,000、无AutoCloud路径及动态同步原状保持；语言为english/schinese。
- 预检查显示`You're ready to publish now.`。正常完成确认后回读`Publish to steam OK`、`Publishing successful!`和“祝贺！您的改动现已上线。”。
- [玩家成就页面](https://steamcommunity.com/stats/5088120/achievements/?l=schinese)显示总成就30，全部中文标题和说明可读。页面60个成就JPEG全部加载，均256×256，文件名顺序与后台逐项回读一致；另有1张商店胶囊图，不计入成就数。
- [构建页](https://partner.steamgames.com/apps/builds/5088120)发布后独立回读：default为25154403，steam-integration为25160280；本批未修改两者。测试包来源仍为d4728d4，不能当925d03f或后续源码已经入包。

逐项后台/玩家页面JPEG文件名在`icon_readback.tsv`；Steam正常上传将本地PNG转为JPEG，文件名仅记录服务端资源标识，不冒充下载后重新计算的SHA。`page_observation.json`保留操作观察范围、各项核对和本地原图SHA。记录来自浏览器页面及DOM回读，不是原始HTTP响应。公开页面以当前浏览器会话读取；独立网页读取工具未成功，不宣称退出登录的匿名访问验证。

## 尚未验收

工坊保持“仅限开发人员”；ISteamUGC、立即可用内容、Map/Defense分类和中英文说明已核对。品牌图和真实作品未完成；测试组及第二个可用账号已向用户询问，收到后再做订阅/更新/取消订阅/坏包和账号隔离。真实Steam客户端初始化、Overlay、正常条件解锁、离线回连/重试及存档跨进程统计仍未验收。本批不向账号发放测试成就或统计。

第一次文件选择超时来自编辑后API名称变为input值、旧hasText定位未命中；按实际行ID重定位后正常chooser可用。三行批处理超时后按已保存状态续传，没有盲目重建条目。页面导出功能在此Edge会话不受支持，因此只保存与任务相关的脱敏观察，不保存含登录账户或分支口令的整页内容。
