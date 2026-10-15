# 阮小七持枪身份与技能接入 QA

实际完整PCK 1363项检查、185张截图通过，5625份冻结来源在主工程和隔离工程均零变化。21张原生纹理核对，普通近战命中/受击/倒地、四方向实际四帧移动、三等级技能/个人增益到期、无额外普通伤害、四语言三尺寸HUD/实际悬停卡/图鉴/小传，以及实际黄泥冈旧商人身体与任务场景回归通过。源码同步与Steam发布分开，Steam未更新。

- `final_native/`：全新冻结批原始日志、输入、原生纹理参考、收据、报告及185张截图，按原字节复制，不包含PCK/缓存/DLL/档案。
- `adoption_receipt.json`：生产/执行器来源SHA、PCK哈希及明确未接受的范围；作者构建脚本只记录独立SHA，不冒称原生执行步骤。
- `raw_evidence_manifest.json`：复制原始证据SHA逐项核对；`generation_provenance.json`：内置生成与原PNG字节/引用链。
- `source_scope_review.json`、`definition_changes.json`、`localization_scope.json`：原生前的静态定义/翻译核对，保留当时待验标志。其他定义行/4522条旧翻译不变，新加9条映射；黄泥冈继承范围200→28。
- `translation_predicate_preflight/`：首轮1363项/185图，只有三条繁体名称误报；“截路重刺”简繁同形有效。只修正QA谓词，最终另起新批，并未为检查改译文。
- `visual_review.json`：直接看过的9张首轮实际PCK图与发现，不能把截图总数称逐张人工审核。

边界：后视接触步视觉相似，四个实际帧索引通过不等于完整步态自然度通过，下一批优先改善；商人阶段旧身体仍未完成原著身份统一。Battle/其他演员冻结、显式推进待结算是夹具。不是完整通关、完整存档恢复、竞技平衡、常态性能、正式EXE/live SDK、Steam或全美术完成。

复现：`python -X utf8 -B tools/run_ruan_xiaoqi_spear_20261016.py --run`，可设外部`--work-root`；作者只读核对`python -X utf8 -B tools/build_ruan_xiaoqi_canon_20261016.py`。原著来源与具体设计边界见[实现](../../docs/RUAN_XIAOQI_SPEAR_20261016.md)。

最终批另直接目检960图鉴及繁体R实际悬停卡2张，合计直接目检11张（首轮9/最终2）；全部185张不称逐张人工审过。
