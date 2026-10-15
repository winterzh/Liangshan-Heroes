# 施恩受击与倒地来源候选

9张内置ImageGen原生RGBA、9份完整请求，选择四向各2个受击/恢复姿势和四向各4个倒地姿势，共24姿势。目录`assets/characters/shi_en_reaction_20261015/`含`.gdignore`，未导入或接入生产游戏。原图完整保留，没有镜像、程序绘图、抠底、旋转站图或重写PNG像素。

SW受击初稿重复SE方向，原失败来源和请求保留在外部`D:/CodexTemp/shi_en_reaction_20261015/`；新SW v2使用原待机和SW攻击身份参考独立生成。NE倒地原第三帧只有一根明确落棒，该区域明确弃用；原其他三帧保留，新单帧NE fall补齐两根落棒。每项请求、参考、原PNG SHA和原区域RGBA SHA绑定在`source_manifest.json`。

采样预备阶段因靴子/落棒靠近分格线拒绝两次，原错误记录在`sampling_rejections.json`。边界移到实际透明间隙后，全部源前景被选择或明确弃用一次，24姿势完整留白、真透明和来源/参考链复核通过，没有放宽8像素实质alpha边距或改图。不同像素只能排除字节重复；姿态语义另直接看图。

`candidate_preview.html`支持受击/倒地切换和逐帧；六张`preview_*.png`为直接查看的浏览器画面。受击原图RGB看起来有底色雾光，但实测中间背景alpha=0、浏览器真实alpha合成没有该雾光；没有做背景删除。预览脚点只是来源布局，倒地枢轴、身体/双棒衔接、原受击/死亡回调及Godot/PCK/平台资格均未通过。

来源复核：`python -B tools/prepare_shi_en_reaction_candidates_20261015.py`；重建预览追加`--preview`。`source_verify_output.json`为实际复核输出，`verification_receipt.json`绑定工具/来源记录/截图。共享Godot仍由盲盒原生批占用；接入工作须串行。
