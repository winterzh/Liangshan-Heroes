# 阮小二携货推车原生验收

最终`20261017_220657_d23be53e`：基包＋真实导出补丁1365项/118图通过，157纹理尺寸/像素/mipmap保持，6768当前冻结输入/6602不可变owner零漂移，包内实际identity匹配。不是新导出单体完整PCK。工具在包外冻结核SHA，生产纹理/脚本/identity由挂载PCK读取；release仍排除tools。

`receipt.json`、`report.json`、各日志和`pack_chain.json`为原始证据；约1.25GB基包与8,046,408字节补丁原位保留，两者SHA在索引。最终因生产identity/派生常量/native依赖完全相同而复用已导出补丁，没有将“无改动可导出”当成功导出。

`attempts.json`保留三次前置失败的真实收据索引：初版加载器误查已被Godot移除的命令参数；第二次无新生产差异的export报错；异常退出遗留两份~DLL使第三次identity保护拒绝。`mount_diagnostic.log`及失败日志保留，最终不是借用失败批通过结论。两份临时副本经核对与正式库同SHA，逐文件移到证据目录保存，正式SDK未删改；见`hot_reload_tail_preserved.json`。模板同卷硬链接且原字节SHA保持。

64张重点原图直接查看（20近景/4真实行走/8停车受击挥刀/3取交掉货/4语言空手/20默认/4中距/1默认空手）。`screenshot_inventory.json`列完整118图路径/字节/SHA，`direct_review.json`列实际目检和欠项；`visual/`只复制4张原字节代表图，完整C盘原图不是缓存，跨机按索引取回校验后才能声称重看。背面B与过渡B脚型变化小、完整轮转/罩布连续性、旧受击血条遮头/敌方标签及浮字仍待打磨；三目标/肩挑与部分语言仍在。

`private_restore_archive.json`列旧候选6777 canonical输入（6393 Git+384 ZIP）、生成常量和36额外冻结QA工具恢复清单/ZIP路径/SHA；最初公孙胜6746 canonical输入另有首批变更前档案。内层编译树现为阮小二，不能称旧公孙胜源码原地不变；不可变owner和旧完整PCK保持，非新冷导入。完整ZIP/私有档案/SDK/PCK不进Git。

测试显式预设CARRY/drug前提、取景位置、冻结他人/关迷雾，实际物理移动/取货/伤害命中/交付/drop仍用原回调。强制交战/战败是游戏兼容分支，不是原著此处阮小二发生这些事件。不是完整酒计、全关自然游玩、全战役/续玩/性能/Steam或全美术验收。12个保护文件及81无关未跟踪文件收尾核验见`closeout.json`。[实现和复现](../../docs/RUAN_XIAOER_PUSHCART_20261017.md)。
