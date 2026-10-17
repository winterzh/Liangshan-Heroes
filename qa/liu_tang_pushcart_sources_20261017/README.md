# 刘唐推车原稿来源检查（2026-10-17）

内置 imagegen 生成/编辑11份原图，当前5张候选、2张因未明显换脚退回、4张被后续修订替代。所有11份原PNG字节/解码、14份引用SHA和81项无关输入保持；5当前候选的严格角点零alpha通过。3份替代稿保留alpha1失败，不抹除或当作候选使用。10份原稿时的失败报告保存在[source_check_10_before_idle_v3.json](source_check_10_before_idle_v3.json)。当前检查见[source_check.json](source_check.json)。

只读复现：`python -X utf8 -B tools/verify_liu_tang_pushcart_sources_20261017.py`。工具区分当前候选与被退回/替代的原稿。预览中饱和红RGB像素均没有alpha高于8者，不能仅据预览认定原生有不透明红边；实际合成仍待Godot验证。透明缝诊断仅供后续采样校准，不是完整图集合格结论。

第16回写七人将十一担财物装入七辆江州车、遮盖后推走。现有游戏仍为三担肩挑，本批未改生产表现、文案或数量抽象。车轮/载架结构、布色和绑绳是美术设计，没有复用白胜挑酒姿势。尚未接入资源或运行Godot，四向换脚/手把、连续性、轮转、脚点、显示尺寸待原生验收。[范围](../../docs/LIU_TANG_PUSHCART_SOURCES_20261017.md)。
