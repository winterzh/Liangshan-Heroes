# 八关 Level 组件验证

最终批次：`20260908_182211_992a0be3`。**205项组件行为检查通过**。fresh import与component均退出0/错误0；profile_guard按预期退出2/错误0，错误profile在fixture创建前被拒绝且未写报告。源码基线`21d70bcf85f6cd7c8601dec110a84c54f01f59ba`加本批新文件。

复现：在开发工程执行`py -3.14 -X utf8 -B tools/run_campaign_level_state_qa.py --run`。默认只预检；测试使用共享引擎锁、私有profile、冻结生产依赖、fresh import，无Steam登录/写入。可通过`--work-root`指定真实绝对工作目录。

最终批次保存`report.json`、`receipt.json`、三份引擎日志、相关代码和主场景快照。receipt包含2945个冻结输入SHA，当前工程与冻结副本分别核对，5890次完整性检查及profile_guard不计入205项行为通过数。Godot4.6.3二进制SHA也已核验。导入缓存、profile和未压缩游戏项目只位于忽略的本地工作路径，未复制到本QA目录。

测试使用八个真实生产关卡类的独立实例与真实Unit类，覆盖继承声明审计、JSON中转、显式值、稳定ID引用/空位/有序嵌套、外部token、INF哨兵、版本与缺失引用、非法阶段/波次，以及禁止绑定活动或已挂载对象。固定引用池缺项、超长及高俅嵌套内层缺项均拒绝；动态escorts仍允许空数组。恢复只生成RefCounted关卡，不调用deploy/on_start。

**边界：**这不是完整关卡任务/奖励正确性、实战部署、跨进程世界续玩、Steam统计或真人验收。Mission、视觉工厂、Unit metadata对象引用、RNG和世界屏障尚由外层负责。完整审计见`docs/CAMPAIGN_RESUME_STATE_AUDIT_20260908.md`。

最早一次直接`--script`尝试因生产autoload解析时机失败，已由Node主场景取代；空检查报告不能作为PASS。正式批次采用runner退出码、错误日志、检查数量和源码hash四项共同判定。

历史批次`20260908_181217_518d3e1e`的152项未覆盖固定引用池缺项；`20260908_181947_939bf440`的205项已修正维度，但没有最后的profile_guard负向进程。两批原始证据保留，当前结论仅采用上述最终批次，runner现在要求至少200项行为检查。

最终独立复核回读205项及三份日志，并重新核对当前工程、冻结副本和归档快照。完整来源指纹、零差异结果及全部批次证据指纹见`final_review_20260908.json`；此次复核未重新启动引擎，也未改动已测试的三个源码。
