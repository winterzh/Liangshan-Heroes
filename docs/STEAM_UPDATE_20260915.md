# 2026-09-15 Windows Steam 更新：祝家庄补员引导

用户明确要求“发布steam”。目标 App5088120 / Windows Depot5088121 / default。固定生产来源 `dd4046fdfd398fec43d992cb315982da35de0c2c`；网页核实此前 default 为 Build25290621 / Manifest53262799732835110。当前发布状态见[发布收据](../qa/steam_release_20260915/publication_receipt.json)。

## 本次内容

- 祝家庄普通士兵损失后显示补员提示，并区分训练中、出口受阻、资源/人口不足、研究/建设中及无兵营/工人等状态。
- “查看 · 兵营”“查看 · 前营”只移动镜头，保留当前选择和命令；补回普通兵、目标可收军或战斗结束时收起。
- 简中、繁中、英语、日语同步，英语面板避开较高顶栏。

相对线上50558b05生产基线，运行内容只涉及新提示、关卡接入、本地化目录和已单独提交的默认关闭资源观察钩/等值退款封装。三计划测试工具、设计文档、截图和日志不进入发行包。经济、伤害、训练时长和关卡路线未调；玩家中途保存/继续入口保持原有隐藏状态。

## 验证与范围

沿项目现有流程执行独立源码/profile的原生Steam整合QA、Windows导出、包内脚本/本地化/原生依赖检查、源码与PCK内容身份检查、实际EXE串行短测。额外通过编辑器宿主挂载本次实际EXE内嵌PCK，检查补员面板自动接入、四语词条、定位信号、正常招募/撤单及终局隐藏。

包内专项是冻结状态夹具和按钮信号检查，不声称OS鼠标、自然接敌或真人理解通过；此前250项自然恢复/边界检查和11张源码截图目检保持[原有证据范围](../qa/zhujiazhuang_recovery_20260915/README.md)，不重复计为本轮完整EXE画面验收。实际EXE短测覆盖启动与预设断言，不等于八关完整通关、性能长跑、客户端下载或真实Steam持久写入。

本次使用六个根文件的Windows标准ZIP，不修改macOS Depot、其他Steamworks未发布设置或商店页面，也未发布新公告。构建、上传副本哈希、服务器文件与default回读在[QA记录](../qa/steam_release_20260915/README.md)分别记录。

## 当前交付状态

**已正式上线**：Steam成功提示与default分支均回读为 **Build25316671**，Windows Depot5088121 / Manifest **7776799335954834384**。服务器六成员名称、字节数及SHA1全部匹配已验证候选；磁盘326741403字节、压缩250198816字节，Steam预计从上一版更新下载 **5.7 MB**。

用户完成手动上传后，新Build已出现在构建页。本轮完成服务器核对和default上线；macos仍为0、steam-integration仍为25179481，其他Steamworks未发布设置和公告未改。原等待选文件阶段保留于 [publication_before_upload.json](../qa/steam_release_20260915/publication_before_upload.json)，候选创建时的历史状态保留不回写。最终 [publication_receipt.json](../qa/steam_release_20260915/publication_receipt.json) 与 [服务器核对](../qa/steam_release_20260915/server_manifest_verification.json) 为本轮交付依据。未追加客户端下载试玩或真实Steam持久写入验收。
