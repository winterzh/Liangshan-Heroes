# 2026-10-03 项目进度与开发计划同步

## 范围

用户要求先同步 GitHub 项目进度、列最新开发计划，再完整同步。本轮完成文档与仓库状态核对：新增 `docs/DEVELOPMENT_PLAN.md`，更新项目进度、WORKLOG、SOURCE_SETUP、DIRECTORY_INDEX、README、历史打磨路线、Steam 功能优先级和美术台账；随后在引擎空闲时完成原有大厅候选验证，将代码、工具及 [大厅 QA](../defense_hall_20261003/README.md) 一同同步。发布/QA 历史证据保留原字节；不打包、发布 Steam/Android 或操作 main。

## GitHub 核对

已核对仓库 `https://github.com/winterzh/Liangshan-Heroes.git`、目标 `codex/sync-20260905-stable`。开始时本地及远端 stable 均为 `f4402676b510d34bb2a516023c2616ab6fa36bdd`，领先/落后为 0/0；远端 main 为 `6cb12a192b2f10a5d951e923358bd2cca0a43b1d`（PR #6 合并），两分支内容树一致。执行 fetch 只更新远端引用，因工作区有候选未执行 pull、stash、reset。

本轮提交只包含本轮文档、`.gitattributes` 的新 QA 字节保护规则、两份大厅生产脚本、两份 QA 工具及两个新 QA 目录的明确文件。采用普通提交、推送 stable，不推 main 或重写历史。推后直接读取远端目标引用并比对本地提交；实际同步提交及远端回读结果在任务回复中给出，避免为把自身 SHA 写进文档而形成循环提交。

## 已验证并纳入同步的原本地候选

- `scripts/levels/skirmish.gd`
- `scripts/unit.gd`
- `tools/defense_hall_qa.gd`
- `tools/run_defense_hall_qa.py`

候选针对据守静态忠义堂/玩法建筑的外观与 UI 来源。初次只读预检返回 `files=3393`、`lock_busy=false`、`engine_busy=true`，引擎被其他项目占用；其自行释放引擎后开始原生验证。首轮自定义夹具空配置导致 6 项断言失败，修正为非空配置后最终 51/51 通过，3393 输入及私有副本零漂移，三张截图核对通过。原有两份生产修改与 Python 工具保持接续前字节，测试脚本只修正夹具配置；未终止其他进程或绕过独占保护。代码、工具及失败/最终证据均纳入本轮同步。

## 验证与限制

检查本轮新增/修改文档的相对链接、文档引用范围、进度对应发布收据、白名单暂存差异、文件大小和敏感内容；核验两份原生产修改/Python 工具未漂移以及测试脚本夹具修订的明确范围。记录见 [verification.json](verification.json)。游戏验证限大厅外观/HUD 及作用域，不冒称完整战斗、性能、战役续玩或设备验收。平台公开状态按历史最终收据表达，不把本次 GitHub 分支核对当成 Steam/Android 线上复验。

最新计划仍保留真实缺口：战役续玩未开放、呼延灼双铁鞭透明源未采用、核心通用四向不齐、严格尾帧与最终清理未过、Android 2.0.1 真机后验未入档。第二账号/跨设备未测但按用户决定不阻塞当前阶段。长测时长按用户约 10 分钟要求，不擅自恢复旧 30 分钟门槛。
