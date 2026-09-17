# 2026-09-15 四语补丁说明公开验证

Build25316671 上线后，用户要求每次发布都写补丁说明。本次通过该构建页内嵌表单发布一条“小型更新/补丁说明”，Steam返回“您的补丁说明已成功发布！”及公开链接。

- [简体中文](https://store.steampowered.com/news/app/5088120/view/714538122294068600?l=schinese)
- [繁体中文](https://store.steampowered.com/news/app/5088120/view/714538122294068600?l=tchinese)
- [English](https://store.steampowered.com/news/app/5088120/view/714538122294068600?l=english)
- [日本語](https://store.steampowered.com/news/app/5088120/view/714538122294068600?l=japanese)

四语表单各自切换回读，标题和完整正文均与[原文](notes.json)一致。发布后逐一访问四个公开URL，accessibility正文的标题及六个非空段落逐项匹配，共4个标题、24段正文通过。中文预览经截图目检，内容清晰、正常换行；平台显示发布时间2026-09-15 15:02 CST。

[发布收据](publication_receipt.json)记录平台成功提示、新闻条目714538122294068600及社区讨论关联562541966849777266。上述访问使用已登录浏览器，未另开退出登录会话，不声称匿名会话单独验证。未增加运行、客户端下载或真人试玩验收；构建来源及发布依据仍见[原构建QA](../steam_release_20260915/README.md)。

项目根AGENTS.md已固化每次授权Steam发布同时完成四语补丁说明的要求；交接文档与目录索引同步。本次只提交原文、说明与收据，不提交浏览器账户资料、构建包或缓存。
