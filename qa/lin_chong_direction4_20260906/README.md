# 林冲四向接入 QA

本批7张原生RGBA、32个独立姿态、20个SpriteFrames，基础五状态四向。`summary.json`列出1,393项本批检查、另248项现有宋江来源工具回归、两套资源复现和全库盘点。`receipt.json`保存实际输入/生产清单/相关证据SHA；最终提交以Git分支回读为准。

- [真实Unit四向矩阵](runtime/unit_pose_matrix.png)：站立、两张迈步、收枪、刺枪、受击和两段终态；不是逐帧视频或真人手感结论。
- [实际出枪](runtime/live_melee.png)与[报告](runtime/report.json)：真实命令、命中帧、受击和死亡释放。截图使用高缩放与固定测试配置，不作为稳定帧率证据。
- [剧情服装矩阵](regressions/terminal/costume_matrix.png)：新增通用披甲动作后，囚服等剧情角色实际死亡仍保持本期服装。
- [正门近景](regressions/gate/main_close.png)、[偏门近景](regressions/gate/side_close.png)、[两门远景](regressions/gate/both_wide.png)：复查原门墙修复，本批没有更换墙材。
- `native_audit.json`：237项原生字节、透明、导入、来源链和无串格审计；人体与朝向另经图形复查。
- `import_*.log`：独立最小Godot工程的7张图导入与实际纹理尺寸；只把选定导入配置和缓存供本地验证，缓存没有提交。
- `regressions/`：剧情终态、宋江、门墙、孙立接应、战役素材、驻守路由与全库盘点；夹具生成的空/错误资源不作为生产资源保存。
- `integration_grid.json`、`integration_chase.json`：快进整合其他已推送修改前后，本轮未完成路径的哈希保持记录。

当前全库文件覆盖26/9/9/7，驻守敌军idle709/778。数字不代表全库五状态已完成，也不代表真人八关、30波、长期性能、来源历史或发行验收已通过。复现和完整边界见 [实现说明](../../docs/LIN_CHONG_DIRECTION4_20260906.md)。
