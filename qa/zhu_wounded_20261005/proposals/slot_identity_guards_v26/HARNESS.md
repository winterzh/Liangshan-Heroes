# v26 原生纯验证 harness（尚未执行）

GD：`slot_identity_guards_v26.gd`，SHA `692ba575533e3d2180cccdb95338e47b79b891f52571f3ce47ed8f2b5bfdabba`；scene：`slot_identity_guards_v26.tscn`，SHA `75e01b69dc5ba28973b0707a7bd110cb087f009565dbfd82834bab93d3aecaad`。未来 producer bytecopy 到私有 frozen project 的 `tools/`，入口 `res://tools/slot_identity_guards_v26.tscn`。`fixtures_v26.json` wrapper SHA `f01d59be1352d1b05f68c08a948ff0adb817e290eb7929031ea6e88f9ba42b9d`，通过 manifest SHA env 固定；inner Matrix/source-pin 两文件及原/decimal payload SHA 另有 code 常量硬 pin，允许新 wrapper 只把读取路径指向同 SHA 的冻结副本，并报告实际读到的路径。

接口：SLOT_IDENTITY_PROFILE / REPORT / FIXTURES / FIXTURES_SHA256 / NONCE / ENGINE_SHA256 / EXPECT_CONTENT。PROFILE 必须是新私有 profile，APPDATA/LOCALAPPDATA/TEMP/TMP 为其对应子目录，Godot user data 必须落在该 APPDATA；STEAM_DISABLED=1、CAMPAIGN_QA=1。REPORT 为项目外新文件、父目录已存在。固定 producer 创建 fresh run/nonce/profile，导入并核对 full source/installed identity 后再运行本 pure process。

所有 134 个固定单叶负例各执行 source 与 json validator，report `cases` 必须恰好 268 行，不能用 minimum count。JSON route 是直接 `_validate_json_document` model call：base 来自真正 Godot JSON.parse 原 pending，Int 测试叶由 QA 明确构造，未声称 JSON.parse 保留整数。source base 为原 `_decode`→Slot JSON boundary 生成的 typed decodedDTO，**不是另一次 native World capture**。只使用原固定 boundary，核对恰好 196 ownership repairs、原完整 source validator。每 case 报 id/path/route、实际替换 typeof、精确 code、complete recursive equality、含所有 typeof/IEEE64/Dictionary order 的 before/after SHA、Slot source/payload SHA。所有其他字段也在构造单叶时全量比较。

纯正/控制项：原 pending full envelope decode 与每 UTF8 canonical byte 原样；parsed JSON ownership float 被 source 严拒；typed decodedDTO source 通过；原 decimal .0 文件及单点 Float0.0 波次 canonical record 仍 NONCANONICAL_RECORD；原 Float0.0 两处波次 document rule 在两route保留；payload SHA/byte count、envelope canonical、document generation mismatch 拒绝。输入 fixtures/source pins 全部独立回读，验证过程不创建 Slot目录，唯一写是新 report。没有 Battle/Unit factory、Session restore、deploy/tick、磁盘 Slot写。

报告 schema `slot_identity_guard_report_v26`，nonce/PID/actual user-data/content/engine、fixture/source/GD/scene pins 都回报。`pure_matrix_passed` 描述这批组件逻辑；exit0 也只表此组件结果。`passed=false`、`overall_qualified=false`、`qualification_complete=false` 和 `missing_required_stages` 有意固定：当前完整 classic槽正例/矩阵暂无真实fixture，原完整 OwnedSlot fault suite 应由 futureproducer独立运行，zero SCRIPT ERROR 是 futureproducer读整份 native log 才能证明。**不得用 component exit0 或 pure_matrix_passed 取代这些整体资格门禁**，原报告不覆写。

未来 producer 必须从全 log 拒绝 SCRIPT ERROR/Parse Error/ERROR，核对 process terminal exit0，全部检查为true、完整134ID×2route、精确code、类型/IEEE fingerprint、SHA/PIDnonce/profile/contentengine。缺 classic正例只能标 not_run；历史 Scenery组件不能伪造 wholeclassic资格；原 OwnedSlot全suite不能嵌造 passed。global资格必须另外在汇总收据确认所有 required stages。

当前 constant source pins 固定 v26 Slot `908f8591f012752b192278362b48a83f212a7e596727214b5b0734dce23bdbde` 与原 Core/其他依赖/OwnedSlot/tool/Provider。结合尚未apply v25 Core时须准备新的 reviewed immutable pin sibling，不能偷偷跳过 mismatch，也不能改已运行本文件。

目前仅做源/API模型和括号词法检查，**没有 GDScript native parse 或引擎执行**，未声称 native通过。HARNESS_STATIC收据记录 exact pins 与限定范围。
