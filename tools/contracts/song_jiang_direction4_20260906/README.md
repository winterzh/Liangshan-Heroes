# 宋江四向来源记录

`generation.json` 保存45次实际内置 imagegen 调用的完整提示词、输入关系、输出文件名/尺寸/哈希与采用状态。采用的15张原生PNG直接保存在生产目录；17张中间参考在 `references/`，原项目身份参考继续指向已有QA文件。未被生产或参考链使用的候选只保留记录。

`pose_recipe.json` 是逐姿态的固定区域、原图脚锚/身体锚及虚拟方框尺寸；`assets/direction4/song_jiang_20260906.json` 保存实际导入尺寸、最终区域与偏移。`resource_builder.py.txt` 是本次资源/导入配置生成过程的文本证据，依赖当时的忽略暂存区，不能直接当作跨电脑一键重生成工具。普通拉取只需导入已提交的PNG与TRES，不需要再次生成图片。

本地仅原字节复制、Godot标准导入与资源排帧，没有程序修改PNG像素。部分PNG的透明区有隐藏RGB色，Godot合成按alpha正确显示；不得仅凭忽略alpha的原图预览判定已烘焙底色。SW迈步和NW身体朝向已逐项返工，生产帧排除了原错误SW格。旧项目身份图的早期来源仍独立待核实。

只读复核：`py -3 tools/song_jiang_direction4_sources.py`。实机及当前范围见 [实现说明](../../../docs/SONG_JIANG_DIRECTION4_20260906.md)。
