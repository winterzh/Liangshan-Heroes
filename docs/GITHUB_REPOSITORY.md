# GitHub 仓库约定

默认分支 main 提供项目首页和正式版源码入口。开发与验收提交同步至 codex/sync-20260905-stable。需同步 main 时，依项目约定先确认用户指示、核对两分支的祖先关系，再用快进同步已验收的提交。源码提交、Steam 构建号和 GitHub Release 各自记录。 [项目首页](../README.md) · [分支列表](https://github.com/winterzh/Liangshan-Heroes/branches)

- 玩家可从首页进入 Steam Windows 正式版，在更新记录查看构建和公告。GitHub Releases 提供历史安装包，版本和平台列在更新记录。
- 开发者从源码设置进入，按文档和 QA 索引查找设计、验证和发布证据。开发候选的验收范围以对应收据为准。 [源码设置](SOURCE_SETUP.md) · [文档索引](README.md) · [QA 索引](../qa/README.md)
- 代码和生产素材按白名单同步。Steam 的构建包、安装文件、账号缓存和玩家存档留在本地。 [Steam 发布指南](STEAM_RELEASE_GUIDE.md)
- GitHub 的仓库资料、权限和默认分支设置由仓库管理员管理。协作者负责已授权的代码推送和项目资料整理。

[更新记录](../CHANGELOG.md) · [历史仓库快照](../qa/github_organization_20261020/README.md)
