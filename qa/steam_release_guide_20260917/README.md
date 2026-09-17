# Steam 发布指南文档 QA（2026-09-17）

本批只新增项目级 Steam Windows 更新发布指南并更新交接索引，不构建候选、不上传 Steam、不切换 `default`、不发布公告。

## 覆盖范围

- 新增 `docs/STEAM_RELEASE_GUIDE.md`。
- 固定 App `5088120`、Windows Depot `5088121`、正式分支 `default/public` 与六文件发布白名单。
- 将候选 QA、Steamworks 网页 ZIP、SteamCMD Preview/Upload、Set Live、手机确认、四语公告、服务端/客户端回验和回滚写成独立阶段。
- 明确发布授权边界，以及本地候选、Depot 上传、正式上线、公告公开、客户端验收和真人验收之间不能互相替代。
- 更新 `docs/WORKLOG.md`、`docs/SOURCE_SETUP.md`、`docs/DIRECTORY_INDEX.md`。

## 文档核对

- 指南中的候选构建命令来自当前 `tools/run_steam_integration_qa.py` 与 `tools/build_steam_candidate.py` 参数。
- 六成员名称与最近发布候选收据一致。
- App / Depot 标识与现有正式发布记录一致。
- SteamCMD VDF 示例沿用已成功发布批次的显式六文件映射，并将路径、描述、账号全部改为占位符。
- 没有写入密码、令牌、Steam 登录缓存、玩家数据或发行 ZIP。
- 指南没有宣称 2026-09-16 候选已上传或上线，只把其 README 作为开始操作前必须重新核对的历史入口。

实际复核结果：

- `qa/steam_release_20260916/candidate_delivery.json` 成员名与指南白名单 `6/6` 一致；
- 新增指南与本 QA 内部 Markdown 链接缺失数为 `0`；
- 三个 Steam 官方参考链接当前 HTTP 状态均为 `200`；
- `git diff --check` 通过；
- 敏感词与已知本机 Steam 账号标识扫描未发现真实凭据。

## 验证边界

本批验证的是 Markdown 内容、项目内链接、固定标识和命令入口的一致性。未运行 Godot 或 SteamCMD；文档变化不修改游戏运行内容，不能作为候选包、Steam 服务端、客户端或真人验收证据。
