# 四向固定矩形候选检查（2026-09-02）

本批只写 QA 候选，没有修改 `assets/`，也没有修改 Steam 发布目录。

`direction4_web_art_slice.py` 已停止提供连通域归属清零功能，改为固定矩形候选管线入口。`direction4_web_state_slice.py` 也已移除 `components` 模式，只保留完整透明网格切片。新工具的连通域仅做只读完整性验证，不参与图片像素处理。

正式入口现在并列支持旧的 `transparent_grid_v1` 和候选专用的 `fixed_cell_rect_v1`。固定矩形工具另支持 `fixed_direction_row_rect_v1` 四向单行覆盖候选。三者都不得遮罩、清零、镜像、补画或局部改方向；两种固定矩形路径没有生产提交能力。

十张基础网页原图生成 160 帧，另有一张通用武松双戒刀四向攻击覆盖行，共保存 164 个 QA 输出；覆盖后有效矩阵仍是 160 帧：

- 164/164 固定矩形完整保留本格大主体；
- 外来大主体可见像素总数为 0；
- 164/164 脚、马蹄或倒地最低接触点落到输出 Y=210；
- 164/164 输出画布四边 alpha 最大值为 0；
- 逐行使用同一缩放比例，每帧记录原始 SHA、会话 URL、基础及修正提示词 SHA、裁切矩形、缩放、补边、输出 SHA 和像素来源证明；
- 近景检查未见人物、兵器和马匹裁断，四向没有镜像代替；
- 164/164 输出的低透明高色差像素超过当前人工复核阈值，主要为红色描边；只记录，不清除，也不自动采用；
- 正式报告中的生产 `assets/` 快照在验证前后相同。

英雄攻击第三稿的 4×4 几何候选完整，但其中徒手武松行不再作为通用 attack 最终候选。新的一行四列原图为同一后期行者武松四向拔双戒刀攻击，四格人物和双刀完整、相互隔离、方向独立，已作为通用 `wu_song` attack 覆盖候选。第一稿的动作身份不符、第二稿的跨格证据仍保留在 provenance 中。

英雄受伤第二稿和兵种受伤第二稿重排后均通过固定矩形完整性检查。英雄图保留林冲长兵器以及武松四向双戒刀连鞘；兵种图保留朴刀、刀盾、钩镰和连环甲马的骑手、马甲与长兵器。两张第一稿的跨格 bbox 和像素证据仍保留为历史阻断记录。

倒地两图继续使用 `lowest_contact` 锚点；武松四向双戒刀鞘、连环甲马骑手和马具均保留。以上结论只覆盖几何完整性、动作可辨和指定装备一致性，原著服饰与装备终审以及彩边人工复核尚未完成。

本批通用英雄图还有明确的战役造型禁用范围。新双刀覆盖行和其余武松行都是后期行者装，不能覆盖快活林 `wu_song_mengzhou`；醉打蒋门神时期应是万字头巾、土色布衫、红绢搭膊、腿绷护膝、八搭麻鞋，且尚未扮行者。通用武装林冲也不能覆盖野猪林的 `lin_chong_bound`、`lin_chong_prisoner` 或 `lin_chong_escort`。因此不能把英雄图整套批准到这些剧情变体。

运行时映射仍有两项生产硬阻断：两张 `down` 设计图按当前冻结批次输出为 `death` 状态和 `*_death_{direction}.png`，通用素材查询不会在 `down` 与 `death` 间互转；两张通用 `hurt` 图虽然通过几何检查，但 `Unit` 当前只在 `art_variant` 非空时选择受伤方向帧。这两项修好并复测以前，候选不能进入生产。

候选没有复制到 `assets/anim`，也没有进入 Steam 构建。

证据：

- `qa/direction4_fixed_crop_20260902/summary.json`
- `qa/direction4_fixed_crop_20260902/formal_candidate_intake_report.json`
- `qa/direction4_fixed_crop_20260902/heroes_manifest.json`
- `qa/direction4_fixed_crop_20260902/troops_manifest.json`
- `qa/direction4_fixed_crop_20260902/heroes_walk_manifest.json`
- `qa/direction4_fixed_crop_20260902/troops_walk_manifest.json`
- `qa/direction4_fixed_crop_20260902/heroes_attack_manifest.json`
- `qa/direction4_fixed_crop_20260902/troops_attack_manifest.json`
- `qa/direction4_fixed_crop_20260902/heroes_hurt_manifest.json`
- `qa/direction4_fixed_crop_20260902/troops_hurt_manifest.json`
- `qa/direction4_fixed_crop_20260902/heroes_down_manifest.json`
- `qa/direction4_fixed_crop_20260902/troops_down_manifest.json`
- `qa/direction4_fixed_crop_20260902/wu_song_attack_double_blades_manifest.json`
- 十张基础 `*_contact.jpg` 与 `wu_song_attack_double_blades_contact.jpg` 近景拼图
