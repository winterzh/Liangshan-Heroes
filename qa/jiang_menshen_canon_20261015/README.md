# 蒋门神原著外观与图鉴布局验证

最终批`20261015_173027_15076f01`：316项检查、41张图通过，5292份主工程/隔离来源零变化；导入、解析、参考纹理、完整PCK导出、原生OpenGL窗口均退出0、错误0。最终采用依据为`final_native/receipt.json`与`final_native/visual/report.json`，不是下方中间批。

PCK为900650436字节，SHA-256为`90e667dda7401e6870413850d4ade35130d2c93020bda51adee84d6fc4608b23`。原包留在工程外执行目录，不进入Git。`raw_evidence_manifest.json`核对50份原始记录/画面，全部41图与原report SHA相符；`production_binding.json`与`visual_review.json`分别记录最终冻结绑定和11张代表图目检。

## 采用范围

- 内置imagegen原生头像一张，采用白布衫、黄髯、紫褐肤色、青筋、粗貌怪眼；发式与具体五官为保守设计。
- 普通蒋门神复用既有剧情五状态四方向20张身体；与既有清单逐份SHA一致，没有新制作完整多帧步态。
- 普通出拳不再叠画按射程推断的枪刺白线；战斗定义、伤害和命中节奏不变。
- 图鉴预览窄窗自动换行，原文字按可用宽度折行；保持232像素图框，沿用详情滚动。

## 证据

`original_text_review.json`保存回目、身份合同、20张身体与采用清单的SHA核对及逐图目检范围。原生头像、完整提示词和参考SHA位于`assets/characters/jiang_menshen_canon_sources_20261015/`。

`rejected_first_visual/`保留原252项技术通过的receipt/report及原出拳截图；该批因目检发现枪刺白线判退，没有改写raw report中的技术通过状态。`review.json`单独记录不采用的理由。

`intermediate_layout_pass/`保留第二批276项/33图通过的原收据与报告。之后清理重复赋值、明确FlowContainer间距并增加共享图鉴样本，因此它不替代最终冻结源码的验证。

## 明确边界

原始NPC、友军、地形和Battle模拟冻结；图鉴选择、敌方查看和告饶回调由真实对象API驱动，非鼠标完整通关。普通移动由原Unit物理处理执行；出拳是纯表演fixture，死亡为实际受伤进入死亡状态的局部采样，不证明整场战斗或完整死亡序列。没有发布EXE、live SDK、Steam、性能、触屏/Android、全人物/全语言或全库美术通过声明。

施恩无须造型与第二十八回三绺髭须的冲突、毒系玩法改编和张团练身份卡仍开放。详见[本批实现](../../docs/JIANG_MENSHEN_CANON_20261015.md)。
