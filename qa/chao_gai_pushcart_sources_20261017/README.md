# 晁盖推车原稿选格检查（2026-10-17）

内置imagegen生成12份原PNG，逐字节入库，27引用SHA核对；181项来源/选格检查通过。待机与四阶段步态共20个明确视图来自7份PNG。未运行Godot、未导出或接入生产，不能作为原生、动作连续性或全美术验收。

4份原PNG仍有全图角点alpha=1，报告逐一列出，`full_selected_atlases_zero_corner_alpha_passed=false`。没有把这些图说成整张干净，也没有脚本清理像素。passing B选SE/NE自v5、SW自v4、NW自v2；这20个实际选格角点均为0，角色/换脚/握把目检按格绑定。未选的方向或区域未采用，原稿与完整提示词仍保留。Godot后续需要单独验证Atlas边缘/mipmap、固定车轮、人物比例、真实行动及卸货/drop，不能由当前选格报告替代。

退回稿包括悬空手、A/B重复腿型和透明角点不足。不会复用刘唐的人物像素；刘唐图只作为车和已核对的腿型参考，最终人物仍是晁盖的棕巾/黑须/赤膊/灰裤/草鞋。现有生产仅刘唐推车与劫取后落地车已采用，当前本批不改变生产或Steam。

复核：`python -X utf8 -B tools/verify_chao_gai_pushcart_sources_20261017.py`。原图与完整提示词在`assets/characters/chao_gai_pushcart_sources_20261017/`；上层.gitignore之外仍用.gdignore隔离Godot导入。只读工具不生成或写入PNG。
